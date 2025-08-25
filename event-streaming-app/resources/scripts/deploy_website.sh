#!/bin/bash

# Script to deploy the website files to S3 after CloudFormation deployment
# Usage: ./deploy_website.sh <stack-name> <aws-profile> <aws-region>

set -e

if [ $# -ne 3 ]; then
    echo "Usage: $0 <stack-name> <aws-profile> <aws-region>"
    echo "Example: $0 uktv-event-streaming-app streaming us-east-1"
    exit 1
fi

STACK_NAME=$1
PROFILE=$2
REGION=$3

echo "🚀 Deploying website to S3 for stack: $STACK_NAME"
echo "📁 Profile: $PROFILE"
echo "🌍 Region: $REGION"

# Get the website bucket name from CloudFormation outputs
echo "📋 Getting website bucket name from CloudFormation..."
BUCKET_NAME=$(aws cloudformation describe-stacks \
    --stack-name "$STACK_NAME" \
    --profile "$PROFILE" \
    --region "$REGION" \
    --query 'Stacks[0].Outputs[?OutputKey==`WebsiteBucket`].OutputValue' \
    --output text)

if [ -z "$BUCKET_NAME" ] || [ "$BUCKET_NAME" == "None" ]; then
    echo "❌ Could not find WebsiteBucket output from CloudFormation stack"
    exit 1
fi

echo "🪣 Website bucket: $BUCKET_NAME"

# Get the website URL
WEBSITE_URL=$(aws cloudformation describe-stacks \
    --stack-name "$STACK_NAME" \
    --profile "$PROFILE" \
    --region "$REGION" \
    --query 'Stacks[0].Outputs[?OutputKey==`WebsiteUrl`].OutputValue' \
    --output text)

echo "🌐 Website URL: $WEBSITE_URL"

# Upload website files
echo "📤 Uploading website files to S3..."

# Upload HTML files
aws s3 cp index.html "s3://$BUCKET_NAME/" --profile "$PROFILE" --region "$REGION"
aws s3 cp error.html "s3://$BUCKET_NAME/" --profile "$PROFILE" --region "$REGION"

# Upload JavaScript file
aws s3 cp app.js "s3://$BUCKET_NAME/" --profile "$PROFILE" --region "$REGION"

# Set proper content types
aws s3 cp "s3://$BUCKET_NAME/index.html" "s3://$BUCKET_NAME/index.html" \
    --profile "$PROFILE" --region "$REGION" \
    --content-type "text/html" --metadata-directive REPLACE

aws s3 cp "s3://$BUCKET_NAME/error.html" "s3://$BUCKET_NAME/error.html" \
    --profile "$PROFILE" --region "$REGION" \
    --content-type "text/html" --metadata-directive REPLACE

aws s3 cp "s3://$BUCKET_NAME/app.js" "s3://$BUCKET_NAME/app.js" \
    --profile "$PROFILE" --region "$REGION" \
    --content-type "application/javascript" --metadata-directive REPLACE

echo "✅ Website files uploaded successfully!"

# Make the bucket publicly readable
echo "🔓 Setting bucket policy for public read access..."
aws s3api put-bucket-policy \
    --bucket "$BUCKET_NAME" \
    --profile "$PROFILE" \
    --region "$REGION" \
    --policy '{
        "Version": "2012-10-17",
        "Statement": [
            {
                "Sid": "PublicReadGetObject",
                "Effect": "Allow",
                "Principal": "*",
                "Action": "s3:GetObject",
                "Resource": "arn:aws:s3:::'"$BUCKET_NAME"'/*"
            }
        ]
    }'

echo "✅ Bucket policy updated!"

# Enable website hosting if not already enabled
echo "🌐 Enabling website hosting..."
aws s3 website "s3://$BUCKET_NAME/" \
    --profile "$PROFILE" \
    --region "$REGION" \
    --index-document index.html \
    --error-document error.html

echo "✅ Website hosting enabled!"

echo ""
echo "🎉 Website deployment complete!"
echo "🌐 Your website is available at: $WEBSITE_URL"
echo ""
echo "📝 Next steps:"
echo "1. Update the config in app.js with your actual values:"
echo "   - userPoolId: Get from CloudFormation output 'UserPoolId'"
echo "   - userPoolClientId: Get from CloudFormation output 'UserPoolClientId'"
echo "   - apiEndpoint: Get from CloudFormation output 'ApiEndpoint' (WebApiApp)"
echo "   - preferencesApiEndpoint: Get from CloudFormation output 'ApiEndpoint' (UserPreferencesApp)"
echo "2. Upload the updated app.js file to S3"
echo "3. Test the website functionality"
