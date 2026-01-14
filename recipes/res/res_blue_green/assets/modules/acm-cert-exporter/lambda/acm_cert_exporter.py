import json
import logging
import os

import boto3
from cryptography.hazmat.backends import default_backend
from cryptography.hazmat.primitives import serialization

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

acm = boto3.client("acm")
secrets = boto3.client("secretsmanager")


def _decrypt_private_key(encrypted_key: bytes, passphrase: str) -> str:
    """
    Decrypt a PEM-encrypted private key

    Args:
        encrypted_key: Encrypted private key in PEM format
        passphrase: Passphrase used to encrypt the key

    Returns:
        Unencrypted private key in PEM format as string
    """
    logger.debug("Decrypting private key")

    try:
        # Load the encrypted private key
        private_key = serialization.load_pem_private_key(
            encrypted_key,
            password=passphrase.encode("utf-8"),
            backend=default_backend(),
        )

        # Serialize the private key without encryption
        unencrypted_key = private_key.private_bytes(
            encoding=serialization.Encoding.PEM,
            format=serialization.PrivateFormat.TraditionalOpenSSL,
            encryption_algorithm=serialization.NoEncryption(),
        )

        logger.debug("Private key decrypted successfully")
        return unencrypted_key.decode("utf-8")

    except Exception as e:
        logger.error(f"Failed to decrypt private key: {str(e)}")
        raise


def handler(event, context):
    logger.info(f"Processing event: {event['detail-type']}")

    cert_arn = event["resources"][0]
    logger.info(f"Certificate ARN: {cert_arn}")

    cert_secret_id = os.environ["CERT_SECRET_ID"]
    key_secret_id = os.environ["KEY_SECRET_ID"]
    passphrase_secret_id = os.environ["PASSPHRASE_SECRET_ID"]

    logger.debug(f"Certificate Secret ID: {cert_secret_id}")
    logger.debug(f"Key Secret ID: {key_secret_id}")
    logger.debug(f"Passphrase Secret ID: {passphrase_secret_id}")

    # Only process certificate issuance events
    if event["detail-type"] not in ["ACM Certificate Available"]:
        logger.info(f"Skipping event type: {event['detail-type']}")
        return {"statusCode": 200, "body": "Not a certificate issuance event"}

    try:
        # Get passphrase from Secrets Manager
        logger.info(
            f"Retrieving passphrase from Secrets Manager: {passphrase_secret_id}"
        )
        passphrase_response = secrets.get_secret_value(SecretId=passphrase_secret_id)
        passphrase = passphrase_response["SecretString"]
        logger.debug("Passphrase retrieved successfully")

        # Export certificate
        logger.info(f"Exporting certificate: {cert_arn}")
        response = acm.export_certificate(
            CertificateArn=cert_arn, Passphrase=passphrase.encode("utf-8")
        )
        logger.info("Certificate exported successfully")

        # Update Secrets Manager with certificate and chain
        logger.info(f"Updating certificate secret: {cert_secret_id}")
        secrets.update_secret(
            SecretId=cert_secret_id,
            SecretString=response["Certificate"] + "\n" + response["CertificateChain"],
        )
        logger.info("Certificate secret updated successfully")

        # Decrypt and update Secrets Manager with private key
        logger.info(f"Decrypting and updating private key secret: {key_secret_id}")
        decrypted_key = _decrypt_private_key(
            response["PrivateKey"].encode("utf-8"), passphrase
        )
        secrets.update_secret(
            SecretId=key_secret_id,
            SecretString=decrypted_key,
        )
        logger.info("Private key secret updated successfully")

        logger.info(f"Certificate export completed successfully for: {cert_arn}")
        return {
            "statusCode": 200,
            "body": json.dumps("Certificate exported successfully"),
        }

    except Exception as e:
        logger.error(f"Error exporting certificate {cert_arn}: {str(e)}", exc_info=True)
        return {"statusCode": 500, "body": json.dumps(f"Error: {str(e)}")}
