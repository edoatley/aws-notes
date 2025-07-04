import json
import base64
import logging
import os

# Configure logger
logger = logging.getLogger()
logger.setLevel(os.environ.get("LOG_LEVEL", "INFO").upper())

def lambda_handler(event, context):
    """
    Consumes title recommendation events from a Kinesis stream and logs them.
    """
    logger.info(f"Received {len(event.get('Records', []))} records from Kinesis.")

    for record in event.get('Records', []):
        try:
            # Kinesis data is base64 encoded, so we must decode it
            payload_bytes = base64.b64decode(record.get('kinesis', {}).get('data'))
            payload_str = payload_bytes.decode('utf-8')
            title_event = json.loads(payload_str)

            logger.info(f"Successfully processed title event: {json.dumps(title_event)}")

        except (TypeError, json.JSONDecodeError, UnicodeDecodeError) as e:
            logger.error(f"Failed to decode or parse Kinesis record data: {e}")
            # Continue to the next record without failing the whole batch
            continue

    return {
        'message': f"Successfully processed {len(event.get('Records', []))} records."
    }