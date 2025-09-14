#!/bin/bash
# This script deploys changes to the existing AWS stack for rapid development and testing.

set -e

STACK_NAME="uktv-event-streaming-app"
PROFILE="streaming"
REGION="eu-west-2"

########################################################################################################################
echo "🚀 Step 1: Checking AWS SSO session for profile: ${PROFILE}..."
########################################################################################################################
echo "🔎 Checking AWS SSO session for profile: ${PROFILE}..."
# We don't redirect stderr here, so if the token is expired, the user sees the error.
if ! aws sts get-caller-identity --profile "${PROFILE}" > /dev/null; then
   echo "⚠️ AWS SSO session expired or not found. Attempting to refresh..."
   aws sso login --profile "${PROFILE}"

   # Final check after login attempt
   if ! aws sts get-caller-identity --profile "${PROFILE}" > /dev/null 2>&1; then
       echo "❌ AWS login failed. Please check your configuration. Aborting."
       exit 1
   fi
   echo "✅ AWS login successful."
else
   echo "✅ AWS SSO session is active."
fi

# Get AWS Account ID for constructing resource names if needed
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text --profile "${PROFILE}")

# Navigate to the SAM project directory to ensure samconfig.toml is found
cd "$(dirname "$0")/../../"

########################################################################################################################
echo "🚀 Step 2: Checking stack status and cleaning up if necessary..."
########################################################################################################################
STACK_STATUS=$(aws cloudformation describe-stacks --stack-name "$STACK_NAME" --query "Stacks[0].StackStatus" --output text --profile "$PROFILE" --region "$REGION" 2>/dev/null || echo "DOES_NOT_EXIST")

if [ "$STACK_STATUS" == "ROLLBACK_COMPLETE" ] || [ "$STACK_STATUS" == "DELETE_FAILED" ]; then
    echo "🗑️ Stack is in a recoverable but failed state ($STACK_STATUS). Cleaning up before deployment..."

    # First, try to get the bucket name from the failed stack's outputs.
    WEBSITE_BUCKET=$(aws cloudformation describe-stacks --stack-name "$STACK_NAME" --query "Stacks[0].Outputs[?OutputKey=='WebsiteBucket'].OutputValue" --output text --profile "$PROFILE" --region "$REGION" 2>/dev/null)

    # If the output doesn't exist (common in rollbacks), construct the name manually.
    if [ -z "$WEBSITE_BUCKET" ] || [ "$WEBSITE_BUCKET" == "None" ]; then
        echo "⚠️ Could not find WebsiteBucket in stack outputs. Constructing name manually."
        WEBSITE_BUCKET="${STACK_NAME}-website-${ACCOUNT_ID}"
    fi

    echo "🧹 Emptying S3 bucket: s3://${WEBSITE_BUCKET}..."
    # Use aws s3 ls to check if the bucket exists before trying to empty it.
    if aws s3 ls "s3://${WEBSITE_BUCKET}" --profile "${PROFILE}" --region "$REGION" > /dev/null 2>&1; then
        aws s3 rm "s3://${WEBSITE_BUCKET}" --recursive --profile "$PROFILE" --region "$REGION"
        aws s3api delete-bucket --bucket "${WEBSITE_BUCKET}" --profile "$PROFILE" --region "$REGION"
        echo "✅ Bucket emptied and deleted to be safe."
    else
        echo "✅ Bucket does not exist or is already gone. No action needed."
    fi

    echo "🗑️ Deleting stack..."
    aws cloudformation delete-stack --stack-name "$STACK_NAME" --profile "$PROFILE" --region "$REGION"
    echo "⏳ Waiting for stack to be deleted..."
    aws cloudformation wait stack-delete-complete --stack-name "$STACK_NAME" --profile "$PROFILE" --region "$REGION"
    echo "✅ Stack deleted."
elif [ "$STACK_STATUS" != "DOES_NOT_EXIST" ] && [ "$STACK_STATUS" != "CREATE_COMPLETE" ] && [ "$STACK_STATUS" != "UPDATE_COMPLETE" ] && [ "$STACK_STATUS" != "UPDATE_ROLLBACK_COMPLETE" ]; then
    echo "⚠️ Stack is in an unrecoverable state ($STACK_STATUS). Please check the AWS console. Aborting."
    exit 1
fi

########################################################################################################################
echo "🚀 Step 3: Building the application with SAM..."
########################################################################################################################
sam build --use-container

########################################################################################################################
echo "🚀 Step 4: Deploying changes to the stack '$STACK_NAME'..."
########################################################################################################################
# Check if WATCHMODE_API_KEY is set
if [ -z "$WATCHMODE_API_KEY" ]; then
    echo "❌ Error: WATCHMODE_API_KEY environment variable is not set."
    echo "Please set it before running this script:"
    echo "export WATCHMODE_API_KEY='your-api-key-here'"
    exit 1
fi

sam deploy \
    --stack-name "$STACK_NAME" \
    --profile "$PROFILE" \
    --region "$REGION" \
    --capabilities CAPABILITY_NAMED_IAM CAPABILITY_AUTO_EXPAND \
    --parameter-overrides "CreateDataStream=true" "WatchModeApiKey=${WATCHMODE_API_KEY}"

echo "✅ Deployment complete. Your changes are now live."

########################################################################################################################
echo "🚀 Step 5: Setting password for the test user..."
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
echo "↔ Step 6: Creating config.js and syncing web content to S3"
########################################################################################################################
# Fetch outputs for config.js
WEBSITE_BUCKET=$(aws cloudformation describe-stacks --stack-name "$STACK_NAME" --query "Stacks[0].Outputs[?OutputKey=='WebsiteBucket'].OutputValue" --output text --profile "$PROFILE" --region "$REGION")
USER_POOL_ID=$(aws cloudformation describe-stacks --stack-name "$STACK_NAME" --query "Stacks[0].Outputs[?OutputKey=='UserPoolId'].OutputValue" --output text --profile "$PROFILE" --region "$REGION")
USER_POOL_CLIENT_ID=$(aws cloudformation describe-stacks --stack-name "$STACK_NAME" --query "Stacks[0].Outputs[?OutputKey=='UserPoolClientId'].OutputValue" --output text --profile "$PROFILE" --region "$REGION")
USER_POOL_DOMAIN=$(aws cloudformation describe-stacks --stack-name "$STACK_NAME" --query "Stacks[0].Outputs[?OutputKey=='UserPoolDomain'].OutputValue" --output text --profile "$PROFILE" --region "$REGION")
WEB_API_ENDPOINT=$(aws cloudformation describe-stacks --stack-name "$STACK_NAME" --query "Stacks[0].Outputs[?OutputKey=='WebApiEndpoint'].OutputValue" --output text --profile "$PROFILE" --region "$REGION")
ADMIN_API_ENDPOINT=$(aws cloudformation describe-stacks --stack-name "$STACK_NAME" --query "Stacks[0].Outputs[?OutputKey=='AdminApiEndpoint'].OutputValue" --output text --profile "$PROFILE" --region "$REGION")

# Validate that all required outputs were fetched
if [ -z "$WEBSITE_BUCKET" ] || [ -z "$USER_POOL_ID" ] || [ -z "$USER_POOL_CLIENT_ID" ] || [ -z "$USER_POOL_DOMAIN" ] || [ -z "$WEB_API_ENDPOINT" ] || [ -z "$ADMIN_API_ENDPOINT" ]; then
    echo "❌ Error: Failed to retrieve one or more required outputs from the CloudFormation stack."
    echo "Please check the stack '$STACK_NAME' in the AWS console and ensure it deployed successfully with all outputs."
    exit 1
fi
echo "✅ All required stack outputs retrieved successfully."

# Create config.js in the web directory
CONFIG_FILE="src/web/config.js"
echo "📝 Creating config file at ${CONFIG_FILE}..."
cat << EOF > "$CONFIG_FILE"
window.appConfig = {
    Auth: {
        userPoolId: "${USER_POOL_ID}",
        userPoolClientId: "${USER_POOL_CLIENT_ID}",
        region: "${REGION}",
        oauth: {
            domain: "${USER_POOL_DOMAIN}.auth.${REGION}.amazoncognito.com",
            scope: ['openid', 'email', 'profile'],
            redirectSignIn: "", // Not used in this flow, but good to have
            redirectSignOut: "", // Not used in this flow
            responseType: 'token'
        }
    },
    ApiEndpoint: "${WEB_API_ENDPOINT}",
    AdminApiEndpoint: "${ADMIN_API_ENDPOINT}"
};
EOF
echo "✅ Config file created."

# Sync the entire web directory to the S3 bucket
echo "🔄 Syncing src/web/ to s3://${WEBSITE_BUCKET}..."
aws s3 sync "src/web/" "s3://${WEBSITE_BUCKET}" --profile "${PROFILE}" --region "${REGION}" --delete
echo "✅ Web content synced successfully."

########################################################################################################################
echo "🧹 Step 7: Clearing the CloudFront cache..."
########################################################################################################################
DISTRIBUTION_ID=$(aws cloudformation describe-stacks --stack-name "$STACK_NAME" --query "Stacks[0].Outputs[?OutputKey=='WebsiteDistributionId'].OutputValue" --output text --profile "$PROFILE" --region "$REGION")
if [ -z "$DISTRIBUTION_ID" ]; then
    echo "❌ Could not retrieve CloudFront Distribution ID from stack outputs. Aborting cache clear."
    exit 1
fi

aws cloudfront create-invalidation --distribution-id "$DISTRIBUTION_ID" --paths "/*" --profile "$PROFILE" --region "$REGION" | jq
echo "✅ CloudFront cache invalidation created. Changes will be live shortly."
