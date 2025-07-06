import json
import os
import boto3
from botocore.exceptions import ClientError
import logging
import decimal

# Configure logger
logger = logging.getLogger()
logger.setLevel(os.environ.get("LOG_LEVEL", "INFO").upper())

# Environment variables
DYNAMODB_TABLE_NAME = os.environ.get('DYNAMODB_TABLE_NAME')
AWS_ENDPOINT_URL = os.environ.get('AWS_ENDPOINT_URL') # Check for LocalStack endpoint

# Constants
USER_PREF_PREFIX = 'userpref:'
SOURCE_PREFIX = 'source:'
GENRE_PREFIX = 'genre:'

# Global AWS clients
table = None

# Initialization block
try:
    if not DYNAMODB_TABLE_NAME:
        raise EnvironmentError("DYNAMODB_TABLE_NAME environment variable must be set.")
    boto3_kwargs = {}
    if AWS_ENDPOINT_URL:
        logger.info(f"Using LocalStack endpoint for DynamoDB: {AWS_ENDPOINT_URL}")
        boto3_kwargs['endpoint_url'] = AWS_ENDPOINT_URL

    dynamodb_resource = boto3.resource('dynamodb', **boto3_kwargs)
    table = dynamodb_resource.Table(DYNAMODB_TABLE_NAME)
    logger.info(f"Successfully initialized DynamoDB table client for: {DYNAMODB_TABLE_NAME}")
except (EnvironmentError, ClientError) as e:
    logger.error(f"Initialization error: {e}", exc_info=True)
    raise


class DecimalEncoder(json.JSONEncoder):
    """
    Custom JSON Encoder to handle DynamoDB's Decimal type
    """
    def default(self, o):
        if isinstance(o, decimal.Decimal):
            if o % 1 == 0:
                return int(o)
            else:
                return float(o)
        return super(DecimalEncoder, self).default(o)


def build_response(status_code, body):
    """Helper to build API Gateway proxy response."""
    return {
        "statusCode": status_code,
        "headers": {
            "Content-Type": "application/json",
            "Access-Control-Allow-Origin": "*",
        },
        "body": json.dumps(body, cls=DecimalEncoder)
    }

def get_entities(pk_prefix: str):
    """Scans DynamoDB for entities with a given PK prefix (e.g., 'source:')."""
    try:
        response = table.scan(
            FilterExpression="begins_with(PK, :pk_prefix)",
            ExpressionAttributeValues={":pk_prefix": pk_prefix}
        )
        items = response.get('Items', [])

        while 'LastEvaluatedKey' in response:
            response = table.scan(
                FilterExpression="begins_with(PK, :pk_prefix)",
                ExpressionAttributeValues={":pk_prefix": pk_prefix},
                ExclusiveStartKey=response['LastEvaluatedKey']
            )
            items.extend(response.get('Items', []))

        return build_response(200, items)

    except ClientError as e:
        if e.response['Error']['Code'] == 'ResourceNotFoundException':
            logger.error(f"Error: Table '{DYNAMODB_TABLE_NAME}' not found.")
            return build_response(500, {"error": "Internal server configuration error."})
        else:
            logger.error(f"DynamoDB ClientError getting entities: {e}", exc_info=True)
            return build_response(500, {"error": "Could not retrieve data."})
    except Exception as e:
        logger.error(f"Unexpected error getting entities: {e}", exc_info=True)
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
            try:
                prefix, pref_id = sk.split(':', 1)
                if prefix == 'source':
                    preferences["sources"].append(pref_id)
                elif prefix == 'genre':
                    preferences["genres"].append(pref_id)
            except ValueError:
                logger.warning(f"Skipping malformed SK without a ':' prefix: {sk}")
                continue

        return build_response(200, preferences)
    except ClientError as e:
        logger.error(f"DynamoDB error getting preferences for user {user_id}: {e}", exc_info=True)
        return build_response(500, {'error': 'Could not retrieve preferences'})

def set_user_preferences(user_id: str, body: dict):
    """Deletes all existing preferences and sets new ones for a user."""
    pk = f'userpref:{user_id}'
    new_source_ids = body.get('sources', [])
    new_genre_ids = body.get('genres', [])

    try:
        existing_items_response = table.query(KeyConditionExpression=boto3.dynamodb.conditions.Key('PK').eq(pk))

        with table.batch_writer() as batch:
            for item in existing_items_response.get('Items', []):
                batch.delete_item(Key={'PK': item['PK'], 'SK': item['SK']})
                logger.info(f"Queueing delete for user {user_id}, item {item['SK']}")

            for source_id in new_source_ids:
                if isinstance(source_id, str):
                    full_sk = f'{SOURCE_PREFIX}{source_id}'
                    batch.put_item(Item={'PK': pk, 'SK': full_sk})
                    logger.info(f"Queueing put for user {user_id}, source {full_sk}")

            for genre_id in new_genre_ids:
                if isinstance(genre_id, str):
                    full_sk = f'{GENRE_PREFIX}{genre_id}'
                    batch.put_item(Item={'PK': pk, 'SK': full_sk})
                    logger.info(f"Queueing put for user {user_id}, genre {full_sk}")
    except ClientError as e:
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
        try:
            user_id = event.get('requestContext', {}).get('authorizer', {}).get('claims', {}).get('sub')
            if not user_id:
                logger.warning("User ID not found in authorizer claims.")
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