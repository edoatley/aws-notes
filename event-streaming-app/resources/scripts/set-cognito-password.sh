#!/bin/bash

# Exit immediately if a command exits with a non-zero status.
set -e

STACK_NAME="uktv-event-streaming-app"
NEW_PASSWORD="A-Strong-P@ssw0rd1"

echo "Fetching outputs from CloudFormation stack: $STACK_NAME..."

# Use aws cli to describe the stack and query the outputs.
# The --query parameter filters the JSON response.
# The --output text parameter returns the value as a clean string.
USER_POOL_ID=$(aws cloudformation describe-stacks \
  --stack-name "$STACK_NAME" \
  --query "Stacks[0].Outputs[?OutputKey=='UserPoolId'].OutputValue" \
  --output text)

USER_POOL_CLIENT_ID=$(aws cloudformation describe-stacks \
  --stack-name "$STACK_NAME" \
  --query "Stacks[0].Outputs[?OutputKey=='UserPoolClientId'].OutputValue" \
  --output text)

TEST_USERNAME=$(aws cloudformation describe-stacks \
  --stack-name "$STACK_NAME" \
  --query "Stacks[0].Outputs[?OutputKey=='TestUsername'].OutputValue" \
  --output text)

# --- Validation ---
# Check if the variables were successfully populated.
if [ -z "$USER_POOL_ID" ] || [ -z "$TEST_USERNAME" ]; then
    echo "Error: Could not retrieve stack outputs. Please check if the stack '$STACK_NAME' exists and is in a 'CREATE_COMPLETE' or 'UPDATE_COMPLETE' state."
    exit 1
fi

echo "✅ Stack outputs retrieved successfully!"
echo "   - User Pool ID: $USER_POOL_ID"
echo "   - Test Username: $TEST_USERNAME"
echo ""

# --- Set User Password ---
echo "Setting initial password for test user: $TEST_USERNAME..."

aws cognito-idp admin-set-user-password \
  --user-pool-id "$USER_POOL_ID" \
  --username "$TEST_USERNAME" \
  --password "$NEW_PASSWORD" \
  --permanent

echo "✅ Password for '$TEST_USERNAME' has been set."
echo "You can now log in with this user."