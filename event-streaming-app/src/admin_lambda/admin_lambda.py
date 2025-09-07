import json
import boto3
import os

# Initialize AWS clients
dynamodb = boto3.resource('dynamodb')
lambda_client = boto3.client('lambda')

# Get table names from environment variables or hardcode if necessary
# It's better to pass these via CloudFormation parameters or environment variables
# For now, let's assume they are known or can be discovered.
# Example:
# SOURCES_TABLE_NAME = os.environ.get('SOURCES_TABLE_NAME', 'SourcesTable')
# TITLES_TABLE_NAME = os.environ.get('TITLES_TABLE_NAME', 'TitlesTable')

# Placeholder for table names - these should be dynamically configured
# In a real scenario, these would be passed via CloudFormation parameters
# or discovered via AWS SDK calls if possible.
# For now, let's use common names that might exist in the project.
# We will need to confirm these table names from the CloudFormation template later.
TABLE_NAMES = {
    "reference": "SourcesTable", # Placeholder
    "titles": "TitlesTable",     # Placeholder
    "user_preferences": "UserPreferencesTable" # Placeholder
}

# Lambda function names for triggering other functions
# These should also be dynamically configured via CloudFormation
LAMBDA_FUNCTIONS = {
    "reference_data_refresh": "periodic_reference_data_lambda", # Placeholder
    "title_data_refresh": "userprefs_title_ingestion_lambda",   # Placeholder
    "title_enrichment": "title_enrichment_lambda"               # Placeholder
}

def get_dynamodb_summary():
    """
    Retrieves summary information for DynamoDB tables.
    """
    summary = {"tables": []}
    try:
        # List all tables in the region (requires dynamodb:ListTables permission)
        # This might be too broad if there are many tables.
        # A more targeted approach would be to use table names from CloudFormation.
        # For now, let's assume we know the relevant table names.
        
        for key, table_name in TABLE_NAMES.items():
            table = dynamodb.Table(table_name)
            response = table.item_count
            item_count = response.get('ItemCount')
            
            # Getting table size is not directly available via item_count.
            # We might need to use table.describe_table() for more details,
            # but item_count is a good start.
            # For a more accurate size, one might need to scan or use CloudWatch metrics.
            # For this design, we'll stick to item_count as a primary metric.
            
            summary["tables"].append({
                "name": table_name,
                "item_count": item_count,
                # "size_bytes": "N/A" # Placeholder for size, as it's not directly available here
            })
        summary["message"] = "DynamoDB data summary retrieved successfully."
    except Exception as e:
        print(f"Error retrieving DynamoDB summary: {e}")
        # In a real scenario, you might want to return a more specific error
        # or log this to CloudWatch.
        return {
            "message": f"Error retrieving DynamoDB summary: {str(e)}",
            "tables": []
        }, 500
    return summary, 200

def trigger_lambda_function(function_name, payload=None):
    """
    Triggers another Lambda function asynchronously.
    """
    try:
        if payload is None:
            payload = {}
        
        response = lambda_client.invoke(
            FunctionName=function_name,
            InvocationType='Event',  # Asynchronous invocation
            Payload=json.dumps(payload)
        )
        print(f"Successfully invoked Lambda function: {function_name}")
        # The response for 'Event' invocation type is empty on success
        return {"message": f"Lambda function '{function_name}' invoked successfully."}, 202
    except lambda_client.exceptions.ResourceNotFoundException:
        print(f"Error: Lambda function '{function_name}' not found.")
        return {"message": f"Error: Lambda function '{function_name}' not found."}, 404
    except Exception as e:
        print(f"Error invoking Lambda function {function_name}: {e}")
        return {"message": f"Error invoking Lambda function {function_name}: {str(e)}"}, 500

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
    
    if http_method == 'POST':
        if path == '/admin/data/reference/refresh':
            # Trigger reference data refresh
            # We might need to pass specific payloads if the target lambda expects them
            # For now, assuming an empty payload is sufficient for triggering.
            response_body, status_code = trigger_lambda_function(LAMBDA_FUNCTIONS["reference_data_refresh"])
        elif path == '/admin/data/titles/refresh':
            # Trigger title data refresh
            response_body, status_code = trigger_lambda_function(LAMBDA_FUNCTIONS["title_data_refresh"])
        elif path == '/admin/data/titles/enrich':
            # Trigger title enrichment
            response_body, status_code = trigger_lambda_function(LAMBDA_FUNCTIONS["title_enrichment"])
        else:
            response_body = {"message": "Not Found"}
            status_code = 404
            
    elif http_method == 'GET':
        if path == '/admin/system/dynamodb/summary':
            # Get DynamoDB summary
            response_body, status_code = get_dynamodb_summary()
        else:
            response_body = {"message": "Not Found"}
            status_code = 404
            
    else:
        response_body = {"message": "Method Not Allowed"}
        status_code = 405

    return {
        'statusCode': status_code,
        'headers': {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*' # Adjust CORS as needed
        },
        'body': json.dumps(response_body)
    }
