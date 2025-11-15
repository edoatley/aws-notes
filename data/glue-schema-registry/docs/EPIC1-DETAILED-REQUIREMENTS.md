# Epic 1: Infrastructure Deployment - Detailed Requirements

## Overview

This document provides detailed specifications for Epic 1: Infrastructure Deployment. It serves as a developer "to-do" list for implementing the CloudFormation template and related infrastructure components.

**User Story:** As a developer, I want to deploy all required AWS infrastructure by running a single `aws cloudformation deploy` command.

---

## 1. Project File Structure

The following files and directories must be created at the project root:

```
aws-notes/
└── data/
    └── glue-schema-registry/
        ├── REQUIREMENTS.md (existing)
        ├── EPIC1-DETAILED-REQUIREMENTS.md (this file)
        ├── template.yaml (to be created)
        └── .gitignore (to be created)
```

### 1.1 Files to Create

#### `template.yaml`
- **Location:** `/Users/edoatley/source/aws-notes/data/glue-schema-registry/template.yaml`
- **Purpose:** Single CloudFormation template containing all infrastructure resources
- **Format:** YAML
- **Description:** This file will contain all AWS resources defined in sections 2-4 below

#### `.gitignore`
- **Location:** `/Users/edoatley/source/aws-notes/data/glue-schema-registry/.gitignore`
- **Purpose:** Exclude build artifacts and sensitive files from version control
- **Content to include:**
  - `*.class` (compiled Java files)
  - `build/` (Gradle build directory)
  - `.gradle/` (Gradle cache)
  - `*.log` (log files)
  - `.idea/` (IntelliJ IDEA files, if used)
  - `.vscode/` (VS Code files, if used)
  - `*.iml` (IntelliJ module files)

---

## 2. CloudFormation Template Structure

The `template.yaml` file must follow the standard CloudFormation template structure:

```yaml
AWSTemplateFormatVersion: '2010-09-09'
Description: 'AWS Glue Schema Registry Testbed Infrastructure'
Parameters:
  # (if any parameters are needed)
Resources:
  # All resources defined below
Outputs:
  # All outputs defined in section 4
```

---

## 3. Detailed Resource Breakdown

### 3.1 VPC and Networking Resources

#### 3.1.1 VPC (`AWS::EC2::VPC`)
- **Logical ID:** `TestVPC`
- **Properties:**
  - `CidrBlock`: `10.0.0.0/16`
  - `EnableDnsHostnames`: `true`
  - `EnableDnsSupport`: `true`
  - `Tags`: 
    - `Key: Name`, `Value: GlueSchemaRegistryTestVPC`

#### 3.1.2 Internet Gateway (`AWS::EC2::InternetGateway`)
- **Logical ID:** `TestInternetGateway`
- **Properties:**
  - `Tags`: 
    - `Key: Name`, `Value: GlueSchemaRegistryTestIGW`
- **Dependencies:** None

#### 3.1.3 Internet Gateway Attachment (`AWS::EC2::VPCGatewayAttachment`)
- **Logical ID:** `TestIGWAttachment`
- **Properties:**
  - `InternetGatewayId`: `!Ref TestInternetGateway`
  - `VpcId`: `!Ref TestVPC`
- **Dependencies:** `TestVPC`, `TestInternetGateway`

#### 3.1.4 Public Subnet 1 (`AWS::EC2::Subnet`)
- **Logical ID:** `PublicSubnet1`
- **Properties:**
  - `VpcId`: `!Ref TestVPC`
  - `AvailabilityZone`: Use `!Select [0, !GetAZs '']` to get first AZ
  - `CidrBlock`: `10.0.1.0/24`
  - `MapPublicIpOnLaunch`: `true`
  - `Tags`: 
    - `Key: Name`, `Value: GlueSchemaRegistryPublicSubnet1`

#### 3.1.5 Public Subnet 2 (`AWS::EC2::Subnet`)
- **Logical ID:** `PublicSubnet2`
- **Properties:**
  - `VpcId`: `!Ref TestVPC`
  - `AvailabilityZone`: Use `!Select [1, !GetAZs '']` to get second AZ
  - `CidrBlock`: `10.0.2.0/24`
  - `MapPublicIpOnLaunch`: `true`
  - `Tags`: 
    - `Key: Name`, `Value: GlueSchemaRegistryPublicSubnet2`
- **Note:** MSK Serverless requires subnets in at least 2 different AZs

#### 3.1.6 Public Route Table (`AWS::EC2::RouteTable`)
- **Logical ID:** `PublicRouteTable`
- **Properties:**
  - `VpcId`: `!Ref TestVPC`
  - `Tags`: 
    - `Key: Name`, `Value: GlueSchemaRegistryPublicRouteTable`

#### 3.1.7 Default Public Route (`AWS::EC2::Route`)
- **Logical ID:** `PublicDefaultRoute`
- **Properties:**
  - `RouteTableId`: `!Ref PublicRouteTable`
  - `DestinationCidrBlock`: `0.0.0.0/0`
  - `GatewayId`: `!Ref TestInternetGateway`
- **Dependencies:** `PublicRouteTable`, `TestIGWAttachment`

#### 3.1.8 Subnet Route Table Association 1 (`AWS::EC2::SubnetRouteTableAssociation`)
- **Logical ID:** `PublicSubnet1RouteTableAssociation`
- **Properties:**
  - `SubnetId`: `!Ref PublicSubnet1`
  - `RouteTableId`: `!Ref PublicRouteTable`

#### 3.1.9 Subnet Route Table Association 2 (`AWS::EC2::SubnetRouteTableAssociation`)
- **Logical ID:** `PublicSubnet2RouteTableAssociation`
- **Properties:**
  - `SubnetId`: `!Ref PublicSubnet2`
  - `RouteTableId`: `!Ref PublicRouteTable`

---

### 3.2 Security Groups

#### 3.2.1 MSK Security Group (`AWS::EC2::SecurityGroup`)
- **Logical ID:** `MSKSecurityGroup`
- **Properties:**
  - `GroupDescription`: `Security group for MSK Serverless cluster`
  - `VpcId`: `!Ref TestVPC`
  - `SecurityGroupIngress`: 
    - **Rule 1:**
      - `IpProtocol`: `tcp`
      - `FromPort`: `9098` (TLS port for MSK)
      - `ToPort`: `9098`
      - `SourceSecurityGroupId`: `!Ref EC2SecurityGroup`
      - `Description`: `Allow TLS traffic from EC2 instance`
    - **Rule 2:**
      - `IpProtocol`: `tcp`
      - `FromPort`: `9096` (Plaintext port for MSK, if needed)
      - `ToPort`: `9096`
      - `SourceSecurityGroupId`: `!Ref EC2SecurityGroup`
      - `Description`: `Allow plaintext traffic from EC2 instance`
  - `Tags`: 
    - `Key: Name`, `Value: GlueSchemaRegistryMSKSG`
- **Dependencies:** `TestVPC`, `EC2SecurityGroup` (must be defined before this resource)

#### 3.2.2 EC2 Security Group (`AWS::EC2::SecurityGroup`)
- **Logical ID:** `EC2SecurityGroup`
- **Properties:**
  - `GroupDescription`: `Security group for EC2 test instance`
  - `VpcId`: `!Ref TestVPC`
  - `SecurityGroupIngress`: 
    - **None** (access via SSM Session Manager, no inbound rules needed)
  - `SecurityGroupEgress`: 
    - **Rule 1:**
      - `IpProtocol`: `-1` (all protocols)
      - `CidrIp`: `0.0.0.0/0`
      - `Description`: `Allow all outbound traffic for package installation and Kafka communication`
  - `Tags`: 
    - `Key: Name`, `Value: GlueSchemaRegistryEC2SG`
- **Dependencies:** `TestVPC`

---

### 3.3 Glue Schema Registry

#### 3.3.1 Glue Registry (`AWS::Glue::Registry`)
- **Logical ID:** `PaymentSchemaRegistry`
- **Properties:**
  - `Name`: `PaymentSchemaRegistry`
  - `Description`: `Schema registry for payment events (AVRO and JSON Schema)`
- **Dependencies:** None

---

### 3.4 MSK Serverless Cluster

#### 3.4.1 MSK Serverless Cluster (`AWS::MSK::ServerlessCluster`)
- **Logical ID:** `MSKServerlessCluster`
- **Properties:**
  - `ClusterName`: `glue-schema-registry-test-cluster`
  - `VpcConfig`: 
    - `SubnetIds`: 
      - `!Ref PublicSubnet1`
      - `!Ref PublicSubnet2`
    - `SecurityGroupIds`: 
      - `!Ref MSKSecurityGroup`
  - `ClientAuthentication`: 
    - `Sasl`: 
      - `Iam`: 
        - `Enabled`: `true`
  - `Tags`: 
    - `Key: Name`, `Value: GlueSchemaRegistryMSKCluster`
- **Dependencies:** `PublicSubnet1`, `PublicSubnet2`, `MSKSecurityGroup`
- **Note:** MSK Serverless uses IAM authentication by default. The cluster will be accessible via IAM roles.

---

### 3.5 IAM Resources

#### 3.5.1 EC2 Instance Role (`AWS::IAM::Role`)
- **Logical ID:** `EC2InstanceRole`
- **Properties:**
  - `RoleName`: `GlueSchemaRegistryEC2InstanceRole` (optional, for easier identification)
  - `AssumeRolePolicyDocument`: 
    ```json
    {
      "Version": "2012-10-17",
      "Statement": [
        {
          "Effect": "Allow",
          "Principal": {
            "Service": "ec2.amazonaws.com"
          },
          "Action": "sts:AssumeRole"
        }
      ]
    }
    ```
  - `ManagedPolicyArns`: 
    - `arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore`
  - `Policies`: 
    - **Policy Name:** `GlueSchemaRegistryPermissions`
      - **Policy Document:**
        ```json
        {
          "Version": "2012-10-17",
          "Statement": [
            {
              "Effect": "Allow",
              "Action": [
                "glue:RegisterSchemaVersion",
                "glue:CreateSchema",
                "glue:GetSchemaVersion",
                "glue:GetSchema"
              ],
              "Resource": "*"
            },
            {
              "Effect": "Allow",
              "Action": [
                "kafka-cluster:WriteData",
                "kafka-cluster:ReadData",
                "kafka-cluster:DescribeCluster",
                "kafka:CreateTopic"
              ],
              "Resource": "*"
            }
          ]
        }
        ```
  - `Tags`: 
    - `Key: Name`, `Value: GlueSchemaRegistryEC2InstanceRole`
- **Dependencies:** None

#### 3.5.2 EC2 Instance Profile (`AWS::IAM::InstanceProfile`)
- **Logical ID:** `EC2InstanceProfile`
- **Properties:**
  - `InstanceProfileName`: `GlueSchemaRegistryEC2InstanceProfile` (optional)
  - `Roles`: 
    - `!Ref EC2InstanceRole`
  - `Tags`: 
    - `Key: Name`, `Value: GlueSchemaRegistryEC2InstanceProfile`
- **Dependencies:** `EC2InstanceRole`

---

### 3.6 EC2 Instance

#### 3.6.1 EC2 Instance (`AWS::EC2::Instance`)
- **Logical ID:** `TestEC2Instance`
- **Properties:**
  - `ImageId`: Use `!Sub '{{resolve:ssm:/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-6.1-x86_64}}'` to get the latest Amazon Linux 2023 AMI
  - `InstanceType`: `t3.micro`
  - `IamInstanceProfile`: `!Ref EC2InstanceProfile`
  - `SecurityGroupIds`: 
    - `!Ref EC2SecurityGroup`
  - `SubnetId`: `!Ref PublicSubnet1`
  - `UserData`: Base64-encoded script (see section 3.7 below)
  - `Tags`: 
    - `Key: Name`, `Value: GlueSchemaRegistryTestInstance`
- **Dependencies:** `EC2InstanceProfile`, `EC2SecurityGroup`, `PublicSubnet1`
- **Note:** The instance must be in a public subnet to download packages, but access will be via SSM (no public IP needed if SSM is configured correctly).

---

## 4. EC2 UserData Script Specification

The UserData script must be provided as a Base64-encoded string in the CloudFormation template. The script should be written in bash and executed on instance boot.

### 4.1 Script Logic

The script must perform the following operations in order:

1. **Update system packages:**
   ```bash
   sudo dnf update -y
   ```

2. **Install Java 11 (Amazon Corretto):**
   ```bash
   sudo dnf install -y java-11-amazon-corretto-devel
   ```

3. **Verify Java installation:**
   ```bash
   java -version
   ```
   (This should output Java 11 information)

4. **Install Git:**
   ```bash
   sudo dnf install -y git
   ```

5. **Install Gradle:**
   - **Option A (Recommended - using SDKMAN):**
     ```bash
     # Install SDKMAN
     curl -s "https://get.sdkman.io" | bash
     source "$HOME/.sdkman/bin/sdkman-init.sh"
     
     # Install Gradle via SDKMAN
     sdk install gradle 8.5
     ```
   - **Option B (Alternative - direct download):**
     ```bash
     # Download Gradle 8.5
     cd /opt
     sudo wget https://services.gradle.org/distributions/gradle-8.5-bin.zip
     sudo unzip gradle-8.5-bin.zip
     sudo mv gradle-8.5 gradle
     sudo ln -s /opt/gradle/bin/gradle /usr/local/bin/gradle
     ```

6. **Verify Gradle installation:**
   ```bash
   gradle -v
   ```

7. **Set environment variables (if using direct download method):**
   ```bash
   echo 'export PATH=$PATH:/opt/gradle/bin' >> ~/.bashrc
   source ~/.bashrc
   ```

### 4.2 Complete UserData Script (SDKMAN method)

```bash
#!/bin/bash
set -e

# Update system
sudo dnf update -y

# Install Java 11 (Amazon Corretto)
sudo dnf install -y java-11-amazon-corretto-devel

# Verify Java
java -version

# Install Git
sudo dnf install -y git

# Install SDKMAN
curl -s "https://get.sdkman.io" | bash
source "$HOME/.sdkman/bin/sdkman-init.sh"

# Install Gradle via SDKMAN
sdk install gradle 8.5 -y

# Verify Gradle
gradle -v

# Log completion
echo "UserData script completed successfully" >> /var/log/user-data.log
```

### 4.3 CloudFormation Encoding

In the CloudFormation template, the UserData must be encoded using the `Fn::Base64` intrinsic function:

```yaml
UserData:
  Fn::Base64: !Sub |
    #!/bin/bash
    set -e
    # ... (script content as above)
```

---

## 5. CloudFormation Outputs

The template must output the following values:

### 5.1 MSK Bootstrap Servers

- **Output Name:** `MSKBootstrapServers`
- **Description:** `MSK Serverless cluster bootstrap server endpoints`
- **Value:** `!GetAtt MSKServerlessCluster.BootstrapServerString`
- **Export:** Optional (not required for this epic)

### 5.2 EC2 Instance ID

- **Output Name:** `EC2InstanceId`
- **Description:** `EC2 instance ID for connecting via SSM`
- **Value:** `!Ref TestEC2Instance`
- **Export:** Optional (not required for this epic)

### 5.3 Glue Registry Name

- **Output Name:** `GlueRegistryName`
- **Description:** `Name of the Glue Schema Registry`
- **Value:** `!Ref PaymentSchemaRegistry`
- **Export:** Optional (not required for this epic)

### 5.4 VPC ID

- **Output Name:** `VPCId`
- **Description:** `VPC ID for reference`
- **Value:** `!Ref TestVPC`
- **Export:** Optional (not required for this epic)

### 5.5 Complete Outputs Section

```yaml
Outputs:
  MSKBootstrapServers:
    Description: MSK Serverless cluster bootstrap server endpoints
    Value: !GetAtt MSKServerlessCluster.BootstrapServerString
    Export:
      Name: !Sub '${AWS::StackName}-MSKBootstrapServers'
  
  EC2InstanceId:
    Description: EC2 instance ID for connecting via SSM
    Value: !Ref TestEC2Instance
    Export:
      Name: !Sub '${AWS::StackName}-EC2InstanceId'
  
  GlueRegistryName:
    Description: Name of the Glue Schema Registry
    Value: !Ref PaymentSchemaRegistry
    Export:
      Name: !Sub '${AWS::StackName}-GlueRegistryName'
  
  VPCId:
    Description: VPC ID for reference
    Value: !Ref TestVPC
    Export:
      Name: !Sub '${AWS::StackName}-VPCId'
```

---

## 6. CloudFormation Deployment Command

### 6.1 Basic Deployment Command

The deployment command must be run from the directory containing `template.yaml`:

```bash
aws cloudformation deploy \
  --template-file template.yaml \
  --stack-name glue-schema-registry-testbed \
  --capabilities CAPABILITY_NAMED_IAM \
  --region us-east-1
```

### 6.2 Command Breakdown

- **`--template-file template.yaml`:** Specifies the CloudFormation template file
- **`--stack-name glue-schema-registry-testbed`:** Name of the CloudFormation stack
- **`--capabilities CAPABILITY_NAMED_IAM`:** Required because the template creates IAM roles with custom names
- **`--region us-east-1`:** AWS region (adjust as needed, but ensure MSK Serverless is available in the region)

### 6.3 Parameter Overrides

**No parameters are required for this epic.** All values are hardcoded in the template.

If parameters are added in the future, they would be specified using:
```bash
--parameter-overrides ParameterKey=KeyName,ParameterValue=Value
```

### 6.4 Alternative: Using AWS SAM or Other Tools

If using AWS SAM CLI or other deployment tools, the command structure may differ, but the core CloudFormation template remains the same.

---

## 7. Resource Dependencies and Order

The following dependency order must be respected in the CloudFormation template:

1. **VPC** (no dependencies)
2. **Internet Gateway** (no dependencies)
3. **Subnets** (depend on VPC)
4. **IGW Attachment** (depends on VPC and IGW)
5. **Route Table** (depends on VPC)
6. **Route** (depends on Route Table and IGW Attachment)
7. **Subnet Route Table Associations** (depend on Subnets and Route Table)
8. **EC2 Security Group** (depends on VPC)
9. **MSK Security Group** (depends on VPC and EC2 Security Group)
10. **Glue Registry** (no dependencies)
11. **EC2 Instance Role** (no dependencies)
12. **EC2 Instance Profile** (depends on EC2 Instance Role)
13. **MSK Serverless Cluster** (depends on Subnets and MSK Security Group)
14. **EC2 Instance** (depends on Instance Profile, Security Group, and Subnet)

---

## 8. Validation and Testing

### 8.1 Pre-Deployment Validation

Before deploying, validate the template:

```bash
aws cloudformation validate-template \
  --template-body file://template.yaml \
  --region us-east-1
```

### 8.2 Post-Deployment Verification

After deployment, verify:

1. **Stack Status:**
   ```bash
   aws cloudformation describe-stacks \
     --stack-name glue-schema-registry-testbed \
     --region us-east-1 \
     --query 'Stacks[0].StackStatus'
   ```
   Should return: `CREATE_COMPLETE`

2. **Get Outputs:**
   ```bash
   aws cloudformation describe-stacks \
     --stack-name glue-schema-registry-testbed \
     --region us-east-1 \
     --query 'Stacks[0].Outputs'
   ```

3. **Verify EC2 Instance:**
   ```bash
   aws ec2 describe-instances \
     --filters "Name=tag:Name,Values=GlueSchemaRegistryTestInstance" \
     --region us-east-1 \
     --query 'Reservations[0].Instances[0].InstanceId'
   ```

4. **Verify MSK Cluster:**
   ```bash
   aws kafka list-clusters \
     --region us-east-1 \
     --query 'ClusterInfoList[?ClusterName==`glue-schema-registry-test-cluster`]'
   ```

5. **Verify Glue Registry:**
   ```bash
   aws glue get-registry \
     --registry-id RegistryName=PaymentSchemaRegistry \
     --region us-east-1
   ```

---

## 9. Cost Considerations

### 9.1 Expected Costs

- **VPC:** Free (no charges for VPC, subnets, route tables, IGW)
- **EC2 t3.micro:** Free Tier eligible (750 hours/month for first 12 months)
- **MSK Serverless:** Pay-per-use, no idle charges
- **Glue Schema Registry:** Free tier (1,000 requests/month)
- **Data Transfer:** Minimal (within same region)

### 9.2 Cost Monitoring

Monitor costs via:
```bash
aws ce get-cost-and-usage \
  --time-period Start=2024-01-01,End=2024-01-02 \
  --granularity DAILY \
  --metrics BlendedCost \
  --filter file://cost-filter.json
```

---

## 10. Cleanup Command

After testing, destroy all resources:

```bash
aws cloudformation delete-stack \
  --stack-name glue-schema-registry-testbed \
  --region us-east-1
```

Verify deletion:
```bash
aws cloudformation describe-stacks \
  --stack-name glue-schema-registry-testbed \
  --region us-east-1
```
(Should return an error indicating the stack does not exist)

---

## 11. Known Limitations and Considerations

### 11.1 MSK Serverless

- MSK Serverless clusters can take 10-15 minutes to create
- The bootstrap server string is only available after the cluster is in `ACTIVE` state
- MSK Serverless uses IAM authentication by default

### 11.2 EC2 Instance

- The instance must be in a public subnet to download packages during UserData execution
- SSM Session Manager does not require a public IP or SSH keys
- UserData script execution can take 5-10 minutes

### 11.3 IAM Permissions

- The EC2 instance role must have permissions for both Glue and MSK
- MSK IAM authentication requires `kafka-cluster:*` permissions on the cluster resource ARN
- For simplicity, this template uses `Resource: "*"` in inline policies (can be refined later)

### 11.4 Region Availability

- Ensure MSK Serverless is available in the target region
- Verify Glue Schema Registry is available in the target region

---

## 12. Next Steps After Epic 1

Once Epic 1 is complete and the infrastructure is deployed:

1. Retrieve the MSK Bootstrap Server string from CloudFormation outputs
2. Connect to the EC2 instance via SSM Session Manager
3. Verify Java 11 and Gradle are installed
4. Proceed to Epic 2: AVRO Producer-Consumer Flow

---

## Appendix A: Resource Naming Conventions

All resources should follow consistent naming:

- **VPC:** `GlueSchemaRegistryTestVPC`
- **Subnets:** `GlueSchemaRegistryPublicSubnet1`, `GlueSchemaRegistryPublicSubnet2`
- **Security Groups:** `GlueSchemaRegistryMSKSG`, `GlueSchemaRegistryEC2SG`
- **MSK Cluster:** `glue-schema-registry-test-cluster`
- **Glue Registry:** `PaymentSchemaRegistry`
- **EC2 Instance:** `GlueSchemaRegistryTestInstance`
- **IAM Role:** `GlueSchemaRegistryEC2InstanceRole`

---

## Appendix B: CIDR Block Allocation

- **VPC:** `10.0.0.0/16`
- **Public Subnet 1:** `10.0.1.0/24`
- **Public Subnet 2:** `10.0.2.0/24`
- **Future private subnets (if needed):** `10.0.3.0/24`, `10.0.4.0/24`

---

## End of Epic 1 Detailed Requirements

This document provides complete specifications for implementing Epic 1. The developer should use this as a checklist when creating the CloudFormation template.

