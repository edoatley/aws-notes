import json
import logging
import os
import boto3
import cfnresponse
from botocore.exceptions import ClientError

# Configure logger
logger = logging.getLogger()
logger.setLevel(os.environ.get("LOG_LEVEL", "INFO").upper())

# Initialize S3 client
s3_client = boto3.client('s3')

def get_content_type(filename):
    """Determine the MIME content type based on file extension."""
    extension = filename.lower().split('.')[-1]
    content_types = {
        'html': 'text/html',
        'js': 'application/javascript',
        'css': 'text/css',
        'ico': 'image/x-icon',
    }
    return content_types.get(extension, 'application/octet-stream')

def upload_s3_object(bucket_name, key, body, content_type):
    """Upload a single object to S3."""
    try:
        s3_client.put_object(
            Bucket=bucket_name,
            Key=key,
            Body=body,
            ContentType=content_type,
            ACL='public-read'
        )
        logger.info(f"Successfully uploaded {key} to s3://{bucket_name}")
    except ClientError as e:
        logger.error(f"Error uploading {key} to S3: {e}")
        raise

def deploy_website(properties):
    """Deploys the website files, including the dynamic config.js."""
    bucket_name = properties['BucketName']
    
    # --- Create and upload config.js ---
    config_js_content = f"""
const config = {{
    region: '{properties['Region']}',
    userPoolId: '{properties['UserPoolId']}',
    userPoolClientId: '{properties['UserPoolClientId']}',
    apiEndpoint: '{properties['WebApiEndpoint']}',
    preferencesApiEndpoint: '{properties['UserPreferencesApiEndpoint']}'
}};
"""
    upload_s3_object(bucket_name, 'config.js', config_js_content, 'application/javascript')

    # --- Upload static files from the local 'web' directory ---
    static_files_dir = os.path.join(os.path.dirname(__file__), '..', 'web')
    static_files = ['index.html', 'error.html', 'app.js']

    for filename in static_files:
        try:
            filepath = os.path.join(static_files_dir, filename)
            with open(filepath, 'r', encoding='utf-8') as f:
                content = f.read()
            content_type = get_content_type(filename)
            upload_s3_object(bucket_name, filename, content, content_type)
        except FileNotFoundError:
            logger.error(f"Static file not found: {filepath}")
            raise
        except Exception as e:
            logger.error(f"Error processing static file {filepath}: {e}")
            raise

def cleanup_website(bucket_name):
    """Removes all objects from the S3 bucket."""
    logger.info(f"Cleaning up website files from bucket: {bucket_name}")
    try:
        response = s3_client.list_objects_v2(Bucket=bucket_name)
        if 'Contents' in response:
            objects_to_delete = [{'Key': obj['Key']} for obj in response['Contents']]
            if objects_to_delete:
                s3_client.delete_objects(
                    Bucket=bucket_name,
                    Delete={'Objects': objects_to_delete}
                )
                logger.info(f"Deleted {len(objects_to_delete)} objects from S3 bucket.")
    except ClientError as e:
        logger.warning(f"Could not clean up S3 bucket (this is expected if the bucket was already deleted): {e}")


def lambda_handler(event, context):
    """Handle CloudFormation custom resource events for website deployment."""
    logger.info(f"Received event: {json.dumps(event)}")
    physical_resource_id = f"s3-website-deployment-{event.get('StackId', '').split('/')[-1]}"
    
    try:
        request_type = event['RequestType']
        properties = event.get('ResourceProperties', {})
        
        if request_type in ['Create', 'Update']:
            logger.info("RequestType is Create or Update, deploying website...")
            deploy_website(properties)
            cfnresponse.send(event, context, cfnresponse.SUCCESS, {}, physical_resource_id)
        
        elif request_type == 'Delete':
            logger.info("RequestType is Delete, cleaning up website...")
            cleanup_website(properties.get('BucketName'))
            cfnresponse.send(event, context, cfnresponse.SUCCESS, {}, physical_resource_id)
            
    except Exception as e:
        logger.error(f"Error handling custom resource: {e}", exc_info=True)
        cfnresponse.send(event, context, cfnresponse.FAILED, {'Error': str(e)}, physical_resource_id)
