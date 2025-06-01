# API Deployment on AWS

<!-- TOC -->
* [API Deployment on AWS](#api-deployment-on-aws)
  * [Introduction](#introduction)
  * [Deployment using ECS](#deployment-using-ecs)
    * [Simplistic implementation](#simplistic-implementation)
      * [Architecture Diagram](#architecture-diagram)
    * [More Private Implementation](#more-private-implementation)
      * [Architectural Diagram](#architectural-diagram)
  * [Deployment using lambda](#deployment-using-lambda)
    * [AWS Serverless Application Model (SAM)](#aws-serverless-application-model-sam)
      * [Step 1 - sam init](#step-1---sam-init)
      * [Step 2 - sam pipeline init --bootstrap](#step-2---sam-pipeline-init---bootstrap)
      * [Step 2 - sam validate](#step-2---sam-validate)
      * [Step 3 - deploy and check lambda](#step-3---deploy-and-check-lambda)
      * [Step 4 - test the API](#step-4---test-the-api)
      * [Step 5 - update the Hello world API to function like the product API](#step-5---update-the-hello-world-api-to-function-like-the-product-api)
<!-- TOC -->

## Introduction

Here we look at deploying a simple RESTful API to AWS. We will explore various different mechanisms to achieve this. 
The API is written using Spring boot and provides the following:

- `POST /api/v1/products` - Create a new product
- `GET /api/v1/products/{id}` - Retrieve a specific product by ID
- `GET /api/v1/products` - List all products
- `PUT /api/v1/products/{id}` - Update an existing product
- `DELETE /api/v1/products/{id}` - Delete a product by ID

The database is DynamoDB and these operations are tested in the script [test-api.sh](./api/scripts/test-api.sh)

## Deployment using ECS

Elastic Container Service (ECS) is a container orchestration service provided by AWS. It integrates easily with other AWS services such as:
- VPC
- IAM
- CloudWatch
- DynamoDB

In addition to the option of running your containers on ECS using EC2 VMs, ECS also supports both AWS Fargate for a serverless option. This can reduce operational burden and costs depending on the nature of the running container.

### Simplistic implementation

To get started I developed the cloudformation template [ecs-deploy.cfn](ecs-deployments/cloudformation/ecs-deploy.cfn) which has the following resources:

- Network Resources
    - VPC
    - 2 Public Subnets - In different AZs for high availability
    - Internet Gateway - Allows internet access
    - Route Table - Routes traffic through IGW
- Container Infrastructure
    - ECS Cluster - Manages Fargate tasks
    - Task Definition 
      - image from ECR
      - cloudwatch logging
      -  health check on /actuator/health
      -  fargate launch type
      -  configuration (environment variables)
      -  IAM roles links 
- ECS Service
    - Defined to runs in public subnets
    - Public IP enabled
    - Security group to allow traffic in on port 8080 and out - not best practice but this is a simple getting started config
- DynamoDB Table 
  - Hash key on `id`
  - Pay-per-request billing
  - Accessed by ECS tasks via TaskRole
- Security - IAM Roles
    - ExecutionRole - Allows ECS to pull images and create logs
    - TaskRole - Allows containers to access DynamoDB and CloudWatch

#### Architecture Diagram

```mermaid
graph TB
    subgraph AWS Cloud
        subgraph VPC
            subgraph Public_Subnet_1
                ECS1[ECS Task]
            end
            subgraph Public_Subnet_2
                ECS2[ECS Task]
            end
            IGW[Internet Gateway]
        end
        
        DDB[(DynamoDB)]
        CW[(CloudWatch Logs)]
        ECR[(ECR Registry)]
        
        subgraph IAM
            ExecutionRole[Execution Role]
            TaskRole[Task Role]
        end
    end
    
    Internet((Internet))

    %% Connections
    Internet <--> IGW
    IGW <--> ECS1
    IGW <--> ECS2
    ECS1 --> DDB
    ECS2 --> DDB
    ECS1 --> CW
    ECS2 --> CW
    ECR --> ECS1
    ECR --> ECS2
    TaskRole -.-> DDB
    TaskRole -.-> CW
    ExecutionRole -.-> ECR
    
    %% Styling
    classDef aws fill:#FFE4B5,stroke:#D2691E,stroke-width:2px,color:#8B4513;
    classDef vpc fill:#E6E6FA,stroke:#483D8B,stroke-width:2px,color:#483D8B;
    classDef subnet fill:#E0FFFF,stroke:#5F9EA0,stroke-width:2px,color:#4682B4;
    classDef iam fill:#F0FFF0,stroke:#228B22,stroke-width:2px,color:#006400;
    classDef internet fill:#F5F5F5,stroke:#696969,stroke-width:2px,color:#696969;

    %% Apply classes
    class DDB,CW,ECR aws;
    class VPC vpc;
    class Public_Subnet_1,Public_Subnet_2 subnet;
    class ExecutionRole,TaskRole,IAM iam;
    class Internet internet;
```

With the infrastructure defined we can now deploy and test via script:

```bash
cd ecs-deployments/scripts
# Cloudformation Deployment:
./deploy.sh ecs-deploy
# Testing:
./ecs-api-test.sh
```

### More Private Implementation

The cloudformation template [ecs-deploy-private.cfn](ecs-deployments/cloudformation/ecs-deploy-private.cfn) improves security and adds API Gateway integration with these resources:

- Network Resources
    - VPC
    - 2 Private Subnets - For ECS tasks
    - Network Load Balancer - to share load across the ECS tasks
    - Private Route Tables - private subnet -> VPC Endpoint routing
- Container Infrastructure
    - ECS Cluster - Manages Fargate tasks
    - Task Definition 
      - Image from ECR
      - CloudWatch logging
      - Health check on /actuator/health
      - Fargate launch type
      - Environment variables
      - IAM role links
- API Gateway - for now simply provides a public endpoint and proxies traffic to the NLB
- DynamoDB Table - as above
- ECS Service
    - Defined to runs in private subnets
    - Public IP disabled
- VPC Endpoints (PrivateLink)
    - DynamoDB Gateway endpoint
    - ECR API/Docker endpoints
    - Logs - S3 / Cloudwatch
- Security
    - IAM Roles
      - ExecutionRole - Pull images and create logs
      - TaskRole - Access DynamoDB and CloudWatch
    - Security Groups
      - ECS & VPC Endpoints - Only allow inbound only from VPC
    - WAF Rate Limiting
      - 2000 requests per 5 minutes per IP

This implementation improves on the basic version by:

1. Isolating ECS tasks in private subnets
2. Adding API Gateway as a managed API layer
3. Using VPC endpoints for private AWS service access
  - interface endpoints that create an ENI in the subnets to access AWS services over a private IP
  - gateway endpoints for S3 and dynamo that rely on route tables to route the traffic privately despite referencing the public IPs of those services
4. Implementing basic rate limiting via WAF
5. Providing cross AZ load balancing across the ECS tasks

The network flow is as follows:

```text
Client -> Internet -> API Gateway -> VPC Link -> Private NLB -> ECS Tasks (across AZs)
```

#### Architectural Diagram

```mermaid
graph TB
    subgraph AWS Cloud
        subgraph VPC
            subgraph Private_Subnet_1
                ECS1[ECS Task]
                NLB_ENI1[NLB ENI]
            end
            subgraph Private_Subnet_2
                ECS2[ECS Task]
                NLB_ENI2[NLB ENI]
            end

            NLB[Network Load Balancer]
            VPCLink[VPC Link]

            VPCEndpoints{VPC Endpoints}
        end

        APIGW[API Gateway]
        DDB[(DynamoDB)]
        CW[(CloudWatch Logs)]
        ECR[(ECR Registry)]
        S3[(S3)]
        ECS_ControlPlane[ECS Control Plane]

        subgraph IAM
            ExecutionRole[Execution Role]
            TaskRole[Task Role]
        end

        subgraph WAF[WAF Rate Limiting]
            RateLimit[2000 req/5min/IP]
        end
    end

    Internet((Internet))

%% Connections
    Internet --> WAF
    WAF --> APIGW
    APIGW --> VPCLink
    VPCLink --> NLB
    NLB --> NLB_ENI1
    NLB --> NLB_ENI2
    NLB_ENI1 --> ECS1
    NLB_ENI2 --> ECS2

    ECS1 --> VPCEndpoints
    ECS2 --> VPCEndpoints
    VPCEndpoints --> DDB
    VPCEndpoints --> CW
    VPCEndpoints --> ECR
    VPCEndpoints --> S3
    VPCEndpoints --> ECS_ControlPlane

    TaskRole -.-> DDB
    TaskRole -.-> CW
    ExecutionRole -.-> ECR
    ExecutionRole -.-> S3
    ExecutionRole -.-> CW 

%% Styling 
    classDef aws fill:#FFE4B5,stroke:#D2691E,stroke-width:2px,color:#8B4513;
    classDef vpc fill:#E6E6FA,stroke:#483D8B,stroke-width:2px,color:#483D8B;
    classDef subnet fill:#E0FFFF,stroke:#5F9EA0,stroke-width:2px,color:#4682B4;
    classDef iam fill:#F0FFF0,stroke:#228B22,stroke-width:2px,color:#006400;
    classDef internet fill:#F5F5F5,stroke:#696969,stroke-width:2px,color:#696969;
    classDef waf fill:#FFE4E1,stroke:#FF6B6B,stroke-width:2px,color:#CD5C5C;
    classDef endpoints fill:#F0F8FF,stroke:#4682B4,stroke-width:2px,color:#4682B4;

%% Apply classes
    class DDB,CW,ECR,S3,APIGW,ECS_ControlPlane aws;
    class VPC,NLB,VPCLink vpc;
    class Private_Subnet_1,Private_Subnet_2 subnet;
    class ExecutionRole,TaskRole,IAM iam;
    class Internet internet;
    class WAF,RateLimit waf;
    class VPCEndpoints endpoints;
```

Though this deployment is much better than the basic one it still has a number of shortcomings most notably the 
API Gateway deployment should leverage robust authentication & authorization, likely using a Cognito user pool.

These shortcomings could be addressed in a future iteration

## Deployment using lambda

Next we are going to explore doing the same thing using AWS Lambda which should simplify things significantly for such a basic application.
To simplify things further we will use some pre-baked serverless patterns described on [serverlessland](https://serverlessland.com/patterns/)

### AWS Serverless Application Model (SAM)

According to the documentation:

> AWS Serverless Application Model (AWS SAM) is an open-source framework for building serverless applications using infrastructure as code (IaC).

Here we will try from scratch to create a lambda application using AWS SAM

#### Step 1 - sam init

To get started we install SAM as per the [documentation](https://docs.aws.amazon.com/serverless-application-model/latest/developerguide/install-sam-cli.html) and run `sam init` which then proceeds with an interactive workflow:

```text
Which template source would you like to use? 1 - AWS Quick Start Templates
Choose an AWS Quick Start application template: 1 - Hello World Example
Use the most popular runtime and package type? (python3.13 and zip) [y/N]: n
Which runtime would you like to use?: 7 - java21
What package type would you like to use?: 1 - Zip
Which dependency manager would you like to use?: 1 - gradle
Would you like to enable X-Ray tracing on the function(s) in your application? [y/N]: y
Would you like to enable monitoring using CloudWatch Application Insights? [y/N]: y
Would you like to set Structured Logging in JSON format on your Lambda functions? [y/N]:  y
Project name [sam-app]: java-ddb-product-api
```

This then works some magic and creates the application structure for you with the following displayed in the terminal:

```text
    -----------------------
    Generating application:
    -----------------------
    Name: java-ddb-product-api
    Runtime: java21
    Architectures: x86_64
    Dependency Manager: gradle
    Application Template: hello-world
    Output Directory: .
    Configuration file: java-ddb-product-api/samconfig.toml
    
    Next steps can be found in the README file at java-ddb-product-api/README.md
        

Commands you can use next
=========================
[*] Create pipeline: cd java-ddb-product-api && sam pipeline init --bootstrap
[*] Validate SAM template: cd java-ddb-product-api && sam validate
[*] Test Function in the Cloud: cd java-ddb-product-api && sam sync --stack-name {stack-name} --watch
```

#### Step 2 - sam pipeline init --bootstrap

We want to run the deployment via a GH actions pipeline so we can initiate the deployment that via the command:

```bash
cd java-ddb-product-api && sam pipeline init --bootstrap 
```

which ran another interactive workflow (some bits removed for brevity/security):

```text
Select a pipeline template to get started: 1 - AWS Quick Start Pipeline Templates
Select CI/CD system: 3 - GitHub Actions

You are using the 2-stage pipeline template.
 _________    _________ 
|         |  |         |
| Stage 1 |->| Stage 2 |
|_________|  |_________|

Do you want to go through stage setup process now? [Y/n]: y

Stage 1 Setup

[1] Stage definition
Stage configuration name: dev

[2] Account details
Select a credential source to associate with this stage: 3
Associated account <AWS Acc ID> with configuration dev.
Enter the region in which you want these resources to be created [eu-west-2]: 
Select a user permissions provider: 1 - IAM (default)
Enter the pipeline IAM user ARN if you have previously created one, or we will create one for you []: 

[3] Reference application build resources
Enter the pipeline execution role ARN if you have previously created one, or we will create one for you []: 
Enter the CloudFormation execution role ARN if you have previously created one, or we will create one for you []: 
Please enter the artifact bucket ARN for your Lambda function. If you do not have a bucket, we will create one for you []: 
Does your application contain any IMAGE type Lambda functions? [y/N]: n

[4] Summary
Below is the summary of the answers:
        1 - Account: <AWS Acc ID>
        2 - Stage configuration name: dev
        3 - Region: eu-west-2
        4 - Pipeline user: [to be created]
        5 - Pipeline execution role: [to be created]
        6 - CloudFormation execution role: [to be created]
        7 - Artifacts bucket: [to be created]
        8 - ECR image repository: [skipped]
Press enter to confirm the values above, or select an item to edit the value: 

The following resources were created in your account:
        - Pipeline execution role
        - CloudFormation execution role
        - Artifact bucket
        - Pipeline IAM user

Stage 2 Setup

[1] Stage definition
Stage configuration name: prod

[2] Account details
Select a credential source to associate with this stage: 3
Associated account <AWS Acc ID> with configuration prod.
Enter the region in which you want these resources to be created [eu-west-2]: 

[3] Reference application build resources
Enter the pipeline execution role ARN if you have previously created one, or we will create one for you []: 
Enter the CloudFormation execution role ARN if you have previously created one, or we will create one for you []: 
Please enter the artifact bucket ARN for your Lambda function. If you do not have a bucket, we will create one for you []: 
Does your application contain any IMAGE type Lambda functions? [y/N]: n

[4] Summary
Below is the summary of the answers:
        1 - Account: <AWS Acc ID>
        2 - Stage configuration name: prod
        3 - Region: eu-west-2
        4 - Pipeline user ARN: arn:aws:iam::<AWS Acc ID>:user/aws-sam-cli-managed-dev-pipeline-resou-PipelineUser-ZHzmXqcFjxRG
        5 - Pipeline execution role: [to be created]
        6 - CloudFormation execution role: [to be created]
        7 - Artifacts bucket: [to be created]
        8 - ECR image repository: [skipped]
Press enter to confirm the values above, or select an item to edit the value: 

The following resources were created in your account:
        - Pipeline execution role
        - CloudFormation execution role
        - Artifact bucket

This template configures a pipeline that deploys a serverless application to a testing and a production stage.

What is the GitHub secret name for pipeline user account access key ID? [AWS_ACCESS_KEY_ID]: SAM_AWS_ACCESS_KEY_ID_1
What is the GitHub Secret name for pipeline user account access key secret? [AWS_SECRET_ACCESS_KEY]: SAM_AWS_SECRET_ACCESS_KEY_1
What is the git branch used for production deployments? [main]: 
What is the template file path? [template.yaml]: api-deployment/sam/java-ddb-product-api/template.yaml
We use the stage configuration name to automatically retrieve the bootstrapped resources created when you ran `sam pipeline bootstrap`.

Here are the stage configuration names detected in .aws-sam/pipeline/pipelineconfig.toml:
        1 - dev
        2 - prod
Select an index or enter the stage 1's configuration name (as provided during the bootstrapping): 1
What is the sam application stack name for stage 1? [sam-app]: sam-java-ddb-product-api-dev
Stage 1 configured successfully, configuring stage 2.

Here are the stage configuration names detected in .aws-sam/pipeline/pipelineconfig.toml:
        1 - dev
        2 - prod
Select an index or enter the stage 2's configuration name (as provided during the bootstrapping): 2
What is the sam application stack name for stage 2? [sam-app]: sam-java-ddb-product-api-prod
Stage 2 configured successfully.

SUMMARY
We will generate a pipeline config file based on the following information:
        Select a user permissions provider.: AWS IAM
        What is the GitHub secret name for pipeline user account access key ID?: SAM_AWS_ACCESS_KEY_ID_1
        What is the GitHub Secret name for pipeline user account access key secret?: SAM_AWS_SECRET_ACCESS_KEY_1
        What is the git branch used for production deployments?: main
        What is the template file path?: api-deployment/sam/java-ddb-product-api/template.yaml
        Select an index or enter the stage 1's configuration name (as provided during the bootstrapping): 1
        What is the sam application stack name for stage 1?: sam-java-ddb-product-api-dev
        What is the pipeline execution role ARN for stage 1?: arn:aws:iam::<AWS Acc ID>:role/aws-sam-cli-managed-dev-pipel-PipelineExecutionRole-8ZelUvsUDiJN
        What is the CloudFormation execution role ARN for stage 1?: arn:aws:iam::<AWS Acc ID>:role/aws-sam-cli-managed-dev-p-CloudFormationExecutionRo-Xik3IuCAnyTL
        What is the S3 bucket name for artifacts for stage 1?: aws-sam-cli-managed-dev-pipeline-r-artifactsbucket-xkn3f3fg8zin
        What is the ECR repository URI for stage 1?: 
        What is the AWS region for stage 1?: eu-west-2
        Select an index or enter the stage 2's configuration name (as provided during the bootstrapping): 2
        What is the sam application stack name for stage 2?: sam-java-ddb-product-api-prod
        What is the pipeline execution role ARN for stage 2?: arn:aws:iam::<AWS Acc ID>:role/aws-sam-cli-managed-prod-pipe-PipelineExecutionRole-aqksMyhWnm11
        What is the CloudFormation execution role ARN for stage 2?: arn:aws:iam::<AWS Acc ID>:role/aws-sam-cli-managed-prod--CloudFormationExecutionRo-kXNxTMH8NQQN
        What is the S3 bucket name for artifacts for stage 2?: aws-sam-cli-managed-prod-pipeline--artifactsbucket-kmex6rxriwjz
        What is the ECR repository URI for stage 2?: 
        What is the AWS region for stage 2?: eu-west-2
Successfully created the pipeline configuration file(s):
        - .github/workflows/pipeline.yaml
```

I then moved this to the root of the repo:

```bash
mv .github/workflows/pipeline.yaml <repo root>/.github/workflows/java-ddb-product-api.yaml
```

#### Step 2 - sam validate

Before proceeding further we can validate the template:

```bash
sam validate
/Users/edoatley/source/aws-notes/api-deployment/sam/java-ddb-product-api/template.yaml is a valid SAM Template
```

#### Step 3 - deploy and check lambda

Firstly we can commit the code to main to check the pipeline works. On doing this a workflow triggered in GitHub:

![sam-github-pipeline](images/sam-github-pipeline.png)

Secondly we can run a build locally:

```bash
❯ sam build                                                                                                                                                                                                                                                                                                              12:47:19
sam deploy --guided
Starting Build use cache                                                                                                                                                                                                                                                                                                                                                                                                         
Cache is invalid, running build and copying resources for following functions (HelloWorldFunction)                                                                                                                                                                                                                                                                                                                               
Building codeuri: /Users/edoatley/source/aws-notes/api-deployment/sam/java-ddb-product-api/HelloWorldFunction runtime: java21 architecture: x86_64 functions: HelloWorldFunction                                                                                                                                                                                                                                                 
 Running JavaGradleWorkflow:GradleBuild                                                                                                                                                                                                                                                                                                                                                                                          
 Running JavaGradleWorkflow:JavaGradleCopyArtifacts                                                                                                                                                                                                                                                                                                                                                                              
 Running JavaGradleWorkflow:CleanUp                                                                                                                                                                                                                                                                                                                                                                                              
 Running JavaGradleWorkflow:JavaCopyDependencies                                                                                                                                                                                                                                                                                                                                                                                 

Build Succeeded

Built Artifacts  : .aws-sam/build
Built Template   : .aws-sam/build/template.yaml

Commands you can use next
=========================
[*] Validate SAM template: sam validate
[*] Invoke Function: sam local invoke
[*] Test Function in the Cloud: sam sync --stack-name {{stack-name}} --watch
[*] Deploy: sam deploy --guided

Configuring SAM deploy
======================

        Looking for config file [samconfig.toml] :  Found
        Reading default arguments  :  Success

        Setting default arguments for 'sam deploy'
        =========================================
        Stack Name [java-ddb-product-api]: 
        AWS Region [eu-west-2]: 
        #Shows you resources changes to be deployed and require a 'Y' to initiate deploy
        Confirm changes before deploy [Y/n]: n
        #SAM needs permission to be able to create roles to connect to the resources in your template
        Allow SAM CLI IAM role creation [Y/n]: y
        #Preserves the state of previously provisioned resources when an operation fails
        Disable rollback [y/N]: 
        HelloWorldFunction has no authentication. Is this okay? [y/N]: y
        Save arguments to configuration file [Y/n]: y
        SAM configuration file [samconfig.toml]: 
        SAM configuration environment [default]: local

        Looking for resources needed for deployment:
        Creating the required resources...
        Successfully created!

        Managed S3 bucket: aws-sam-cli-managed-default-samclisourcebucket-iwqvvtsbytfu
        Auto resolution of buckets can be turned off by setting resolve_s3=False
        To use a specific S3 bucket, set --s3-bucket=<bucket_name>
        Above settings can be stored in samconfig.toml

        Saved arguments to config file
        Running 'sam deploy' for future deployments will use the parameters saved above.
        The above parameters can be changed by modifying samconfig.toml
        Learn more about samconfig.toml syntax at 
        https://docs.aws.amazon.com/serverless-application-model/latest/developerguide/serverless-sam-cli-config.html

        Uploading to java-ddb-product-api/93c7d69105961b6385a3429bc37c18a5  875089 / 875089  (100.00%)

        Deploying with following values
        ===============================
        Stack name                   : java-ddb-product-api
        Region                       : eu-west-2
        Confirm changeset            : False
        Disable rollback             : False
        Deployment s3 bucket         : aws-sam-cli-managed-default-samclisourcebucket-iwqvvtsbytfu
        Capabilities                 : ["CAPABILITY_IAM"]
        Parameter overrides          : {}
        Signing Profiles             : {}

Initiating deployment
=====================

        Uploading to java-ddb-product-api/f7d4ea2596068f27406c8df4821ad23c.template  1960 / 1960  (100.00%)


Waiting for changeset to be created..

CloudFormation stack changeset
-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Operation                                                                                               LogicalResourceId                                                                                       ResourceType                                                                                            Replacement                                                                                           
-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
+ Add                                                                                                   ApplicationInsightsMonitoring                                                                           AWS::ApplicationInsights::Application                                                                   N/A                                                                                                   
+ Add                                                                                                   ApplicationResourceGroup                                                                                AWS::ResourceGroups::Group                                                                              N/A                                                                                                   
+ Add                                                                                                   HelloWorldFunctionHelloWorldPermissionProd                                                              AWS::Lambda::Permission                                                                                 N/A                                                                                                   
+ Add                                                                                                   HelloWorldFunctionRole                                                                                  AWS::IAM::Role                                                                                          N/A                                                                                                   
+ Add                                                                                                   HelloWorldFunction                                                                                      AWS::Lambda::Function                                                                                   N/A                                                                                                   
+ Add                                                                                                   ServerlessRestApiDeployment47fc2d5f9d                                                                   AWS::ApiGateway::Deployment                                                                             N/A                                                                                                   
+ Add                                                                                                   ServerlessRestApiProdStage                                                                              AWS::ApiGateway::Stage                                                                                  N/A                                                                                                   
+ Add                                                                                                   ServerlessRestApi                                                                                       AWS::ApiGateway::RestApi                                                                                N/A                                                                                                   
-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------


Changeset created successfully. arn:aws:cloudformation:eu-west-2:503561418276:changeSet/samcli-deploy1748173812/2745b667-0bac-4663-afa5-049aca70a253


2025-05-25 12:50:17 - Waiting for stack create/update to complete

CloudFormation events from stack operations (refresh every 5.0 seconds)
-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
ResourceStatus                                                                                          ResourceType                                                                                            LogicalResourceId                                                                                       ResourceStatusReason                                                                                  
-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
CREATE_IN_PROGRESS                                                                                      AWS::CloudFormation::Stack                                                                              java-ddb-product-api                                                                                    User Initiated                                                                                        
CREATE_IN_PROGRESS                                                                                      AWS::IAM::Role                                                                                          HelloWorldFunctionRole                                                                                  -                                                                                                     
CREATE_IN_PROGRESS                                                                                      AWS::ResourceGroups::Group                                                                              ApplicationResourceGroup                                                                                -                                                                                                     
CREATE_IN_PROGRESS                                                                                      AWS::ResourceGroups::Group                                                                              ApplicationResourceGroup                                                                                Resource creation Initiated                                                                           
CREATE_IN_PROGRESS                                                                                      AWS::IAM::Role                                                                                          HelloWorldFunctionRole                                                                                  Resource creation Initiated                                                                           
CREATE_COMPLETE                                                                                         AWS::ResourceGroups::Group                                                                              ApplicationResourceGroup                                                                                -                                                                                                     
CREATE_IN_PROGRESS                                                                                      AWS::ApplicationInsights::Application                                                                   ApplicationInsightsMonitoring                                                                           -                                                                                                     
CREATE_IN_PROGRESS                                                                                      AWS::ApplicationInsights::Application                                                                   ApplicationInsightsMonitoring                                                                           Resource creation Initiated                                                                           
CREATE_COMPLETE                                                                                         AWS::IAM::Role                                                                                          HelloWorldFunctionRole                                                                                  -                                                                                                     
CREATE_IN_PROGRESS                                                                                      AWS::Lambda::Function                                                                                   HelloWorldFunction                                                                                      -                                                                                                     
CREATE_IN_PROGRESS                                                                                      AWS::Lambda::Function                                                                                   HelloWorldFunction                                                                                      Resource creation Initiated                                                                           
CREATE_IN_PROGRESS - CONFIGURATION_COMPLETE                                                             AWS::Lambda::Function                                                                                   HelloWorldFunction                                                                                      Eventual consistency check initiated                                                                  
CREATE_IN_PROGRESS                                                                                      AWS::ApiGateway::RestApi                                                                                ServerlessRestApi                                                                                       -                                                                                                     
CREATE_IN_PROGRESS                                                                                      AWS::ApiGateway::RestApi                                                                                ServerlessRestApi                                                                                       Resource creation Initiated                                                                           
CREATE_COMPLETE                                                                                         AWS::ApiGateway::RestApi                                                                                ServerlessRestApi                                                                                       -                                                                                                     
CREATE_IN_PROGRESS                                                                                      AWS::Lambda::Permission                                                                                 HelloWorldFunctionHelloWorldPermissionProd                                                              -                                                                                                     
CREATE_IN_PROGRESS                                                                                      AWS::ApiGateway::Deployment                                                                             ServerlessRestApiDeployment47fc2d5f9d                                                                   -                                                                                                     
CREATE_IN_PROGRESS                                                                                      AWS::Lambda::Permission                                                                                 HelloWorldFunctionHelloWorldPermissionProd                                                              Resource creation Initiated                                                                           
CREATE_IN_PROGRESS                                                                                      AWS::ApiGateway::Deployment                                                                             ServerlessRestApiDeployment47fc2d5f9d                                                                   Resource creation Initiated                                                                           
CREATE_COMPLETE                                                                                         AWS::Lambda::Permission                                                                                 HelloWorldFunctionHelloWorldPermissionProd                                                              -                                                                                                     
CREATE_COMPLETE                                                                                         AWS::ApiGateway::Deployment                                                                             ServerlessRestApiDeployment47fc2d5f9d                                                                   -                                                                                                     
CREATE_COMPLETE                                                                                         AWS::Lambda::Function                                                                                   HelloWorldFunction                                                                                      -                                                                                                     
CREATE_IN_PROGRESS                                                                                      AWS::ApiGateway::Stage                                                                                  ServerlessRestApiProdStage                                                                              -                                                                                                     
CREATE_IN_PROGRESS                                                                                      AWS::ApiGateway::Stage                                                                                  ServerlessRestApiProdStage                                                                              Resource creation Initiated                                                                           
CREATE_IN_PROGRESS - CONFIGURATION_COMPLETE                                                             AWS::ApplicationInsights::Application                                                                   ApplicationInsightsMonitoring                                                                           Eventual consistency check initiated                                                                  
CREATE_COMPLETE                                                                                         AWS::ApplicationInsights::Application                                                                   ApplicationInsightsMonitoring                                                                           -                                                                                                     
CREATE_COMPLETE                                                                                         AWS::ApiGateway::Stage                                                                                  ServerlessRestApiProdStage                                                                              -                                                                                                     
CREATE_COMPLETE                                                                                         AWS::CloudFormation::Stack                                                                              java-ddb-product-api                                                                                    -                                                                                                     
-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

CloudFormation outputs from deployed stack
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Outputs                                                                                                                                                                                                                                                                                                                                                                                                                      
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Key                 HelloWorldFunctionIamRole                                                                                                                                                                                                                                                                                                                                                                                
Description         Implicit IAM Role created for Hello World function                                                                                                                                                                                                                                                                                                                                                       
Value               arn:aws:iam::503561418276:role/java-ddb-product-api-HelloWorldFunctionRole-3YjfTSL0zt6b                                                                                                                                                                                                                                                                                                                  

Key                 HelloWorldApi                                                                                                                                                                                                                                                                                                                                                                                            
Description         API Gateway endpoint URL for Prod stage for Hello World function                                                                                                                                                                                                                                                                                                                                         
Value               https://7u44o3udy0.execute-api.eu-west-2.amazonaws.com/Prod/hello/                                                                                                                                                                                                                                                                                                                                       

Key                 HelloWorldFunction                                                                                                                                                                                                                                                                                                                                                                                       
Description         Hello World Lambda Function ARN                                                                                                                                                                                                                                                                                                                                                                          
Value               arn:aws:lambda:eu-west-2:503561418276:function:java-ddb-product-api-HelloWorldFunction-SJX8fTLQtTg3                                                                                                                                                                                                                                                                                                      
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------


Successfully created/updated stack - java-ddb-product-api in eu-west-2
```

Looking at what has been created we can look at CloudFormation:

```bash
aws cloudformation list-stacks --region eu-west-2 --stack-status-filter CREATE_COMPLETE --output table
# amended the output to remove some extraneous detail
+-----------------------------------------------------------------------------------------------------------------------------------------------------------------+
||                                                                        StackSummaries                                                                         ||
|+-------------------------+-------------------------------------------------------------------------------------------------------------------------------------+|
||  CreationTime           |  2025-05-25T11:50:12.437000+00:00                                                                                                   ||
||  LastUpdatedTime        |  2025-05-25T11:50:17.821000+00:00                                                                                                   ||
||  StackId                |  arn:aws:cloudformation:eu-west-2:503561418276:stack/java-ddb-product-api/6a6a8440-395e-11f0-8bba-06f845de0133                      ||
||  StackName              |  java-ddb-product-api                                                                                                               ||
||  StackStatus            |  CREATE_COMPLETE                                                                                                                    ||
||  TemplateDescription    |  java-ddb-product-api
|+------------------------+--------------------------------------------------------------------------------------------------------------------------------------+|
||  CreationTime          |  2025-05-25T11:49:25.286000+00:00                                                                                                    ||
||  LastUpdatedTime       |  2025-05-25T11:49:40.737000+00:00                                                                                                    ||
||  StackId               |  arn:aws:cloudformation:eu-west-2:503561418276:stack/aws-sam-cli-managed-default/4e568f10-395e-11f0-9b9f-02403da432b3                ||
||  StackName             |  aws-sam-cli-managed-default                                                                                                         ||
||  StackStatus           |  CREATE_COMPLETE                                                                                                                     ||
||  TemplateDescription   |  Managed Stack for AWS SAM CLI                                                                                                       ||
|+------------------------+--------------------------------------------------------------------------------------------------------------------------------------+|
|+------------------------+--------------------------------------------------------------------------------------------------------------------------------------+|
||  CreationTime          |  2025-05-25T11:48:48.791000+00:00                                                                                                    ||
||  LastUpdatedTime       |  2025-05-25T11:48:54.520000+00:00                                                                                                    ||
||  StackId               |  arn:aws:cloudformation:eu-west-2:503561418276:stack/sam-java-ddb-product-api-prod/38898110-395e-11f0-bfc9-027355a9c2b9              ||
||  StackName             |  sam-java-ddb-product-api-prod                                                                                                       ||
||  StackStatus           |  CREATE_COMPLETE                                                                                                                     ||
||  TemplateDescription   |  java-ddb-product-api                                                                                                                ||
|+------------------------+--------------------------------------------------------------------------------------------------------------------------------------+|
||  CreationTime          |  2025-05-25T11:47:28.918000+00:00                                                                                                    ||
||  LastUpdatedTime       |  2025-05-25T11:47:34.712000+00:00                                                                                                    ||
||  StackId               |  arn:aws:cloudformation:eu-west-2:503561418276:stack/sam-java-ddb-product-api-dev/08eb41f0-395e-11f0-8db6-060b56d3a3dd               ||
||  StackName             |  sam-java-ddb-product-api-dev                                                                                                        ||
||  StackStatus           |  CREATE_COMPLETE                                                                                                                     ||
||  TemplateDescription   |  java-ddb-product-api                                                                                                                ||
|+------------------------+--------------------------------------------------------------------------------------------------------------------------------------+|
|+---------------------+-----------------------------------------------------------------------------------------------------------------------------------------+|
||  CreationTime       |  2025-05-25T11:16:09.052000+00:00                                                                                                       ||
||  LastUpdatedTime    |  2025-05-25T11:16:24.512000+00:00                                                                                                       ||
||  StackId            |  arn:aws:cloudformation:eu-west-2:503561418276:stack/aws-sam-cli-managed-prod-pipeline-resources/a87b4990-3959-11f0-9ff9-061e7c95a79b   ||
||  StackName          |  aws-sam-cli-managed-prod-pipeline-resources                                                                                            ||
||  StackStatus        |  CREATE_COMPLETE                                                                                                                        ||
||  TemplateDescription|                                                                                                                                         ||
|+---------------------+-----------------------------------------------------------------------------------------------------------------------------------------+|
||  CreationTime       |  2025-05-25T11:13:49.662000+00:00                                                                                                       ||
||  LastUpdatedTime    |  2025-05-25T11:14:05.127000+00:00                                                                                                       ||
||  StackId            |  arn:aws:cloudformation:eu-west-2:503561418276:stack/aws-sam-cli-managed-dev-pipeline-resources/5566d300-3959-11f0-bc94-0286de70d613    ||
||  StackName          |  aws-sam-cli-managed-dev-pipeline-resources                                                                                             ||
||  StackStatus        |  CREATE_COMPLETE                                                                                                                        ||
||  TemplateDescription|                                                                                                                                         ||
|+---------------------+-----------------------------------------------------------------------------------------------------------------------------------------+|
```

So we now have a stack for the local, dev and prod stacks plus one for the aws sam cli and a dev and prod pipeline resources one. The API ones look like this:

![sam-api-stack-resources](images/sam-api-stack-resources.png)

while the sam cli one looks like this:

![sam-aws-cli-stack](images/sam-aws-cli-stack.png)

and the pipeline resources like this:

![sam-pipeline-resources-stack](images/sam-pipeline-resources-stack.png)

#### Step 4 - test the API

Now we have the locally deployed plus the dev and prod stages deployed via the GitHub actions we can try to test them.

Firstly we need the endpoints to test via API Gateway
```bash
for stack in $(aws cloudformation list-stacks --region eu-west-2 --stack-status-filter CREATE_COMPLETE --query "StackSummaries[*].{StackName: StackName}" --output text); do
  ep=$(aws cloudformation describe-stacks --stack-name "${stack}" \
    --query "Stacks[0].{HelloWorldApi: Outputs[?OutputKey=='HelloWorldApi'].OutputValue, HelloWorldFunction: Outputs[?OutputKey=='HelloWorldFunction'].OutputValue}" \
    --output text \
    --region eu-west-2)
  echo $ep
done
```

Which is a bit clunky but gives this:

```output
HELLOWORLDAPI           https://7u44o3udy0.execute-api.eu-west-2.amazonaws.com/Prod/hello/
HELLOWORLDFUNCTION      arn:aws:lambda:eu-west-2:503561418276:function:java-ddb-product-api-HelloWorldFunction-SJX8fTLQtTg3
HELLOWORLDAPI           https://4ck52bvc5k.execute-api.eu-west-2.amazonaws.com/Prod/hello/
HELLOWORLDFUNCTION      arn:aws:lambda:eu-west-2:503561418276:function:sam-java-ddb-product-api-prod-HelloWorldFunction-xHHYGrg1JVE9
HELLOWORLDAPI           https://09ro33fp8l.execute-api.eu-west-2.amazonaws.com/Prod/hello/
HELLOWORLDFUNCTION      arn:aws:lambda:eu-west-2:503561418276:function:sam-java-ddb-product-api-dev-HelloWorldFunction-MvarrmekKyql
```

So lets start eacy and just curl the endpoints:

```text
api_identifiers=(7u44o3udy0 4ck52bvc5k 09ro33fp8l)
for api_id in "${api_identifiers[@]}"; do
  echo "Testing ${api_id}:"
  curl -sX GET "https://${api_id}.execute-api.eu-west-2.amazonaws.com/Prod/hello/" | jq
done
```

Which works nicely giving:

```output
Testing 7u44o3udy0:
{
  "message": "hello world",
  "location": "35.177.124.4"
}
Testing 4ck52bvc5k:
{
  "message": "hello world",
  "location": "18.175.177.35"
}
Testing 09ro33fp8l:
{
  "message": "hello world",
  "location": "18.134.155.168"
}
```

Now to invoke the lambda functions directly. Firstly we create a minimal [event](./sam/java-ddb-product-api/events/hello.json)

We can test this event  locally with:

```bash
# Replace HelloWorldFunction with the logical ID from your template.yaml
sam local invoke HelloWorldFunction -e event.json-e events/hello.json  --region eu-west-2    
Invoking helloworld.App::handleRequest (java21)                                                                                                                                                                                                                                                                                                                                                                                  
Local image was not found.                                                                                                                                                                                                                                                                                                                                                                                                       
Removing rapid images for repo public.ecr.aws/sam/emulation-java21                                                                                                                                                                                                                                                                                                                                                               
Building image........................
Using local image: public.ecr.aws/lambda/java:21-rapid-x86_64.                                                                                                                                                                                                                                                                                                                                                                   
                                                                                                                                                                                                                                                                                                                                                                                                                                 
Mounting /Users/edoatley/source/aws-notes/api-deployment/sam/java-ddb-product-api/.aws-sam/build/HelloWorldFunction as /var/task:ro,delegated, inside runtime container                                                                                                                                                                                                                                                          
START RequestId: 07024244-2819-49a8-8b7d-1b1ffca65a78 Version: $LATEST
END RequestId: 4f0ae3ae-97da-47f1-98f4-e7de1b1b4c48
REPORT RequestId: 4f0ae3ae-97da-47f1-98f4-e7de1b1b4c48  Init Duration: 0.08 ms  Duration: 1188.15 ms    Billed Duration: 1189 ms        Memory Size: 512 MB     Max Memory Used: 512 MB 
{"statusCode": 200, "headers": {"X-Custom-Header": "application/json", "Content-Type": "application/json"}, "body": "{ \"message\": \"hello world\", \"location\": \"84.71.84.203\" }"}
```

Finally we can invoke the functions already deployed to AWS using the HELLOWORLDFUNCTION values above

HELLOWORLDAPI           https://7u44o3udy0.execute-api.eu-west-2.amazonaws.com/Prod/hello/
HELLOWORLDFUNCTION      arn:aws:lambda:eu-west-2:503561418276:function:java-ddb-product-api-HelloWorldFunction-SJX8fTLQtTg3
HELLOWORLDAPI           https://4ck52bvc5k.execute-api.eu-west-2.amazonaws.com/Prod/hello/
HELLOWORLDFUNCTION      arn:aws:lambda:eu-west-2:503561418276:function:sam-java-ddb-product-api-prod-HelloWorldFunction-xHHYGrg1JVE9
HELLOWORLDAPI           https://09ro33fp8l.execute-api.eu-west-2.amazonaws.com/Prod/hello/
HELLOWORLDFUNCTION      arn:aws:lambda:eu-west-2:503561418276:function:sam-java-ddb-product-api-dev-HelloWorldFunction-MvarrmekKyql

```bash
stack_ids=( java-ddb-product-api sam-java-ddb-product-api-dev sam-java-ddb-product-api-prod)
FUNCTION_LOGICAL_ID="HelloWorldFunction" # From template.yaml
for sid in "${stack_ids[@]}"; do
    echo "Testing ${sid}"
    echo ""
    sam remote invoke "${FUNCTION_LOGICAL_ID}" \
        --event-file events/hello.json \
        --stack-name "${sid}" \
        --region eu-west-2 | jq '.body'
    echo ""
done        
```

#### Step 5 - update the Hello world API to function like the product API

Now we have the hello world version working, and we can test what we have it is time to amend our API to meet the contract we had in **boot-ddb-products-api**

The first step is to update the code to provide the endpoints we had and write a JUnit test which is all in `api-deployment/sam/java-ddb-product-api/ProductApiFunction`
and update the [template](./sam/java-ddb-product-api/template.yaml) to add the different paths:

```yaml
      Events:
        GetSpecificProduct:
          Type: Api
          Properties:
            Path: /api/v1/products/{id}
            Method: get
        GetAllProducts:
          Type: Api
          Properties:
            Path: /api/v1/products
            Method: get
        AddNewProduct:
          Type: Api
          Properties:
            Path: /api/v1/products
            Method: post
        UpdateProduct:
          Type: Api
          Properties:
            Path: /api/v1/products/{id}
            Method: put
        DeleteProduct:
          Type: Api
          Properties:
            Path: /api/v1/products/{id}
            Method: delete
```

and define the table and IAM role:

```yaml
      Policies:
        - DynamoDBCrudPolicy:
            TableName: !Ref ProductDDBTable

  ProductDDBTable:
    Type: AWS::Serverless::SimpleTable
    Properties:
      TableName: products
      PrimaryKey:
        Name: id
        Type: String
```

With the unit tests working and the template defined we can test locally by running `sam local invoke` which is scripted
in [local-test.sh](./sam/java-ddb-product-api/scripts/local-test.sh) which gives the following output (cleaned for clarity):

```output
  ~/source/aws-notes/api-deployment/sam/java-ddb-product-api   feature/sam-hello-world ⇡2 +5 !4 ❯ ./scripts/local-test.sh                                                                                                                                                                      47s  17:04:30
Building SAM application from: /Users/edoatley/source/aws-notes/api-deployment/sam/java-ddb-product-api                                                                                                                                                                                                             

Build Succeeded

Built Artifacts  : .aws-sam/build
Built Template   : .aws-sam/build/template.yaml

---------------------------------------------------------------------
Initial scan of DynamoDB table: products-local (first 5 items)
{"description":{"S":"An updated test product"},"id":{"S":"test-id-x"},"price":{"N":"19.99"},"name":{"S":"Updated Product"}}
{"description":{"S":"Description 2"},"id":{"S":"2"},"price":{"N":"149.99"},"name":{"S":"Product 2"}}
{"description":{"S":"Test Description"},"id":{"S":"1"},"price":{"N":"99.99"},"name":{"S":"Test Product"}}
{"description":{"S":"A fantastic product created via POST"},"id":{"S":"fe66d3f5-652f-40e9-9c8e-0d5724cfa394"},"price":{"N":"49.99"},"name":{"S":"Brand New Product"}}
---------------------------------------------------------------------

Testing POST new product using event file: events/post_product.json
---------------------------------------------------------------------
Invoking product.ProductApiFunctionHandler::handleRequest (java21)                                                                                                                                                                                                                                                 
Mounting /Users/edoatley/source/aws-notes/api-deployment/sam/java-ddb-product-api/.aws-sam/build/ProductApiFunction as /var/task:ro,delegated, inside runtime container                                                                                                                                            
START RequestId: 3e776bc2-282b-4332-bd85-b321d2f8a3a6 Version: $LATEST
SLF4J: Failed to load class "org.slf4j.impl.StaticLoggerBinder".
SLF4J: Defaulting to no-operation (NOP) logger implementation
SLF4J: See http://www.slf4j.org/codes.html#StaticLoggerBinder for further details.
{"timestamp":"2025-05-28T16:25:36.463Z","message":"Received POST request for path: /api/v1/products","level":"UNDEFINED","AWSRequestId":"fb68ed97-3b84-424b-96a0-a0bf2ee44a63"}
END RequestId: fb68ed97-3b84-424b-96a0-a0bf2ee44a63
REPORT RequestId: fb68ed97-3b84-424b-96a0-a0bf2ee44a63  Init Duration: 0.03 ms  Duration: 3229.50 ms    Billed Duration: 3230 ms        Memory Size: 512 MB     Max Memory Used: 512 MB 

POST Response:
{"statusCode": 201, "headers": {"Content-Type": "application/json"}, "body": "{\"id\":\"cd8239b8-e4fb-40db-babe-1832c58dec78\",\"name\":\"Brand New Product\",\"description\":\"A fantastic product created via POST\",\"price\":49.99}"}
---------------------------------------------------------------------

Captured PRODUCT_ID: cd8239b8-e4fb-40db-babe-1832c58dec78
---------------------------------------------------------------------

Testing GET specific product for ID: cd8239b8-e4fb-40db-babe-1832c58dec78
---------------------------------------------------------------------
Reading invoke payload from stdin (you can also pass it from file with --event)                                                                                                                                                                                                                                    
Invoking product.ProductApiFunctionHandler::handleRequest (java21)                                                                                                                                                                                                                                                 
Mounting /Users/edoatley/source/aws-notes/api-deployment/sam/java-ddb-product-api/.aws-sam/build/ProductApiFunction as /var/task:ro,delegated, inside runtime container                                                                                                                                            
START RequestId: 6af4971a-4188-4435-882a-e8460bafeff6 Version: $LATEST
SLF4J: Failed to load class "org.slf4j.impl.StaticLoggerBinder".
SLF4J: Defaulting to no-operation (NOP) logger implementation
SLF4J: See http://www.slf4j.org/codes.html#StaticLoggerBinder for further details.
{"timestamp":"2025-05-28T16:25:44.273Z","message":"Received GET request for path: /api/v1/products/cd8239b8-e4fb-40db-babe-1832c58dec78","level":"UNDEFINED","AWSRequestId":"7b15bcdd-89f6-4ee9-a4cf-801926238a79"}
{"timestamp":"2025-05-28T16:25:44.278Z","message":"Fetching product by ID: cd8239b8-e4fb-40db-babe-1832c58dec78","level":"UNDEFINED","AWSRequestId":"7b15bcdd-89f6-4ee9-a4cf-801926238a79"}
END RequestId: 7b15bcdd-89f6-4ee9-a4cf-801926238a79
REPORT RequestId: 7b15bcdd-89f6-4ee9-a4cf-801926238a79  Init Duration: 0.05 ms  Duration: 3134.36 ms    Billed Duration: 3135 ms        Memory Size: 512 MB     Max Memory Used: 512 MB 
{"statusCode": 200, "headers": {"Content-Type": "application/json"}, "body": "{\"id\":\"cd8239b8-e4fb-40db-babe-1832c58dec78\",\"name\":\"Brand New Product\",\"description\":\"A fantastic product created via POST\",\"price\":49.99}"}
---------------------------------------------------------------------

Testing PUT (update) specific product for ID: cd8239b8-e4fb-40db-babe-1832c58dec78
---------------------------------------------------------------------
Reading invoke payload from stdin (you can also pass it from file with --event)                                                                                                                                                                                                                                    
Invoking product.ProductApiFunctionHandler::handleRequest (java21)                                                                                                                                                                                                                                                 
Mounting /Users/edoatley/source/aws-notes/api-deployment/sam/java-ddb-product-api/.aws-sam/build/ProductApiFunction as /var/task:ro,delegated, inside runtime container                                                                                                                                            
START RequestId: 33f75b38-c9fd-46ee-bab6-34e068730d8c Version: $LATEST
SLF4J: Failed to load class "org.slf4j.impl.StaticLoggerBinder".
SLF4J: Defaulting to no-operation (NOP) logger implementation
SLF4J: See http://www.slf4j.org/codes.html#StaticLoggerBinder for further details.
{"timestamp":"2025-05-28T16:25:52.026Z","message":"Received PUT request for path: /api/v1/products/cd8239b8-e4fb-40db-babe-1832c58dec78","level":"UNDEFINED","AWSRequestId":"dfd1cd59-c5c4-4cdc-8901-4a8f63d0d15e"}
END RequestId: dfd1cd59-c5c4-4cdc-8901-4a8f63d0d15e
REPORT RequestId: dfd1cd59-c5c4-4cdc-8901-4a8f63d0d15e  Init Duration: 0.04 ms  Duration: 3377.81 ms    Billed Duration: 3378 ms        Memory Size: 512 MB     Max Memory Used: 512 MB 
{"statusCode": 200, "headers": {"Content-Type": "application/json"}, "body": "{\"id\":\"cd8239b8-e4fb-40db-babe-1832c58dec78\",\"name\":\"Updated Product\",\"description\":\"An updated test product\",\"price\":19.99}"}
---------------------------------------------------------------------

Testing GET ALL products using event file: events/get_all_products.json
---------------------------------------------------------------------
Invoking product.ProductApiFunctionHandler::handleRequest (java21)                                                                                                                                                                                                                                                 
Mounting /Users/edoatley/source/aws-notes/api-deployment/sam/java-ddb-product-api/.aws-sam/build/ProductApiFunction as /var/task:ro,delegated, inside runtime container                                                                                                                                            
START RequestId: 2530bac4-773a-4f13-884d-74dc22ea3684 Version: $LATEST
SLF4J: Failed to load class "org.slf4j.impl.StaticLoggerBinder".
SLF4J: Defaulting to no-operation (NOP) logger implementation
SLF4J: See http://www.slf4j.org/codes.html#StaticLoggerBinder for further details.
{"timestamp":"2025-05-28T16:25:59.833Z","message":"Received GET request for path: /api/v1/products","level":"UNDEFINED","AWSRequestId":"ae5c9f71-6593-4219-a071-163bf837cd7a"}
{"timestamp":"2025-05-28T16:25:59.839Z","message":"Fetching all products.","level":"UNDEFINED","AWSRequestId":"ae5c9f71-6593-4219-a071-163bf837cd7a"}
END RequestId: ae5c9f71-6593-4219-a071-163bf837cd7a
REPORT RequestId: ae5c9f71-6593-4219-a071-163bf837cd7a  Init Duration: 0.13 ms  Duration: 3152.17 ms    Billed Duration: 3153 ms        Memory Size: 512 MB     Max Memory Used: 512 MB 
{"statusCode": 200, "headers": {"Content-Type": "application/json"}, "body": "[{\"id\":\"test-id-x\",\"name\":\"Updated Product\",\"description\":\"An updated test product\",\"price\":19.99},{\"id\":\"2\",\"name\":\"Product 2\",\"description\":\"Description 2\",\"price\":149.99},{\"id\":\"1\",\"name\":\"Test Product\",\"description\":\"Test Description\",\"price\":99.99},{\"id\":\"cd8239b8-e4fb-40db-babe-1832c58dec78\",\"name\":\"Updated Product\",\"description\":\"An updated test product\",\"price\":19.99},{\"id\":\"fe66d3f5-652f-40e9-9c8e-0d5724cfa394\",\"name\":\"Brand New Product\",\"description\":\"A fantastic product created via POST\",\"price\":49.99}]"}
---------------------------------------------------------------------

Testing DELETE specific product for ID: cd8239b8-e4fb-40db-babe-1832c58dec78
---------------------------------------------------------------------
Reading invoke payload from stdin (you can also pass it from file with --event)                                                                                                                                                                                                                                    
Invoking product.ProductApiFunctionHandler::handleRequest (java21)                                                                                                                                                                                                                                                 
Mounting /Users/edoatley/source/aws-notes/api-deployment/sam/java-ddb-product-api/.aws-sam/build/ProductApiFunction as /var/task:ro,delegated, inside runtime container                                                                                                                                            
START RequestId: 3343dd91-2691-4752-9332-5a98702c44c6 Version: $LATEST
SLF4J: Failed to load class "org.slf4j.impl.StaticLoggerBinder".
SLF4J: Defaulting to no-operation (NOP) logger implementation
SLF4J: See http://www.slf4j.org/codes.html#StaticLoggerBinder for further details.
{"timestamp":"2025-05-28T16:26:07.547Z","message":"Received DELETE request for path: /api/v1/products/cd8239b8-e4fb-40db-babe-1832c58dec78","level":"UNDEFINED","AWSRequestId":"f4bafc0a-bf07-4942-a167-bdb7bec55ae5"}
END RequestId: f4bafc0a-bf07-4942-a167-bdb7bec55ae5
REPORT RequestId: f4bafc0a-bf07-4942-a167-bdb7bec55ae5  Init Duration: 0.05 ms  Duration: 3109.38 ms    Billed Duration: 3110 ms        Memory Size: 512 MB     Max Memory Used: 512 MB 
{"statusCode": 204, "headers": {"Content-Type": "application/json"}, "body": ""}
---------------------------------------------------------------------

Testing GET specific product (after delete) for ID: cd8239b8-e4fb-40db-babe-1832c58dec78
---------------------------------------------------------------------
Reading invoke payload from stdin (you can also pass it from file with --event)                                                                                                                                                                                                                                    
Invoking product.ProductApiFunctionHandler::handleRequest (java21)                                                                                                                                                                                                                                                 
Mounting /Users/edoatley/source/aws-notes/api-deployment/sam/java-ddb-product-api/.aws-sam/build/ProductApiFunction as /var/task:ro,delegated, inside runtime container                                                                                                                                            
START RequestId: 04aa625d-e66b-4078-9e80-2e4d64090513 Version: $LATEST
SLF4J: Failed to load class "org.slf4j.impl.StaticLoggerBinder".
SLF4J: Defaulting to no-operation (NOP) logger implementation
SLF4J: See http://www.slf4j.org/codes.html#StaticLoggerBinder for further details.
{"timestamp":"2025-05-28T16:26:15.211Z","message":"Received GET request for path: /api/v1/products/cd8239b8-e4fb-40db-babe-1832c58dec78","level":"UNDEFINED","AWSRequestId":"a908639e-a09f-4b41-8a31-6c9e1cc88623"}
{"timestamp":"2025-05-28T16:26:15.217Z","message":"Fetching product by ID: cd8239b8-e4fb-40db-babe-1832c58dec78","level":"UNDEFINED","AWSRequestId":"a908639e-a09f-4b41-8a31-6c9e1cc88623"}
{"timestamp":"2025-05-28T16:26:16.023Z","message":"Product Not Found: Product not found with id cd8239b8-e4fb-40db-babe-1832c58dec78","level":"UNDEFINED","AWSRequestId":"a908639e-a09f-4b41-8a31-6c9e1cc88623"}
{"timestamp":"2025-05-28T16:26:16.029Z","message":"Error response: 404 - Product not found with id cd8239b8-e4fb-40db-babe-1832c58dec78","level":"UNDEFINED","AWSRequestId":"a908639e-a09f-4b41-8a31-6c9e1cc88623"}
END RequestId: a908639e-a09f-4b41-8a31-6c9e1cc88623
REPORT RequestId: a908639e-a09f-4b41-8a31-6c9e1cc88623  Init Duration: 0.05 ms  Duration: 3092.06 ms    Billed Duration: 3093 ms        Memory Size: 512 MB     Max Memory Used: 512 MB 
{"statusCode": 404, "headers": {"Content-Type": "application/json"}, "body": "{\"error\": \"Product not found with id cd8239b8-e4fb-40db-babe-1832c58dec78\"}"}
```

With this working we can commit on our feature branch and let the pipeline deploy our lambda/API gateway resources to AWS. 
To find the endpoint we can run:

```bash
# basic details
region="eu-west-2"
stage_name="Prod"
api_base_path="/api/v1/products/"

# get the feature branch name with the feature/ removed
branch_name=$(git branch --show-current | cut -f2 -d/)

#find a rest api with the name of the feature branch
rest_api_id=$(aws apigateway get-rest-apis --region eu-west-2 --query "items[?name=='${branch_name}'].id" --output text)

# Construct the base invoke URL for the stage
invoke_url_stage_base="https://${rest_api_id}.execute-api.${region}.amazonaws.com/${stage_name}"

# construct the full base endpoint for your product API
full_api_endpoint="${invoke_url_stage_base}${api_base_path}"
echo $full_api_endpoint
```

We can then run all the tests for real using [remote-test.sh](./sam/java-ddb-product-api/scripts/remote-test.sh)

### Lambda using a Spring Cloud Function app

