#!/bin/bash
# This script deploys changes to the existing AWS stack for rapid development and testing.

set -e

STACK_NAME="uktv-event-streaming-app"
PROFILE="streaming"
REGION="eu-west-2"

########################################################################################################################
echo "🚀 Step 1: Checking AWS SSO session for profile: ${PROFILE}..."
########################################################################################################################
if ! aws sts get-caller-identity --profile "${PROFILE}" > /dev/null 2>&1; then
    echo "⚠️ AWS SSO session expired or not found. Please log in."
    aws sso login --profile "${PROFILE}"

    if ! aws sts get-caller-identity --profile "${PROFILE}" > /dev/null 2>&1; then
        echo "❌ AWS login failed. Please check your configuration. Aborting."
        exit 1
    fi
    echo "✅ AWS login successful."
else
    echo "✅ AWS SSO session is active."
fi

# Navigate to the SAM project directory to ensure samconfig.toml is found
cd "$(dirname "$0")/../../"

########################################################################################################################
echo "🚀 Step 2: Checking stack status and cleaning up if necessary..."
########################################################################################################################
STACK_STATUS=$(aws cloudformation describe-stacks --stack-name "$STACK_NAME" --query "Stacks[0].StackStatus" --output text --profile "$PROFILE" --region "$REGION" 2>/dev/null || echo "DOES_NOT_EXIST")

if [ "$STACK_STATUS" == "ROLLBACK_COMPLETE" ]; then
    echo "🗑️ Stack is in ROLLBACK_COMPLETE state. Deleting it before deployment..."
    aws cloudformation delete-stack --stack-name "$STACK_NAME" --profile "$PROFILE" --region "$REGION"
    echo "⏳ Waiting for stack to be deleted..."
    aws cloudformation wait stack-delete-complete --stack-name "$STACK_NAME" --profile "$PROFILE" --region "$REGION"
    echo "✅ Stack deleted."
elif [ "$STACK_STATUS" != "DOES_NOT_EXIST" ] && [ "$STACK_STATUS" != "CREATE_COMPLETE" ] && [ "$STACK_STATUS" != "UPDATE_COMPLETE" ]; then
    echo "⚠️ Stack is in an unrecoverable state ($STACK_STATUS). Please check the AWS console. Aborting."
    exit 1
fi

########################################################################################################################
echo "🚀 Step 2: Building the application with SAM..."
########################################################################################################################
sam build --use-container

########################################################################################################################
echo "🚀 Step 3: Deploying changes to the stack '$STACK_NAME'..."
########################################################################################################################
sam deploy \
    --stack-name "$STACK_NAME" \
    --profile "$PROFILE" \
    --region "$REGION" \
    --capabilities CAPABILITY_NAMED_IAM CAPABILITY_AUTO_EXPAND \
    --parameter-overrides "CreateDataStream=true" "WatchModeApiKey=${WATCHMODE_API_KEY}"

echo "✅ Deployment complete. Your changes are now live."

########################################################################################################################
echo "🚀 Step 4: Setting password for the test user..."
########################################################################################################################
# Fetch stack outputs needed to set the password
USER_POOL_ID=$(aws cloudformation describe-stacks --stack-name "$STACK_NAME" --query "Stacks[0].Outputs[?OutputKey=='UserPoolId'].OutputValue" --output text --profile "$PROFILE" --region "$REGION")
TEST_USERNAME=$(aws cloudformation describe-stacks --stack-name "$STACK_NAME" --query "Stacks[0].Outputs[?OutputKey=='TestUsername'].OutputValue" --output text --profile "$PROFILE" --region "$REGION")
WEBSITE_URL=$(aws cloudformation describe-stacks --stack-name "$STACK_NAME" --query "Stacks[0].Outputs[?OutputKey=='WebsiteUrl'].OutputValue" --output text --profile "$PROFILE" --region "$REGION")

if [ -z "$USER_POOL_ID" ] || [ -z "$TEST_USERNAME" ]; then
    echo "❌ Could not retrieve User Pool ID or Test Username from stack outputs. Aborting password set."
    exit 1
fi

# Set a permanent password for the test user
TEST_USER_PASSWORD="A-Strong-P@ssw0rd1"
aws cognito-idp admin-set-user-password \
  --user-pool-id "$USER_POOL_ID" \
  --username "$TEST_USERNAME" \
  --password "$TEST_USER_PASSWORD" \
  --permanent \
  --profile "$PROFILE" \
  --region "$REGION"

echo "✅ Password for '$TEST_USERNAME' has been set."
echo ""
echo "🎉 You can now log in to the application with the following credentials:"
echo "--------------------------------------------------"
echo "Website URL: $WEBSITE_URL"
echo "Username:    $TEST_USERNAME"
echo "Password:    $TEST_USER_PASSWORD"
echo "--------------------------------------------------"

########################################################################################################################
echo "↔ Step 5: sync contents of web folder to the bucket"
########################################################################################################################
WEBSITE_BUCKET=$(aws cloudformation describe-stacks --stack-name "$STACK_NAME" --query "Stacks[0].Outputs[?OutputKey=='WebsiteBucket'].OutputValue" --output text --profile "$PROFILE" --region "$REGION")
aws s3 sync --profile "$PROFILE" --region "$REGION" "event-streaming-app/src/web/" "s3://$WEBSITE_BUCKET" 
