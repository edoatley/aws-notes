#!/bin/bash

# Set variables
STACK_NAME="spring-boot-api"
REGION="eu-west-2"

# Delete the CloudFormation stack
aws cloudformation delete-stack \
    --stack-name "$STACK_NAME" \
    --region "$REGION"

echo "Deleting CloudFormation stack: $STACK_NAME in $REGION"

# Wait for the stack to be deleted
aws cloudformation wait stack-delete-complete \
    --stack-name "$STACK_NAME" \
    --region "$REGION"

echo "CloudFormation stack deletion complete."