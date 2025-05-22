#!/bin/bash

STACK_NAME="spring-boot-api"

# Get stack status
status=$(aws cloudformation describe-stacks --stack-name ${STACK_NAME} --query 'Stacks[0].StackStatus' --output text 2>/dev/null)
if [ $? -eq 0 ]; then
    echo "Stack status: $status"
    
    # Show recent events
    echo "Recent stack events:"
    aws cloudformation describe-stack-events 
        --stack-name ${STACK_NAME} 
        --query 'StackEvents[0:5].[LogicalResourceId,ResourceStatus,ResourceStatusReason]' 
        --output table
else
    echo "Stack ${STACK_NAME} does not exist"
fi