#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

AWS_REGION="eu-west-2"
IMAGE_NAME="product-api"
VERSION="v1"
CONTAINER_NAME="product-api-test"
TEST_PORT=8080

# Function to handle errors
handle_error() {
    echo -e "${RED}Error: $1${NC}"
    exit 1
}

# Get AWS account ID
aws_account=$(aws sts get-caller-identity --query 'Account' --output text) || handle_error "Failed to get AWS account ID"

echo "Building Docker image..."
podman build --format docker -t ${IMAGE_NAME}:${VERSION} .. || handle_error "Image build failed"
echo -e "${GREEN}Docker image built successfully!${NC}"

echo "Starting container for testing..."
# Clean up any existing container
podman rm -f ${CONTAINER_NAME} 2>/dev/null

# Run the container
podman run -d --name ${CONTAINER_NAME} -p ${TEST_PORT}:${TEST_PORT} -e AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID} -e AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY} ${IMAGE_NAME}:${VERSION} || handle_error "Failed to start container"

# Wait for container to be ready
echo "Waiting for container to be ready..."
for i in {1..30}; do
    if curl -s http://localhost:${TEST_PORT}/actuator/health | grep -q "UP"; then
        echo -e "${GREEN}Container is healthy!${NC}"
        break
    fi
    if [ $i -eq 30 ]; then
        handle_error "Container failed to become healthy"
    fi
    echo "Waiting... ($i/30)"
    sleep 2
done

# Run tests
echo "Running API tests..."
if ./test-api.sh "http://localhost:${TEST_PORT}"; then
    echo -e "${GREEN}Tests passed successfully!${NC}"
else
    echo -e "${RED}Error: Tests failed${NC}"
    echo -e "${RED}Tests failed. Check the logs for more details.${NC}"
    # Print the logs from the pod to aid in debugging
    podman logs ${CONTAINER_NAME}
    exit 1
fi

# Stop and remove the test container
podman rm -f ${CONTAINER_NAME}

# Login to ECR
echo "Logging into ECR..."
aws ecr get-login-password --region ${AWS_REGION} | \
    podman login --username AWS --password-stdin ${aws_account}.dkr.ecr.${AWS_REGION}.amazonaws.com || \
    handle_error "ECR login failed"
echo -e "${GREEN}ECR login successful!${NC}"

# Tag and push image
echo "Tagging Docker image for ECR..."
podman tag ${IMAGE_NAME}:${VERSION} ${aws_account}.dkr.ecr.${AWS_REGION}.amazonaws.com/${IMAGE_NAME}:${VERSION} || \
    handle_error "Failed to tag image"

echo "Pushing Docker image to ECR..."
podman push ${aws_account}.dkr.ecr.${AWS_REGION}.amazonaws.com/${IMAGE_NAME}:${VERSION} || \
    handle_error "Failed to push image"

echo -e "${GREEN}Image pushed to ECR successfully!${NC}"