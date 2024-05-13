import boto3
import botocore
import json
import logging
import os

logger = logging.getLogger()
logger.setLevel("INFO")

def lambda_handler(event, context):
    
    try:
        message = event["Records"][0]["Sns"]
        logger.info("TopicArn: {}".format(message["TopicArn"]))
        logger.info("MessageId: {}".format(message["MessageId"]))
        logger.info("Subject: {}".format(message["Subject"]))
        payload = json.loads(event['Records'][0]['Sns']['Message'])
    except Exception as error:
        raise error
    
    body = {
        "topicArn":  message["TopicArn"],
        "messageId": message["MessageId"],
        "subject": message["Subject"],
        "clusterId": None,
        "region": None,
        "amiId": None,
        "amiName": None,
        "computeNodeGroups": [],
        "message": None
    }
    
    region_name = os.environ["PCS_CLUSTER_REGION"]
    cluster_id = os.environ["PCS_CLUSTER_IDENTIFIER"]
    logger.info("Region: {}".format(region_name))
    logger.info("ClusterId: {}".format(cluster_id))
    
    body["clusterId"] = cluster_id
    body["region"] = region_name
    
    # This works with PCS beta because the service model is bundled with
    # the Lambda.
    session = boto3.Session(region_name=region_name)
    logger.info("Initializing PCS client")
    pcs = session.client("pcs")
    
    # TODO - Validate the event payload
    built_ami = payload.get("outputResources", {}).get("amis", [])[0]
    built_ami_id = built_ami.get("image")
    built_ami_name = built_ami.get("name")
    logger.info("amiId: {}".format(built_ami_id))
    
    body["amiId"] = built_ami_id
    body["amiName"] = built_ami_name
    
    logger.info("Listing compute node groups for {}".format(cluster_id))
    try:
        cngs = pcs.list_compute_node_groups(clusterIdentifier=cluster_id).get("computeNodeGroups", [])
    except botocore.exceptions.ClientError as error:
        logger.error("HTTPStatusCode: {}".format(error.response["ResponseMetadata"]["HTTPStatusCode"]))
        logger.error("RequestId: {}".format(error.response["ResponseMetadata"]["RequestId"]))
        raise error
    
    logger.info("Updating compute node groups")
    for cng in cngs:
        cng_id = cng.get("id")
        cng_name = cng.get("name")
        logger.info("ComputeNodeGroupId: {}".format(cng_id))
        try:
            response = pcs.update_compute_node_group(clusterIdentifier=cluster_id, computeNodeGroupIdentifier=cng_id, amiId=built_ami_id)
            body["computeNodeGroups"].append({"id": cng_id, "name": cng_name, "status": response.get("computeNodeGroup", {}).get("status", "")})
        except botocore.exceptions.ClientError as error:
            logger.error("HTTPStatusCode: {}".format(error.response["ResponseMetadata"]["HTTPStatusCode"]))
            logger.error("RequestId: {}".format(error.response["ResponseMetadata"]["RequestId"]))
            raise error
    
    body["message"] = "ImageBuilder pipeline event processed. Compute node group updates underway."

    # TODO implement
    return {
        "statusCode": 200,
        "body": body
    }
