#!/bin/bash
# This script runs integration tests against the deployed Admin API endpoints.

set -e # Exit immediately if a command exits with a non-zero status.
set -o pipefail # The return value of a pipeline is the status of the last command to exit with a non-zero status.

# --- Configuration ---
STACK_NAME="uktv-event-streaming-app"
PROFILE="streaming"
REGION="eu-west-2"
# Admin API Key is assumed to be obtained from stack outputs, similar to Web API Key.
# If Admin API has a separate key or authentication mechanism, this needs adjustment.

# --- Helper Functions ---
log() {
    echo "✅ $1"
}

info() {
    echo "   - $1"
}

error() {
    echo "❌ ERROR: $1" >&2
    exit 1
}

# Function to make Admin API calls
# Usage: admin_api_curl <method> <path> [json_data]
# It uses global variables: ADMIN_API_ENDPOINT
admin_api_curl() {
    local method=$1
    local path=$2
    local data=$3
    local headers=()
    local response
    local http_code
    local body

    if [ -n "$data" ]; then
        headers+=("-H" "Content-Type: application/json")
        response=$(curl -s -w "\n%{http_code}" -X "$method" "${headers[@]}" -d "$data" "${ADMIN_API_ENDPOINT}${path}")
    else
        response=$(curl -s -w "\n%{http_code}" -X "$method" "${headers[@]}" "${ADMIN_API_ENDPOINT}${path}")
    fi

    # Separate body and status code
    http_code=$(tail -n1 <<< "$response")
    body=$(sed '$ d' <<< "$response")

    if ! [[ "$http_code" =~ ^2[0-9]{2}$ ]]; then
        error "Request to $method $path failed with status $http_code. Body: $body"
    fi

    # Return body for further processing
    echo "$body"
}

# --- Main Script ---
echo "🚀 Starting Admin API Integration Tests..."

# Step 0: Prerequisite check
log "Step 0: Checking prerequisites..."
if ! command -v jq &> /dev/null; then
    error "jq is not installed. Please install it (e.g., 'brew install jq' or 'sudo apt-get install jq')."
fi
if ! command -v curl &> /dev/null; then
    error "curl is not installed. Please install it."
fi
if ! command -v aws &> /dev/null; then
    error "AWS CLI is not installed. Please install it."
fi
log "Prerequisites check passed (jq, curl, aws cli are installed)."

# Step 1: Check AWS session
log "Step 1: Checking AWS SSO session for profile: ${PROFILE}..."
if ! aws sts get-caller-identity --profile "${PROFILE}" > /dev/null 2>&1; then
    echo "⚠️ AWS SSO session expired or not found. Please log in."
    aws sso login --profile "${PROFILE}"
    if ! aws sts get-caller-identity --profile "${PROFILE}" > /dev/null 2>&1; then
        error "AWS login failed. Please check your configuration. Aborting."
    fi
fi
log "AWS SSO session is active."

# Step 2: Fetch Admin API Stack Outputs
log "Step 2: Fetching required outputs from stack '$STACK_NAME' for Admin API..."
# From 'uktv-event-streaming-app.yaml', Output 'AdminApiEndpoint' is available.
ADMIN_API_ENDPOINT=$(aws cloudformation describe-stacks --stack-name "$STACK_NAME" --query "Stacks[].Outputs[?OutputKey=='AdminApiEndpoint'].OutputValue" --output text --profile "$PROFILE" --region "$REGION")

if [ -z "$ADMIN_API_ENDPOINT" ]; then
    error "Failed to retrieve Admin API endpoint from stack outputs. Aborting."
fi
log "Successfully fetched Admin API outputs."
info "Admin API Endpoint: $ADMIN_API_ENDPOINT"

# Step 3: Test Admin API Endpoints

log "Step 3: Starting Admin API endpoint tests..."

# --- Test GET /admin/system/dynamodb/summary ---
log "Testing GET /admin/system/dynamodb/summary..."
SUMMARY_RESPONSE=$(admin_api_curl "GET" "/admin/system/dynamodb/summary")
if ! echo "$SUMMARY_RESPONSE" | jq -e '.tables' > /dev/null; then
    error "GET /admin/system/dynamodb/summary did not return expected summary data. Response: $SUMMARY_RESPONSE"
fi
log "GET /admin/system/dynamodb/summary returned valid summary data."
info "Summary data: $SUMMARY_RESPONSE"

# --- Test POST /admin/data/reference/refresh ---
log "Testing POST /admin/data/reference/refresh..."
REFRESH_RESPONSE=$(admin_api_curl "POST" "/admin/data/reference/refresh")
if ! echo "$REFRESH_RESPONSE" | jq -e '.message | contains("initiated")' > /dev/null; then
    error "POST /admin/data/reference/refresh did not return expected initiation message. Response: $REFRESH_RESPONSE"
fi
JOB_ID_REFRESH=$(echo "$REFRESH_RESPONSE" | jq -r '.job_id')
if [ -z "$JOB_ID_REFRESH" ]; then
    error "POST /admin/data/reference/refresh did not return a job_id. Response: $REFRESH_RESPONSE"
fi
log "POST /admin/data/reference/refresh initiated successfully with job ID: $JOB_ID_REFRESH."

# --- Test POST /admin/data/titles/refresh ---
log "Testing POST /admin/data/titles/refresh..."
TITLE_REFRESH_RESPONSE=$(admin_api_curl "POST" "/admin/data/titles/refresh")
if ! echo "$TITLE_REFRESH_RESPONSE" | jq -e '.message | contains("initiated")' > /dev/null; then
    error "POST /admin/data/titles/refresh did not return expected initiation message. Response: $TITLE_REFRESH_RESPONSE"
fi
JOB_ID_TITLE_REFRESH=$(echo "$TITLE_REFRESH_RESPONSE" | jq -r '.job_id')
if [ -z "$JOB_ID_TITLE_REFRESH" ]; then
    error "POST /admin/data/titles/refresh did not return a job_id. Response: $TITLE_REFRESH_RESPONSE"
fi
log "POST /admin/data/titles/refresh initiated successfully with job ID: $JOB_ID_TITLE_REFRESH."

# --- Test POST /admin/data/titles/enrich ---
log "Testing POST /admin/data/titles/enrich..."
ENRICH_RESPONSE=$(admin_api_curl "POST" "/admin/data/titles/enrich")
if ! echo "$ENRICH_RESPONSE" | jq -e '.message | contains("initiated")' > /dev/null; then
    error "POST /admin/data/titles/enrich did not return expected initiation message. Response: $ENRICH_RESPONSE"
fi
JOB_ID_ENRICH=$(echo "$ENRICH_RESPONSE" | jq -r '.job_id')
if [ -z "$JOB_ID_ENRICH" ]; then
    error "POST /admin/data/titles/enrich did not return a job_id. Response: $ENRICH_RESPONSE"
fi
log "POST /admin/data/titles/enrich initiated successfully with job ID: $JOB_ID_ENRICH."

echo ""
echo "🎉 All Admin API integration tests passed successfully! 🎉"

exit 0