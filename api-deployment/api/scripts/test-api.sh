#!/bin/bash

API_URL="http://localhost:8080/api/products"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

# Function to print success/failure
print_result() {
    if [ $1 -eq 0 ]; then
        echo -e "${GREEN}✓ $2${NC}"
    else
        echo -e "${RED}✗ $2${NC}"
        exit 1
    fi
}

# Create a product
echo "Creating product..."
CREATE_RESPONSE=$(curl -s -X POST $API_URL \
    -H "Content-Type: application/json" \
    -d '{"name":"Test Product","description":"A test product","price":10.99}')
PRODUCT_ID=$(echo $CREATE_RESPONSE | jq -r '.id')
print_result $? "Create product"

# Get the product
echo "Getting product..."
curl -s -X GET "$API_URL/$PRODUCT_ID" > /dev/null
print_result $? "Get product"

# Update the product
echo "Updating product..."
curl -s -X PUT "$API_URL/$PRODUCT_ID" \
    -H "Content-Type: application/json" \
    -d "{\"id\":\"$PRODUCT_ID\",\"name\":\"Updated Product\",\"description\":\"An updated test product\",\"price\":19.99}" > /dev/null
print_result $? "Update product"

# List all products
echo "Listing products..."
curl -s -X GET $API_URL > /dev/null
print_result $? "List products"

# Delete the product
echo "Deleting product..."
curl -s -X DELETE "$API_URL/$PRODUCT_ID" > /dev/null
print_result $? "Delete product"

echo -e "${GREEN}All tests completed successfully!${NC}"