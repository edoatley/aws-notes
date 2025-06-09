#!/bin/bash

# basic details
region="eu-west-2"
stage_name="Prod"
api_base_path="/api/v1/products/" # Ensure this trailing slash matches your API Gateway output

# ... (rest of your script for getting rest_api_id) ...
rest_api_id=$1
if [[ -z "$rest_api_id" ]]; then
  # Your logic to find rest_api_id if not provided
  branch_name=$(git branch --show-current | cut -f2 -d/)
  rest_api_id=$(aws apigateway get-rest-apis --region eu-west-2 --query "items[?name=='${branch_name}'].id" --output text)
  if [[ -z "$rest_api_id" ]]; then
    echo "Error: Could not determine REST API ID. Please provide it as an argument."
    exit 1
  fi
fi

invoke_url_stage_base="https://${rest_api_id}.execute-api.${region}.amazonaws.com/${stage_name}"
full_api_endpoint="${invoke_url_stage_base}${api_base_path}"
echo "Target API Endpoint: ${full_api_endpoint}"
echo "---"

echo "1. Create a new product"
# Added -H for Content-Type and changed price to a number
# Added -i to show response headers for better debugging
product_response=$(curl -s -i -X POST \
  -H "Content-Type: application/json" \
  "${full_api_endpoint}" \
  -d '{"description": "Description of product","price":149.99,"name":"A Product Name"}')

echo "Raw POST response with headers:"
echo "$product_response"
echo "---"

# Extract body after headers (assuming HTTP/1.1 OK response)
# This is a bit fragile; a more robust script would parse headers properly
product_json_body=$(echo "$product_response" | awk 'BEGIN {RS="\r\n\r\n"} NR==2 {print}')

if [[ -z "$product_json_body" ]]; then
    echo "Error: POST response body is empty."
    exit 1
fi

uuid=$(echo "${product_json_body}" | jq -r .id)
if [[ -z "$uuid" ]] || [[ "$uuid" == "null" ]]; then
  echo "Error: Could not extract Product ID from POST response body."
  echo "Parsed body was: $product_json_body"
  exit 1
fi
echo "Product ID is ${uuid}"
echo "---"

echo "2. Retrieve the product"
curl -s -X GET "${full_api_endpoint}${uuid}" | jq
echo "---"

echo "3. Update the product"
# Added -H for Content-Type and changed price to a number
curl -s -X PUT \
  -H "Content-Type: application/json" \
  "${full_api_endpoint}${uuid}" \
  -d '{"description": "UPDATED desc of product","price":249.99,"name":"An UPDATED Product Name"}' | jq .
echo "---"

echo "4. Retrieve the updated product"
curl -s -X GET "${full_api_endpoint}${uuid}" | jq
echo "---"

echo "5. Delete the product"
delete_status_code=$(curl -s -X DELETE "${full_api_endpoint}${uuid}" -o /dev/null -w "%{http_code}")
echo "DELETE HTTP Status Code: $delete_status_code"
if [[ "$delete_status_code" -ne 204 ]]; then # 204 is typical for successful DELETE with no content
    echo "Warning: Did not delete product as expected (expected 204, got $delete_status_code)"
fi
echo "---"

echo "6. Retrieve the deleted product (should be 404)"
get_after_delete_status_code=$(curl -s -X GET "${full_api_endpoint}${uuid}" -o /dev/null -w "%{http_code}")
echo "GET after DELETE HTTP Status Code: $get_after_delete_status_code"
if [[ "$get_after_delete_status_code" -ne 404 ]]; then
    echo "Warning: Product not 404 after delete as expected (got $get_after_delete_status_code)"
fi
echo "---"
echo "Remote test script finished."