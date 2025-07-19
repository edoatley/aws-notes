#!/bin/bash
echo "START"
################################################################
# Specialist integration test for UserPrefsTitleIngestionFunction
#
# This test performs the following steps:
# 1. Setup: Creates dummy user preference items in DynamoDB.
# 2. Execute: Invokes the Lambda function via 'sam local invoke'.
# 3. Verify: Polls the Kinesis stream to find the published
#    records and validates their content.
# 4. Teardown: Cleans up the dummy data from DynamoDB.
################################################################

# Exit on error, treat unset variables as an error
set -euo pipefail
# ADD THIS: Print each command to the console before it is executed
#set -x

# --- Configuration ---
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
PROJECT_ROOT=$(cd "${SCRIPT_DIR}/../../.." && pwd)

# Source the helper functions for colored output
# shellcheck source=test_helpers.sh
source "${SCRIPT_DIR}/test_helpers.sh"

# --- LocalStack & AWS Configuration ---
PROFILE_NAME="streaming"
ENDPOINT_URL="http://localhost:4566"
TABLE_NAME="UKTVProgrammesLocal"
STREAM_NAME="ProgrammeDataStreamLocal"
DOCKER_NETWORK="event-streaming-app_podman"

# --- Test Data ---
TEST_USER_ID="test-user-for-ingestion-123"
# Define preferences. Note the overlapping genre '4' to test aggregation.
declare -a PREFERENCES=("source:203" "source:349" "genre:4" "genre:6")

# --- Helper Functions ---

# Sets up the prerequisite data in DynamoDB
setup_preferences() {
    print_info "Setting up prerequisite user preferences in DynamoDB..."
    for pref_sk in "${PREFERENCES[@]}"; do
        print_info "  - Adding preference: ${pref_sk}"
        aws --profile "${PROFILE_NAME}" --endpoint-url "${ENDPOINT_URL}" \
            dynamodb put-item \
            --table-name "${TABLE_NAME}" \
            --item "{\"PK\": {\"S\": \"userpref:${TEST_USER_ID}\"}, \"SK\": {\"S\": \"${pref_sk}\"}}"
    done
    print_success "✅ Setup complete."
}

# Cleans up the data from DynamoDB
teardown_preferences() {
    print_info "Cleaning up test data from DynamoDB..."
    for pref_sk in "${PREFERENCES[@]}"; do
        aws --profile "${PROFILE_NAME}" --endpoint-url "${ENDPOINT_URL}" \
            dynamodb delete-item \
            --table-name "${TABLE_NAME}" \
            --key "{\"PK\": {\"S\": \"userpref:${TEST_USER_ID}\"}, \"SK\": {\"S\": \"${pref_sk}\"}}"
    done
    print_success "✅ Teardown complete."
}

# Invokes the Lambda function
invoke_ingestion_lambda() {
    print_info "Invoking UserPrefsTitleIngestionFunction..."
    # We must be in the project root for sam to find the templates and build artifacts
    cd "${PROJECT_ROOT}"
    sam local invoke "UserPrefsTitleIngestionFunction" \
      --event "events/userprefs_title_ingestion.json" \
      --env-vars "env/userprefs_title_ingestion.json" \
      --docker-network "${DOCKER_NETWORK}" \
      < /dev/null
#      --dns "8.8.8.8" < /dev/null # Add DNS for external API calls from the container
    print_success "✅ Lambda invoked."
}

# Polls Kinesis and verifies the output
verify_kinesis_output() {
    print_info "Verifying output on Kinesis stream '${STREAM_NAME}'..."

    # 1. Get the Shard ID
    local shard_id
    shard_id=$(aws --profile "${PROFILE_NAME}" --endpoint-url "${ENDPOINT_URL}" \
        kinesis describe-stream --stream-name "${STREAM_NAME}" | jq -r '.StreamDescription.Shards[0].ShardId')

    # 2. Get a shard iterator to start reading from the stream
    local shard_iterator
    shard_iterator=$(aws --profile "${PROFILE_NAME}" --endpoint-url "${ENDPOINT_URL}" \
        kinesis get-shard-iterator --stream-name "${STREAM_NAME}" --shard-id "${shard_id}" --shard-iterator-type TRIM_HORIZON | jq -r '.ShardIterator')

    # 3. Poll for records, as the process is asynchronous
    local records_json=""
    for i in {1..5}; do
        # Pass the current iterator to get-records
        records_json=$(aws --profile "${PROFILE_NAME}" --endpoint-url "${ENDPOINT_URL}" \
            kinesis get-records --shard-iterator "${shard_iterator}")

        # Update the iterator for the NEXT loop iteration
        shard_iterator=$(echo "${records_json}" | jq -r '.NextShardIterator')

        if [[ $(echo "${records_json}" | jq '.Records | length') -gt 0 ]]; then
            print_success "✅ Records found on Kinesis stream."
            break
        fi
        print_info "No records found yet, sleeping for 2 seconds... (Attempt $i/5)"
        sleep 2
    done

    if [[ -z "${records_json}" || $(echo "${records_json}" | jq '.Records | length') -eq 0 ]]; then
        print_error "❌ VERIFICATION FAILED: No records were found on the Kinesis stream after polling."
        exit 1
    fi

    # 4. Decode and validate the first record
    print_info "Validating the content of the first record..."
    local first_record_data
    first_record_data=$(echo "${records_json}" | jq -r '.Records[0].Data')

    local decoded_payload
    decoded_payload=$(echo "${first_record_data}" | base64 --decode)

    # Check that the publishing component is correct
    if echo "${decoded_payload}" | jq -e '.header.publishingComponent == "UserPrefsTitleIngestionFunction"' >/dev/null; then
        print_success "  - Header validation passed."
    else
        print_error "❌ VERIFICATION FAILED: Header 'publishingComponent' is incorrect."
        echo "Expected: UserPrefsTitleIngestionFunction"
        echo "Got: $(echo "${decoded_payload}" | jq '.header.publishingComponent')"
        exit 1
    fi

    # Check that the payload has the expected structure
    if echo "${decoded_payload}" | jq -e '.payload | has("id") and has("title")' >/dev/null; then
        print_success "  - Payload structure validation passed."
    else
        print_error "❌ VERIFICATION FAILED: Payload is missing 'id' or 'title' keys."
        echo "Payload received: ${decoded_payload}"
        exit 1
    fi
}

# --- Main Execution ---
# Use a trap to ensure teardown runs even if the script fails
trap teardown_preferences EXIT

print_info "===== START: Integration Test for UserPrefsTitleIngestionFunction ====="
print_info "--> STEP 1: Setting up test data..."
setup_preferences
print_info "--> STEP 2: Invoking the Lambda function..."
invoke_ingestion_lambda
print_info "--> STEP 3: Verifying the Kinesis output..."
verify_kinesis_output
print_success "===== ✅ Integration Test Passed! ====="
echo "END"