# Useful CloudFormation CLI commands

## General

### Set current AWS Profile

```bash
export AWS_PROFILE=PowerUserAccess-503561418276
```

### Set current AWS Region

```bash
export AWS_REGION=us-east-1
```

## Stacks

### Delete a Stack

```bash
aws cloudformation delete-stack --stack-name simple-vpc
```

### Describe a stack

```bash
aws cloudformation describe-stacks --stack-name simple-vpc
```

### Create a stack 

```bash
aws cloudformation create-stack \
    --stack-name developer-user-role \
    --template-body file://resources/identity/developer-user-role-cfn.yaml \
    --capabilities CAPABILITY_NAMED_IAM \
    --region $AWS_REGION
```

### Update a stack 

```bash
aws cloudformation update-stack \
    --stack-name developer-user-role \
    --template-body file://resources/identity/developer-user-role-cfn.yaml \
    --capabilities CAPABILITY_NAMED_IAM \
    --region $AWS_REGION
```