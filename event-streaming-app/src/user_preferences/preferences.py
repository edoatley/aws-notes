# /src/user_preferences/preferences.py
import json
import os
import boto3
from botocore.exceptions import ClientError
import logging

# Configure logger
logger = logging.getLogger()
logger.setLevel(os.environ.get("LOG_LEVEL", "INFO").upper())

# Environment variables
DYNAMODB_TABLE_NAME = os.environ.get('DYNAMODB_TABLE_NAME')

# Constants
USER_PREF_PREFIX = 'userpref:'
SOURCE_PREFIX = 'source:'
GENRE_PREFIX = 'genre:'

# Global AWS clients (initialized once per container)
dynamodb_resource = None
table = None

# Initialization block
try:
    if not DYNAMODB_TABLE_NAME:
        raise EnvironmentError("DYNAMODB_TABLE_NAME environment variable must be set.")
    dynamodb_resource = boto3.resource('dynamodb')
    table = dynamodb_resource.Table(DYNAMODB_TABLE_NAME)
    logger.info(f"Successfully initialized DynamoDB table: {DYNAMODB_TABLE_NAME}")
except (EnvironmentError, ClientError) as e:
    logger.error(f"Fatal error during initialization: {e}", exc_info=True)
    # This will cause subsequent invocations to fail until the container is replaced
    table = None


def get_user_preferences(user_id: str):
    """Gets all preferences for a given user."""
    pk = f"{USER_PREF_PREFIX}{user_id}"
    logger.info(f"Querying preferences for user PK: {pk}")
    try:
        response = table.query(KeyConditionExpression=boto3.dynamodb.conditions.Key('PK').eq(pk))

        preferences = {"sources": [], "genres": []}
        for item in response.get('Items', []):
            sk = item.get('SK', '')
            if sk.startswith(SOURCE_PREFIX):
                preferences["sources"].append(sk)
            elif sk.startswith(GENRE_PREFIX):
                preferences["genres"].append(sk)

        return {'statusCode': 200, 'body': json.dumps(preferences)}
    except ClientError as e:
        logger.error(f"DynamoDB error getting preferences for user {user_id}: {e}", exc_info=True)
        return {'statusCode': 500, 'body': json.dumps({'error': 'Could not retrieve preferences'})}


def set_user_preferences(user_id: str, body: dict):
    """Deletes all existing preferences and sets new ones for a user."""
    pk = f"{USER_PREF_PREFIX}{user_id}"
    new_sources = body.get('sources', [])
    new_genres = body.get('genres', [])

    try:
        # 1. Find all existing preferences to delete them
        existing_items_response = table.query(KeyConditionExpression=boto3.dynamodb.conditions.Key('PK').eq(pk))

        # 2. Use BatchWriter for efficient delete and put operations
        with table.batch_writer() as batch:
            # Delete old items
            for item in existing_items_response.get('Items', []):
                batch.delete_item(Key={'PK': item['PK'], 'SK': item['SK']})
                logger.info(f"Queueing delete for user {user_id}, item {item['SK']}")

            # Add new source preferences
            for source_sk in new_sources:
                # Basic validation
                if isinstance(source_sk, str) and source_sk.startswith(SOURCE_PREFIX):
                    batch.put_item(Item={'PK': pk, 'SK': source_sk})
                    logger.info(f"Queueing put for user {user_id}, source {source_sk}")

            # Add new genre preferences
            for genre_sk in new_genres:
                if isinstance(genre_sk, str) and genre_sk.startswith(GENRE_PREFIX):
                    batch.put_item(Item={'PK': pk, 'SK': genre_sk})
                    logger.info(f"Queueing put for user {user_id}, genre {genre_sk}")

        return {'statusCode': 204, 'body': ''} # 204 No Content is appropriate for a successful PUT

    except ClientError as e:
        logger.error(f"DynamoDB error setting preferences for user {user_id}: {e}", exc_info=True)
        return {'statusCode': 500, 'body': json.dumps({'error': 'Could not update preferences'})}


def get_reference_data(prefix: str):
    """
    Gets all reference data items (sources or genres) using a Scan.
    NOTE: For production, a GSI would be more efficient than a Scan.
    """
    logger.info(f"Scanning for reference data with prefix: {prefix}")
    try:
        response = table.scan(
            FilterExpression=boto3.dynamodb.conditions.Attr('PK').begins_with(prefix)
        )
        # We only want the 'data' attribute from each item
        items = [item.get('data', {}) for item in response.get('Items', [])]
        return {'statusCode': 200, 'body': json.dumps(items)}
    except ClientError as e:
        logger.error(f"DynamoDB error scanning for {prefix}: {e}", exc_info=True)
        return {'statusCode': 500, 'body': json.dumps({'error': f'Could not retrieve {prefix} data'})}


def lambda_handler(event, context):
    """Main handler that routes requests based on the API path."""
    if not table:
        # This indicates a catastrophic failure during initialization
        return {'statusCode': 500, 'body': json.dumps({'error': 'Server is not configured correctly'})}

    logger.info(f"Received event: {json.dumps(event)}")

    http_method = event.get('httpMethod')
    path = event.get('path')

    # Preferences endpoints (require authentication)
    if path == '/preferences':
        try:
            # The user's unique ID from the Cognito token
            user_id = event['requestContext']['authorizer']['claims']['sub']
        except (KeyError, TypeError):
            return {'statusCode': 401, 'body': json.dumps({'error': 'Unauthorized'})}

        if http_method == 'GET':
            return get_user_preferences(user_id)
        elif http_method == 'PUT':
            try:
                body = json.loads(event.get('body', '{}'))
                return set_user_preferences(user_id, body)
            except json.JSONDecodeError:
                return {'statusCode': 400, 'body': json.dumps({'error': 'Invalid JSON in request body'})}

    # Public reference data endpoints
    elif path == '/sources':
        if http_method == 'GET':
            return get_reference_data(SOURCE_PREFIX)

    elif path == '/genres':
        if http_method == 'GET':
            return get_reference_data(GENRE_PREFIX)

    # Default response for unhandled paths
    return {'statusCode': 404, 'body': json.dumps({'error': 'Not Found'})}