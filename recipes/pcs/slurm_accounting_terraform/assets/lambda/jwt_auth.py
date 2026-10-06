import base64
import hashlib
import hmac
import json


def _base64url(value):
    return base64.urlsafe_b64encode(value).rstrip(b"=").decode("ascii")


def decode_signing_key(secret):
    if "SecretString" in secret:
        encoded_key = secret["SecretString"].strip()
        try:
            return base64.b64decode(encoded_key, validate=True)
        except (ValueError, TypeError) as error:
            raise ValueError("JWT SecretString is not valid base64") from error

    if "SecretBinary" in secret:
        value = secret["SecretBinary"]
        return value if isinstance(value, bytes) else base64.b64decode(value)

    raise ValueError("JWT secret has neither SecretString nor SecretBinary")


def create_root_jwt(signing_key, now, ttl_seconds):
    header = {"alg": "HS256", "typ": "JWT"}
    payload = {
        "exp": now + ttl_seconds,
        "iat": now,
        "sun": "root",
        "uid": 0,
        "gid": 0,
        "id": {
            "gecos": "root",
            "dir": "/root",
            "gids": [0],
            "shell": "/bin/bash",
        },
    }

    segments = [
        _base64url(
            json.dumps(header, separators=(",", ":"), sort_keys=True).encode("utf-8")
        ),
        _base64url(
            json.dumps(payload, separators=(",", ":"), sort_keys=True).encode("utf-8")
        ),
    ]
    signing_input = ".".join(segments).encode("ascii")
    signature = hmac.new(signing_key, signing_input, hashlib.sha256).digest()
    return ".".join([*segments, _base64url(signature)])
