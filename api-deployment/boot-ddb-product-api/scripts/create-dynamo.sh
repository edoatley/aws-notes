#!/bin/bash
AWS_REGION="eu-west-2"  # Update this to your preferred region

aws dynamodb create-table \
    --table-name products-local \
    --attribute-definitions AttributeName=id,AttributeType=S \
    --key-schema AttributeName=id,KeyType=HASH \
    --provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5 \
    --region $AWS_REGION | jq