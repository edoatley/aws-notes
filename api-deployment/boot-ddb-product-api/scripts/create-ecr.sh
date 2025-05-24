#!/bin/bash

# Set variables
REPOSITORY_NAME="product-api"
AWS_REGION="eu-west-2"  # Update this to your preferred region
LIFECYCLE_POLICY='{"rules":[{"rulePriority":1,"description":"Keep only latest 5 images","selection":{"tagStatus":"any","countType":"imageCountMoreThan","countNumber":5},"action":{"type":"expire"}}]}'

# Create ECR repository
echo "Creating ECR repository..."
aws ecr create-repository \
    --repository-name "$REPOSITORY_NAME" \
    --region "$AWS_REGION" \
    --image-scanning-configuration scanOnPush=true \
    --image-tag-mutability MUTABLE | jq '.'

# Set lifecycle policy to automatically clean up old images
echo "Setting lifecycle policy..."
aws ecr put-lifecycle-policy \
    --repository-name "$REPOSITORY_NAME" \
    --lifecycle-policy-text "$LIFECYCLE_POLICY" \
    --region "$AWS_REGION" | jq '.'

# Enable image tag immutability
echo "Setting repository policy..."
aws ecr set-repository-policy \
    --repository-name "$REPOSITORY_NAME" \
    --policy-text '{
        "Version": "2012-10-17",
        "Statement": [
            {
                "Sid": "LimitPush",
                "Effect": "Allow",
                "Principal": {
                    "AWS": "arn:aws:iam::'"$(aws sts get-caller-identity --query 'Account' --output text)"':root"
                },
                "Action": [
                    "ecr:PutImage",
                    "ecr:InitiateLayerUpload",
                    "ecr:UploadLayerPart",
                    "ecr:CompleteLayerUpload"
                ]
            }
        ]
    }' | jq '.'

echo "Repository created successfully!"