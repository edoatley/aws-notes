import json
import boto3
import os
import uuid # Import uuid for job ID generation

# Initialize AWS clients
dynamodb = boto3.resource('dynamodb')
lambda_client = boto3.client('lambda')

# --- Configuration ---
# Table names identified from CloudFormation
# Note: The design doc mentions SourcesTable and TitlesTable for summary,
# but only ProgrammesTable is explicitly defined in the root template.
# We will use ProgrammesTable for now. If other tables are needed for summary,
# they would need to be defined or discovered.
PROGRAMMES_TABLE_NAME = os.environ.get('PROGRAMMES_TABLE_NAME', 'UKTVProgrammes') # Default from CloudFormation parameter

# Lambda function names identified from nested CloudFormation templates
LAMBDA_FUNCTIONS = {
    "reference_data_refresh": "PeriodicUKTVReferenceFunction",
    "title_data_refresh": "PeriodicUKTitlesForUserPrefsFunction",
    "title_enrichment": "TitleEnrichmentFunction"
}

# --- Helper Functions ---

def get_dynamodb_summary():
    """
    Retrieves summary information for DynamoDB tables.
    Currently focuses on ProgrammesTable.
    """
    summary = {"tables": []}
    try:
        # Get item count for the ProgrammesTable
        table = dynamodb.Table(PROGRAMMES_TABLE_NAME)
        item_count_response = table.item_count
        item_count = item_count_response.get('ItemCount')

        # Getting table size is not directly available via item_count.
        # For a more accurate size, one might need to scan or use CloudWatch metrics.
        # For this design, we'll stick to item_count as a primary metric.
        # If table size is critical, further implementation is needed.

        summary["tables"].append({
            "name": PROGRAMMES_TABLE_NAME,
            "item_count": item_count,
            "size_bytes": "N/A" # Placeholder for size, as it's not directly available here
        })
        summary["message"] = "DynamoDB data summary retrieved successfully."
        return summary, 200
    except dynamodb.meta.client.exceptions.ResourceNotFoundException:
        error_message = f"DynamoDB table '{PROGRAMMES_TABLE_NAME}' not found."
        print(f"Error: {error_message}")
        return {"message": error_message, "tables": []}, 404
    except Exception as e:
        error_message = f"Error retrieving DynamoDB summary: {str(e)}"
        print(f"Error: {error_message}")
        return {"message": error_message, "tables": []}, 500

def trigger_lambda_function(function_name, payload=None):
    """
    Triggers another Lambda function asynchronously and returns a job ID.
    """
    job_id = str(uuid.uuid4()) # Generate a unique job ID
    try:
        if payload is None:
            payload = {}
        
        # Add job_id to the payload for tracking if needed by the target function
        payload['job_id'] = job_id

        response = lambda_client.invoke(
            FunctionName=function_name,
            InvocationType='Event',  # Asynchronous invocation
            Payload=json.dumps(payload)
        )
        print(f"Successfully invoked Lambda function: {function_name} with job ID: {job_id}")
        
        # The response for 'Event' invocation type is empty on success,
        # so we return the generated job_id.
        return {"message": f"Lambda function '{function_name}' initiated.", "job_id": job_id}, 202
    except lambda_client.exceptions.ResourceNotFoundException:
        error_message = f"Lambda function '{function_name}' not found."
        print(f"Error: {error_message}")
        return {"message": error_message}, 404
    except Exception as e:
        error_message = f"Error invoking Lambda function {function_name}: {str(e)}"
        print(f"Error: {error_message}")
        return {"message": error_message}, 500

# --- Main Handler ---

def lambda_handler(event, context):
    """
    Main handler for the admin Lambda function.
    Routes requests based on HTTP method and path.
    """
    print(f"Received event: {json.dumps(event)}")

    http_method = event.get('httpMethod')
    path = event.get('path')
    
    # API Gateway proxy integration expects a specific response format
    # https://docs.aws.amazon.com/apigateway/latest/developerguide/set-up-lambda-proxy-integrations.html#api-gateway-simple-proxy-for-lambda-output-format
    
    response_body = {"message": "Not Found"}
    status_code = 404
    
    if http_method == 'POST':
        if path == '/admin/data/reference/refresh':
            response_body, status_code = trigger_lambda_function(LAMBDA_FUNCTIONS["reference_data_refresh"])
        elif path == '/admin/data/titles/refresh':
            response_body, status_code = trigger_lambda_function(LAMBDA_FUNCTIONS["title_data_refresh"])
        elif path == '/admin/data/titles/enrich':
            response_body, status_code = trigger_lambda_function(LAMBDA_FUNCTIONS["title_enrichment"])
        else:
            response_body = {"message": f"POST request to unknown path: {path}"}
            status_code = 404
            
    elif http_method == 'GET':
        if path == '/admin/system/dynamodb/summary':
            response_body, status_code = get_dynamodb_summary()
        else:
            response_body = {"message": f"GET request to unknown path: {path}"}
            status_code = 404
            
    else:
        response_body = {"message": f"Unsupported HTTP method: {http_method}"}
        status_code = 405

    return {
        'statusCode': status_code,
        'headers': {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*' # Adjust CORS as needed
        },
        'body': json.dumps(response_body)
    }