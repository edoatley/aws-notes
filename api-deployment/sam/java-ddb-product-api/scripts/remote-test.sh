#!/bin/bash

# basic details
region="eu-west-2"
stage_name="Prod"
api_base_path="/api/v1/products/"

# get the feature branch name with the feature/ removed
branch_name=$(git branch --show-current | cut -f2 -d/)

#find a rest api with the name of the feature branch
rest_api_id=$(aws apigateway get-rest-apis --region eu-west-2 --query "items[?name=='${branch_name}'].id" --output text)

# Construct the base invoke URL for the stage
invoke_url_stage_base="https://${rest_api_id}.execute-api.${region}.amazonaws.com/${stage_name}"

# construct the full base endpoint for your product API
full_api_endpoint="${invoke_url_stage_base}${api_base_path}"
echo $full_api_endpoint

echo "Create a new product"
product_response=$(curl -s -X POST "${full_api_endpoint}" -d "{\"description\": \"Description of product\",\"price\":\"149.99\",\"name\":\"A Product Name\"}")
#echo "product_response=$product_response"

uuid=$(echo "${product_response}" | jq -r .id)
echo "Product ID is ${uuid}"

echo "Retrieve the product"
curl -s -X GET "${full_api_endpoint}${uuid}" | jq

echo "Update the product"
curl -s -X PUT "${full_api_endpoint}${uuid}" -d "{\"description\": \"UPDATED desc of product\",\"price\":\"249.99\",\"name\":\"An UPDATED Product Name\"}"

echo "Retrieve the updated product"
curl -s -X GET "${full_api_endpoint}${uuid}" | jq

echo "Delete the product"
curl -s -X DELETE "${full_api_endpoint}${uuid}" -o /dev/null -w "%{http_code}" | grep -q 204 || echo "Did not delete product"

echo "Retrieve the deleted product and fetch http status"
curl -s -X GET "${full_api_endpoint}${uuid}" -o /dev/null -w "%{http_code}" | grep -q 404

