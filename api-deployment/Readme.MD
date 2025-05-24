# API Deployment on AWS

- [API Deployment on AWS](#api-deployment-on-aws)
  - [Introduction](#introduction)
  - [Deployment using ECS](#deployment-using-ecs)
    - [Simplistic implementation](#simplistic-implementation)
      - [Architecture Diagram](#architecture-diagram)
    - [More Private Implementation](#more-private-implementation)
      - [Architectural Diagram](#architectural-diagram)
  - [Deployment using lambda](#deployment-using-lambda)
    - [Amazon API Gateway to AWS Lambda to Amazon DynamoDB - Java](#amazon-api-gateway-to-aws-lambda-to-amazon-dynamodb---java)

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

To get started I developed the cloudformation template [ecs-deploy.cfn](./deployments/cloudformation/ecs-deploy.cfn) which has the following resources:

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
cd /deployments/scripts
# Cloudformation Deployment:
./deploy.sh ecs-deploy
# Testing:
./ecs-api-test.sh
```

### More Private Implementation

The cloudformation template [ecs-deploy-private.cfn](./deployments/cloudformation/ecs-deploy-private.cfn) improves security and adds API Gateway integration with these resources:

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

## Deployment using lambda

Next we are going to explore doing the same thing using AWS Lambda which should simplify things significantly for such a basic application.
To simplify things further we will use some pre-baked serverless patterns described on [serverlessland](https://serverlessland.com/patterns/)

### Amazon API Gateway to AWS Lambda to Amazon DynamoDB - Java

https://serverlessland.com/patterns/apigw-lambda-dynamodb-sam-java
https://github.com/aws-samples/serverless-patterns/tree/main/apigw-lambda-dynamodb-sam-java