import requests
import os
import json
import boto3
from botocore.exceptions import ClientError

# Environment variables
DYNAMODB_TABLE_NAME = os.environ.get('DYNAMODB_TABLE_NAME')
WATCHMODE_HOSTNAME = os.environ.get('WATCHMODE_HOSTNAME')
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
    if not DYNAMODB_TABLE_NAME or not WATCHMODE_HOSTNAME: # API Key ARN is optional if direct key is used
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
    print(f"WATCHMODE_HOSTNAME: {WATCHMODE_HOSTNAME}")
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

    messages = []

    # Handle source refresh
    if event.get('refresh_sources', 'N').upper() == 'Y':
        region = event.get("regions", "GB") # Default region
        print(f"Attempting to refresh sources for region: {region}")
        try:
            sources_data = get_sources(region, api_key)
            if sources_data:
                save_sources_to_dynamodb(sources_data)
                messages.append(f'Sources refreshed for region {region}')
            else:
                messages.append(f'No sources found or error fetching for region {region}')
        except Exception as e:
            print(f"Error during source refresh process: {e}")
            messages.append(f'Error processing sources for region {region}: {str(e)}')
            # Decide if this should be a 500 or just a message in a 200 response
            # For now, let's keep processing other requests and report errors in the message

    # Handle genre refresh
    if event.get('refresh_genres', 'N').upper() == 'Y':
        print("Attempting to refresh genres")
        try:
            genres_data = get_genres(api_key)
            if genres_data:
                save_genres_to_dynamodb(genres_data)
                messages.append('Genres refreshed')
            else:
                messages.append('No genres found or error fetching')
        except Exception as e:
            print(f"Error during genre refresh process: {e}")
            messages.append(f'Error processing genres: {str(e)}')

    # If no refresh was requested
    if not messages:
        messages.append("No refresh action requested.")

    return {'statusCode': 200, 'body': json.dumps({'messages': messages})}


def get_sources(region, api_key):
    """
    Fetches all streaming sources available for the region.
    Returns a list of source objects (dictionaries).
    """
    url = f'{WATCHMODE_HOSTNAME}/v1/sources/'
    params = {
        "apiKey": api_key,
        "regions": region
    }
    try:
        print(f"Fetching sources from {url} for region {region}")
        response = requests.get(url, params=params, timeout=10)
        response.raise_for_status()
        return response.json()
    except requests.exceptions.RequestException as e:
        print(f"Error fetching sources from WatchMode API: {e}")
        return None # Or raise an error


def get_genres(api_key):
    """
    Fetches all genres available.
    Returns a list of source objects (dictionaries).
    """
    url = f'{WATCHMODE_HOSTNAME}/v1/genres/'
    params = {
        "apiKey": api_key
    }
    try:
        print(f"Fetching genres from {url}")
        response = requests.get(url, params=params, timeout=10)
        response.raise_for_status()
        return response.json()
    except requests.exceptions.RequestException as e:
        print(f"Error fetching genres from WatchMode API: {e}")
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


def save_genres_to_dynamodb(genres_list):
    """
    Saves the list of genre objects to DynamoDB.
    Each genre object is a dictionary.
    """
    if not table:
        print("DynamoDB table not available for saving genres.")
        # Potentially raise an error or handle as a critical failure
        return

    for genre_item in genres_list:
        try:
            # Assuming genre items have 'id' and 'name'
            if not isinstance(genre_item, dict) or 'id' not in genre_item or 'name' not in genre_item:
                print(f"Skipping invalid genre_item: {genre_item}")
                continue

            item_to_save = {
                'PK': f'genre:{genre_item["id"]}',
                'SK': genre_item["name"],
                'data': genre_item
            }
            table.put_item(Item=item_to_save)
            print(f"Saved genre: {genre_item['name']} (ID: {genre_item['id']})")
        except ClientError as e:
            print(f"Error saving genre {genre_item.get('name', 'UNKNOWN')} to DynamoDB: {e}")
