#!/bin/bash

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

STACK_NAME="${1:-spring-boot-api}"

get_container_logs() {
    local task_id=$1
    local log_group="/ecs/${STACK_NAME}-service"
    echo -e "${BLUE}=== Fetching logs for ECS service ${STACK_NAME} ===${NC}\n"
    # Get all log streams for this task
    echo "Looking for log streams in group $log_group..."
    LOG_STREAMS=$(aws logs describe-log-streams \
        --log-group-name "$log_group" \
        --order-by LastEventTime \
        --descending \
        --query 'logStreams[*].logStreamName' \
        --output text)
    
    # Get logs from each stream
    echo -e "${YELLOW}Found log streams: $LOG_STREAMS${NC}"
    for stream in $LOG_STREAMS; do
        echo -e "\n${GREEN}=== Logs from stream: $stream ===${NC}"
        aws logs get-log-events \
            --log-group-name "$log_group" \
            --log-stream-name "$stream" \
            --limit 100 \
            --query 'events[*].[message]' \
            --output json | jq -r '.[][]' | while read message; do
                if [[ "$message" == *"ERROR"* ]]; then
                    echo -e "${RED}$message${NC}"
                elif [[ "$message" == *"WARN"* ]]; then
                    echo -e "${YELLOW}$message${NC}"
                else
                    echo -e "$message"
                fi
            done
    done
}

# Get the task ARN
echo -e "${BLUE}Fetching latest task from ECS service...${NC}"
TASK_ARN=$(aws ecs list-tasks \
    --cluster "${STACK_NAME}-cluster" \
    --service-name "${STACK_NAME}-service" \
    --query 'taskArns[0]' \
    --output text)

if [ -z "$TASK_ARN" ] || [ "$TASK_ARN" == "None" ]; then
    echo -e "${RED}No running tasks found in the service${NC}"
    exit 1
fi

echo -e "${GREEN}Found task: $TASK_ARN${NC}\n"

# Get the logs
get_container_logs "$TASK_ARN"