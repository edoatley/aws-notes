#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

STACK_NAME=${1:-"spring-boot-api"}
MAX_ATTEMPTS=30
SLEEP_SECONDS=10

echo "Getting ECS service details..."

# Get the task ARN
TASK_ARN=$(aws ecs list-tasks \
    --cluster "${STACK_NAME}-cluster" \
    --service-name "${STACK_NAME}-service" \
    --query 'taskArns[0]' \
    --output text)

if [ -z "$TASK_ARN" ]; then
    echo -e "${RED}No running tasks found${NC}"
    exit 1
fi

# Get the ENI ID
ENI_ID=$(aws ecs describe-tasks \
    --cluster "${STACK_NAME}-cluster" \
    --tasks "$TASK_ARN" \
    --query 'tasks[0].attachments[0].details[?name==`networkInterfaceId`].value' \
    --output text)

# Get the public IP
PUBLIC_IP=$(aws ec2 describe-network-interfaces \
    --network-interface-ids "$ENI_ID" \
    --query 'NetworkInterfaces[0].Association.PublicIp' \
    --output text)

echo "ECS service public IP: $PUBLIC_IP"

# Wait for the service to be healthy
echo "Waiting for service to be healthy..."
for ((i=1; i<=$MAX_ATTEMPTS; i++)); do
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "http://${PUBLIC_IP}:8080/actuator/health")
    if [ "$HTTP_CODE" == "200" ]; then
        echo -e "${GREEN}Service is healthy!${NC}"
        break
    fi
    if [ $i -eq $MAX_ATTEMPTS ]; then
        echo -e "${RED}Service failed to become healthy within timeout${NC}"
        exit 1
    fi
    echo "Attempt $i/$MAX_ATTEMPTS - Service not ready yet, waiting ${SLEEP_SECONDS}s..."
    sleep $SLEEP_SECONDS
done

# Run the test script
echo "Running API tests..."
../../api/scripts/test-api-debug.sh "http://${PUBLIC_IP}:8080/api/v1/products"