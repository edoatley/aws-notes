#!/bin/bash

# CloudFormation Template Validation Script
# This script performs multiple validation checks before deployment

set -e

TEMPLATE_FILE="template.yaml"
REGION="${AWS_REGION:-us-east-1}"
STACK_NAME="glue-schema-registry-testbed"
AWS_PROFILE="${AWS_PROFILE:-streaming}"

echo "=========================================="
echo "CloudFormation Template Validation"
echo "=========================================="
echo "Template: $TEMPLATE_FILE"
echo "Region: $REGION"
echo "AWS Profile: $AWS_PROFILE"
echo ""

# Check if template file exists
if [ ! -f "$TEMPLATE_FILE" ]; then
    echo "❌ ERROR: Template file '$TEMPLATE_FILE' not found!"
    exit 1
fi

# 1. YAML Syntax Check (if yamllint is available)
if command -v yamllint &> /dev/null; then
    echo "✓ Checking YAML syntax with yamllint..."
    yamllint "$TEMPLATE_FILE" || {
        echo "❌ YAML syntax errors found!"
        exit 1
    }
    echo "  ✓ YAML syntax is valid"
else
    echo "⚠ yamllint not found, skipping YAML syntax check"
    echo "  Install with: pip install yamllint"
fi

# 2. AWS CloudFormation Template Validation
echo ""
echo "✓ Validating CloudFormation template with AWS CLI..."
VALIDATION_OUTPUT=$(aws cloudformation validate-template \
    --template-body "file://$TEMPLATE_FILE" \
    --region "$REGION" \
    --profile "$AWS_PROFILE" 2>&1) || {
    echo "❌ CloudFormation validation failed!"
    echo "$VALIDATION_OUTPUT"
    exit 1
}

echo "  ✓ CloudFormation template is valid"
echo "  Template Description: $(echo "$VALIDATION_OUTPUT" | jq -r '.Description // "N/A"')"

# 3. Check for common issues using grep
echo ""
echo "✓ Checking for common template issues..."

# Check for unsupported Tags on IAM::InstanceProfile
if grep -A 5 "AWS::IAM::InstanceProfile" "$TEMPLATE_FILE" | grep -q "Tags:"; then
    echo "  ❌ WARNING: AWS::IAM::InstanceProfile does not support Tags property"
    echo "     This will cause deployment to fail!"
    exit 1
fi

# Check for array Tags on MSK::ServerlessCluster (should be object)
if grep -A 10 "AWS::MSK::ServerlessCluster" "$TEMPLATE_FILE" | grep -A 5 "Tags:" | grep -q "Key:"; then
    echo "  ❌ WARNING: AWS::MSK::ServerlessCluster Tags should be an object, not an array"
    echo "     Use: Tags: { Name: value } instead of Tags: [{ Key: Name, Value: value }]"
    exit 1
fi

# Check for proper UserData format
if grep -A 2 "UserData:" "$TEMPLATE_FILE" | grep -q "Fn::Base64.*!Sub"; then
    echo "  ⚠ INFO: UserData uses Fn::Base64 with !Sub (this is valid)"
fi

# 4. Check if stack already exists and is in a bad state
echo ""
echo "✓ Checking if stack '$STACK_NAME' exists..."
if aws cloudformation describe-stacks --stack-name "$STACK_NAME" --region "$REGION" --profile "$AWS_PROFILE" &>/dev/null; then
    STACK_STATUS=$(aws cloudformation describe-stacks \
        --stack-name "$STACK_NAME" \
        --region "$REGION" \
        --profile "$AWS_PROFILE" \
        --query 'Stacks[0].StackStatus' \
        --output text 2>/dev/null || echo "UNKNOWN")
    
    if [[ "$STACK_STATUS" == *"ROLLBACK"* ]] || [[ "$STACK_STATUS" == *"FAILED"* ]]; then
        echo "  ⚠ WARNING: Stack exists with status: $STACK_STATUS"
        echo "  You may need to delete it before deploying:"
        echo "    aws cloudformation delete-stack --stack-name $STACK_NAME --region $REGION --profile $AWS_PROFILE"
    elif [[ "$STACK_STATUS" == "CREATE_COMPLETE" ]] || [[ "$STACK_STATUS" == "UPDATE_COMPLETE" ]]; then
        echo "  ✓ Stack exists and is in good state: $STACK_STATUS"
    else
        echo "  ⚠ Stack exists with status: $STACK_STATUS"
    fi
else
    echo "  ✓ Stack does not exist (ready for new deployment)"
fi

echo ""
echo "=========================================="
echo "✅ All validation checks passed!"
echo "=========================================="
echo ""
echo "You can now deploy with:"
echo "  aws cloudformation deploy \\"
echo "    --template-file $TEMPLATE_FILE \\"
echo "    --stack-name $STACK_NAME \\"
echo "    --capabilities CAPABILITY_NAMED_IAM \\"
echo "    --region $REGION \\"
echo "    --profile $AWS_PROFILE"
echo ""

