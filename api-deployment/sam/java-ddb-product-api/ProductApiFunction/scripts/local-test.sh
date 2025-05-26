#!/bin/bash

# Get the directory where the script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

# Determine the SAM project root directory (two levels up from SCRIPT_DIR)
# SCRIPT_DIR = .../ProductApiFunction/scripts
# PARENT_DIR = .../ProductApiFunction
# SAM_PROJECT_ROOT = .../
SAM_PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"

# Change to the SAM project root directory to run SAM commands
cd "$SAM_PROJECT_ROOT" || { echo "Failed to change directory to SAM project root: $SAM_PROJECT_ROOT"; exit 1; }

echo "Building SAM application from: $(pwd)"
sam build

# Event files are relative to the SAM_PROJECT_ROOT (which is now the current directory)
GET_EVENT_FILE="$SAM_PROJECT_ROOT/events/get_products.json"
PUT_EVENT_FILE="$SAM_PROJECT_ROOT/events/put_products.json"

echo ""
echo "Testing a GET using event file: $GET_EVENT_FILE"
echo ""
sam local invoke ProductApiFunction --event "${GET_EVENT_FILE}" --region eu-west-2

echo ""
echo "Testing a PUT using event file: ${PUT_EVENT_FILE}"
echo ""
sam local invoke ProductApiFunction --event "${PUT_EVENT_FILE}" --region eu-west-2