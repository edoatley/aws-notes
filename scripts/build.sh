#!/bin/bash

CFN_FILE=${1:-containers/basic-container-rt-cfn.yaml}
STACK_NAME=$(echo $CFN_FILE | cut -d'/' -f2 | cut -d'.' -f1)
AWS_REGION=${2:-eu-west-2}
parent_path=$( cd "$(dirname "${BASH_SOURCE[0]}")" ; pwd -P )
cd "$parent_path"

echo "Deploying CloudFormation stack: $STACK_NAME"
echo "Using CloudFormation template: file://$parent_path/resources/$CFN_FILE"

aws cloudformation create-stack \
    --stack-name $STACK_NAME \
    --template-body file://$parent_path/resources/$CFN_FILE \
    --capabilities CAPABILITY_NAMED_IAM \
    --region $AWS_REGION