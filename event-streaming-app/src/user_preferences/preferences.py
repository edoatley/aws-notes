import requests
import os
import json
import boto3
from botocore.exceptions import ClientError

# Environment variables
DYNAMODB_TABLE_NAME = os.environ.get('DYNAMODB_TABLE_NAME')

# Global AWS clients and fetched API key (initialized once per container)
dynamodb_resource = None
table = None

# Initialization block
try:
    if not DYNAMODB_TABLE_NAME :
        raise EnvironmentError("DYNAMODB_TABLE_NAME environment variable must be set.")
    dynamodb_resource = boto3.resource('dynamodb')
    table = dynamodb_resource.Table(DYNAMODB_TABLE_NAME)
except EnvironmentError as e:
    print(f"Configuration error: {e}")
    raise
except ClientError as e:
    print(f"AWS Client Initialization error: {e}")
    raise
def debugEnvironment():
    # print the environment details
    print(f"DYNAMODB_TABLE_NAME: {DYNAMODB_TABLE_NAME}")


def lambda_handler(event, context):
    print(f"Received event: {json.dumps(event)}")
    # debugEnvironment()

    if not table:
        print(f"DynamoDB table not initialized")
        return {'statusCode': 500, 'body': json.dumps({'error': 'DynamoDB table could not be initialized'})}

    # process the request extracting the preferences
    # Note we will assume the IDs are correct for now but we should validate them soon...


def save_preferences_to_dynamodb(preferences):
    """
    Saves the list of source objects to DynamoDB.
    Each source object is a dictionary.
    """
    if not table:
        print("DynamoDB table not available for saving sources.")
        # Potentially raise an error or handle as a critical failure
        return

    # for pref in preferences:
    #     try:
    #         # Make validation better
    #         item_to_save = {
    #             'PK': f'source:{source_item["id"]}',
    #             'SK': source_item["name"],
    #             'data': source_item
    #         }
    #         table.put_item(Item=item_to_save)
    #         print(f"Saved source: {source_item['name']} (ID: {source_item['id']})")
    #     except ClientError as e:
    #         print(f"Error saving source {source_item.get('name', 'UNKNOWN')} to DynamoDB: {e}")
    #     except Exception as e:
    #         print(f"Unexpected error saving source {source_item.get('name', 'UNKNOWN')}: {e}")
