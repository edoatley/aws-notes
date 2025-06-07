#!/bin/bash

# Exit on any error
set -e

function_name=${1:-"ProductApiFunction"}

# Get the directory where the script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
# SAM_PROJECT_ROOT is the parent directory of 'scripts'
SAM_PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Change to the SAM project root directory to run SAM commands
cd "$SAM_PROJECT_ROOT" || { echo "Failed to change directory to SAM project root: $SAM_PROJECT_ROOT"; exit 1; }

echo "Building SAM application from: $(pwd)"
sam build

# Event files are relative to the SAM_PROJECT_ROOT (which is now the current directory)
POST_EVENT_FILE="events/post_product.json" # For creating a new product
GET_ALL_EVENT_FILE="events/get_all_products.json" # Path will be used from this for GET ALL
# Templates for dynamic events - only PUT body is used from its template
PUT_EVENT_TEMPLATE_FILE="events/put_products.json" # Body will be extracted

ENV_VARS_FILE="local-env.json"
REGION="eu-west-2"
LOCAL_API_BASE_URL="http://127.0.0.1:3000" # Default SAM local start-api port
SAM_API_LOG_FILE="./sam-local-api.log"
SAM_API_PID=""

# Function to clean up SAM API process
cleanup() {
    echo ""
    echo "Cleaning up SAM local API..."
    if [ -n "$SAM_API_PID" ] && ps -p "$SAM_API_PID" > /dev/null; then
        kill "$SAM_API_PID"
        wait "$SAM_API_PID" 2>/dev/null
        echo "SAM local API (PID: $SAM_API_PID) stopped."
    else
        echo "SAM local API already stopped or PID not found."
    fi
    if [ -f "$SAM_API_LOG_FILE" ]; then
        echo "SAM local API log available at: $SAM_API_LOG_FILE"
    fi
    echo "Cleanup finished."
}

# Trap EXIT and ERR signals to ensure cleanup
trap cleanup EXIT ERR

echo "---------------------------------------------------------------------"
DYNAMO_TABLE=$(jq -r ".$function_name.DYNAMO_TABLENAME" < "${ENV_VARS_FILE}")
if [ -z "$DYNAMO_TABLE" ] || [ "$DYNAMO_TABLE" == "null" ]; then
    echo "Error: Could not extract DYNAMO_TABLENAME from ${ENV_VARS_FILE} for function ${function_name}"
    exit 1
fi
echo "Initial scan of DynamoDB table: ${DYNAMO_TABLE} (first 5 items)"
aws dynamodb scan --table-name "${DYNAMO_TABLE}" --limit 5 --region "${REGION}" | jq -c '.Items[]'
echo "---------------------------------------------------------------------"

echo ""
echo "Starting SAM local API in background..."
echo "Logs will be written to: ${SAM_API_LOG_FILE}"
# Start sam local start-api, redirecting its stdout and stderr to a log file
sam local start-api \
    --env-vars "${ENV_VARS_FILE}" \
    --region "${REGION}" \
    --log-file "${SAM_API_LOG_FILE}" &
SAM_API_PID=$!
echo "SAM local API started with PID: $SAM_API_PID"

# Wait for the API to be ready
# A more robust check would involve curling a health endpoint in a loop
echo "Waiting for SAM local API to be ready (5 seconds)..."
sleep 5
# Check if the process is still running
if ! ps -p "$SAM_API_PID" > /dev/null; then
    echo "Error: SAM local API failed to start. Check ${SAM_API_LOG_FILE}."
    exit 1
fi
echo "SAM local API should be ready."
echo "---------------------------------------------------------------------"


# --- 1. Test POST New Product & Capture ID ---
echo ""
echo "Testing POST new product using event file: $POST_EVENT_FILE"
echo "Targeting endpoint: ${LOCAL_API_BASE_URL}/api/v1/products"
echo "---------------------------------------------------------------------"
# Extract the 'body' content from the event file for the curl payload
POST_REQUEST_BODY=$(jq -r '.body' "${POST_EVENT_FILE}")

POST_RESPONSE=$(curl -s -X POST \
    -H "Content-Type: application/json" \
    -d "${POST_REQUEST_BODY}" \
    "${LOCAL_API_BASE_URL}/api/v1/products")

echo "POST Response:"
echo "${POST_RESPONSE}" | jq . # Pretty print JSON response
echo "---------------------------------------------------------------------"

# Extract the ID from the POST response's body
# POST_RESPONSE variable in your local-test-api.sh script (when using sam local start-api
# and curl) already contains the direct JSON body returned by your Lambda function, not the
# full API Gateway proxy response structure.

PRODUCT_ID=$(echo "${POST_RESPONSE}" | jq -r '.id')

if [ -z "$PRODUCT_ID" ] || [ "$PRODUCT_ID" == "null" ]; then
    echo "Error: Could not extract PRODUCT_ID from POST response."
    echo "POST_RESPONSE was: ${POST_RESPONSE}"
    exit 1
fi
echo "Captured PRODUCT_ID: ${PRODUCT_ID}"
echo "---------------------------------------------------------------------"


# --- 2. Test GET Specific Product (using captured ID) ---
echo ""
echo "Testing GET specific product for ID: ${PRODUCT_ID}"
echo "Targeting endpoint: ${LOCAL_API_BASE_URL}/api/v1/products/${PRODUCT_ID}"
echo "---------------------------------------------------------------------"
GET_SPECIFIC_RESPONSE=$(curl -s -X GET "${LOCAL_API_BASE_URL}/api/v1/products/${PRODUCT_ID}")
echo "${GET_SPECIFIC_RESPONSE}" | jq .
echo "---------------------------------------------------------------------"


# --- 3. Test PUT (Update) Specific Product (using captured ID) ---
echo ""
echo "Testing PUT (update) specific product for ID: ${PRODUCT_ID}"
echo "Using request body from: ${PUT_EVENT_TEMPLATE_FILE}"
echo "Targeting endpoint: ${LOCAL_API_BASE_URL}/api/v1/products/${PRODUCT_ID}"
echo "---------------------------------------------------------------------"
# Extract the 'body' content from the PUT event template file for the curl payload
PUT_REQUEST_BODY=$(jq -r '.body' "${PUT_EVENT_TEMPLATE_FILE}")

PUT_RESPONSE=$(curl -s -X PUT \
    -H "Content-Type: application/json" \
    -d "${PUT_REQUEST_BODY}" \
    "${LOCAL_API_BASE_URL}/api/v1/products/${PRODUCT_ID}")
echo "${PUT_RESPONSE}" | jq .
echo "---------------------------------------------------------------------"


# --- 4. Test GET ALL Products (to see the overall state) ---
echo ""
echo "Testing GET ALL products"
echo "Targeting endpoint: ${LOCAL_API_BASE_URL}/api/v1/products"
echo "---------------------------------------------------------------------"
GET_ALL_RESPONSE=$(curl -s -X GET "${LOCAL_API_BASE_URL}/api/v1/products")
echo "${GET_ALL_RESPONSE}" | jq .
echo "---------------------------------------------------------------------"


# --- 5. Test DELETE Specific Product (using captured ID) ---
echo ""
echo "Testing DELETE specific product for ID: ${PRODUCT_ID}"
echo "Targeting endpoint: ${LOCAL_API_BASE_URL}/api/v1/products/${PRODUCT_ID}"
echo "---------------------------------------------------------------------"
DELETE_RESPONSE=$(curl -s -X DELETE "${LOCAL_API_BASE_URL}/api/v1/products/${PRODUCT_ID}")
# DELETE often returns 204 No Content, body might be empty or not JSON
if [ -n "$DELETE_RESPONSE" ]; then
  echo "${DELETE_RESPONSE}" | jq .
else
  echo "DELETE request sent, response body is empty (as expected for 204 No Content)."
fi
echo "---------------------------------------------------------------------"


# --- 6. Test GET Specific Product (should now be 404 after delete) ---
echo ""
echo "Testing GET specific product (after delete) for ID: ${PRODUCT_ID}"
echo "Targeting endpoint: ${LOCAL_API_BASE_URL}/api/v1/products/${PRODUCT_ID}"
echo "---------------------------------------------------------------------"
GET_AFTER_DELETE_RESPONSE=$(curl -s -X GET "${LOCAL_API_BASE_URL}/api/v1/products/${PRODUCT_ID}")
echo "${GET_AFTER_DELETE_RESPONSE}" | jq .
echo "---------------------------------------------------------------------"


echo ""
echo "All local tests completed."
# Cleanup will be handled by the trap EXIT