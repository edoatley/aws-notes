import requests
import os
import json
import boto3
from botocore.exceptions import ClientError

# Environment variables
DYNAMODB_TABLE_NAME = os.environ.get('DYNAMODB_TABLE_NAME')
WATCHMODE_URL = os.environ.get('WATCHMODE_URL')
WATCHMODE_API_KEY_SECRET_ARN = os.environ.get('WATCHMODE_API_KEY_SECRET_ARN')
# New: Allow direct API key for local testing
WATCHMODE_API_KEY_DIRECT = os.environ.get('WATCHMODE_API_KEY')


# Global AWS clients and fetched API key (initialized once per container)
dynamodb_resource = None
table = None
secrets_manager_client = None
_cached_watchmode_api_key = None

# Initialization block
try:
    if not DYNAMODB_TABLE_NAME or not WATCHMODE_URL: # API Key ARN is optional if direct key is used
        raise EnvironmentError("DYNAMODB_TABLE_NAME and WATCHMODE_URL environment variables must be set.")
    dynamodb_resource = boto3.resource('dynamodb')
    table = dynamodb_resource.Table(DYNAMODB_TABLE_NAME)
    # Initialize secrets_manager_client only if a secret ARN is provided and no direct key
    if WATCHMODE_API_KEY_SECRET_ARN and not WATCHMODE_API_KEY_DIRECT:
        secrets_manager_client = boto3.client('secretsmanager')
except EnvironmentError as e:
    print(f"Configuration error: {e}")
    raise
except ClientError as e:
    print(f"AWS Client Initialization error: {e}")
    raise


def get_watchmode_api_key_secret():
    """Fetches the WatchMode API key, prioritizing direct env var, then Secrets Manager."""
    global _cached_watchmode_api_key
    if _cached_watchmode_api_key:
        return _cached_watchmode_api_key

    if WATCHMODE_API_KEY_DIRECT:
        print("Using direct API key from WATCHMODE_API_KEY_DIRECT.")
        _cached_watchmode_api_key = WATCHMODE_API_KEY_DIRECT
        return _cached_watchmode_api_key

    if not WATCHMODE_API_KEY_SECRET_ARN:
        raise ValueError("WATCHMODE_API_KEY_SECRET_ARN not set and no direct key provided.")

    if not secrets_manager_client:
        raise ValueError("Secrets Manager client could not be initialized.")

    try:
        print(f"Fetching secret: {WATCHMODE_API_KEY_SECRET_ARN}")
        secret_value_response = secrets_manager_client.get_secret_value(
            SecretId=WATCHMODE_API_KEY_SECRET_ARN
        )
        _cached_watchmode_api_key = secret_value_response['SecretString']
        return _cached_watchmode_api_key
    except ClientError as e:
        print(f"Error fetching API key from Secrets Manager: {e}")
        raise


def debugEnvironment():
    # print the environment details
    print(f"DYNAMODB_TABLE_NAME: {DYNAMODB_TABLE_NAME}")
    print(f"WATCHMODE_URL: {WATCHMODE_URL}")
    print(f"WATCHMODE_API_KEY_SECRET_ARN: {WATCHMODE_API_KEY_SECRET_ARN}")
    print(f"WATCHMODE_API_KEY_DIRECT: {WATCHMODE_API_KEY_DIRECT}")


def lambda_handler(event, context):
    print(f"Received event: {json.dumps(event)}")
    # debugEnvironment()

    if not table:
        print(f"DynamoDB table not initialized")
        return {'statusCode': 500, 'body': json.dumps({'error': 'DynamoDB table could not be initialized'})}

    api_key = None
    try:
        api_key = get_watchmode_api_key_secret()
    except Exception as e:
        print(f"Failed to get API key: {e}")
        return {'statusCode': 500, 'body': json.dumps({'error': f'Failed to retrieve API key: {str(e)}'})}

    if event.get('refresh_sources') == 'Y':
        region = event.get("regions", "GB")
        print(f"Refreshing sources for region: {region}")
        try:
            sources_data = get_sources(region, api_key)
            if sources_data:
                save_sources_to_dynamodb(sources_data)
                return {'statusCode': 200, 'body': json.dumps({'message': f'Sources refreshed for region {region}'})}
            else:
                # Consider if this is a 200 or an error/warning state
                return {'statusCode': 200, 'body': json.dumps({'message': f'No sources found or error fetching for region {region}'})}
        except Exception as e:
            print(f"Error during source refresh process: {e}")
            return {'statusCode': 500, 'body': json.dumps({'error': f'Error processing sources: {str(e)}'})}
    else:
        print("Skipping source refresh (refresh_sources not 'Y').")
        return {'statusCode': 200, 'body': json.dumps({'message': 'Source refresh not requested.'})}


def get_sources(region, api_key):
    """
    Fetches all streaming sources available for the region.
    Returns a list of source objects (dictionaries).
    """
    if not WATCHMODE_URL:
        print("WATCHMODE_URL is not set.")
        return None # Or raise an error

    params = {
        "apiKey": api_key,
        "regions": region
    }
    try:
        print(f"Fetching sources from {WATCHMODE_URL} for region {region}")
        response = requests.get(WATCHMODE_URL, params=params, timeout=10)
        response.raise_for_status()
        return response.json()
    except requests.exceptions.RequestException as e:
        print(f"Error fetching sources from WatchMode API: {e}")
        return None # Or raise an error


def save_sources_to_dynamodb(sources_list):
    """
    Saves the list of source objects to DynamoDB.
    Each source object is a dictionary.
    """
    if not table:
        print("DynamoDB table not available for saving sources.")
        # Potentially raise an error or handle as a critical failure
        return

    for source_item in sources_list:
        try:
            if not isinstance(source_item, dict) or 'id' not in source_item or 'name' not in source_item:
                print(f"Skipping invalid source_item: {source_item}")
                continue

            item_to_save = {
                'PK': f'source:{source_item["id"]}',
                'SK': source_item["name"],
                'data': source_item
            }
            table.put_item(Item=item_to_save)
            print(f"Saved source: {source_item['name']} (ID: {source_item['id']})")
        except ClientError as e:
            print(f"Error saving source {source_item.get('name', 'UNKNOWN')} to DynamoDB: {e}")
        except Exception as e:
            print(f"Unexpected error saving source {source_item.get('name', 'UNKNOWN')}: {e}")
