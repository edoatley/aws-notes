#!/bin/bash

API_HOST=${1:-"http://localhost:8080"}
API_PATH=${2:-"/api/v1/products"}
API_URL="${API_HOST}${API_PATH}"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

exit_code_to_send=0

# Function to make API calls and check response
# Function to make API calls and check response
call_api() {
    local method=$1
    local endpoint=$2
    local data=$3
    local expected_status=$4
    local operation_name=$5

    echo "Performing $operation_name..."
    local RESPONSE
    local HTTP_STATUS
    if [ -z "$data" ]; then
        RESPONSE=$(curl -s -w "%{http_code}" -X "$method" "$endpoint")
    else
        RESPONSE=$(curl -s -w "%{http_code}" -X "$method" "$endpoint" \
            -H "Content-Type: application/json" \
            -d "$data")
    fi
    local CURL_EXIT_CODE=$?
    
    # Extract the status code (last 3 characters) and response body
    HTTP_STATUS="${RESPONSE:(-3)}"
    RESPONSE_BODY="${RESPONSE:0:${#RESPONSE}-3}"
    
    echo "$operation_name response: $RESPONSE_BODY"
    echo "$operation_name status code: $HTTP_STATUS"
    
    # Check if status matches expected
    if [ "$HTTP_STATUS" = "$expected_status" ]; then
        echo -e "${GREEN}✓ $operation_name, HTTP Status: $HTTP_STATUS${NC}"
        echo "$RESPONSE_BODY"
        return 0
    else
        echo -e "${RED}✗ HTTP Status: $HTTP_STATUS (expected $expected_status)${NC}"
        if [ "$HTTP_STATUS" = "500" ]; then
            local error_message=$(echo "$RESPONSE_BODY" | jq -r '.error')
            echo -e "${RED}Error $operation_name: $error_message${NC}"
        fi
        exit_code_to_send=1
        return 1
    fi
}

echo "API_HOST=${API_HOST}"
echo "API_URL=${API_URL}"

# Check if API is reachable
HEALTH_RESPONSE=$(call_api "GET" "${API_HOST}/actuator/health" "" 200 "Health check")

# Create a product
CREATE_RESPONSE=$(call_api "POST" "$API_URL" \
    '{"id":"test-id-2","name":"Test Product","description":"A test product","price":10.99}' \
    201 "Create product")

# Get the created product ID
PRODUCT_ID="test-id-2"

# Get the product
call_api "GET" "${API_URL}/${PRODUCT_ID}" "" 200 "Get product"

# Update the product
call_api "PUT" "${API_URL}/${PRODUCT_ID}" \
    "{\"id\":\"${PRODUCT_ID}\",\"name\":\"Updated Product\",\"description\":\"An updated test product\",\"price\":19.99}" \
    200 "Update product"

# Delete the product
call_api "DELETE" "${API_URL}/${PRODUCT_ID}" "" 200 "Delete product"

# Verify deletion
call_api "GET" "${API_URL}/${PRODUCT_ID}" "" 404 "Verify deletion"

if [ $exit_code_to_send -ne 0 ]; then
    echo -e "${RED}Some tests failed. Please check the logs above.${NC}"
    exit 1
fi

echo -e "${GREEN}All tests completed successfully!${NC}"
