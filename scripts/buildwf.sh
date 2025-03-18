#!/bin/bash
STACK_FOLDER=${1:-network}
STACK_NAME=${2:-simple-vpc}

export GITHUB_TOKEN=$GH_TOKEN_WORKFLOW

# call the aws-cfn.yaml workflow
gh workflow run aws-cfn.yaml \
  --field cloudformation_template_folder=$STACK_FOLDER \
  --field cloudformation_stack_name=$STACK_NAME \
  --field cloudformation_action=apply