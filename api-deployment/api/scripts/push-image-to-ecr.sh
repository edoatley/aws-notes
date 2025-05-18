#!/bin/bash
AWS_REGION="eu-west-2"

aws_account=$(aws sts get-caller-identity --query 'Account' --output text)
version="v1"


aws ecr get-login-password --region $AWS_REGION | podman login --username AWS --password-stdin $aws_account.dkr.ecr.$AWS_REGION.amazonaws.com
echo "Docker login successful!"

echo "Building Docker image..."
# docker build -t product-api:$version ..
# Add --format docker to ensure OCI image compatibility with ECR
podman build --format docker -t product-api:$version ..
echo "Docker image built successfully!"

echo "Tagging Docker image for ECR ..."
podman tag product-api:$version $aws_account.dkr.ecr.$AWS_REGION.amazonaws.com/product-api:$version

echo "Pushing Docker image to ECR..."
podman push $aws_account.dkr.ecr.$AWS_REGION.amazonaws.com/product-api:$version
echo "Image pushed to ECR successfully!"