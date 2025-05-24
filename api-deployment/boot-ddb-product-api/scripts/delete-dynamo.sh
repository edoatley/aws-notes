#!/bin/bash
AWS_REGION="eu-west-2"  # Update this to your preferred region

aws dynamodb delete-table \
    --table-name products-local \
    --region $AWS_REGION | jq