import boto3
import datetime
import os
import logging
from botocore.exceptions import ClientError

# Setup logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

s3 = boto3.client('s3')
BUCKET_NAME = os.environ.get('BUCKET_NAME', '')

def lambda_handler(event, context):
    if not BUCKET_NAME:
        logger.error("BUCKET_NAME environment variable is not set.")
        return {"status": "error", "message": "Missing bucket name"}

    today = datetime.datetime.now(datetime.timezone.utc)
    objects_to_delete = []

    try:
        paginator = s3.get_paginator('list_objects_v2')
        page_iterator = paginator.paginate(Bucket=BUCKET_NAME)

        for page in page_iterator:
            if "Contents" not in page:
                continue

            for obj in page["Contents"]:
                try:
                    key = obj["Key"]
                    size = obj["Size"]
                    last_modified = obj["LastModified"]

                    age_days = (today - last_modified).days

                    if age_days > 7 and size > 10 * 1024:
                        objects_to_delete.append({"Key": key})

                except KeyError as e:
                    logger.warning(f"Skipping object due to missing field: {e}")

    except ClientError as e:
        logger.error(f"Failed to list objects from bucket {BUCKET_NAME}: {e}")
        return {"status": "error", "message": str(e)}

    # Delete in batches of 1000 (S3 limit)
    if objects_to_delete:
        try:
            for i in range(0, len(objects_to_delete), 1000):
                batch = objects_to_delete[i:i+1000]
                response = s3.delete_objects(
                    Bucket=BUCKET_NAME,
                    Delete={"Objects": batch}
                )
                deleted = response.get("Deleted", [])
                errors = response.get("Errors", [])
                logger.info(f"Deleted {len(deleted)} objects")
                if errors:
                    logger.error(f"Errors while deleting: {errors}")

            return {"status": "success", "deleted": len(objects_to_delete)}

        except ClientError as e:
            logger.error(f"Error during delete operation: {e}")
            return {"status": "error", "message": str(e)}
    else:
        logger.info("No matching objects found.")
        return {"status": "success", "deleted": 0} 