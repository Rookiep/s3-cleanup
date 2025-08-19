import boto3
import os
from datetime import datetime, timezone, timedelta

s3 = boto3.client("s3")

def lambda_handler(event, context):
    bucket_name = os.environ["BUCKET_NAME"]
    retention_days = int(os.environ.get("RETENTION_DAYS", 7))

    # Calculate cutoff time
    cutoff_date = datetime.now(timezone.utc) - timedelta(days=retention_days)

    deleted_files = []
    response = s3.list_objects_v2(Bucket=bucket_name)

    if "Contents" in response:
        for obj in response["Contents"]:
            key = obj["Key"]
            last_modified = obj["LastModified"]

            if last_modified < cutoff_date:
                print(f"Deleting {key}, last modified {last_modified}")
                s3.delete_object(Bucket=bucket_name, Key=key)
                deleted_files.append(key)

    return {
        "statusCode": 200,
        "deleted": deleted_files
    }
