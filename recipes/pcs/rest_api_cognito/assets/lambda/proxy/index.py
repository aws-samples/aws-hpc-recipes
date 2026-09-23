# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0
"""Cognito -> slurmrestd proxy Lambda for the rest_api_cognito recipe.

API Gateway's built-in Cognito authorizer verifies the caller and hands this
function the caller's POSIX identity as token claims. The proxy mints the
enriched HS256 JWT that slurmrestd requires (signing key discovered at runtime
from the PCS cluster's Secrets Manager secret) and forwards the request to the
private slurmrestd endpoint on port 6820.

Dependencies (PyJWT) are installed at deploy time by CodeBuild; see the
LambdaBuilder resources in proxy-cognito.yaml. Nothing is vendored into the repo.
"""
import base64
import json
import os
import time
from urllib.parse import urlencode

import boto3
import jwt  # PyJWT, installed at deploy by CodeBuild
import urllib3

# Module-level state, evaluated once per warm container.
_cache = {}
_http = urllib3.PoolManager()
_JWT_EXPIRY = int(os.environ.get("JWT_EXPIRY_SECONDS", "120"))


def _load_cluster():
    if _cache.get("loaded"):
        return
    pcs = boto3.client("pcs")
    cluster = pcs.get_cluster(clusterIdentifier=os.environ["CLUSTER_ID"])["cluster"]

    # slurmrestd endpoint. Re-resolved on a self-heal (see the forward-failure
    # path in handler), because a controller cycle can move it to a new IP.
    endpoint = None
    for ep in cluster.get("endpoints", []):
        if ep.get("type") == "SLURMRESTD":
            endpoint = ep
            break
    if endpoint is None:
        raise RuntimeError("No SLURMRESTD endpoint on cluster")
    _cache["ip"] = endpoint["privateIpAddress"]
    _cache["port"] = endpoint["port"]

    # JWT signing key: jwtAuth.jwtKey (NOT authKey, the daemon secret). Fetch it
    # only once -- it does not change when slurmrestd moves, so a self-heal
    # re-resolve keeps the cached key and skips this GetSecretValue.
    if "key_bytes" not in _cache:
        jwt_key = cluster["slurmConfiguration"]["jwtAuth"]["jwtKey"]
        secret_arn = jwt_key["secretArn"]
        secret_version = jwt_key.get("secretVersion")
        sm = boto3.client("secretsmanager")
        kwargs = {"SecretId": secret_arn}
        if secret_version:
            kwargs["VersionId"] = secret_version
        secret_string = sm.get_secret_value(**kwargs)["SecretString"]
        _cache["key_bytes"] = base64.b64decode(secret_string)

    _cache["loaded"] = True


def _error(status, message):
    return {
        "statusCode": status,
        "headers": {"Content-Type": "application/json"},
        "body": json.dumps({"error": message}),
    }


def handler(event, context):
    try:
        _load_cluster()
    except Exception as exc:  # noqa: BLE001
        return _error(502, f"Failed to resolve cluster configuration: {exc}")

    request_context = event.get("requestContext") or {}
    authorizer = request_context.get("authorizer") or {}
    claims = authorizer.get("claims") or {}

    # Only an ID token carries the POSIX custom attributes, and the API Gateway
    # authorizer is configured to accept only ID tokens -- so in practice this
    # holds. Assert it anyway rather than trust the configuration: if the
    # authorizer were reconfigured, or some future token type carried these
    # claims, the proxy would otherwise mint an identity from it silently.
    token_use = claims.get("token_use")
    if token_use != "id":
        return _error(403, "Caller must present a Cognito ID token")

    try:
        uid = int(claims["custom:uid"])
        gid = int(claims["custom:gid"])
        gids = [int(x) for x in claims.get("custom:gids", "").split(",") if x]
        username = claims["cognito:username"]
    except (KeyError, ValueError) as exc:
        return _error(400, f"Missing or invalid identity claim: {exc}")

    # Defense in depth: never mint a privileged identity, even if a claim asserts
    # one. The pool marks these attributes immutable so a user cannot self-raise
    # them, but the proxy is the last gate: the JWT it signs is fully trusted by
    # slurmrestd, so refuse system ranges here regardless of what the token
    # carries. 1000 is the conventional first-unprivileged uid/gid.
    MIN_ID = 1000
    if uid < MIN_ID or gid < MIN_ID or any(g < MIN_ID for g in gids):
        return _error(403, "Refusing to mint a system/privileged identity")
    gecos = claims.get("custom:gecos", "")
    home = claims.get("custom:home", "")

    now = int(time.time())
    payload = {
        "exp": now + _JWT_EXPIRY,
        "iat": now,
        "sun": username,
        "uid": uid,
        "gid": gid,
        "id": {
            # Slurm's parse_identity_from_jwt discards an incomplete nested id
            # object, which fails job submit with a 1007 protocol authentication
            # error even though the signature is valid and /ping succeeds. The
            # username (name) must be present here.
            "name": username,
            "gecos": gecos,
            "dir": home,
            "shell": "/bin/bash",
            "gids": gids,
        },
    }
    # PyJWT signs HS256 with the raw key bytes; the mint is a cheap local HMAC.
    token = jwt.encode(payload, _cache["key_bytes"], algorithm="HS256")

    # Forward verbatim: the caller chooses the Slurm API version segment.
    path = event.get("path", "/")
    method = event.get("httpMethod", "GET")
    body = event.get("body")
    if isinstance(body, str):
        body = body.encode("utf-8")
    query = event.get("queryStringParameters") or {}
    url = f"http://{_cache['ip']}:{_cache['port']}{path}"
    if query:
        url = url + "?" + urlencode(query)

    # OVERWRITE any inbound Authorization (the caller's Cognito token): never
    # forward it. slurmrestd gets only the minted Slurm JWT.
    headers = {
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json",
    }
    try:
        resp = _http.request(
            method,
            url,
            body=body,
            headers=headers,
            timeout=urllib3.Timeout(connect=5.0, read=25.0),
            retries=False,
        )
    except Exception as exc:  # noqa: BLE001
        # Invalidate only the endpoint so the next invocation re-resolves the
        # slurmrestd IP/port via GetCluster (self-heals after a controller cycle
        # moves slurmrestd). Keep the cached signing key -- it is unchanged, so
        # there is no need to re-fetch the secret.
        for key in ("ip", "port", "loaded"):
            _cache.pop(key, None)
        return _error(
            504,
            "Failed to reach slurmrestd. Check that the cluster security group "
            f"allows TCP 6820 from the proxy Lambda: {exc}",
        )
    return {
        "statusCode": resp.status,
        "headers": {
            "Content-Type": resp.headers.get("Content-Type", "application/json")
        },
        "body": resp.data.decode("utf-8", "replace"),
    }
