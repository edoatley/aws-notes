#!/bin/bash

API_HOST=${1:-"http://localhost:8080"}
API_PATH=${2:-"/api/v1/products"}
API_URL="${API_HOST}${API_PATH}"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

# Function to make API calls and check response
call_api() {
    local method=$1
    local endpoint=$2
    local data=$3
    local expected_status=$4
    local operation_name=$5

    echo "Performing $operation_name..."
    local RESPONSE
    if [ -z "$data" ]; then
        RESPONSE=$(curl -s -X "$method" "$endpoint")
    else
        RESPONSE=$(curl -s -X "$method" "$endpoint" \
            -H "Content-Type: application/json" \
            -d "$data")
    fi
    local CURL_EXIT_CODE=$?
    
    echo "$operation_name response: $RESPONSE"
    check_status "$CURL_EXIT_CODE" "$RESPONSE"
    local STATUS=$?
    print_result "$STATUS" "$operation_name"
    
    # Return the response for further processing if needed
    echo "$RESPONSE"
}

# Function to print success/failure
print_result() {
    if [ $1 -eq 0 ]; then
        echo -e "${GREEN}✓ $2${NC}"
    else
        echo -e "${RED}✗ $2${NC}"
        exit 1
    fi
}

check_status() {
    local curl_exit_code=$1
    local response=$2
    
    if [ "$curl_exit_code" -eq 0 ]; then
        # Extract status from JSON response
        local http_status=$(echo "$response" | jq -r '.status')
        
        # Check if status is 200 or 201
        if [ "$http_status" = "200" ] || [ "$http_status" = "201" ]; then
            echo -e "${GREEN}✓ HTTP Status: $http_status${NC}"
            return 0
        else
            echo -e "${RED}✗ HTTP Status: $http_status${NC}"
            if [ "$http_status" = "500" ]; then
                local error_message=$(echo "$response" | jq -r '.error')
                echo -e "${RED}Error: $error_message${NC}"
            fi
            return 1
        fi
    else
        echo -e "${RED}✗ Curl command failed with exit code: $curl_exit_code${NC}"
        return 1
    fi
}

echo "API_HOST=${API_HOST}"
echo "API_URL=${API_URL}"

# Check if API is reachable
echo "Checking API availability..."
HEALTH_RESPONSE=$(call_api "GET" "${API_HOST}/actuator/health" "" 200 "Health check")

# Create a product
CREATE_RESPONSE=$(call_api "POST" "$API_URL" \
    '{"name":"Test Product","description":"A test product","price":10.99}' \
    201 "Create product")

# Get the created product ID
PRODUCT_ID=$(echo "$CREATE_RESPONSE" | jq -r '.id')

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

echo -e "${GREEN}All tests completed successfully!${NC}"