#!/bin/bash

# A script to generate a key, import it to AWS, and deploy the DocumentDB
# CloudFormation stack.

# --- Configuration ---
STACK_NAME="my-docdb-stack"
AWS_REGION="eu-west-2"
KEY_NAME="docdb-stack-key"
KEY_FILE_PREFIX="docdb_key"
KEY_FILE_PATH="$HOME/.ssh/${KEY_FILE_PREFIX}"
TEMPLATE_FILE_NAME="documentdb-cfn.yaml"
AWS_PROFILE="streaming"

# --- Helper Functions ---
# Function to print colored text
print_info() {
    printf "\n\033[1;34m%s\033[0m\n" "$1"
}

print_success() {
    printf "\033[1;32m%s\033[0m\n" "$1"
}

print_error() {
    printf "\033[1;31m%s\033[0m\n" "$1" >&2
}

# --- Script Start ---

# Get the directory where the script is located to make it runnable from anywhere
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
TEMPLATE_FILE_PATH="$SCRIPT_DIR/$TEMPLATE_FILE_NAME"

# 1. Check for dependencies
print_info "Step 1: Checking for required tools (aws, jq)..."
if ! command -v aws &> /dev/null; then
    print_error "AWS CLI could not be found. Please install it and configure your credentials."
    exit 1
fi
if ! command -v jq &> /dev/null; then
    print_error "jq could not be found. Please install it (e.g., 'sudo apt-get install jq' or 'brew install jq')."
    exit 1
fi
print_success "All tools are present."

# 2. Generate SSH Key
print_info "Step 2: Generating a new SSH key..."
if [ -f "$KEY_FILE_PATH" ]; then
    print_error "Key file '$KEY_FILE_PATH' already exists. To prevent overwriting, please remove it or rename it and run the script again."
    exit 1
fi

ssh-keygen -t rsa -b 4096 -f "$KEY_FILE_PATH" -N "" -C "$KEY_NAME"
if [ $? -ne 0 ]; then
    print_error "Failed to generate SSH key."
    exit 1
fi
print_success "Successfully generated key at $KEY_FILE_PATH"

# 3. Import Key to AWS
print_info "Step 3: Importing the public key to AWS EC2 as '$KEY_NAME'..."
aws ec2 import-key-pair --key-name "$KEY_NAME" --public-key-material "fileb://${KEY_FILE_PATH}.pub" --profile "$AWS_PROFILE" --region "$AWS_REGION" > /dev/null
if [ $? -ne 0 ]; then
    print_error "Failed to import key to AWS. Does a key with the name '$KEY_NAME' already exist in this region?"
    # Clean up the locally generated key if import fails
    rm -f "$KEY_FILE_PATH" "${KEY_FILE_PATH}.pub"
    exit 1
fi
print_success "Key pair '$KEY_NAME' imported to AWS successfully."

# 4. Get Public IP
print_info "Step 4: Fetching your public IP address..."
MY_IP=$(curl -s https://checkip.amazonaws.com)
if [ -z "$MY_IP" ]; then
    print_error "Could not determine public IP address."
    exit 1
fi
print_success "Detected public IP: $MY_IP"

# 5. Get DocumentDB Password
print_info "Step 5: Enter the desired master password for DocumentDB."
read -s -p "Password (will not be displayed): " DOCDB_PASSWORD
echo
if [ ${#DOCDB_PASSWORD} -lt 8 ]; then
    print_error "Password must be at least 8 characters long."
    exit 1
fi

# 6. Deploy CloudFormation Stack
print_info "Step 6: Starting CloudFormation stack deployment..."

# First, check if the template file actually exists
if [ ! -f "$TEMPLATE_FILE_PATH" ]; then
    print_error "CloudFormation template file not found at: $TEMPLATE_FILE_PATH"
    exit 1
fi

aws cloudformation create-stack \
  --stack-name "$STACK_NAME" \
  --template-body "file://$TEMPLATE_FILE_PATH" \
  --profile "$AWS_PROFILE" \
  --region "$AWS_REGION" \
  --parameters \
    ParameterKey=KeyPairName,ParameterValue="$KEY_NAME" \
    ParameterKey=MyIP,ParameterValue="${MY_IP}/32" \
    ParameterKey=DocDBPassword,ParameterValue="$DOCDB_PASSWORD"
if [ $? -ne 0 ]; then
    print_error "CloudFormation stack creation failed to start."
    exit 1
fi
print_success "Stack creation initiated. Waiting for completion... (This may take 10-15 minutes)"

# 7. Wait for completion
aws cloudformation wait stack-create-complete --stack-name "$STACK_NAME" --profile "$AWS_PROFILE" --region "$AWS_REGION"
print_success "Stack '$STACK_NAME' has been created successfully!"

# 8. Display Outputs
print_info "--- Stack Outputs ---"
STACK_OUTPUTS=$(aws cloudformation describe-stacks --stack-name "$STACK_NAME" --profile "$AWS_PROFILE" --region "$AWS_REGION" --query "Stacks[0].Outputs")

# FIX: Use a different delimiter (#) for sed to handle file paths correctly.
SSH_COMMAND_TEMPLATE=$(echo "$STACK_OUTPUTS" | jq -r '.[] | select(.OutputKey=="SSHCommand") | .Value')
SSH_COMMAND=$(echo "$SSH_COMMAND_TEMPLATE" | sed "s#'my-key.pem'#'${KEY_FILE_PATH}'#")

echo "$STACK_OUTPUTS" | jq -r '.[] | select(.OutputKey!="SSHCommand") | "\(.OutputKey): \(.OutputValue)"'
echo "SSHCommand: $SSH_COMMAND"

print_info "--- Cleanup Instructions ---"
echo "To avoid ongoing charges, remember to delete the resources when you are finished:"
echo "1. Delete the CloudFormation stack:"
echo "   aws cloudformation delete-stack --stack-name \"$STACK_NAME\" --profile \"$AWS_PROFILE\" --region \"$AWS_REGION\""
echo "2. Delete the EC2 key pair from AWS:"
echo "   aws ec2 delete-key-pair --key-name \"$KEY_NAME\" --profile \"$AWS_PROFILE\" --region \"$AWS_REGION\""
echo "3. (Optional) Delete the local key files:"
echo "   rm \"$KEY_FILE_PATH\" \"${KEY_FILE_PATH}.pub\""