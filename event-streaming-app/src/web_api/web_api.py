import json
import logging
import os
import boto3
from datetime import datetime, timedelta
from botocore.exceptions import ClientError
from decimal import Decimal

# Configure logger
logger = logging.getLogger()
logger.setLevel(os.environ.get("LOG_LEVEL", "INFO").upper())

# --- Environment Variables & Boto3 Clients ---
DYNAMODB_TABLE_NAME = os.environ.get('DYNAMODB_TABLE_NAME')
AWS_ENDPOINT_URL = os.environ.get('AWS_ENDPOINT_URL')

# Constants
TITLE_PREFIX = 'title:'
USER_PREF_PREFIX = 'userpref:'
SOURCE_PREFIX = 'source:'
GENRE_PREFIX = 'genre:'

table = None
try:
    if not DYNAMODB_TABLE_NAME:
        raise EnvironmentError("DYNAMODB_TABLE_NAME environment variable must be set.")

    boto3_kwargs = {'endpoint_url': AWS_ENDPOINT_URL} if AWS_ENDPOINT_URL else {}
    dynamodb_resource = boto3.resource('dynamodb', **boto3_kwargs)
    table = dynamodb_resource.Table(DYNAMODB_TABLE_NAME)
    logger.info(f"Successfully initialized DynamoDB table client for: {DYNAMODB_TABLE_NAME}")
except Exception as e:
    logger.error(f"Error during AWS client initialization: {e}", exc_info=True)
    raise

def build_response(status_code, body):
    """Build a standardized API Gateway response."""
    return {
        'statusCode': status_code,
        'headers': {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Headers': 'Content-Type,Authorization',
            'Access-Control-Allow-Methods': 'GET,POST,PUT,DELETE,OPTIONS'
        },
        'body': json.dumps(body, default=str)
    }

def get_all_sources():
    """Get all sources. Placeholder returning hardcoded data."""
    # In a real application, you would fetch this from DynamoDB
    logger.info("Fetching all sources (placeholder data).")
    return [
        {"id": "203", "name": "Netflix"},
        {"id": "372", "name": "Disney+"},
        {"id": "387", "name": "Amazon Prime Video"}
    ]

def get_all_genres():
    """Get all genres. Placeholder returning hardcoded data."""
    # In a real application, you would fetch this from DynamoDB
    logger.info("Fetching all genres (placeholder data).")
    return [
        {"id": "1", "name": "Action"},
        {"id": "2", "name": "Adventure"},
        {"id": "4", "name": "Comedy"},
        {"id": "7", "name": "Drama"},
        {"id": "8", "name": "Fantasy"}
    ]

def get_user_preferences(user_id):
    """Get user preferences from DynamoDB."""
    try:
        pk = f"{USER_PREF_PREFIX}{user_id}"
        response = table.query(
            KeyConditionExpression='PK = :pk',
            ExpressionAttributeValues={':pk': pk}
        )
        
        preferences = {"sources": [], "genres": []}
        for item in response.get('Items', []):
            sk = item.get('SK', '')
            if sk.startswith('source:'):
                pref_id = sk.split(':', 1)[1]
                preferences["sources"].append(pref_id)
            elif sk.startswith('genre:'):
                pref_id = sk.split(':', 1)[1]
                preferences["genres"].append(pref_id)
        
        return preferences
    except ClientError as e:
        logger.error(f"DynamoDB error getting preferences for user {user_id}: {e}", exc_info=True)
        return None

def update_user_preferences(user_id, preferences_data):
    """Update user preferences in DynamoDB by deleting old and inserting new."""
    try:
        # First, query for existing preferences to delete them
        existing_prefs = get_user_preferences(user_id)
        if existing_prefs is None: # Error occurred in get_user_preferences
            return False

        with table.batch_writer() as batch:
            # Delete old source preferences
            for source_id in existing_prefs.get('sources', []):
                batch.delete_item(Key={'PK': f'{USER_PREF_PREFIX}{user_id}', 'SK': f'{SOURCE_PREFIX}{source_id}'})
            # Delete old genre preferences
            for genre_id in existing_prefs.get('genres', []):
                batch.delete_item(Key={'PK': f'{USER_PREF_PREFIX}{user_id}', 'SK': f'{GENRE_PREFIX}{genre_id}'})

            # Add new source preferences
            for source_id in preferences_data.get('sources', []):
                batch.put_item(Item={'PK': f'{USER_PREF_PREFIX}{user_id}', 'SK': f'{SOURCE_PREFIX}{source_id}'})
            # Add new genre preferences
            for genre_id in preferences_data.get('genres', []):
                batch.put_item(Item={'PK': f'{USER_PREF_PREFIX}{user_id}', 'SK': f'{GENRE_PREFIX}{genre_id}'})
        
        logger.info(f"Successfully updated preferences for user {user_id}")
        return True
    except ClientError as e:
        logger.error(f"DynamoDB error updating preferences for user {user_id}: {e}", exc_info=True)
        return False

def get_titles_by_preferences(user_id):
    """Get titles that match the user's preferences."""
    try:
        preferences = get_user_preferences(user_id)
        if not preferences:
            return []
        
        titles = []
        processed_titles = set()
        
        # For each source-genre combination the user prefers, get titles
        for source_id in preferences.get('sources', []):
            for genre_id in preferences.get('genres', []):
                index_pk = f"source:{source_id}:genre:{genre_id}"
                
                response = table.query(
                    KeyConditionExpression='PK = :pk',
                    ExpressionAttributeValues={':pk': index_pk}
                )
                
                for item in response.get('Items', []):
                    title_id = item.get('SK', '').split(':', 1)[1]
                    if title_id not in processed_titles:
                        # Get the full title record
                        title_response = table.get_item(
                            Key={'PK': f"{TITLE_PREFIX}{title_id}", 'SK': 'record'}
                        )
                        
                        if 'Item' in title_response:
                            title_data = title_response['Item'].get('data', {})
                            titles.append({
                                'id': title_id,
                                'title': title_data.get('title', 'Unknown'),
                                'plot_overview': title_data.get('plot_overview', 'No description available'),
                                'poster': title_data.get('poster', ''),
                                'user_rating': float(title_data.get('user_rating', 0)) if title_data.get('user_rating') else 0,
                                'source_ids': title_data.get('source_ids', []),
                                'genre_ids': title_data.get('genre_ids', [])
                            })
                            processed_titles.add(title_id)
        
        return titles
    except ClientError as e:
        logger.error(f"DynamoDB error getting titles for user {user_id}: {e}", exc_info=True)
        return []

def get_recommendations(user_id):
    """Get new recommendations for the user (rating > 7, added within last week)."""
    try:
        preferences = get_user_preferences(user_id)
        if not preferences:
            return []
        
        titles = []
        processed_titles = set()
        
        for source_id in preferences.get('sources', []):
            for genre_id in preferences.get('genres', []):
                index_pk = f"source:{source_id}:genre:{genre_id}"
                
                response = table.query(
                    KeyConditionExpression='PK = :pk',
                    ExpressionAttributeValues={':pk': index_pk}
                )
                
                for item in response.get('Items', []):
                    title_id = item.get('SK', '').split(':', 1)[1]
                    if title_id not in processed_titles:
                        title_response = table.get_item(
                            Key={'PK': f"{TITLE_PREFIX}{title_id}", 'SK': 'record'}
                        )
                        
                        if 'Item' in title_response:
                            title_data = title_response['Item'].get('data', {})
                            user_rating = title_data.get('user_rating', 0)
                            
                            if user_rating and float(user_rating) > 7:
                                titles.append({
                                    'id': title_id,
                                    'title': title_data.get('title', 'Unknown'),
                                    'plot_overview': title_data.get('plot_overview', 'No description available'),
                                    'poster': title_data.get('poster', ''),
                                    'user_rating': float(user_rating),
                                    'source_ids': title_data.get('source_ids', []),
                                    'genre_ids': title_data.get('genre_ids', [])
                                })
                                processed_titles.add(title_id)
        
        return titles
    except ClientError as e:
        logger.error(f"DynamoDB error getting recommendations for user {user_id}: {e}", exc_info=True)
        return []

def lambda_handler(event, context):
    """Handle API Gateway requests for the web API."""
    logger.info(f"Received event: {json.dumps(event)}")

    http_method = event.get('httpMethod')
    path = event.get('path')
    
    # Handle preflight OPTIONS request for CORS
    if http_method == 'OPTIONS':
        return build_response(200, {})
    
    # --- Public endpoints (no authentication required) ---
    if http_method == 'GET':
        if path == '/sources':
            return build_response(200, get_all_sources())
        if path == '/genres':
            return build_response(200, get_all_genres())

    # --- Protected endpoints (authentication required) ---
    try:
        user_id = event.get('requestContext', {}).get('authorizer', {}).get('claims', {}).get('sub')
        if not user_id:
            logger.warning("User ID not found in authorizer claims.")
            return build_response(401, {"error": "Unauthorized"})
    except Exception:
        logger.error("Could not parse user ID from event.", exc_info=True)
        return build_response(400, {"error": "Bad request format"})

    if http_method == 'GET':
        if path == '/titles':
            return build_response(200, get_titles_by_preferences(user_id))
        if path == '/recommendations':
            return build_response(200, get_recommendations(user_id))
        if path == '/preferences':
            return build_response(200, get_user_preferences(user_id))

    if http_method == 'PUT':
        if path == '/preferences':
            try:
                body = json.loads(event.get('body', '{}'))
                if update_user_preferences(user_id, body):
                    return build_response(200, {"message": "Preferences updated successfully"})
                else:
                    return build_response(500, {"error": "Failed to update preferences"})
            except json.JSONDecodeError:
                return build_response(400, {"error": "Invalid JSON in request body"})

    return build_response(404, {"error": f"Path not found or method not allowed: {http_method} {path}"})
