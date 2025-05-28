#!/bin/bash

# Get the directory where the script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

# Determine the SAM project root directory (two levels up from SCRIPT_DIR)
# SCRIPT_DIR = .../scripts
# SAM_PROJECT_ROOT = .../
SAM_PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Change to the SAM project root directory to run SAM commands
cd "$SAM_PROJECT_ROOT" || { echo "Failed to change directory to SAM project root: $SAM_PROJECT_ROOT"; exit 1; }

echo "Building SAM application from: $(pwd)"
sam build

# Event files are relative to the SAM_PROJECT_ROOT (which is now the current directory)
GET_EVENT_FILE="events/get_products.json" # Relative path from SAM_PROJECT_ROOT
PUT_EVENT_FILE="events/put_products.json" # Relative path from SAM_PROJECT_ROOT
ENV_VARS_FILE="local-env.json"            # Relative path from SAM_PROJECT_ROOT

echo ""
echo "Testing a GET using event file: $GET_EVENT_FILE"
echo "Using environment variables from: $ENV_VARS_FILE"
echo ""
sam local invoke ProductApiFunction \
    --event "${GET_EVENT_FILE}" \
    --env-vars "${ENV_VARS_FILE}" \
    --region eu-west-2

echo ""
echo "Testing a PUT using event file: ${PUT_EVENT_FILE}"
echo "Using environment variables from: $ENV_VARS_FILE"
echo ""
sam local invoke ProductApiFunction \
    --event "${PUT_EVENT_FILE}" \
    --env-vars "${ENV_VARS_FILE}" \
    --region eu-west-2