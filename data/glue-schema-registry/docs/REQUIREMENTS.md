# Requirements document 
## **Project: AWS Glue Schema Registry Testbed**

### 1. Objective

The primary objective of this project is to build a minimal, low-cost proof-of-concept (PoC) to test and document the core functionalities of the **AWS Glue Schema Registry**. The project will demonstrate schema registration, serialization, and deserialization using a Kafka-based messaging system for both **AVRO** and **JSON Schema** data formats.

This document outlines the requirements for a human developer, with potential collaboration from an AI assistant, to build and document the solution.

### 2. Technology Stack

The project will be built using the following technologies:

* **Infrastructure-as-Code (IaC):** AWS CloudFormation
* **AWS Services:**
    * AWS Glue Schema Registry
    * Amazon MSK Serverless (as the event bus)
    * AWS VPC (for networking)
    * AWS EC2 (t3.micro, as the client test host)
    * AWS IAM (for permissions)
    * AWS Systems Manager (SSM) Session Manager (for secure EC2 access)
* **Orchestration/CLI:** AWS CLI
* **Application:**
    * **Java 11 (Amazon Corretto 11)** (Selected for maximum compatibility with the Glue library)
    * Gradle (for dependency management and building)
    * Kafka Clients
    * AWS Glue Schema Registry SerDe Library (`software.amazon.glue:schema-registry-serde`)

### 3. Cost Constraints

This project must strictly minimize costs, with a target of **staying under $10** for the entire test.

* **AWS Glue Schema Registry:** We will utilize the free tier (1,000 requests/month).
* **Event Bus:** We will use **Amazon MSK Serverless**, which has no idle compute charges.
* **Compute:** We will use a **t3.micro** EC2 instance, which is eligible for the AWS Free Tier.
* **Cleanup:** All infrastructure **must** be destroyed via the CloudFormation stack immediately after testing to prevent ongoing charges.

### 4. Core Infrastructure (via CloudFormation)

A single CloudFormation template (`template.yaml`) shall be created to deploy all resources.

* **VPC and Networking:**
    * 1 x `AWS::EC2::VPC`
    * 2 x `AWS::EC2::Subnet` (in different AZs for MSK)
    * 1 x `AWS::EC2::InternetGateway` and `AWS::EC2::RouteTable` (to allow the EC2 instance to pull dependencies).
* **Security Groups:**
    * 1 x `AWS::EC2::SecurityGroup` for the **MSK Cluster** (`MSK-SG`). It must allow all TCP traffic from the `EC2-SG`.
    * 1 x `AWS::EC2::SecurityGroup` for the **EC2 Instance** (`EC2-SG`). It requires no inbound rules (access via SSM) but needs outbound access (0.0.0.0/0) for setup and Kafka communication.
* **Glue Schema Registry:**
    * 1 x `AWS::Glue::Registry` (e.g., `PaymentSchemaRegistry`)
* **MSK Serverless Cluster:**
    * 1 x `AWS::MSK::ServerlessCluster` configured to use the VPC subnets and the `MSK-SG`.
    * The template must **output** the cluster's **Bootstrap Server string**.
* **IAM Role & Instance Profile:**
    * 1 x `AWS::IAM::Role` (`EC2InstanceRole`) for the EC2 instance, trusted by the EC2 service.
    * The role must have the following AWS-managed policies attached:
        * `AmazonSSMManagedInstanceCore` (for SSM access).
    * The role must have an inline policy granting permissions for:
        * **Glue:** `glue:RegisterSchemaVersion`, `glue:CreateSchema`, `glue:GetSchemaVersion`, `glue:GetSchema`.
        * **MSK:** `kafka-cluster:WriteData`, `kafka-cluster:ReadData`, `kafka-cluster:DescribeCluster`, `kafka:CreateTopic`.
    * 1 x `AWS::IAM::InstanceProfile` to attach this role to the EC2 instance.
* **EC2 Compute Host:**
    * 1 x `AWS::EC2::Instance`
    * **Instance Type:** `t3.micro`
    * **AMI:** Latest Amazon Linux 2023 AMI (SSM Agent is pre-installed).
    * **Instance Profile:** The `EC2InstanceRole` created above.
    * **Security Group:** The `EC2-SG` created above.
    * **Subnet:** One of the public subnets.
    * **UserData Script:** A script that, on boot, installs:
        * `sudo dnf install -y java-11-amazon-corretto-devel`
        * `sudo dnf install -y git`
        * Installs **Gradle** (e.g., via SDKMAN or by downloading the binary).

### 5. Functional Requirements (Test Plan)

The project will be delivered as a single Gradle project with separate runnable classes (e.g., `AvroProducer`, `AvroConsumer`) for each test case.

---

#### **Epic 1: Infrastructure Deployment**
(Corresponds to user step 1)

* **User Story:** As a developer, I want to deploy all required AWS infrastructure by running a single `aws cloudformation deploy` command.

---

#### **Epic 2: AVRO Producer-Consumer Flow**
(Corresponds to user steps 2 & 3)

* **User Story (Producer):** As a producer, I want to send a Java object to a Kafka topic, so that it is automatically serialized and its AVRO schema is registered with the AWS Glue Schema Registry.
    * **Acceptance Criteria:**
        1.  A simple `Payment` AVRO schema (`.avsc`) is defined.
        2.  A Kafka producer app is configured with `GlueSchemaRegistryKafkaSerializer`, `DataFormat.AVRO`, the registry name, and a schema name (e.g., `payment-schema`).
        3.  When run, the app sends 10 messages to a `payments-avro` topic.
        4.  The `payment-schema` appears in the AWS Glue Schema Registry console with Version 1.

* **User Story (Consumer):** As a consumer, I want to read and deserialize messages from the Kafka topic using the AVRO schema from the Glue Registry.
    * **Acceptance Criteria:**
        1.  A Kafka consumer app is configured with `GlueSchemaRegistryKafkaDeserializer`.
        2.  When run, the app subscribes to the `payments-avro` topic.
        3.  The app logs the 10 deserialized Java objects.

---

#### **Epic 3: AVRO Schema Evolution & Error Scenarios**
(Corresponds to user step 4)

* **User Story (Backward Compatibility):** As a developer, I want to evolve the schema in a backward-compatible way and confirm the old consumer is unaffected.
    * **Acceptance Criteria:**
        1.  The `Payment` schema is modified to add a **new, optional field** (e.g., `String description`).
        2.  A `V2` producer sends 10 messages with this new schema. This creates "Version 2" in the registry.
        3.  The *original* `AvroConsumer` (from Epic 2) is run again.
        4.  The `AvroConsumer` successfully reads the 10 "V2" messages, ignoring the new field.

* **User Story (Incompatible Change):** As a developer, I want to test an incompatible schema change to see how the producer fails.
    * **Acceptance Criteria:**
        1.  The `Payment` schema is modified to **rename a required field** (e.g., `amount` to `paymentAmount`).
        2.  A `V3` producer attempts to send a message with this schema.
        3.  The producer *fails* and logs an exception, as the registry's default `BACKWARD` compatibility check rejects this incompatible change.

---

#### **Epic 4: JSON Schema Producer-Consumer Flow**
(Corresponds to user step 5)

* **User Story (JSON Flow):** As a developer, I want to repeat the successful producer/consumer flow using JSON Schema instead of AVRO.
    * **Acceptance Criteria:**
        1.  A `JsonProducer` is created, configured for `DataFormat.JSON`.
        2.  A JSON Schema definition is provided for a simple object (e.g., `SensorReading`).
        3.  The producer sends 10 JSON messages to a `sensors-json` topic. The schema is registered in Glue.
        4.  A `JsonConsumer` is created, configured for `DataFormat.JSON`.
        5.  The consumer successfully reads the 10 messages and logs the deserialized data.

### 6. Documentation (README.md)

The root of the repository must contain a `README.md` file that allows a colleague to replicate the entire test. It must include:

1.  **Objective:** A brief summary of the project.
2.  **Prerequisites:**
    * AWS CLI installed and configured.
    * **AWS SSM Session Manager Plugin** installed.
    * Java 11 (for local development, optional).
    * Git.
3.  **Step-by-Step Instructions:**
    * **Step 1: Deploy Infrastructure:**
        * The `aws cloudformation deploy ...` command.
        * Instructions to get the MSK Bootstrap Server string from the CloudFormation output.
    * **Step 2: Connect to the Test Instance:**
        * The `aws ssm start-session ...` command to connect to the EC2 instance.
    * **Step 3: Setup EC2 Host:**
        * `git clone <your-repo-url>`
        * `cd <your-repo-name>`
        * Verify Java and Gradle are installed (from UserData).
    * **Step 4: Build Project:**
        * `./gradlew build` (or `gradle build` depending on setup).
    * **Step 5: Run Tests (on EC2):**
        * "Open two SSM terminal sessions."
        * **Terminal 1:** Run the consumer: `java -jar ... AvroConsumer <msk-bootstrap-servers>`
        * **Terminal 2:** Run the producer: `java -jar ... AvroProducer <msk-bootstrap-servers>`
        * Provide commands for all other test cases (JSON, errors).
    * **Step 6: View Results:**
        * Instructions on where to look for output (consumer terminal, AWS Glue console).
4.  **CRITICAL: Cleanup:**
    * The exact `aws cloudformation delete-stack` command to destroy all resources.