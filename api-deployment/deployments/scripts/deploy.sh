#!/bin/bash

# Strict mode:
# -e: Exit immediately if a command exits with a non-zero status.
# -u: Treat unset variables as an error and exit immediately.
# -o pipefail: The return value of a pipeline is the status of the
#              last command to exit with a non-zero status, or zero if
#              no command exited with a non-zero status.
set -euo pipefail

TEMPLATE="${1:-ecs-deploy}"
STACK_NAME="spring-boot-api"
# MAX_WAIT_MINUTES and SLEEP_INTERVAL are not used by `aws cloudformation wait` commands, so they've been removed.

# --- Helper Functions ---

# Function to check if stack exists
# Usage: stack_exists "stack-name"
stack_exists() {
    local stack_name_arg="$1"
    # This command is allowed to fail without exiting the script when used in an if condition.
    # The exit status (0 for exists, non-0 for not exists/error) is returned.
    aws cloudformation describe-stacks --stack-name "${stack_name_arg}" >/dev/null 2>&1
    return $?
}

# Function to check stack status
# Usage: check_stack_status "stack-name"
check_stack_status() {
    local stack_name_arg="$1"
    aws cloudformation describe-stacks \
        --stack-name "${stack_name_arg}" \
        --query 'Stacks[0].StackStatus' \
        --output text
}

# Function to get stack events, focusing on failures and rollbacks
# Usage: get_failure_stack_events "stack-name"
# Function to get stack events, focusing on failures and rollbacks
# Usage: get_failure_stack_events "stack-name"
get_failure_stack_events() {
    local stack_name_arg="$1"
    # Ensure this initial message also goes to stderr if the whole function's output is intended for error reporting
    echo "Fetching failure/rollback events for stack: ${stack_name_arg}" >&2

    local events_data
    local aws_cli_exit_code=0

    # Execute the command and capture its output and exit code
    events_data=$(aws cloudformation describe-stack-events \
        --stack-name "${stack_name_arg}" \
        --query 'StackEvents[?ResourceStatusReason && (contains(ResourceStatus, `FAILED`) || contains(ResourceStatus, `ROLLBACK`))].[Timestamp,LogicalResourceId,ResourceType,ResourceStatus,ResourceStatusReason]' \
        --output text --max-items 15 2>&1) # Capture stdout and stderr from the aws command
    aws_cli_exit_code=$?

    if [[ ${aws_cli_exit_code} -ne 0 ]]; then
        # The aws cli command itself failed.
        echo "Warning: 'aws cloudformation describe-stack-events' command failed with exit code ${aws_cli_exit_code}." >&2
        if [[ -n "${events_data}" ]]; then
            # Print the captured output from the failed aws command, which might contain the error details
            echo "Output/Error from failed 'describe-stack-events' command:" >&2
            echo "${events_data}" >&2
        else
            echo "The 'describe-stack-events' command failed, but no output was captured. Check IAM permissions or AWS CLI configuration." >&2
        fi
    elif [[ -z "${events_data}" ]]; then
        # The command succeeded but returned no events matching the specific failure/rollback query.
        echo "No specific failure/rollback events found matching the query for stack ${stack_name_arg}." >&2
        echo "Attempting to fetch the last 5 raw events for context (these might not all be errors):" >&2
        aws cloudformation describe-stack-events \
            --stack-name "${stack_name_arg}" \
            --query 'StackEvents[].[Timestamp,LogicalResourceId,ResourceType,ResourceStatus,ResourceStatusReason]' \
            --output text --max-items 5 >&2 || echo "Warning: Could not fetch raw stack events." >&2
    else
        # Command succeeded and returned matching events.
        echo "Found the following failure/rollback events:" >&2
        echo "${events_data}" >&2
    fi
}

# Error handler for the trap
# This function is called when any command fails due to `set -e`.
handle_error() {
    local exit_code=$?
    local line_no=$1
    # BASH_COMMAND contains the command that was executed.
    local failed_command="${BASH_COMMAND}"

    echo ""
    echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!" >&2
    echo "ERROR: Command '${failed_command}' on line ${line_no} failed with exit code ${exit_code}." >&2
    echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!" >&2
    echo "" >&2

    # Attempt to get stack status and events if STACK_NAME is set and seems relevant.
    # This check avoids errors if STACK_NAME isn't defined yet or the error is unrelated to CloudFormation.
    if [[ -n "${STACK_NAME:-}" ]]; then
        # Use a subshell and temporarily disable `set -e` for these checks to avoid cascading failures within the trap.
        (
            set +e # Temporarily disable exit on error for these AWS CLI calls
            if aws cloudformation describe-stacks --stack-name "${STACK_NAME}" >/dev/null 2>&1; then
                local current_status
                current_status=$(check_stack_status "${STACK_NAME}")
                echo "Current stack status of '${STACK_NAME}': ${current_status}" >&2
                get_failure_stack_events "${STACK_NAME}" >&2
            else
                echo "Stack '${STACK_NAME}' may not exist or is not accessible. Cannot fetch events for it." >&2
            fi
        )
    else
        echo "STACK_NAME variable not set, cannot fetch CloudFormation specific events." >&2
    fi
    # The script will exit automatically due to `set -e` after the trap finishes.
}

# Set the trap to call handle_error on ERR signal (any command failure).
trap 'handle_error $LINENO' ERR

# --- Main script execution ---

echo "Validating CloudFormation template: ${TEMPLATE}.cfn"
TEMPLATE_PATH="$(dirname "$0")/../cloudformation/${TEMPLATE}.cfn"

if [[ ! -f "${TEMPLATE_PATH}" ]]; then
    echo "Error: Template file not found at ${TEMPLATE_PATH}" >&2
    exit 1
fi

aws cloudformation validate-template --template-body "file://${TEMPLATE_PATH}"
# If validation fails, output is on stderr, and script exits via trap.
echo "Template validation successful."

# Parameters for the stack. Consider making ECRImageNameTag more dynamic.
PARAMETERS="ParameterKey=ECRImageNameTag,ParameterValue=product-api:v1"

# Check if stack exists and handle accordingly
if stack_exists "${STACK_NAME}"; then
    echo "Attempting to update existing stack: ${STACK_NAME}..."
    # Capture output to check for "No updates are to be performed."
    # This message from AWS CLI for `update-stack` indicates no changes were detected and exits with 0.
    update_command_output=""
    update_exit_code=0
    update_command_output=$(aws cloudformation update-stack \
        --stack-name "${STACK_NAME}" \
        --template-body "file://${TEMPLATE_PATH}" \
        --parameters "${PARAMETERS}" \
        --capabilities CAPABILITY_IAM 2>&1) || update_exit_code=$? # Capture exit code if command fails

    if echo "${update_command_output}" | grep -q "No updates are to be performed."; then
        echo "No updates to be performed on stack ${STACK_NAME}. Current state assumed to be satisfactory."
        # Skip waiting, proceed to final status check.
    elif [[ ${update_exit_code} -ne 0 ]]; then
        # update-stack command itself failed for a reason other than "No updates"
        echo "Error during 'aws cloudformation update-stack' command (exit code ${update_exit_code}):" >&2
        echo "${update_command_output}" >&2
        # The trap should have already fired due to `set -e`.
        # This explicit exit ensures the script stops if the trap mechanism has issues or if `set -e` was somehow bypassed.
        exit "${update_exit_code}"
    else
        # Update was initiated successfully (exit code 0 and no "No updates" message)
        echo "Update initiated for stack ${STACK_NAME}. Waiting for completion..."
        aws cloudformation wait stack-update-complete --stack-name "${STACK_NAME}"
        # If wait fails (e.g., rollback), the trap will handle it.
        echo "Stack ${STACK_NAME} update process reported as finished by 'wait' command."
    fi
else
    echo "Creating new stack: ${STACK_NAME}..."
    aws cloudformation create-stack \
        --stack-name "${STACK_NAME}" \
        --template-body "file://${TEMPLATE_PATH}" \
        --parameters "${PARAMETERS}" \
        --capabilities CAPABILITY_IAM

    echo "Waiting for stack creation to complete for ${STACK_NAME}..."
    aws cloudformation wait stack-create-complete --stack-name "${STACK_NAME}"
    # If wait fails (e.g., rollback), the trap will handle it.
    echo "Stack ${STACK_NAME} creation process reported as finished by 'wait' command."
fi

# --- Final Status Check ---
# If we reach here with `set -e`, all critical AWS CLI commands that were expected to succeed did so.
# The `wait` commands would have triggered the ERR trap on failure (e.g., ROLLBACK_COMPLETE).

echo ""
echo "----------------------------------------------------------------------"
echo "Final check for stack: ${STACK_NAME}"
final_status=$(check_stack_status "${STACK_NAME}")
echo "Final Status: ${final_status}"
echo "----------------------------------------------------------------------"

case "${final_status}" in
    CREATE_COMPLETE|UPDATE_COMPLETE)
        echo "Deployment of ${STACK_NAME} was successful."
        exit 0
        ;;
    UPDATE_COMPLETE_CLEANUP_IN_PROGRESS)
        # This is a transient state that can occur after UPDATE_COMPLETE.
        # It's generally a success but might need a bit more time to settle.
        echo "Deployment of ${STACK_NAME} is ${final_status}. Considering successful."
        exit 0
        ;;
    *_ROLLBACK_COMPLETE|*_FAILED|DELETE_COMPLETE|DELETE_FAILED)
        echo "Error: Deployment of ${STACK_NAME} resulted in a failure or unexpected state: ${final_status}." >&2
        # The trap should have already printed detailed events. This is a final confirmation.
        # Call get_failure_stack_events again in case the trap didn't capture everything or for emphasis.
        get_failure_stack_events "${STACK_NAME}" >&2
        exit 1
        ;;
    *)
        # Any other status that isn't a clear success or a clear failure handled by `wait`.
        echo "Warning: Deployment of ${STACK_NAME} resulted in an indeterminate or unexpected status: ${final_status}." >&2
        echo "Please review the stack in the AWS Console." >&2
        get_failure_stack_events "${STACK_NAME}" >&2 # Get events just in case
        exit 1 # Treat as failure
        ;;
esac