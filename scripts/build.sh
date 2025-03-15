#!/bin bash
STACK_FOLDER=${1:-network}
STACK_NAME=${2:-simple-vpc}

# call the aws-cfn.yaml workflow passing the parameters in
gh workflow run aws-cfn.yaml \
  -p cloudformation_template_folder=$STACK_FOLDER \
  -p cloudformation_stack_name=$STACK_NAME \
  -p cloudformation_action=create
 