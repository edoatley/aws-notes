import requests
import os
import json
import boto3
from botocore.exceptions import ClientError
import logging

# Configure logger
logger = logging.getLogger()
logger.setLevel(os.environ.get("LOG_LEVEL", "INFO").upper()) # Allow log level to be set by env var

# Define constants for DynamoDB keys and prefixes
PK_FIELD = 'PK'
SK_FIELD = 'SK'
DATA_FIELD = 'data'
SOURCE_PREFIX = 'source:'
GENRE_PREFIX = 'genre:'

# Environment variables
DYNAMODB_TABLE_NAME = os.environ.get('DYNAMODB_TABLE_NAME')
WATCHMODE_HOSTNAME = os.environ.get('WATCHMODE_HOSTNAME')
WATCHMODE_API_KEY_SECRET_ARN = os.environ.get('WATCHMODE_API_KEY_SECRET_ARN')
AWS_ENDPOINT_URL = os.environ.get('AWS_ENDPOINT_URL') # Check for LocalStack endpoint

# Global AWS clients and fetched API key
dynamodb_resource = None
table = None
secrets_manager_client = None
_cached_watchmode_api_key = None

# Initialization block
try:
    if not DYNAMODB_TABLE_NAME:
        raise EnvironmentError("DYNAMODB_TABLE_NAME environment variable not set.")
    if not WATCHMODE_HOSTNAME:
        raise EnvironmentError("WATCHMODE_HOSTNAME environment variable not set.")
    if not WATCHMODE_API_KEY_SECRET_ARN:
        raise EnvironmentError("WATCHMODE_API_KEY_SECRET_ARN environment variable not set.")

    # Configure boto3 for LocalStack if endpoint is provided
    is_local = os.environ.get("AWS_SAM_LOCAL")
    boto3_kwargs = {}
    if is_local and AWS_ENDPOINT_URL:
        logger.info(f"Using LocalStack endpoint: {AWS_ENDPOINT_URL}")
        boto3_kwargs['endpoint_url'] = AWS_ENDPOINT_URL
    else:
        logger.info(f"Using AWS Default endpoint because {AWS_ENDPOINT_URL=} {is_local=}")

    # Configure AWS resources the lambda requires
    dynamodb_resource = boto3.resource('dynamodb', **boto3_kwargs)
    table = dynamodb_resource.Table(DYNAMODB_TABLE_NAME)
    logger.info(f"Successfully initialized DynamoDB table: {DYNAMODB_TABLE_NAME}")
    secrets_manager_client = boto3.client('secretsmanager', **boto3_kwargs)
    logger.info("Successfully initialized Secrets Manager client.")
except (EnvironmentError, ClientError) as e:
    logger.error(f"Initialization error: {e}", exc_info=True)
    raise


def get_watchmode_api_key_secret() -> str:
    """Fetches the WatchMode API key from Secrets Manager."""
    global _cached_watchmode_api_key
    if _cached_watchmode_api_key:
        return _cached_watchmode_api_key

    if not secrets_manager_client:
        raise ValueError("Secrets Manager client was not initialized. Check WATCHMODE_API_KEY_SECRET_ARN.")

    try:
        logger.info(f"Fetching secret: {WATCHMODE_API_KEY_SECRET_ARN}")
        secret_value_response = secrets_manager_client.get_secret_value(
            SecretId=WATCHMODE_API_KEY_SECRET_ARN
        )
        _cached_watchmode_api_key = secret_value_response['SecretString']
        return _cached_watchmode_api_key
    except ClientError as e:
        logger.error(f"Error fetching API key from Secrets Manager: {e}")
        raise


def _fetch_watchmode_data(api_key: str, endpoint: str, params: dict = None) -> list | None:
    """Generic function to fetch data from a WatchMode API endpoint."""
    if not WATCHMODE_HOSTNAME:
        logger.error("WATCHMODE_HOSTNAME is not configured.")
        return None # Or raise

    url = f'{WATCHMODE_HOSTNAME}/v1/{endpoint}/'
    base_params = {"apiKey": api_key}
    if params:
        base_params.update(params)

    try:
        logger.info(f"Fetching data from {url} with params: {params if params else 'N/A'}")
        response = requests.get(url, params=base_params, timeout=10)
        response.raise_for_status()
        return response.json()
    except requests.exceptions.RequestException as e:
        logger.error(f"Error fetching data from {url}: {e}", exc_info=True)
        return None
    except json.JSONDecodeError as e:
        logger.error(f"Error decoding JSON response from {url}: {e}", exc_info=True)
        return None


def get_sources(region: str, api_key: str) -> list | None:
    """Fetches all streaming sources available for the region."""
    return _fetch_watchmode_data(api_key, "sources", params={"regions": region})


def get_genres(api_key: str) -> list | None:
    """Fetches all genres available."""
    return _fetch_watchmode_data(api_key, "genres")


def _save_items_to_dynamodb(items_list: list, item_type_prefix: str, item_type_name: str) -> bool:
    """
    Generic function to save a list of items (sources or genres) to DynamoDB.
    Returns True if save operation was attempted for at least one item, False otherwise or if table is unavailable.
    """
    if not table:
        logger.error(f"DynamoDB table not available for saving {item_type_name}s.")
        return False

    if not items_list: # No items to save
        logger.info(f"No {item_type_name} items provided to save.")
        return True # Operation considered successful as there's nothing to do

    try:
        with table.batch_writer() as batch:
            for item in items_list:
                if not isinstance(item, dict) or 'id' not in item or 'name' not in item:
                    logger.warning(f"Skipping invalid {item_type_name}_item: {item}")
                    continue
                item_to_save = {
                    PK_FIELD: f'{item_type_prefix}{item["id"]}',
                    SK_FIELD: item["name"],
                    DATA_FIELD: item
                }
                batch.put_item(Item=item_to_save)
        logger.info(f"Successfully saved {len(items_list)} {item_type_name} items to DynamoDB.")
        return True
    except ClientError as e:
        logger.error(f"DynamoDB batch write error for {item_type_name}s: {e}", exc_info=True)
        return False


def save_sources_to_dynamodb(sources_list: list):
    """Saves the list of source objects to DynamoDB."""
    return _save_items_to_dynamodb(sources_list, SOURCE_PREFIX, "source")


def save_genres_to_dynamodb(genres_list: list):
    """Saves the list of genre objects to DynamoDB."""
    return _save_items_to_dynamodb(genres_list, GENRE_PREFIX, "genre")

# def debugEnvironment():
#     logger.info(f'DYNAMODB_TABLE_NAME {DYNAMODB_TABLE_NAME}')
#     logger.info(f'WATCHMODE_HOSTNAME {WATCHMODE_HOSTNAME}')
#     logger.info(f'WATCHMODE_API_KEY_SECRET_ARN {WATCHMODE_API_KEY_SECRET_ARN}')
#     logger.info(f'WATCHMODE_API_KEY {WATCHMODE_API_KEY}')


def lambda_handler(event, context):
    logger.info(f"Received event: {json.dumps(event)}")
    # debugEnvironment()

    if not table:
        logger.error(f"DynamoDB table not initialized")
        return {'statusCode': 500, 'body': json.dumps({'error': 'DynamoDB table could not be initialized'})}

    api_key = None
    try:
        api_key = get_watchmode_api_key_secret()
    except Exception as e:
        logger.error(f"Failed to get API key: {e}")
        return {'statusCode': 500, 'body': json.dumps({'error': f'Failed to retrieve API key: {str(e)}'})}

    messages = []

    status_code = 200

    # Handle source refresh
    if event.get('refresh_sources', 'N').upper() == 'Y':
        region = event.get("regions", "GB") # Default region
        logger.info(f"Attempting to refresh sources for region: {region}")
        try:
            sources_data = get_sources(region, api_key)
            if sources_data:
                save_sources_to_dynamodb(sources_data)
                messages.append(f'Sources refreshed for region {region}')
            else:
                messages.append(f'No sources found or error fetching for region {region}')
        except Exception as e:
            logger.error(f"Error during source refresh process: {e}")
            messages.append(f'Error processing sources for region {region}: {str(e)}')
            status_code = 500

    # Handle genre refresh
    if event.get('refresh_genres', 'N').upper() == 'Y':
        logger.info("Attempting to refresh genres")
        try:
            genres_data = get_genres(api_key)
            if genres_data:
                save_genres_to_dynamodb(genres_data)
                messages.append('Genres refreshed')
            else:
                messages.append('No genres found or error fetching')
        except Exception as e:
            logger.error(f"Error during genre refresh process: {e}")
            messages.append(f'Error processing genres: {str(e)}')
            status_code = 500

    # If no refresh was requested
    if not messages:
        messages.append("No refresh action requested.")

    return {'statusCode': status_code, 'body': json.dumps({'messages': messages})}
