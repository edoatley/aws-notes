#!/bin/bash

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
SAM_PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Change to the SAM project root directory to run SAM commands
cd "$SAM_PROJECT_ROOT" || { echo "Failed to change directory to SAM project root: $SAM_PROJECT_ROOT"; exit 1; }

echo "Building SAM application from: $(pwd)"
sam build

# Event files are relative to the SAM_PROJECT_ROOT (which is now the current directory)
GET_ALL_EVENT_FILE="events/get_all_products.json"
POST_EVENT_FILE="events/post_product.json"
GET_SPECIFIC_EVENT_FILE="events/get_specific_product.json"
PUT_EVENT_FILE="events/put_products.json" # This one updates a specific product
DELETE_EVENT_FILE="events/delete_product.json"

ENV_VARS_FILE="local-env.json"

echo "---------------------------------------------------------------------"
DYNAMO_TABLE=$(jq -r '.ProductApiFunction.DYNAMO_TABLENAME' < ${ENV_VARS_FILE})
aws dynamodb scan --table-name ${DYNAMO_TABLE} --limit 10
echo "---------------------------------------------------------------------"


echo ""
echo "Testing POST new product using event file: $POST_EVENT_FILE"
echo "Using environment variables from: $ENV_VARS_FILE"
echo "---------------------------------------------------------------------"
sam local invoke ProductApiFunction \
    --event "${POST_EVENT_FILE}" \
    --env-vars "${ENV_VARS_FILE}" \
    --region eu-west-2
echo "---------------------------------------------------------------------"

echo ""
echo "Testing GET ALL products using event file: $GET_ALL_EVENT_FILE"
echo "Using environment variables from: $ENV_VARS_FILE"
echo "---------------------------------------------------------------------"
sam local invoke ProductApiFunction \
    --event "${GET_ALL_EVENT_FILE}" \
    --env-vars "${ENV_VARS_FILE}" \
    --region eu-west-2
echo "---------------------------------------------------------------------"

echo ""
echo "Testing GET specific product using event file: $GET_SPECIFIC_EVENT_FILE"
echo "Using environment variables from: $ENV_VARS_FILE"
echo "---------------------------------------------------------------------"
sam local invoke ProductApiFunction \
    --event "${GET_SPECIFIC_EVENT_FILE}" \
    --env-vars "${ENV_VARS_FILE}" \
    --region eu-west-2
echo "---------------------------------------------------------------------"

echo ""
echo "Testing PUT (update) specific product using event file: ${PUT_EVENT_FILE}"
echo "Using environment variables from: $ENV_VARS_FILE"
echo "---------------------------------------------------------------------"
sam local invoke ProductApiFunction \
    --event "${PUT_EVENT_FILE}" \
    --env-vars "${ENV_VARS_FILE}" \
    --region eu-west-2
echo "---------------------------------------------------------------------"

echo ""
echo "Testing DELETE specific product using event file: $DELETE_EVENT_FILE"
echo "Using environment variables from: $ENV_VARS_FILE"
echo "---------------------------------------------------------------------"
sam local invoke ProductApiFunction \
    --event "${DELETE_EVENT_FILE}" \
    --env-vars "${ENV_VARS_FILE}" \
    --region eu-west-2
echo "---------------------------------------------------------------------"

echo ""
echo "All local tests completed."