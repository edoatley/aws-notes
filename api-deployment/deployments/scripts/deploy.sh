#!/bin/bash


TEMPLATE="${1:-ecs-deploy}"
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
        --query 'StackEvents[?ResourceStatus==`CREATE_FAILED` || ResourceStatus==`UPDATE_FAILED`].[Timestamp,LogicalResourceId,ResourceType,ResourceStatus,ResourceStatusReason]' \
        --output text
}

# Function to validate stack status after create/update
validate_stack_applied_ok() {
    local status=$(check_stack_status ${STACK_NAME})
    if [[ "$status" != *"_COMPLETE" ]]; then
        echo "Stack operation failed. Checking events..."
        get_stack_events
        exit 1
    else
        echo "Stack operation completed successfully."
    fi
}

echo "Validating CloudFormation template..."
aws cloudformation validate-template \
    --template-body file://$(dirname "$0")/../cloudformation/$TEMPLATE.cfn --output text | cat
if [ $? -ne 0 ]; then
    echo "Template validation failed. Exiting."
    exit 1
fi
echo "Template validation successful."

# Check if stack exists and handle accordingly
if stack_exists; then
    echo "Updating existing stack ${STACK_NAME}..."
    aws cloudformation update-stack \
        --stack-name ${STACK_NAME} \
        --template-body file://$(dirname "$0")/../cloudformation/$TEMPLATE.cfn \
        --parameters ParameterKey=ECRImageNameTag,ParameterValue=product-api:v1 \
        --capabilities CAPABILITY_IAM --output text | cat
    echo "Waiting for stack update to complete..."
    aws cloudformation wait stack-update-complete --stack-name ${STACK_NAME}
    validate_stack_applied_ok
else
    echo "Creating new stack ${STACK_NAME}..."
    aws cloudformation create-stack \
        --stack-name ${STACK_NAME} \
        --template-body file://$(dirname "$0")/../cloudformation/$TEMPLATE.cfn \
        --parameters ParameterKey=ECRImageNameTag,ParameterValue=product-api:v1 \
        --capabilities CAPABILITY_IAM  --output text | cat
    echo "Waiting for stack creation to complete..."
    aws cloudformation wait stack-create-complete --stack-name ${STACK_NAME}
    validate_stack_applied_ok
fi
