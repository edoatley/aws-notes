#!/bin/bash

AWS_REGION="eu-west-2"

echo "----------------------------------------"
echo "Listing DynamoDB tables in $AWS_REGION region..."
echo "----------------------------------------"

aws dynamodb list-tables \
    --region $AWS_REGION | jq -r '.TableNames[]' | \
    while read -r table; do
        echo "----------------------------------------"
        echo "Table: $table"
        echo "----------------------------------------"
        aws dynamodb describe-table --table-name "$table" --region $AWS_REGION | jq '.'
        echo "----------------------------------------"
    done
echo ""
echo "----------------------------------------"
echo "All tables listed."
echo "----------------------------------------"
