#!/bin/bash

STACK_NAME="spring-boot-api"
MAX_WAIT_MINUTES=5
SLEEP_INTERVAL=60  # 1 minute in seconds

# Function to check if stack exists
stack_exists() {
    aws cloudformation describe-stacks --stack-name ${STACK_NAME} >/dev/null 2>&1
    return $?
}

# Deploy or update the stack
if stack_exists; then
    echo "Updating existing stack ${STACK_NAME}..."
    aws cloudformation update-stack \
        --stack-name ${STACK_NAME} \
        --template-body file://../cloudformation/ecs-deploy.cfn \
        --parameters ParameterKey=ECRImageNameTag,ParameterValue=product-api:v1 \
        --capabilities CAPABILITY_IAM | jq || {
            # Check if the error was "No updates are to be performed"
            if [[ $? -eq 255 && $(aws cloudformation describe-stacks --stack-name ${STACK_NAME} --query 'Stacks[0].StackStatus' --output text) == "UPDATE_COMPLETE" ]]; then
                echo "No updates needed for stack ${STACK_NAME}"
                exit 0
            else
                echo "Stack update failed"
                exit 1
            fi
        }
    operation="UPDATE"
else
    echo "Creating new stack ${STACK_NAME}..."
    aws cloudformation create-stack \
        --stack-name ${STACK_NAME} \
        --template-body file://../cloudformation/ecs-deploy.cfn \
        --parameters ParameterKey=ECRImageNameTag,ParameterValue=product-api:v1 \
        --capabilities CAPABILITY_IAM | jq
    operation="CREATE"
fi

# Function to check stack status
check_stack_status() {
    aws cloudformation describe-stacks \
        --stack-name ${STACK_NAME} \
        --query 'Stacks[0].StackStatus' \
        --output text
}

# Wait for stack completion
echo "Waiting for stack ${operation} (max ${MAX_WAIT_MINUTES} minutes)..."
attempts=$((MAX_WAIT_MINUTES * 60 / SLEEP_INTERVAL))
count=0

while [ $count -lt $attempts ]; do
    status=$(check_stack_status)
    
    case $status in
        "${operation}_COMPLETE")
            echo "Stack ${operation} successful!"
            exit 0
            ;;
        "${operation}_FAILED"|"ROLLBACK_IN_PROGRESS"|"ROLLBACK_COMPLETE"|"UPDATE_ROLLBACK_IN_PROGRESS"|"UPDATE_ROLLBACK_COMPLETE")
            echo "Stack ${operation} failed with status: $status"
            exit 1
            ;;
        *)
            echo "Current status: $status (Attempt $((count + 1))/${attempts})"
            ;;
    esac
    
    count=$((count + 1))
    
    if [ $count -lt $attempts ]; then
        sleep $SLEEP_INTERVAL
    fi
done

echo "Operation timed out after ${MAX_WAIT_MINUTES} minutes"
exit 1