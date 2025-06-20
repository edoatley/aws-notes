import json
import os
import boto3
from botocore.exceptions import ClientError

# Environment variables
KINESIS_STREAM_NAME = os.environ.get('KINESIS_STREAM_NAME') # Get from environment variable

# Global AWS clients and fetched API key (initialized once per container)
kinesis_client = None

# Initialization block
try:
    if not KINESIS_STREAM_NAME:
        raise EnvironmentError("KINESIS_STREAM_NAME environment variable must be set.")
    kinesis_client = boto3.client('kinesis')
except EnvironmentError as e:
    print(f"Configuration error: {e}")
    raise
except ClientError as e:
    print(f"AWS Client Initialization error: {e}")
    raise


def lambda_handler(event, context):
    """
    Periodically fetches TV data from an external API and sends it to Kinesis.
    """
    print(f"Received event: {json.dumps(event)}")
    print(f"Kinesis Stream Name from env: {KINESIS_STREAM_NAME}")

    # Dummy data for now
    data_to_ingest = {
        "program_id": "12345",
        "title": "Example Show",
        "channel": "BBC One",
        "start_time": "2024-07-28T20:00:00Z",
        "end_time": "2024-07-28T21:00:00Z",
        "description": "An example TV show."
    }

    if not KINESIS_STREAM_NAME:
        print("Error: KINESIS_STREAM_NAME environment variable not set.")
        return {
            'statusCode': 500,
            'body': json.dumps({'error': 'Kinesis stream name not configured'})
        }

    try:
        response = kinesis_client.put_record(
            StreamName=KINESIS_STREAM_NAME,
            Data=json.dumps(data_to_ingest), # Data must be bytes or string
            PartitionKey=data_to_ingest["program_id"] # Choose a good partition key
        )
        print(f"Successfully sent data to Kinesis. SequenceNumber: {response['SequenceNumber']}")
        return {
            'statusCode': 200,
            'body': json.dumps({'message': 'Data ingested successfully', 'sequenceNumber': response['SequenceNumber']})
        }
    except Exception as e:
        print(f"Error sending data to Kinesis: {e}")
        return {
            'statusCode': 500,
            'body': json.dumps({'error': str(e)})
        }
