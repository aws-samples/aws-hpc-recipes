# recipes/res/res_user_tag/assets/lambda/handler.py
"""Tag RES VDI desktop instances with res:User=<session owner> on launch.

Triggered by an EventBridge rule on EC2 "running" state changes. Derives the RES
environment from the instance's own res:EnvironmentName tag, looks up the owner in
that environment's user-sessions DynamoDB table (GSI: server-instance-id-index),
and applies the res:User tag. Environment- and version-agnostic: one deployment
serves every RES environment in the account (blue/green and future) with no config.
Idempotent; safe to re-invoke.
"""
import boto3

TAG_KEY = "res:User"
NODE_TYPE_TAG = "res:NodeType"
ENV_NAME_TAG = "res:EnvironmentName"
DCV_HOST_NODE_TYPE = "virtual-desktop-dcv-host"
GSI_NAME = "server-instance-id-index"
GSI_KEY = "server_instance_id"
OWNER_ATTR = "owner"


def _table_name(env_name):
    return f"{env_name}.vdc.controller.user-sessions"


def is_res_dcv_host(tags):
    return tags.get(NODE_TYPE_TAG) == DCV_HOST_NODE_TYPE


def env_name_from_tags(tags):
    return tags.get(ENV_NAME_TAG)


def resolve_owner(instance_id, ddb_client, env_name):
    resp = ddb_client.query(
        TableName=_table_name(env_name),
        IndexName=GSI_NAME,
        KeyConditionExpression="#k = :v",
        ExpressionAttributeNames={"#k": GSI_KEY},
        ExpressionAttributeValues={":v": {"S": instance_id}},
        Limit=1,
    )
    items = resp.get("Items", [])
    if not items:
        return None
    return items[0].get(OWNER_ATTR, {}).get("S")


def _instance_tags(instance_id, ec2_client):
    resp = ec2_client.describe_instances(InstanceIds=[instance_id])
    for reservation in resp.get("Reservations", []):
        for inst in reservation.get("Instances", []):
            return {t["Key"]: t["Value"] for t in inst.get("Tags", [])}
    return {}


def lambda_handler(event, context, ec2_client=None, ddb_client=None):
    ec2_client = ec2_client or boto3.client("ec2")
    ddb_client = ddb_client or boto3.client("dynamodb")

    detail = event.get("detail", {})
    instance_id = detail.get("instance-id")
    if not instance_id:
        print("[res-user-tagger] no instance-id in event; skipping.")
        return

    tags = _instance_tags(instance_id, ec2_client)
    if not is_res_dcv_host(tags):
        print(f"[res-user-tagger] {instance_id} is not a RES DCV host; skipping.")
        return

    env_name = env_name_from_tags(tags)
    if not env_name:
        print(f"[res-user-tagger] {instance_id} has no res:EnvironmentName tag; skipping.")
        return

    owner = resolve_owner(instance_id, ddb_client, env_name)
    if not owner:
        print(f"[res-user-tagger] no owner found for {instance_id} in {env_name}; skipping.")
        return

    ec2_client.create_tags(Resources=[instance_id], Tags=[{"Key": TAG_KEY, "Value": owner}])
    print(f"[res-user-tagger] applied {TAG_KEY}={owner} to {instance_id} ({env_name}).")
