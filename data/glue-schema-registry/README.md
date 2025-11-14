# AWS Glue Schema Registry Testbed

## Objective

This project is a minimal, low-cost proof-of-concept (PoC) to test and document the core functionalities of the **AWS Glue Schema Registry**. The project demonstrates schema registration, serialization, and deserialization using a Kafka-based messaging system for both **AVRO** and **JSON Schema** data formats.

The infrastructure is deployed using AWS CloudFormation and includes:
- AWS Glue Schema Registry
- Amazon MSK Serverless (event bus)
- AWS EC2 instance (t3.micro) for running test applications
- VPC and networking components
- IAM roles and permissions

## Prerequisites

Before deploying this infrastructure, ensure you have:

1. **AWS CLI** installed and configured with appropriate credentials
   ```bash
   aws --version
   aws configure list
   ```

2. **AWS SSM Session Manager Plugin** installed (for connecting to EC2 instance)
   
   **macOS Installation:**
   ```bash
   brew install --cask session-manager-plugin
   ```
   
   **Linux Installation:**
   ```bash
   curl "https://s3.amazonaws.com/session-manager-downloads/plugin/latest/linux_64bit/session-manager-plugin.rpm" -o "session-manager-plugin.rpm"
   sudo yum install -y session-manager-plugin.rpm
   ```
   
   **Verify Installation:**
   ```bash
   session-manager-plugin
   ```
   
   If you see version information, the plugin is installed correctly. If you get "command not found", follow the installation steps above or see the [AWS documentation](https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-working-with-install-plugin.html).

3. **Java 11** (optional, for local development)
   - The EC2 instance will have Java 11 pre-installed via UserData

4. **Git** (for cloning the repository on the EC2 instance)

5. **AWS Account** with permissions to create:
   - VPC, Subnets, Internet Gateway, Route Tables
   - EC2 instances and Security Groups
   - MSK Serverless clusters
   - Glue Schema Registry
   - IAM roles and policies

## Step-by-Step Instructions

### Step 1: Deploy Infrastructure

Deploy all infrastructure using CloudFormation:

```bash
cd /Users/edoatley/source/aws-notes/data/glue-schema-registry

aws cloudformation deploy \
  --template-file template.yaml \
  --stack-name glue-schema-registry-testbed \
  --capabilities CAPABILITY_NAMED_IAM \
  --region us-east-1 \
  --profile streaming
```

**Note:** The deployment may take 10-15 minutes, as MSK Serverless clusters require time to provision.

#### Get MSK Bootstrap Server String

**Important:** MSK Serverless clusters don't expose `BootstrapServerString` as a CloudFormation attribute. You need to retrieve it using the AWS CLI after the cluster is in `ACTIVE` state.

First, get the MSK cluster ARN from CloudFormation outputs:

```bash
MSK_ARN=$(aws cloudformation describe-stacks \
  --stack-name glue-schema-registry-testbed \
  --region us-east-1 \
  --profile streaming \
  --query 'Stacks[0].Outputs[?OutputKey==`MSKClusterArn`].OutputValue' \
  --output text)

echo "MSK Cluster ARN: $MSK_ARN"
```

Then, wait for the cluster to be in `ACTIVE` state (this can take 10-15 minutes):

```bash
aws kafka describe-cluster-v2 \
  --cluster-arn "$MSK_ARN" \
  --region us-east-1 \
  --query ClusterInfo.State \
  --output text \
  --profile streaming
```

**Note:** MSK Serverless clusters don't support the `describe-cluster` API. Use `describe-cluster-v2` instead. The status should be `ACTIVE` before you can retrieve bootstrap servers.

Once the cluster is `ACTIVE`, retrieve the bootstrap servers:

```bash
# First, see the full response to understand available endpoints
aws kafka get-bootstrap-brokers \
  --cluster-arn $MSK_ARN \
  --region us-east-1 \
  --profile streaming
```

For MSK Serverless with IAM authentication, use the `BootstrapBrokerStringSaslIam` field:

```bash
# Get bootstrap servers (IAM/SASL endpoint - use this for IAM authentication)
BOOTSTRAP_SERVERS=$(aws kafka get-bootstrap-brokers \
  --cluster-arn $MSK_ARN \
  --region us-east-1 \
  --profile streaming \
  --query 'BootstrapBrokerStringSaslIam' \
  --output text)

echo "Bootstrap Servers: $BOOTSTRAP_SERVERS"
```

**Expected Format:** The bootstrap server string will be in the format:
```
boot-xxxxxx.yy.kafka-serverless.us-east-1.amazonaws.com:9098
```

The port `9098` is the TLS port used for IAM-authenticated connections to MSK Serverless.

**Note:** 
- For IAM authentication, always use `BootstrapBrokerStringSaslIam`
- If `BootstrapBrokerStringSaslIam` is not available in the response, check that the cluster is fully `ACTIVE` and IAM authentication is properly configured
- The bootstrap server string already includes the port number - use it as-is in your Kafka client configuration

Save this bootstrap server string - you'll need it for the Kafka producer and consumer applications configured with IAM authentication.

#### Kafka Client Configuration for IAM Authentication

When configuring your Kafka producer and consumer applications to connect to MSK Serverless with IAM authentication, you'll need to set the following properties (as shown in the [AWS blog post](https://aws.amazon.com/blogs/big-data/build-a-secure-serverless-streaming-pipeline-with-amazon-msk-serverless-amazon-emr-serverless-and-iam/)):

**Required Kafka Client Properties:**
- `bootstrap.servers`: Use the bootstrap server string retrieved above (includes port 9098)
- `security.protocol`: `SASL_SSL`
- `sasl.mechanism`: `AWS_MSK_IAM`
- `sasl.jaas.config`: `software.amazon.msk.auth.iam.IAMLoginModule required;`
- `sasl.client.callback.handler.class`: `software.amazon.msk.auth.iam.IAMClientCallbackHandler`

The EC2 instance role (`GlueSchemaRegistryEC2InstanceRole`) already has the necessary IAM permissions for MSK (`kafka-cluster:WriteData`, `kafka-cluster:ReadData`, etc.), so your applications running on the EC2 instance will automatically use IAM authentication without needing additional credentials.

**Note:** For Java applications, you'll need to include the `aws-msk-iam-auth` library in your dependencies. This will be configured in the Gradle project in Epic 2.

Alternatively, get all CloudFormation outputs:

```bash
aws cloudformation describe-stacks \
  --stack-name glue-schema-registry-testbed \
  --region us-east-1 \
  --profile streaming \
  --query 'Stacks[0].Outputs'
```

### Step 2: Connect to the Test Instance

Connect to the EC2 instance using AWS Systems Manager Session Manager:

```bash
# First, get the EC2 instance ID
INSTANCE_ID=$(aws cloudformation describe-stacks \
  --stack-name glue-schema-registry-testbed \
  --region us-east-1 \
  --profile streaming \
  --query 'Stacks[0].Outputs[?OutputKey==`EC2InstanceId`].OutputValue' \
  --output text)

# Connect via SSM
aws ssm start-session \
  --target $INSTANCE_ID \
  --region us-east-1 \
  --profile streaming
```

**Note:** If you get an error, wait a few minutes for the instance to fully initialize and the SSM agent to be ready.

### Step 3: Setup EC2 Host

Once connected to the EC2 instance, verify the environment:

```bash
# Verify Java 11 is installed
java -version
# Should show: openjdk version "11.x.x" (Amazon Corretto)

# Verify Gradle is installed
gradle -v
# Should show Gradle version 8.5

# Verify Git is installed
git --version
```

If any of these are missing, check the UserData logs:

```bash
sudo tail -f /var/log/user-data.log
```

**Troubleshooting Gradle Installation:**

If Gradle is not found, the UserData script may have installed SDKMAN in the root user's home directory (since UserData runs as root). Try these options:

**Option 1: Check if SDKMAN is in root's home directory**
```bash
# Check if SDKMAN was installed for root
sudo ls /root/.sdkman/

# If it exists, source it and check Gradle
sudo -i
source /root/.sdkman/bin/sdkman-init.sh
gradle -v
exit
```

**Option 2: Install SDKMAN for ec2-user (Recommended)**
```bash
# Switch to ec2-user
sudo su - ec2-user

# Install SDKMAN
curl -s "https://get.sdkman.io" | bash
source "$HOME/.sdkman/bin/sdkman-init.sh"

# Install Gradle
sdk install gradle 8.5 -y

# Verify
gradle -v
```

**Option 3: Install SDKMAN for your current user (ssm-user)**
```bash
# Install SDKMAN
curl -s "https://get.sdkman.io" | bash
source "$HOME/.sdkman/bin/sdkman-init.sh"

# Install Gradle
sdk install gradle 8.5 -y

# Verify
gradle -v
```

**Option 4: Use the Gradle wrapper (when project is available)**
If the project includes a Gradle wrapper (`gradlew`), you can use it directly without needing Gradle installed:
```bash
./gradlew build
```

### Step 4: Build Project

*(This step will be completed in Epic 2 when the Java application code is added)*

Once the Gradle project is available, build it:

```bash
cd <project-directory>
./gradlew build
```

Or if using the system Gradle:

```bash
gradle build
```

### Step 5: Run Tests (on EC2)

*(This step will be completed in Epic 2-4 when the test applications are implemented)*

The test applications will be run from the EC2 instance. You'll need to:

1. Open two SSM terminal sessions (one for producer, one for consumer)
2. Run the consumer first in Terminal 1
3. Run the producer in Terminal 2

Example commands (to be updated when code is available):

```bash
# Terminal 1: Consumer
java -jar build/libs/glue-schema-registry-testbed.jar AvroConsumer <msk-bootstrap-servers>

# Terminal 2: Producer
java -jar build/libs/glue-schema-registry-testbed.jar AvroProducer <msk-bootstrap-servers>
```

### Step 6: View Results

After running tests, view results:

1. **Consumer Terminal:** Check for deserialized message output
2. **AWS Glue Console:** Navigate to AWS Glue → Schema Registry → `PaymentSchemaRegistry` to see registered schemas
3. **CloudWatch Logs:** (if logging is configured)

## CRITICAL: Cleanup

**IMPORTANT:** To avoid ongoing charges, destroy all infrastructure immediately after testing:

```bash
aws cloudformation delete-stack \
  --stack-name glue-schema-registry-testbed \
  --region us-east-1 \
  --profile streaming
```

Verify deletion:

```bash
aws cloudformation describe-stacks \
  --stack-name glue-schema-registry-testbed \
  --region us-east-1 \
  --profile streaming
```

This should return an error indicating the stack does not exist.

**Note:** MSK Serverless cluster deletion may take several minutes. Monitor the stack deletion status:

```bash
aws cloudformation describe-stacks \
  --stack-name glue-schema-registry-testbed \
  --region us-east-1 \
  --profile streaming \
  --query 'Stacks[0].StackStatus'
```

## Cost Considerations

This project is designed to minimize costs:

- **VPC Components:** Free (no charges)
- **EC2 t3.micro:** Free Tier eligible (750 hours/month for first 12 months)
- **MSK Serverless:** Pay-per-use, no idle charges
- **Glue Schema Registry:** Free tier (1,000 requests/month)
- **Data Transfer:** Minimal (within same region)

**Target:** Stay under $10 for the entire test.

**Remember:** Always delete the stack after testing to prevent ongoing charges!

## Troubleshooting

### Wrong AWS Profile

If the AWS CLI gives an error like this:

```output
An error occurred (InvalidClientTokenId) when calling the ValidateTemplate operation: The security token included in the request is invalid.
```

it is likely the wrong profile is set. We can fix this as follows:

```bash
unset AWS_ACCESS_KEY_ID
unset AWS_SECRET_ACCESS_KEY
export AWS_PROFILE=streaming     
```

Note the `unset` is required

### Stack Creation Fails

1. Check CloudFormation events:
   ```bash
   aws cloudformation describe-stack-events \
     --stack-name glue-schema-registry-testbed \
     --region us-east-1 \
     --max-items 10
   ```

2. Verify MSK Serverless is available in your region:
   ```bash
   aws kafka list-clusters --region us-east-1
   ```

### Cannot Connect to EC2 Instance

1. Wait 5-10 minutes after stack creation for UserData to complete
2. Verify SSM agent is running:
   ```bash
   aws ssm describe-instance-information \
     --filters "Key=InstanceIds,Values=$INSTANCE_ID" \
     --region us-east-1
   ```
3. Check IAM role has `AmazonSSMManagedInstanceCore` policy attached

### MSK Bootstrap Servers Not Available

MSK Serverless clusters can take 10-15 minutes to become `ACTIVE`. Wait and check:

```bash
# Check cluster status (MSK Serverless uses describe-cluster-v2)
aws kafka describe-cluster-v2 \
  --cluster-arn "$MSK_ARN" \
  --region us-east-1 \
  --profile streaming \
  --query 'ClusterInfo.State' \
  --output text
```

**Note:** MSK Serverless doesn't support `describe-cluster`. Use `describe-cluster-v2` instead.

### Session Manager Plugin Not Found

If you get the error `SessionManagerPlugin is not found`, you need to install the Session Manager plugin:

**macOS:**
```bash
brew install --cask session-manager-plugin
```

**Linux:**
```bash
curl "https://s3.amazonaws.com/session-manager-downloads/plugin/latest/linux_64bit/session-manager-plugin.rpm" -o "session-manager-plugin.rpm"
sudo yum install -y session-manager-plugin.rpm
```

**Verify installation:**
```bash
session-manager-plugin --version
```

For more installation options, see the [AWS Session Manager Plugin documentation](https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-working-with-install-plugin.html).

### Gradle Command Not Found

If you get `bash: gradle: command not found`, the UserData script may have installed SDKMAN in the root user's home directory (since UserData runs as root), or the installation may have failed.

**Check if SDKMAN exists in root's home:**
```bash
sudo ls /root/.sdkman/
```

**If SDKMAN exists in /root, use it:**
```bash
sudo -i
source /root/.sdkman/bin/sdkman-init.sh
gradle -v
exit
```

**If SDKMAN doesn't exist, install it for ec2-user:**
```bash
sudo su - ec2-user
curl -s "https://get.sdkman.io" | bash
source "$HOME/.sdkman/bin/sdkman-init.sh"
sdk install gradle 8.5 -y
gradle -v
```

**Or install for your current user (ssm-user):**
```bash
curl -s "https://get.sdkman.io" | bash
source "$HOME/.sdkman/bin/sdkman-init.sh"
sdk install gradle 8.5 -y
gradle -v
```

**Note:** When the Gradle project is available (Epic 2), you can use the Gradle wrapper (`./gradlew`) which doesn't require Gradle to be in your PATH.

## Next Steps

After Epic 1 (Infrastructure Deployment) is complete:

1. ✅ Infrastructure deployed
2. ✅ MSK Bootstrap Servers retrieved
3. ✅ Connected to EC2 instance
4. ✅ Verified Java 11 and Gradle installation
5. ⏭️ Proceed to Epic 2: AVRO Producer-Consumer Flow

## Additional Resources

- [AWS Glue Schema Registry Documentation](https://docs.aws.amazon.com/glue/latest/dg/schema-registry.html)
- [Amazon MSK Serverless Documentation](https://docs.aws.amazon.com/msk/latest/developerguide/serverless.html)
- [AWS Glue Schema Registry SerDe Library](https://github.com/awslabs/aws-glue-schema-registry)

