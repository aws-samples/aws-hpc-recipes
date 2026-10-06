import hashlib
import json
import logging
import os
import time
from copy import deepcopy

from configuration import (
    RESOURCE_TYPES,
    normalize_configuration,
    order_account_associations,
)
from jwt_auth import create_root_jwt, decode_signing_key
from slurm_rest import SlurmRestClient, find_endpoint


LOGGER = logging.getLogger()
LOGGER.setLevel(logging.INFO)


def _validate_cluster(cluster):
    if cluster.get("status") != "ACTIVE":
        raise RuntimeError(f"PCS cluster is {cluster.get('status')}, not ACTIVE")

    slurm_configuration = cluster.get("slurmConfiguration", {})
    if slurm_configuration.get("accounting", {}).get("mode") != "STANDARD":
        raise RuntimeError("PCS cluster accounting mode is not STANDARD")
    if slurm_configuration.get("slurmRest", {}).get("mode") != "STANDARD":
        raise RuntimeError("PCS cluster Slurm REST mode is not STANDARD")

    jwt_key = slurm_configuration.get("jwtAuth", {}).get("jwtKey")
    if not isinstance(jwt_key, dict) or not jwt_key.get("secretArn"):
        raise RuntimeError("PCS cluster does not expose a JWT signing key")
    return jwt_key


def _get_secret(secrets_manager, jwt_key):
    arguments = {"SecretId": jwt_key["secretArn"]}
    if jwt_key.get("secretVersion"):
        arguments["VersionId"] = jwt_key["secretVersion"]
    return secrets_manager.get_secret_value(**arguments)


def _ordered_associations(configuration):
    account_associations = order_account_associations(
        [
            association
            for association in configuration["associations"]
            if association["user"] is None
        ]
    )
    user_associations = [
        association
        for association in configuration["associations"]
        if association["user"] is not None
    ]
    return [*account_associations, *user_associations]


def _upsert_phases(configuration):
    phases = []
    if configuration["qos"]:
        qos_records = deepcopy(configuration["qos"])
        preemption_records = []
        for qos in qos_records:
            preempt = qos.get("preempt", {})
            if "list" not in preempt:
                continue
            preemption_records.append(
                {
                    "name": qos["name"],
                    "preempt": {"list": preempt.pop("list")},
                }
            )
            if not preempt:
                qos.pop("preempt")

        phases.append(
            (
                "qos",
                qos_records,
                "Upsert QOS records",
            )
        )
        if preemption_records:
            phases.append(
                (
                    "qos",
                    preemption_records,
                    "Upsert QOS preemption relationships",
                )
            )

    for resource_name in ("accounts", "users", "wckeys"):
        records = configuration[resource_name]
        if records:
            phases.append(
                (
                    resource_name,
                    records,
                    f"Upsert Slurm {resource_name}",
                )
            )

    associations = _ordered_associations(configuration)
    if associations:
        phases.append(
            (
                "associations",
                associations,
                "Upsert Slurm associations",
            )
        )
    return phases


def _run_bootstrap(
    event,
    pcs,
    secrets_manager,
    cluster_identifier,
    preferred_api_version,
    ttl_seconds,
    timeout_seconds,
    retries,
    now=None,
):
    cluster = pcs.get_cluster(clusterIdentifier=cluster_identifier)["cluster"]
    jwt_key = _validate_cluster(cluster)
    configuration = normalize_configuration(event, cluster["name"])
    upsert_phases = _upsert_phases(configuration)
    required_upserts = sorted(
        {resource_name for resource_name, _, _ in upsert_phases}
    )
    if configuration["coordinators"]:
        required_upserts = sorted({*required_upserts, "accounts"})

    signing_key = decode_signing_key(
        _get_secret(secrets_manager, jwt_key)
    )
    token = create_root_jwt(
        signing_key,
        now=int(time.time()) if now is None else now,
        ttl_seconds=ttl_seconds,
    )
    rest = SlurmRestClient(
        find_endpoint(cluster, "SLURMRESTD"),
        token,
        timeout_seconds,
        retries,
    )
    api_version = rest.verify_connectivity(
        preferred_api_version,
        required_upserts,
    )

    for resource_name, records, operation in upsert_phases:
        rest.upsert(
            api_version,
            resource_name,
            records,
            operation,
        )

    if configuration["coordinators"]:
        rest.add_account_coordinators(
            api_version,
            configuration["coordinators"],
        )

    upserted = {
        record_type: len(configuration[record_type])
        for record_type in RESOURCE_TYPES
    }
    upserted["wckeys"] = len(configuration["wckeys"])
    upserted["coordinators"] = sum(
        len(record["users"])
        for record in configuration["coordinators"]
    )
    configuration_sha = hashlib.sha256(
        json.dumps(
            event,
            separators=(",", ":"),
            sort_keys=True,
        ).encode("utf-8")
    ).hexdigest()
    LOGGER.info(
        "Slurm accounting bootstrap completed",
        extra={
            "cluster_id": cluster["id"],
            "api_version": api_version,
            "configuration_sha256": configuration_sha,
            "upserted": upserted,
        },
    )
    return {
        "status": "SUCCEEDED",
        "cluster": {
            "id": cluster["id"],
            "name": cluster["name"],
        },
        "apiVersion": api_version,
        "configurationSha256": configuration_sha,
        "upserted": upserted,
    }


def lambda_handler(event, context):
    del context

    import boto3

    return _run_bootstrap(
        event=event,
        pcs=boto3.client("pcs"),
        secrets_manager=boto3.client("secretsmanager"),
        cluster_identifier=os.environ["PCS_CLUSTER_IDENTIFIER"],
        preferred_api_version=os.environ.get(
            "SLURM_REST_API_VERSION",
            "auto",
        ),
        ttl_seconds=int(os.environ.get("JWT_TTL_SECONDS", "300")),
        timeout_seconds=int(os.environ.get("REQUEST_TIMEOUT_SECONDS", "15")),
        retries=int(os.environ.get("REQUEST_RETRIES", "3")),
    )
