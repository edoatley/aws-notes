#!/bin/bash

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
POST_EVENT_FILE="events/apigw/post_product.json"
GET_ALL_EVENT_FILE="events/apigw/get_all_products.json"
# Templates for dynamic events
GET_SPECIFIC_EVENT_TEMPLATE_FILE="events/apigw/get_specific_product_template.json"
PUT_EVENT_TEMPLATE_FILE="events/apigw/put_product_template.json"
DELETE_EVENT_TEMPLATE_FILE="events/apigw/delete_product_template.json"
ENV_VARS_FILE="local-env.json"
REGION="eu-west-2"

# Function to clean up temporary files
cleanup_temp_files() {
    # echo "Cleaning up temporary event files..."
    rm -f /tmp/get_specific_event_*.json /tmp/put_event_*.json /tmp/delete_event_*.json
}

# Trap EXIT to ensure cleanup of temp files
trap cleanup_temp_files EXIT

echo "---------------------------------------------------------------------"
DYNAMO_TABLE=$(jq -r ".$function_name.DYNAMO_TABLENAME" < "${ENV_VARS_FILE}")
if [ -z "$DYNAMO_TABLE" ] || [ "$DYNAMO_TABLE" == "null" ]; then
    echo "Error: Could not extract DYNAMO_TABLENAME from ${ENV_VARS_FILE}"
    exit 1
fi
echo "Initial scan of DynamoDB table: ${DYNAMO_TABLE} (first 5 items)"
aws dynamodb scan --table-name "${DYNAMO_TABLE}" --limit 5 --region "${REGION}" | jq -c '.Items[]'
echo "---------------------------------------------------------------------"

# --- 1. Test POST New Product & Capture ID ---
echo ""
echo "Testing POST new product using event file: $POST_EVENT_FILE"
echo "Using environment variables from: $ENV_VARS_FILE"
echo "---------------------------------------------------------------------"
POST_RESPONSE=$(sam local invoke "$function_name" \
    --event "${POST_EVENT_FILE}" \
    --env-vars "${ENV_VARS_FILE}" \
    --region "${REGION}")

echo "POST Response:"
echo "${POST_RESPONSE}"
echo "---------------------------------------------------------------------"

PRODUCT_ID=$(echo "${POST_RESPONSE}" | jq -r '.body | fromjson | .id')

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
echo "Using environment variables from: $ENV_VARS_FILE"
echo "---------------------------------------------------------------------"
NEW_PATH="/api/v1/products/${PRODUCT_ID}"
TEMP_GET_SPECIFIC_EVENT_FILE=$(mktemp /tmp/get_specific_event_XXXXXX.json)
jq --arg id "$PRODUCT_ID" --arg new_path "$NEW_PATH" \
    '.pathParameters.id = $id | .path = $new_path | .requestContext.path = $new_path' \
    "${GET_SPECIFIC_EVENT_TEMPLATE_FILE}" > "${TEMP_GET_SPECIFIC_EVENT_FILE}"

sam local invoke "$function_name" \
    --event "${TEMP_GET_SPECIFIC_EVENT_FILE}" \
    --env-vars "${ENV_VARS_FILE}" \
    --region "${REGION}"
echo "---------------------------------------------------------------------"


# --- 3. Test PUT (Update) Specific Product (using captured ID) ---
echo ""
echo "Testing PUT (update) specific product for ID: ${PRODUCT_ID}"
echo "Using environment variables from: $ENV_VARS_FILE"
echo "---------------------------------------------------------------------"
NEW_PATH="/api/v1/products/${PRODUCT_ID}"
TEMP_PUT_EVENT_FILE=$(mktemp /tmp/put_event_XXXXXX.json)
if [ -z "$TEMP_PUT_EVENT_FILE" ]; then
    echo "Error: mktemp failed for PUT event file."
    exit 1
fi

# Construct the new body JSON string. Adjust name, description, price as needed for the update.
# This example uses fixed values for the update.
NEW_BODY_CONTENT=$(jq -n --arg id "$PRODUCT_ID" \
  '{id: $id, name: "Updated Product via Script", description: "Description updated by script", price: 29.99}')

# Ensure the NEW_BODY_CONTENT is a string within the final event's body field
jq --arg id "$PRODUCT_ID" \
   --arg new_path "$NEW_PATH" \
   --argjson new_body_obj "$NEW_BODY_CONTENT" \
    '
    .pathParameters.id = $id |
    .path = $new_path |
    .requestContext.path = $new_path |
    .body = ($new_body_obj | tojson) # Convert the new body object to a JSON string
    ' \
    "${PUT_EVENT_TEMPLATE_FILE}" > "${TEMP_PUT_EVENT_FILE}"

if [ ! -s "${TEMP_PUT_EVENT_FILE}" ]; then
    echo "Error: jq failed to create a valid event file for PUT. Check ${PUT_EVENT_TEMPLATE_FILE} and jq syntax."
    cat "${PUT_EVENT_TEMPLATE_FILE}" # Output template for debugging
    exit 1
fi

sam local invoke "$function_name" \
    --event "${TEMP_PUT_EVENT_FILE}" \
    --env-vars "${ENV_VARS_FILE}" \
    --region "${REGION}"
echo "---------------------------------------------------------------------"

# --- 4. Test GET ALL Products (to see the overall state) ---
echo ""
echo "Testing GET ALL products using event file: $GET_ALL_EVENT_FILE"
echo "Using environment variables from: $ENV_VARS_FILE"
echo "---------------------------------------------------------------------"
sam local invoke "$function_name" \
    --event "${GET_ALL_EVENT_FILE}" \
    --env-vars "${ENV_VARS_FILE}" \
    --region "${REGION}"
echo "---------------------------------------------------------------------"


# --- 5. Test DELETE Specific Product (using captured ID) ---
echo ""
echo "Testing DELETE specific product for ID: ${PRODUCT_ID}"
echo "Using environment variables from: $ENV_VARS_FILE"
echo "---------------------------------------------------------------------"
NEW_PATH="/api/v1/products/${PRODUCT_ID}"
TEMP_DELETE_EVENT_FILE=$(mktemp /tmp/delete_event_XXXXXX.json)
if [ -z "$TEMP_DELETE_EVENT_FILE" ]; then
    echo "Error: mktemp failed for DELETE event file."
    exit 1
fi

jq --arg id "$PRODUCT_ID" --arg new_path "$NEW_PATH" \
    '.pathParameters.id = $id | .path = $new_path | .requestContext.path = $new_path' \
    "${DELETE_EVENT_TEMPLATE_FILE}" > "${TEMP_DELETE_EVENT_FILE}"

if [ ! -s "${TEMP_DELETE_EVENT_FILE}" ]; then
    echo "Error: jq failed to create a valid event file for DELETE. Check ${DELETE_EVENT_TEMPLATE_FILE}."
    cat "${DELETE_EVENT_TEMPLATE_FILE}" # Output template for debugging
    exit 1
fi

sam local invoke "$function_name" \
    --event "${TEMP_DELETE_EVENT_FILE}" \
    --env-vars "${ENV_VARS_FILE}" \
    --region "${REGION}"
echo "---------------------------------------------------------------------"


# --- 6. Test GET Specific Product (should now be 404 or error, using the same logic as step 2) ---
echo ""
echo "Testing GET specific product (after delete) for ID: ${PRODUCT_ID}"
echo "Using environment variables from: $ENV_VARS_FILE"
echo "---------------------------------------------------------------------"
# Re-generate the event file for this specific call to ensure it's fresh
# (though TEMP_GET_SPECIFIC_EVENT_FILE from step 2 could be reused if not deleted)
NEW_PATH="/api/v1/products/${PRODUCT_ID}"
TEMP_GET_SPECIFIC_AFTER_DELETE_EVENT_FILE=$(mktemp /tmp/get_specific_event_YYYYYY.json)
if [ -z "$TEMP_GET_SPECIFIC_AFTER_DELETE_EVENT_FILE" ]; then
    echo "Error: mktemp failed to create temporary file for final GET."
    exit 1
fi

jq --arg id "$PRODUCT_ID" --arg new_path "$NEW_PATH" \
    '.pathParameters.id = $id | .path = $new_path | .requestContext.path = $new_path' \
    "${GET_SPECIFIC_EVENT_TEMPLATE_FILE}" > "${TEMP_GET_SPECIFIC_AFTER_DELETE_EVENT_FILE}"

if [ ! -s "${TEMP_GET_SPECIFIC_AFTER_DELETE_EVENT_FILE}" ]; then
    echo "Error: jq failed to create a valid event file for the final GET. Check ${GET_SPECIFIC_EVENT_TEMPLATE_FILE}."
    exit 1
fi

sam local invoke "$function_name" \
    --event "${TEMP_GET_SPECIFIC_AFTER_DELETE_EVENT_FILE}" \
    --env-vars "${ENV_VARS_FILE}" \
    --region "${REGION}"
echo "---------------------------------------------------------------------"


echo ""
echo "All local tests completed."
# Temporary files are cleaned up by the trap