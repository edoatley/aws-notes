#!/bin/bash
# This script is used to configure AWS CLI with SSO


echo "Configuring AWS CLI with SSO"
echo "Enter the SSO Session name: $AWS_SSO_SESSION"
echo "Enter the SSO Start URL: $AWS_SSO_START_URL"
echo "Enter the SSO Region: $AWS_SSO_REGION"
echo "Enter the SSO registration scope: sso:account:access"

aws configure sso --use-device-code