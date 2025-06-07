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
POST_EVENT_FILE="events/post_product.json" # For creating a new product
GET_ALL_EVENT_FILE="events/get_all_products.json"
# Templates for dynamic events
GET_SPECIFIC_EVENT_TEMPLATE_FILE="events/get_specific_product.json" # Will be modified
PUT_EVENT_TEMPLATE_FILE="events/put_products.json"                # Will be modified (path/pathParams)
DELETE_EVENT_TEMPLATE_FILE="events/delete_product.json"            # Will be modified

ENV_VARS_FILE="local-env.json"
REGION="eu-west-2"

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
POST_RESPONSE=$(sam local invoke $function_name \
    --event "${POST_EVENT_FILE}" \
    --env-vars "${ENV_VARS_FILE}" \
    --region "${REGION}")

echo "POST Response:"
echo "${POST_RESPONSE}"
echo "---------------------------------------------------------------------"

# Extract the ID from the POST response's body
# The body itself is a JSON string, so we parse it twice with jq
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
# Modify the get_specific_product.json template with the new ID
GET_SPECIFIC_EVENT_JSON=$(jq --arg id "$PRODUCT_ID" \
    '.pathParameters.id = $id | .path = ("/api/v1/products/" + $id)' \
    "${GET_SPECIFIC_EVENT_TEMPLATE_FILE}")

sam local invoke $function_name \
    --event - \
    --env-vars "${ENV_VARS_FILE}" \
    --region "${REGION}" <<< "${GET_SPECIFIC_EVENT_JSON}"
echo "---------------------------------------------------------------------"


# --- 3. Test PUT (Update) Specific Product (using captured ID) ---
echo ""
echo "Testing PUT (update) specific product for ID: ${PRODUCT_ID}"
echo "Using environment variables from: $ENV_VARS_FILE"
echo "---------------------------------------------------------------------"
# Modify the put_products.json template's path and pathParameters
# The body of put_products.json can remain as is, since the handler uses the path ID
# If you wanted to update the ID in the body string as well, it'd be more complex jq
PUT_EVENT_JSON=$(jq --arg id "$PRODUCT_ID" \
    '.pathParameters.id = $id | .path = ("/api/v1/products/" + $id)' \
    "${PUT_EVENT_TEMPLATE_FILE}")
# Note: The body of PUT_EVENT_TEMPLATE_FILE still has its original ID,
# but your handler $function_nameHandler.handlePutRequest correctly sets productToUpdate.setId(productIdFromPath)

sam local invoke $function_name \
    --event - \
    --env-vars "${ENV_VARS_FILE}" \
    --region "${REGION}" <<< "${PUT_EVENT_JSON}"
echo "---------------------------------------------------------------------"


# --- 4. Test GET ALL Products (to see the overall state) ---
echo ""
echo "Testing GET ALL products using event file: $GET_ALL_EVENT_FILE"
echo "Using environment variables from: $ENV_VARS_FILE"
echo "---------------------------------------------------------------------"
sam local invoke $function_name \
    --event "${GET_ALL_EVENT_FILE}" \
    --env-vars "${ENV_VARS_FILE}" \
    --region "${REGION}"
echo "---------------------------------------------------------------------"


# --- 5. Test DELETE Specific Product (using captured ID) ---
echo ""
echo "Testing DELETE specific product for ID: ${PRODUCT_ID}"
echo "Using environment variables from: $ENV_VARS_FILE"
echo "---------------------------------------------------------------------"
DELETE_EVENT_JSON=$(jq --arg id "$PRODUCT_ID" \
    '.pathParameters.id = $id | .path = ("/api/v1/products/" + $id)' \
    "${DELETE_EVENT_TEMPLATE_FILE}")

sam local invoke $function_name \
    --event - \
    --env-vars "${ENV_VARS_FILE}" \
    --region "${REGION}" <<< "${DELETE_EVENT_JSON}"
echo "---------------------------------------------------------------------"


# --- 6. Test GET Specific Product (should now be 404 after delete) ---
echo ""
echo "Testing GET specific product (after delete) for ID: ${PRODUCT_ID}"
echo "Using environment variables from: $ENV_VARS_FILE"
echo "---------------------------------------------------------------------"
# We can reuse GET_SPECIFIC_EVENT_JSON from step 2
sam local invoke $function_name \
    --event - \
    --env-vars "${ENV_VARS_FILE}" \
    --region "${REGION}" <<< "${GET_SPECIFIC_EVENT_JSON}" # Uses the same JSON as the earlier GET specific
echo "---------------------------------------------------------------------"


echo ""
echo "All local tests completed."