#!/bin/bash
# This script runs integration tests against the deployed Admin API endpoints.

set -e # Exit immediately if a command exits with a non-zero status.
set -o pipefail # The return value of a pipeline is the status of the last command to exit with a non-zero status.

# --- Configuration ---
STACK_NAME="uktv-event-streaming-app"
PROFILE="streaming"
REGION="eu-west-2"

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

    http_code=$(tail -n1 <<< "$response")
    body=$(sed '$ d' <<< "$response")

    if ! [[ "$http_code" =~ ^2[0-9]{2}$ ]]; then
        error "Request to $method $path failed with status $http_code. Body: $body"
    fi

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
ADMIN_API_ENDPOINT=$(aws cloudformation describe-stacks --stack-name "$STACK_NAME" --query "Stacks[].Outputs[?OutputKey=='AdminApiEndpoint'].OutputValue" --output text --profile "$PROFILE" --region "$REGION")
PERIODIC_REFERENCE_FUNCTION_NAME=$(aws cloudformation describe-stacks --stack-name "$STACK_NAME" --query "Stacks[].Outputs[?OutputKey=='PeriodicReferenceFunctionName'].OutputValue" --output text --profile "$PROFILE" --region "$REGION")
USER_PREFS_INGESTION_FUNCTION_NAME=$(aws cloudformation describe-stacks --stack-name "$STACK_NAME" --query "Stacks[].Outputs[?OutputKey=='UserPrefsTitleIngestionFunctionName'].OutputValue" --output text --profile "$PROFILE" --region "$REGION")
TITLE_ENRICHMENT_FUNCTION_NAME=$(aws cloudformation describe-stacks --stack-name "$STACK_NAME" --query "Stacks[].Outputs[?OutputKey=='TitleEnrichmentFunctionName'].OutputValue" --output text --profile "$PROFILE" --region "$REGION")

if [ -z "$ADMIN_API_ENDPOINT" ]; then
    error "Failed to retrieve Admin API endpoint from stack outputs. Aborting."
fi
log "Successfully fetched API and function details."
info "Admin API Endpoint: $ADMIN_API_ENDPOINT"

# Step 3: Test Admin API Endpoints
log "Step 3: Starting Admin API endpoint tests..."

# --- Test GET /admin/system/dynamodb/summary ---
log "Testing GET /admin/system/dynamodb/summary..."
SUMMARY_RESPONSE=$(admin_api_curl "GET" "/admin/system/dynamodb/summary")
info "DynamoDB Summary Response: $SUMMARY_RESPONSE"

# --- Test POST /admin/data/reference/refresh ---
log "Testing POST /admin/data/reference/refresh..."
REFRESH_PAYLOAD='{"refresh_sources": "Y", "refresh_genres": "Y", "regions": "GB"}'
admin_api_curl "POST" "/admin/data/reference/refresh" "$REFRESH_PAYLOAD" > /dev/null 2>&1
log "POST /admin/data/reference/refresh initiated. Waiting for logs..."
sleep 20 # Wait for logs to be generated
./resources/scripts/get_lambda_logs.sh "$PERIODIC_REFERENCE_FUNCTION_NAME" "$PROFILE" "$REGION"

# --- Test POST /admin/data/titles/refresh ---
log "Testing POST /admin/data/titles/refresh..."
admin_api_curl "POST" "/admin/data/titles/refresh" '{}' > /dev/null 2>&1
log "POST /admin/data/titles/refresh initiated. Waiting for logs..."
sleep 20 # Wait for logs to be generated
./resources/scripts/get_lambda_logs.sh "$USER_PREFS_INGESTION_FUNCTION_NAME" "$PROFILE" "$REGION"


# --- Test POST /admin/data/titles/enrich ---
log "Testing POST /admin/data/titles/enrich..."
admin_api_curl "POST" "/admin/data/titles/enrich" '{}' > /dev/null 2>&1
log "POST /admin/data/titles/enrich initiated. Waiting for logs..."
sleep 20 # Wait for logs to be generated
./resources/scripts/get_lambda_logs.sh "$TITLE_ENRICHMENT_FUNCTION_NAME" "$PROFILE" "$REGION"

echo ""
echo "🎉 All Admin API integration tests passed successfully! 🎉"
exit 0
