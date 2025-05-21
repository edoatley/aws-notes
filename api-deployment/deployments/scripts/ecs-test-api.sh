#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

# Get the directory of this script
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/../../" && pwd )"

STACK_NAME=${1:-"spring-boot-api"}
MAX_ATTEMPTS=30
SLEEP_SECONDS=10

# Add this function at the start of your script
extract_task_id() {
    local task_arn=$1
    echo "$task_arn" | awk -F'/' '{print $NF}'
}

# Function to get logs from CloudWatch
get_container_logs() {
    local task_id=$1
    local log_group="/aws/ecs/${STACK_NAME}-service"
    
    echo "Fetching logs for task $task_id from log group $log_group..."
    
    # List log groups to verify existence
    echo "Available log groups:"
    aws logs describe-log-groups --query 'logGroups[*].logGroupName' --output table
    
    # Get all log streams for this task
    echo "Looking for log streams in group $log_group..."
    LOG_STREAMS=$(aws logs describe-log-streams \
        --log-group-name "$log_group" \
        --log-stream-name-prefix "api-container" \
        --order-by LastEventTime \
        --descending \
        --query 'logStreams[*].logStreamName' \
        --output text)
    
    if [ -z "$LOG_STREAMS" ] || [ "$LOG_STREAMS" = "None" ]; then
        echo -e "${RED}No log streams found${NC}"
        echo "Checking task status..."
        aws ecs describe-tasks \
            --cluster "${STACK_NAME}-cluster" \
            --tasks "$TASK_ARN" \
            --output json | jq '.'
        return 1
    fi
    
    # Get logs from each stream
    echo "Found log streams: $LOG_STREAMS"
    for stream in $LOG_STREAMS; do
        echo -e "\n${GREEN}Logs from stream: $stream${NC}"
        aws logs get-log-events \
            --log-group-name "$log_group" \
            --log-stream-name "$stream" \
            --limit 100 \
            --query 'events[*].message' \
            --output text | sed 's/^/    /'
    done
}

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
# When tests fail, collect logs
echo "Running API tests..."
"$PROJECT_ROOT/api/scripts/test-api.sh" "http://${PUBLIC_IP}:8080" || {
    echo -e "${RED}Tests failed. Collecting diagnostic information...${NC}"
    
    # Get task details
    echo -e "\n${GREEN}Task Details:${NC}"
    aws ecs describe-tasks \
        --cluster "${STACK_NAME}-cluster" \
        --tasks "$TASK_ARN" \
        --output json | jq '.tasks[0].containers[0]'
    
    # Get container logs
    echo -e "\n${GREEN}Container Logs:${NC}"
    get_container_logs "$TASK_ARN"
    
    # Get service events
    echo -e "\n${GREEN}Service Events:${NC}"
    aws ecs describe-services \
        --cluster "${STACK_NAME}-cluster" \
        --services "${STACK_NAME}-service" \
        --query 'services[0].events[0:5]' \
        --output json | jq '.'
    
    exit 1
}

echo -e "${GREEN}API tests passed!${NC}"