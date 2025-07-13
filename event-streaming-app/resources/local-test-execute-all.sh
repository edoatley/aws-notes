#!/bin/bash
##########################################################
# Script to use sam invoke and run all the tests we have
##########################################################

# Exit immediately if a command exits with a non-zero status.
set -e
# Treat unset variables as an error when substituting.
set -u

# Get the script directory and the directory from which to invoke the sam calls
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
SAM_DIR=$(dirname $SCRIPT_DIR) # assumes SAM DIR is PARENT
ENV_DIR="${SAM_DIR}/env"
EVENT_DIR="${SAM_DIR}/events"
PROFILE_NAME="streaming"
DEBUG=false

# --- Source Helper Functions ---
# shellcheck source=resources/test-helpers.sh
source "${SCRIPT_DIR}/test-helpers.sh"

# --- Argument Parsing for Debug Flag ---
if [[ "${1:-}" == "-d" || "${1:-}" == "--debug" ]]; then
    DEBUG=true
    print_info "Debug mode enabled. Full 'sam local invoke' output will be shown."
fi
export DEBUG

# --- Check for AWS SSO Login ---

print_info "Checking AWS SSO session for profile: ${PROFILE_NAME}..."
# The >/dev/null 2>&1 silences the command's output on success
if ! aws sts get-caller-identity --profile "${PROFILE_NAME}" > /dev/null 2>&1; then
    print_info "AWS SSO session expired or not found. Please log in."
    # This command is interactive and will open a browser
    aws sso login --profile "${PROFILE_NAME}"

    # Re-check after login attempt to ensure it was successful before proceeding
    if ! aws sts get-caller-identity --profile "${PROFILE_NAME}" > /dev/null 2>&1; then
        print_error "AWS login failed. Please check your configuration. Aborting."
        exit 1
    fi
    print_success "✅ AWS login successful."
else
    print_success "✅ AWS SSO session is active."
fi

# --- Main Execution ---
print_info "Moving to SAM project directory: ${SAM_DIR}"
cd "${SAM_DIR}" || exit

# Run tests for each function
# Format: "FunctionName EventFile EnvFile"
declare -a tests=(
  "PeriodicReferenceFunction periodic_reference.json periodic_reference.json"
  "UserPreferencesFunction user_prefs_get_sources.json user_preferences.json"
  "UserPreferencesFunction user_prefs_get_genres.json user_preferences.json"
  "UserPreferencesFunction user_prefs_get_preferences.json user_preferences.json"
  "UserPreferencesFunction user_prefs_put_preferences.json user_preferences.json"
  "UserPreferencesFunction user_prefs_get_preferences.json user_preferences.json"
)

# --- Loop through the defined tests and run them ---
for test_case in "${tests[@]}"; do
  # Split the test case string into an array of parameters
  read -r -a test_params <<< "$test_case"

  run_test "${test_params[0]}" \
    "${EVENT_DIR}/${test_params[1]}" \
    "${ENV_DIR}/${test_params[2]}"
done

print_info "================================="
print_success "All local tests passed successfully!"
print_info "================================="