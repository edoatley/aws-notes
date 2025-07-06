#!/bin/bash
##########################################################
# Script to use sam invoke and run all the tests we have
##########################################################

# Get the script directory and the directory from which to invoke the sam calls
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
SAM_DIR=$(dirname $SCRIPT_DIR) # assumes SAM DIR is PARENT
ENV_DIR=$"${SAM_DIR}/env"
EVENT_DIR=$"${SAM_DIR}/events"

# --- Source Helper Functions ---
# shellcheck source=resources/test-helpers.sh
source "${SCRIPT_DIR}/test-helpers.sh"

# --- Argument Parsing for Debug Flag ---
DEBUG=false
if [[ "${1:-}" == "-d" || "${1:-}" == "--debug" ]]; then
    DEBUG=true
    print_info "Debug mode enabled. Full 'sam local invoke' output will be shown."
fi

# --- Main Execution ---
print_info "Moving to SAM project directory: ${SAM_DIR}"
cd "${SAM_DIR}" || exit

# Run tests for each function
run_test "PeriodicReferenceFunction" \
  "${EVENT_DIR}/periodic_reference.json" \
  "${ENV_DIR}/periodic_reference.json"

# Example of how you would add more tests in the future:
# run_test "UserPreferencesFunction" \
#   "${EVENT_DIR}/user_prefs_get_sources.json" \
#   "${ENV_DIR}/user_preferences.json"
#
# run_test "UserPreferencesFunction" \
#   "${EVENT_DIR}/user_prefs_put_preferences.json" \
#   "${ENV_DIR}/user_preferences.json"

print_info "================================="
print_success "All local tests passed successfully!"
print_info "================================="
