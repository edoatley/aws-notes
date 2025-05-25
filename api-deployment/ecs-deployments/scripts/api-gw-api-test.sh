#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

# Get the directory of this script
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/../../" && pwd )"

STACK_NAME=${1:-"spring-boot-api"}
AWS_REGION=${2:-"eu-west-2"}

# Here we will find the deployed APIs for our API gateway
find_deployed_apis() {
    local stack_name=$1
    local api_ids

    # Get the API IDs from the API Gateway
    api_ids=$(aws apigateway get-rest-apis --query "items[?contains(name, \`${stack_name}\`)].id" --output text)

    if [ -z "$api_ids" ]; then
        echo -e "${RED}No deployed APIs found for stack ${stack_name}${NC}"
        exit 1
    fi

    echo "$api_ids"
}

find_stage() {
    local api_id=$1
    local stage_name

    # Get the stage name from the API Gateway
    stage_name=$(aws apigateway get-stages --rest-api-id "$api_id" --query "item[0].stageName" --output text)

    if [ -z "$stage_name" ]; then
        echo -e "${RED}No stage found for API ID ${api_id}${NC}"
        exit 1
    fi

    echo "$stage_name"
}

format_api_url() {
    local api_id=$1
    local stage_name=$2

    # Format the API URL
    echo "https://${api_id}.execute-api.${AWS_REGION}.amazonaws.com/${stage_name}"
}

API_IDENTIFIER=$(find_deployed_apis "$STACK_NAME")
API_STAGE=$(find_stage "$API_IDENTIFIER")
API_URL=$(format_api_url "$API_IDENTIFIER" "$API_STAGE")
echo "API URL: $API_URL"

# Run the test script 
# When tests fail, collect logs
echo "Running API tests..."
"$PROJECT_ROOT/boot-ddb-product-api/scripts/test-api.sh" "$API_URL" || {
    echo -e "${RED}Tests failed. Collecting diagnostic information...${NC}"
    echo "Collecting logs..."
    # Collect logs from the API Gateway
    aws logs describe-log-groups --log-group-name-prefix "/aws/apigateway/$API_IDENTIFIER" --query "logGroups[*].logGroupName" --output text | while read -r log_group; do
        echo "Logs for $log_group:"
        aws logs get-log-events --log-group-name "$log_group" --limit 10 --output text
    done
    echo -e "${RED}API tests failed!${NC}"
    echo "Please check the logs above for more information."
    echo "Exiting with error code 1."
    exit 1
}

echo -e "${GREEN}API tests passed!${NC}"