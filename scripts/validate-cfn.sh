#!/bin/bash

CFN_FILE=${1:-containers/basic-container-rt-cfn.yaml}
STACK_NAME=$(echo $CFN_FILE | cut -d'/' -f2 | cut -d'.' -f1)
AWS_REGION=${2:-eu-west-2}
parent_path=$(dirname $(dirname "$(realpath "$0")"))

echo "Deploying CloudFormation stack: $STACK_NAME"
echo "Using CloudFormation template: file://$parent_path/resources/$CFN_FILE"

aws cloudformation validate-template \
    --template-body file://$parent_path/resources/$CFN_FILE \
    --region $AWS_REGION