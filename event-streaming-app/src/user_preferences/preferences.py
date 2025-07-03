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

# Global AWS clients
dynamodb_resource = None
table=None

# Initialization block
try:
    if not DYNAMODB_TABLE_NAME:
        raise EnvironmentError("DYNAMODB_TABLE_NAME environment variable must be set.")
    # Using the resource API can be simpler for data operations
    dynamodb_resource = boto3.resource('dynamodb')
    table = dynamodb_resource.Table(DYNAMODB_TABLE_NAME)
except (EnvironmentError, ClientError) as e:
    logger.error(f"Initialization error: {e}")
    raise

def build_response(status_code, body):
    """Helper to build API Gateway proxy response."""
    return {
        "statusCode": status_code,
        "headers": {
            "Content-Type": "application/json",
            "Access-Control-Allow-Origin": "*", # Good practice for public APIs
        },
        "body": json.dumps(body)
    }

def get_entities(pk_prefix: str):
    """Scans DynamoDB for entities with a given PK prefix (e.g., 'source:')."""
    try:

        # Scan is okay for small reference tables, but use Query for larger datasets
        response = table.scan(
            FilterExpression="begins_with(PK, :pk_prefix)",
            ExpressionAttributeValues={":pk_prefix": pk_prefix}
        )

        # This correctly returns an empty list if no items are found
        items = response.get('Items', [])

        # Continue scanning if the table is large and results are paginated
        while 'LastEvaluatedKey' in response:
            response = table.scan(
                FilterExpression="begins_with(PK, :pk_prefix)",
                ExpressionAttributeValues={":pk_prefix": pk_prefix},
                ExclusiveStartKey=response['LastEvaluatedKey']
            )
            items.extend(response.get('Items', []))

        # Return 200 OK with the list of items (which could be empty)
        return build_response(200, items)

    except ClientError as e:
        if e.response['Error']['Code'] == 'ResourceNotFoundException':
            logger.error(f"Error: Table '{DYNAMODB_TABLE_NAME}' not found.")
            return build_response(500, {"error": "Internal server configuration error."})
        else:
            logger.error(f"DynamoDB ClientError getting entities: {e}")
            return build_response(500, {"error": "Could not retrieve data."})
    except Exception as e:
        logger.error(f"Unexpected error getting entities: {e}")
        return build_response(500, {"error": "An unexpected error occurred."})

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

        return build_response(200, preferences) #
    except ClientError as e:
        logger.error(f"DynamoDB error getting preferences for user {user_id}: {e}", exc_info=True)
        return build_response(500, {'error': 'Could not retrieve preferences'})

def set_user_preferences(user_id: str, body: dict):
    """Deletes all existing preferences and sets new ones for a user."""
    pk = f'userpref:{user_id}'
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
    except ClientError as e: # Before: except:
        logger.error(f"DynamoDB error setting preferences for user {user_id}: {e}", exc_info=True)
        return build_response(500, {'error': 'Could not set preferences'})
    except Exception as e:
        logger.error(f"An unexpected error occurred while setting preferences for user {user_id}: {e}", exc_info=True)
        return build_response(500, {'error': 'An unexpected error occurred'})

    return {
        "statusCode": 204,
        "headers": {
            "Access-Control-Allow-Origin": "*",
        }
    }

def lambda_handler(event, context):
    """
    Handles API Gateway requests for user preferences, sources, and genres.
    """
    logger.info(f"Received event: {json.dumps(event)}")

    http_method = event.get('httpMethod')
    path = event.get('path')

    if http_method == 'GET' and path == '/sources':
        return get_entities(SOURCE_PREFIX)

    elif http_method == 'GET' and path == '/genres':
        return get_entities(GENRE_PREFIX)

    elif path == '/preferences':
        # get the userid of the authenticated user from the event
        try:
            # Safely access nested keys
            user_id = event.get('requestContext', {}).get('authorizer', {}).get('claims', {}).get('sub')
            if not user_id:
                logger.error("User ID not found in authorizer claims.")
                return build_response(401, {"error": "Unauthorized"})
        except Exception:
            logger.error("Could not parse user ID from event.", exc_info=True)
            return build_response(400, {"error": "Bad request format"})

        if http_method == 'GET':
            return get_user_preferences(user_id)
        elif http_method == 'PUT':
            try:
                body = json.loads(event.get('body') or '{}')
                return set_user_preferences(user_id, body)
            except json.JSONDecodeError:
                logger.warning("Received invalid JSON in PUT /preferences body")
                return build_response(400, {"error": "Invalid JSON format"})

    return build_response(404, {"error": f"Path not found: {http_method} {path}"})
