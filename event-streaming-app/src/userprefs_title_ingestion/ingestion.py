# src/userprefs_title_ingestion/ingestion.py

import json
import os
import boto3
import requests
from botocore.exceptions import ClientError
import logging
from datetime import datetime, timezone

# Configure logger
logger = logging.getLogger()
logger.setLevel(os.environ.get("LOG_LEVEL", "INFO").upper())

# --- Environment Variables ---
DYNAMODB_TABLE_NAME = os.environ.get('DYNAMODB_TABLE_NAME')
KINESIS_STREAM_NAME = os.environ.get('KINESIS_STREAM_NAME')
WATCHMODE_HOSTNAME = os.environ.get('WATCHMODE_HOSTNAME')
WATCHMODE_API_KEY_SECRET_ARN = os.environ.get('WATCHMODE_API_KEY_SECRET_ARN')
USER_PREF_PREFIX = os.environ.get('USER_PREF_PREFIX', 'userpref:')

# --- Global Clients & Cache ---
dynamodb = boto3.resource('dynamodb')
kinesis_client = boto3.client('kinesis')
table = dynamodb.Table(DYNAMODB_TABLE_NAME)
_cached_api_key = None

def get_api_key() -> str:
    """Fetches the WatchMode API key from Secrets Manager and caches it."""
    global _cached_api_key
    if _cached_api_key:
        return _cached_api_key

    if not WATCHMODE_API_KEY_SECRET_ARN:
        raise ValueError("WATCHMODE_API_KEY_SECRET_ARN environment variable not set.")

    try:
        secrets_manager_client = boto3.client('secretsmanager')
        secret_value_response = secrets_manager_client.get_secret_value(SecretId=WATCHMODE_API_KEY_SECRET_ARN)
        _cached_api_key = secret_value_response['SecretString']
        return _cached_api_key
    except ClientError as e:
        logger.error(f"Error fetching API key from Secrets Manager: {e}")
        raise

def get_all_user_preferences() -> dict:
    """Scans DynamoDB to get all unique source and genre preferences across all users."""
    all_sources = set()
    all_genres = set()
    try:
        # Using a paginator is more robust for scanning large tables
        paginator = table.meta.client.get_paginator('scan')
        pages = paginator.paginate(
            FilterExpression="begins_with(PK, :pk_prefix)",
            ExpressionAttributeValues={":pk_prefix": {"S": USER_PREF_PREFIX}}
        )
        for page in pages:
            for item in page.get('Items', []):
                sk = item.get('SK', {}).get('S', '')
                if not sk:
                    continue
                try:
                    prefix, pref_id = sk.split(':', 1)
                    if prefix == 'source':
                        all_sources.add(pref_id)
                    elif prefix == 'genre':
                        all_genres.add(pref_id)
                except ValueError:
                    logger.warning(f"Skipping malformed SK: {sk}")

        logger.info(f"Found {len(all_sources)} unique sources and {len(all_genres)} unique genres.")
        return {"sources": list(all_sources), "genres": list(all_genres)}
    except ClientError as e:
        logger.error(f"Error scanning for user preferences: {e}")
        raise

def fetch_titles(api_key: str, sources: list, genres: list) -> list:
    """Fetches titles from WatchMode based on aggregated preferences."""
    if not sources or not genres:
        logger.info("No sources or genres to fetch titles for.")
        return []

    url = f'{WATCHMODE_HOSTNAME}/v1/list-titles/'
    params = {
        "apiKey": api_key,
        "source_ids": ",".join(sources),
        "genres": ",".join(genres),
        "regions": "GB",
        "limit": 20 # Be a good citizen, limit the results for now
    }
    try:
        response = requests.get(url, params=params, timeout=20)
        response.raise_for_status()
        data = response.json()
        return data.get('titles', [])
    except requests.exceptions.RequestException as e:
        logger.error(f"Error fetching titles from WatchMode: {e}")
        return [] # Return empty list on error to not fail the whole process

def publish_titles_to_kinesis(titles: list):
    """Publishes a list of titles to the Kinesis stream."""
    if not titles:
        logger.info("No titles to publish.")
        return

    records = []
    for title in titles:
        payload = {
            "header": {
                "publishingComponent": "UserPrefsTitleIngestionFunction",
                "publishTimestamp": datetime.now(timezone.utc).isoformat(),
                "publishCause": "scheduled_user_prefs_ingestion"
            },
            "payload": title
        }
        records.append({
            'Data': json.dumps(payload),
            'PartitionKey': str(title.get('id', 'unknown'))
        })

    try:
        # Using put_records for batching is more efficient
        if records:
            kinesis_client.put_records(StreamName=KINESIS_STREAM_NAME, Records=records)
            logger.info(f"Successfully published {len(records)} titles to Kinesis.")
    except ClientError as e:
        logger.error(f"Error publishing records to Kinesis: {e}")
        raise

def lambda_handler(event, context):
    logger.info(f"Starting title ingestion based on all user preferences.")

    try:
        api_key = get_api_key()
        preferences = get_all_user_preferences()

        if preferences.get("sources") and preferences.get("genres"):
            titles = fetch_titles(api_key, preferences["sources"], preferences["genres"])
            publish_titles_to_kinesis(titles)
        else:
            logger.info("No user preferences found, nothing to ingest.")

        return {'statusCode': 200, 'body': json.dumps({'message': 'Ingestion process completed.'})}
    except Exception as e:
        logger.error(f"An unhandled error occurred: {e}", exc_info=True)
        raise