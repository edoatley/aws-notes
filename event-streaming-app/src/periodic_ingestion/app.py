import json
import os
import boto3 # AWS SDK for Python

# Initialize Kinesis client outside the handler for better performance
kinesis_client = boto3.client('kinesis')
KINESIS_STREAM_NAME = os.environ.get('KINESIS_STREAM_NAME') # Get from environment variable

def lambda_handler(event, context):
    """
    Periodically fetches TV data from an external API and sends it to Kinesis.
    """
    print(f"Received event: {json.dumps(event)}")
    print(f"Kinesis Stream Name from env: {KINESIS_STREAM_NAME}")

    # Placeholder for fetching data from external API
    # For example:
    # external_api_endpoint = os.environ.get('EXTERNAL_API_ENDPOINT')
    # print(f"External API Endpoint: {external_api_endpoint}")
    # response = requests.get(external_api_endpoint)
    # data_to_ingest = response.json()

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
        # Send data to Kinesis
        # The partition key helps distribute data among shards.
        # For this example, using program_id or a timestamp could be suitable.
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

# For local testing (optional)
if __name__ == "__main__":
    # Mock event and context for local testing
    mock_event = {"source": "local_test"}
    mock_context = {}
    # Set environment variables if running locally
    os.environ['KINESIS_STREAM_NAME'] = 'ProgrammeDataStream' # Replace with your actual stream name if different
    # os.environ['EXTERNAL_API_ENDPOINT'] = 'your_api_endpoint_here'
    print(lambda_handler(mock_event, mock_context))
