#!/bin/bash

STACK_NAME="${1:-spring-boot-api}"

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

# Get the task ARN
TASK_ARN=$(aws ecs list-tasks \
    --cluster "${STACK_NAME}-cluster" \
    --service-name "${STACK_NAME}-service" \
    --query 'taskArns[0]' \
    --output text)


# Get the logs
get_container_logs "$TASK_ARN"