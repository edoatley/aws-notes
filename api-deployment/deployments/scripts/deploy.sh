#!/bin/bash

STACK_NAME="spring-boot-api"
MAX_WAIT_MINUTES=10
SLEEP_INTERVAL=30  # 30 seconds

# Function to check if stack exists
stack_exists() {
    aws cloudformation describe-stacks --stack-name ${STACK_NAME} >/dev/null 2>&1
    return $?
}

# Function to check stack status
check_stack_status() {
    aws cloudformation describe-stacks \
        --stack-name ${STACK_NAME} \
        --query 'Stacks[0].StackStatus' \
        --output text
}

# Function to get stack events
get_stack_events() {
    aws cloudformation describe-stack-events \
        --stack-name ${STACK_NAME} \
        --query 'StackEvents[?ResourceStatus==`CREATE_FAILED` || ResourceStatus==`UPDATE_FAILED`].[LogicalResourceId,ResourceStatusReason]' \
        --output text
}

echo "Validating CloudFormation template..."
aws cloudformation validate-template \
    --template-body file://$(dirname "$0")/../cloudformation/ecs-deploy.cfn | jq '.'
if [ $? -ne 0 ]; then
    echo "Template validation failed. Exiting."
    exit 1
fi
echo "Template validation successful."£


# Check if stack is in progress
if stack_exists; then
    # Update the stack if it exists
    current_status=$(check_stack_status)
    aws cloudformation update-stack \
        --stack-name ${STACK_NAME} \
        --template-body file://$(dirname "$0")/../cloudformation/ecs-deploy.cfn \
        --parameters ParameterKey=ECRImageNameTag,ParameterValue=product-api:v1 \
        --capabilities CAPABILITY_IAM | jq '.'
    aws cloudformation wait stack-update-complete --stack-name ${STACK_NAME}
    if [ $? -ne 0 ]; then
        echo "Stack update failed. Checking events..."
        get_stack_events
        exit 1
    fi
    echo "Stack updated successfully."
fi


echo "Creating new stack ${STACK_NAME}..."
aws cloudformation create-stack \
    --stack-name ${STACK_NAME} \
    --template-body file://$(dirname "$0")/../cloudformation/ecs-deploy.cfn \
    --parameters ParameterKey=ECRImageNameTag,ParameterValue=product-api:v1 \
    --capabilities CAPABILITY_IAM | jq '.'

# Wait for stack completion
aws cloudformation wait stack-create-complete --stack-name ${STACK_NAME}


