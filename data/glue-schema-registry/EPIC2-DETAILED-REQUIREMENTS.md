# Epic 2: AVRO Producer-Consumer Flow - Detailed Requirements and Implementation Plan

## Overview

This document provides detailed specifications for Epic 2: AVRO Producer-Consumer Flow. It serves as a developer "to-do" list for implementing a Gradle-based Java application that demonstrates AVRO serialization/deserialization using AWS Glue Schema Registry with Kafka.

**User Story (Producer):** As a producer, I want to send a Java object to a Kafka topic, so that it is automatically serialized and its AVRO schema is registered with the AWS Glue Schema Registry.

**User Story (Consumer):** As a consumer, I want to read and deserialize messages from the Kafka topic using the AVRO schema from the Glue Registry.

---

## 1. Project Structure

The following files and directories must be created at the project root:

```
aws-notes/
└── data/
    └── glue-schema-registry/
        ├── build.gradle (new)
        ├── settings.gradle (new, optional)
        ├── gradle/
        │   └── wrapper/
        │       ├── gradle-wrapper.jar (new)
        │       └── gradle-wrapper.properties (new)
        ├── src/
        │   └── main/
        │       ├── java/
        │       │   └── com/
        │       │       └── example/
        │       │           ├── AvroProducer.java (new)
        │       │           └── AvroConsumer.java (new)
        │       └── avro/
        │           └── Payment.avsc (new)
        ├── README.md (update existing)
        ├── template.yaml (existing)
        └── [other existing files]
```

### 1.1 Files to Create

#### `build.gradle`

- **Location:** `/Users/edoatley/source/aws-notes/data/glue-schema-registry/build.gradle`
- **Purpose:** Gradle build configuration with plugins, dependencies, and build tasks
- **Format:** Groovy DSL

#### `settings.gradle` (optional)

- **Location:** `/Users/edoatley/source/aws-notes/data/glue-schema-registry/settings.gradle`
- **Purpose:** Gradle project settings (project name, etc.)
- **Format:** Groovy DSL

#### `gradle/wrapper/gradle-wrapper.properties`

- **Location:** `/Users/edoatley/source/aws-notes/data/glue-schema-registry/gradle/wrapper/gradle-wrapper.properties`
- **Purpose:** Gradle wrapper configuration
- **Content:** Specify Gradle version 8.5 (to match EC2 installation)

#### `gradle/wrapper/gradle-wrapper.jar`

- **Location:** `/Users/edoatley/source/aws-notes/data/glue-schema-registry/gradle/wrapper/gradle-wrapper.jar`
- **Purpose:** Gradle wrapper executable JAR
- **Note:** Can be generated using `gradle wrapper` command

#### `src/main/java/com/example/AvroProducer.java`

- **Location:** `/Users/edoatley/source/aws-notes/data/glue-schema-registry/src/main/java/com/example/AvroProducer.java`
- **Purpose:** Kafka producer application that serializes Payment objects using AVRO and Glue Schema Registry
- **Package:** `com.example`

#### `src/main/java/com/example/AvroConsumer.java`

- **Location:** `/Users/edoatley/source/aws-notes/data/glue-schema-registry/src/main/java/com/example/AvroConsumer.java`
- **Purpose:** Kafka consumer application that deserializes Payment objects from Kafka using Glue Schema Registry
- **Package:** `com.example`

#### `src/main/avro/Payment.avsc`

- **Location:** `/Users/edoatley/source/aws-notes/data/glue-schema-registry/src/main/avro/Payment.avsc`
- **Purpose:** AVRO schema definition for the Payment record
- **Format:** JSON (AVRO schema format)

---

## 2. build.gradle Configuration

### 2.1 Gradle Plugins

The `build.gradle` file must include the following plugins:

1. **`java`** - Standard Java plugin for compilation and building
2. **`application`** - Application plugin for creating runnable JARs with main class configuration
3. **`com.github.davidmc24.gradle.plugin.avro`** - AVRO plugin for automatic code generation from `.avsc` files

                                                - **Version:** Latest compatible version (e.g., `1.7.1`)
                                                - **Purpose:** Automatically generates Java classes from AVRO schema files during build

**Plugin Declaration Example:**

```groovy
plugins {
    id 'java'
    id 'application'
    id 'com.github.davidmc24.gradle.plugin.avro' version '1.7.1'
}
```

### 2.2 Dependencies

The `build.gradle` file must include the following dependencies in the `dependencies` block:

#### Core Dependencies:

1. **Kafka Clients**

                                                - **Group:** `org.apache.kafka`
                                                - **Artifact:** `kafka-clients`
                                                - **Version:** `3.5.1` (or latest stable compatible with Java 11)
                                                - **Purpose:** Kafka producer and consumer APIs

2. **AWS Glue Schema Registry SerDe**

                                                - **Group:** `software.amazon.glue`
                                                - **Artifact:** `schema-registry-serde`
                                                - **Version:** `1.1.15` (or latest stable)
                                                - **Purpose:** Glue Schema Registry Kafka serializer and deserializer

3. **Apache AVRO**

                                                - **Group:** `org.apache.avro`
                                                - **Artifact:** `avro`
                                                - **Version:** `1.11.3` (or latest compatible with Glue Schema Registry)
                                                - **Purpose:** AVRO serialization library

4. **AWS MSK IAM Auth**

                                                - **Group:** `software.amazon.msk`
                                                - **Artifact:** `aws-msk-iam-auth`
                                                - **Version:** `1.1.9` (or latest)
                                                - **Purpose:** IAM authentication for MSK Serverless

5. **Logging Framework**

                                                - **Group:** `org.slf4j`
                                                - **Artifact:** `slf4j-simple`
                                                - **Version:** `1.7.36` (or latest)
                                                - **Purpose:** Simple logging implementation

#### Dependency Block Example:

```groovy
dependencies {
    implementation 'org.apache.kafka:kafka-clients:3.5.1'
    implementation 'software.amazon.glue:schema-registry-serde:1.1.15'
    implementation 'org.apache.avro:avro:1.11.3'
    implementation 'software.amazon.msk:aws-msk-iam-auth:1.1.9'
    implementation 'org.slf4j:slf4j-simple:1.7.36'
}
```

### 2.3 Additional Build Configuration

#### Java Version:

- **Source Compatibility:** Java 11
- **Target Compatibility:** Java 11

#### Application Plugin Configuration:

- **Main Class:** Not set (will use command-line arguments to select producer or consumer)
- **Alternative:** Use separate main classes or create a launcher class

#### Shadow JAR Plugin (Optional but Recommended):

- **Plugin:** `com.github.johnrengelman.shadow` version `8.1.1`
- **Purpose:** Create a "fat JAR" with all dependencies included
- **Task:** `shadowJar` creates `build/libs/glue-schema-registry-testbed-all.jar`

#### AVRO Plugin Configuration:

- **Source Directory:** `src/main/avro`
- **Output Directory:** `build/generated-main-avro-java` (default)
- **Note:** Generated classes will be in package structure matching the schema namespace

#### Complete build.gradle Structure:

```groovy
plugins {
    id 'java'
    id 'application'
    id 'com.github.davidmc24.gradle.plugin.avro' version '1.7.1'
    id 'com.github.johnrengelman.shadow' version '8.1.1'
}

java {
    sourceCompatibility = JavaVersion.VERSION_11
    targetCompatibility = JavaVersion.VERSION_11
}

repositories {
    mavenCentral()
}

dependencies {
    // [dependencies as listed above]
}

// Shadow JAR configuration
shadowJar {
    archiveBaseName = 'glue-schema-registry-testbed'
    archiveClassifier = 'all'
    mergeServiceFiles()
}

// Application plugin - no default main class (use command-line args)
application {
    mainClass = null  // Or create a launcher class
}
```

---

## 3. AVRO Schema Definition

### 3.1 Payment.avsc File

**Location:** `src/main/avro/Payment.avsc`

**Complete Schema Definition:**

```json
{
  "type": "record",
  "name": "Payment",
  "namespace": "com.example",
  "fields": [
    {
      "name": "paymentId",
      "type": "string"
    },
    {
      "name": "amount",
      "type": "double"
    },
    {
      "name": "timestamp",
      "type": "long"
    }
  ]
}
```

### 3.2 Schema Details

- **Type:** `record` (AVRO record type for structured data)
- **Name:** `Payment` (Java class name will be `Payment`)
- **Namespace:** `com.example` (Java package for generated class)
- **Fields:**
                                - `paymentId` (string): Unique identifier for the payment
                                - `amount` (double): Payment amount
                                - `timestamp` (long): Unix timestamp in milliseconds

### 3.3 Generated Java Class

After running `./gradlew build`, the AVRO plugin will generate:

- **Class:** `com.example.Payment`
- **Location:** `build/generated-main-avro-java/com/example/Payment.java`
- **Usage:** Import and use in producer/consumer code

---

## 4. Java Application Design

### 4.1 AvroProducer.java

#### 4.1.1 Main Method Logic

1. **Command-Line Arguments:**

                                                - `args[0]`: Bootstrap server string (e.g., `boot-xxxxxx.yy.kafka-serverless.us-east-1.amazonaws.com:9098`)
                                                - Validate that at least one argument is provided

2. **Topic Configuration:**

                                                - Topic name: `payments-avro`
                                                - Key type: `String` (simple string keys)
                                                - Value type: `Payment` (AVRO record)

3. **Producer Initialization:**

                                                - Create `Properties` object
                                                - Set all required Kafka and Glue Schema Registry properties
                                                - Create `KafkaProducer<String, Payment>` instance

4. **Message Production:**

                                                - Loop 10 times (send 10 messages)
                                                - For each iteration:
                                                                                - Create a new `Payment` object with:
                                                                                                                - `paymentId`: Unique string (e.g., `"payment-1"`, `"payment-2"`, etc.)
                                                                                                                - `amount`: Random or sequential double value (e.g., `100.50`, `200.75`, etc.)
                                                                                                                - `timestamp`: Current system time in milliseconds (`System.currentTimeMillis()`)
                                                                                - Create `ProducerRecord<String, Payment>` with:
                                                                                                                - Topic: `payments-avro`
                                                                                                                - Key: Payment ID string
                                                                                                                - Value: Payment object
                                                                                - Send record using `producer.send(record)`
                                                                                - Log the sent message (e.g., `"Sent payment: paymentId=payment-1, amount=100.50"`)
                                                                                - Optional: Add small delay between messages (e.g., `Thread.sleep(100)`)

5. **Cleanup:**

                                                - Call `producer.flush()` to ensure all messages are sent
                                                - Call `producer.close()` to close the producer
                                                - Log completion message

#### 4.1.2 Key Kafka Producer Properties

The following properties must be set in the producer configuration:

1. **`ProducerConfig.BOOTSTRAP_SERVERS_CONFIG`**

                                                - Value: Bootstrap server string from `args[0]`
                                                - Purpose: Kafka broker connection endpoint

2. **`ProducerConfig.KEY_SERIALIZER_CLASS_CONFIG`**

                                                - Value: `org.apache.kafka.common.serialization.StringSerializer.class.getName()`
                                                - Purpose: Serialize message keys as strings

3. **`ProducerConfig.VALUE_SERIALIZER_CLASS_CONFIG`**

                                                - Value: `software.amazon.glue.schema.registry.kafka.GlueSchemaRegistryKafkaSerializer.class.getName()`
                                                - Purpose: Use Glue Schema Registry serializer for values

4. **`ProducerConfig.ACKS_CONFIG`**

                                                - Value: `"all"` (optional, for reliability)
                                                - Purpose: Wait for all in-sync replicas to acknowledge

5. **`ProducerConfig.RETRIES_CONFIG`**

                                                - Value: `3` (optional)
                                                - Purpose: Number of retry attempts

#### 4.1.3 Key Glue Schema Registry Properties

The following properties must be set for the Glue Schema Registry serializer:

1. **`AWSSchemaRegistryConstants.AWS_REGION`**

                                                - Value: `"us-east-1"` (or region where infrastructure is deployed)
                                                - Purpose: AWS region for Glue Schema Registry

2. **`AWSSchemaRegistryConstants.DATA_FORMAT`**

                                                - Value: `DataFormat.AVRO.toString()` or `"AVRO"`
                                                - Purpose: Specify AVRO data format

3. **`AWSSchemaRegistryConstants.REGISTRY_NAME`**

                                                - Value: `"PaymentSchemaRegistry"` (matches CloudFormation registry name)
                                                - Purpose: Name of the Glue Schema Registry

4. **`AWSSchemaRegistryConstants.SCHEMA_NAME`**

                                                - Value: `"payment-schema"` (schema name in the registry)
                                                - Purpose: Name of the schema within the registry

5. **`AWSSchemaRegistryConstants.SCHEMA_AUTO_REGISTRATION_SETTING`** (Optional)

                                                - Value: `true` (boolean or string `"true"`)
                                                - Purpose: Automatically register schema if it doesn't exist

6. **`AWSSchemaRegistryConstants.COMPATIBILITY_SETTING`** (Optional)

                                                - Value: `"BACKWARD"` (default)
                                                - Purpose: Schema compatibility mode

#### 4.1.4 MSK IAM Authentication Properties

The following properties must be set for MSK Serverless IAM authentication:

1. **`CommonClientConfigs.SECURITY_PROTOCOL_CONFIG`**

                                                - Value: `"SASL_SSL"`
                                                - Purpose: Use SASL over SSL for IAM authentication

2. **`SaslConfigs.SASL_MECHANISM`**

                                                - Value: `"AWS_MSK_IAM"`
                                                - Purpose: IAM authentication mechanism

3. **`SaslConfigs.SASL_JAAS_CONFIG`**

                                                - Value: `"software.amazon.msk.auth.iam.IAMLoginModule required;"`
                                                - Purpose: JAAS configuration for IAM login module

4. **`SaslConfigs.SASL_CLIENT_CALLBACK_HANDLER_CLASS`**

                                                - Value: `"software.amazon.msk.auth.iam.IAMClientCallbackHandler"`
                                                - Purpose: Callback handler for IAM authentication

#### 4.1.5 Imports Required

- `org.apache.kafka.clients.producer.*`
- `org.apache.kafka.common.config.SaslConfigs`
- `software.amazon.glue.schema.registry.kafka.GlueSchemaRegistryKafkaSerializer`
- `com.amazonaws.services.schemaregistry.common.AWSSchemaRegistryConstants`
- `com.amazonaws.services.schemaregistry.common.configs.DataFormat`
- `com.example.Payment` (generated class)
- `java.util.Properties`
- `java.util.concurrent.Future`
- `org.slf4j.Logger`
- `org.slf4j.LoggerFactory`

### 4.2 AvroConsumer.java

#### 4.2.1 Main Method Logic

1. **Command-Line Arguments:**

                                                - `args[0]`: Bootstrap server string
                                                - Validate that at least one argument is provided

2. **Topic Configuration:**

                                                - Topic name: `payments-avro`
                                                - Subscribe to this topic

3. **Consumer Initialization:**

                                                - Create `Properties` object
                                                - Set all required Kafka and Glue Schema Registry properties
                                                - Create `KafkaConsumer<String, Payment>` instance
                                                - Subscribe to `payments-avro` topic using `consumer.subscribe(Collections.singletonList("payments-avro"))`

4. **Message Consumption Loop:**

                                                - Enter infinite loop (or loop until 10 messages received)
                                                - Call `consumer.poll(Duration.ofSeconds(1))` to poll for records
                                                - For each `ConsumerRecord<String, Payment>` in the poll result:
                                                                                - Extract `Payment` object from `record.value()`
                                                                                - Log the deserialized payment:
                                                                                                                - `"Received payment: paymentId={}, amount={}, timestamp={}"`
                                                                                                                - Use `payment.getPaymentId()`, `payment.getAmount()`, `payment.getTimestamp()`
                                                                                - Increment message counter
                                                                                - If 10 messages received, break from loop

5. **Cleanup:**

                                                - Call `consumer.close()` to close the consumer
                                                - Log completion message

#### 4.2.2 Key Kafka Consumer Properties

The following properties must be set in the consumer configuration:

1. **`ConsumerConfig.BOOTSTRAP_SERVERS_CONFIG`**

                                                - Value: Bootstrap server string from `args[0]`
                                                - Purpose: Kafka broker connection endpoint

2. **`ConsumerConfig.KEY_DESERIALIZER_CLASS_CONFIG`**

                                                - Value: `org.apache.kafka.common.serialization.StringDeserializer.class.getName()`
                                                - Purpose: Deserialize message keys as strings

3. **`ConsumerConfig.VALUE_DESERIALIZER_CLASS_CONFIG`**

                                                - Value: `software.amazon.glue.schema.registry.kafka.GlueSchemaRegistryKafkaDeserializer.class.getName()`
                                                - Purpose: Use Glue Schema Registry deserializer for values

4. **`ConsumerConfig.GROUP_ID_CONFIG`**

                                                - Value: `"payment-consumer-group"` (or any unique group ID)
                                                - Purpose: Consumer group identifier

5. **`ConsumerConfig.AUTO_OFFSET_RESET_CONFIG`**

                                                - Value: `"earliest"`
                                                - Purpose: Start reading from the beginning of the topic if no offset is committed

6. **`ConsumerConfig.ENABLE_AUTO_COMMIT_CONFIG`**

                                                - Value: `true` (optional, default)
                                                - Purpose: Automatically commit offsets

#### 4.2.3 Key Glue Schema Registry Properties

The following properties must be set for the Glue Schema Registry deserializer:

1. **`AWSSchemaRegistryConstants.AWS_REGION`**

                                                - Value: `"us-east-1"` (or region where infrastructure is deployed)
                                                - Purpose: AWS region for Glue Schema Registry

2. **`AWSSchemaRegistryConstants.AVRO_RECORD_TYPE`**

                                                - Value: `"GENERIC_RECORD"` or `"SPECIFIC_RECORD"` (use `"SPECIFIC_RECORD"` for generated classes)
                                                - Purpose: Type of AVRO record to deserialize to

3. **`AWSSchemaRegistryConstants.REGISTRY_NAME`** (Optional, if not auto-detected)

                                                - Value: `"PaymentSchemaRegistry"`
                                                - Purpose: Name of the Glue Schema Registry

#### 4.2.4 MSK IAM Authentication Properties

Same as producer (see section 4.1.4):

- `SECURITY_PROTOCOL_CONFIG`: `"SASL_SSL"`
- `SASL_MECHANISM`: `"AWS_MSK_IAM"`
- `SASL_JAAS_CONFIG`: `"software.amazon.msk.auth.iam.IAMLoginModule required;"`
- `SASL_CLIENT_CALLBACK_HANDLER_CLASS`: `"software.amazon.msk.auth.iam.IAMClientCallbackHandler"`

#### 4.2.5 Imports Required

- `org.apache.kafka.clients.consumer.*`
- `org.apache.kafka.common.config.SaslConfigs`
- `software.amazon.glue.schema.registry.kafka.GlueSchemaRegistryKafkaDeserializer`
- `com.amazonaws.services.schemaregistry.common.AWSSchemaRegistryConstants`
- `com.example.Payment` (generated class)
- `java.util.Properties`
- `java.util.Collections`
- `java.time.Duration`
- `org.slf4j.Logger`
- `org.slf4j.LoggerFactory`

---

## 5. README.md Updates

### 5.1 New Sections to Add

The following sections must be added to the existing `README.md` file:

#### 5.1.1 Section: "Step 4: Build Project" (Update Existing Placeholder)

**Location:** After "Step 3: Setup EC2 Host" section

**Content:**

````markdown
### Step 4: Build Project

Once connected to the EC2 instance, clone the repository and build the project:

```bash
# Clone the repository (if not already cloned)
git clone <your-repo-url>
cd <your-repo-name>/data/glue-schema-registry

# Build the project using Gradle wrapper
./gradlew build shadowJar
````

**What this does:**

- Compiles Java source files
- Generates Java classes from AVRO schema files
- Creates a "fat JAR" with all dependencies at `build/libs/glue-schema-registry-testbed-all.jar`

**Expected Output:**

- Build should complete successfully with `BUILD SUCCESSFUL`
- JAR file should be created at `build/libs/glue-schema-registry-testbed-all.jar`
````

#### 5.1.2 Section: "Step 5: Run AVRO Producer-Consumer Test" (Update Existing Placeholder)

**Location:** Replace existing "Step 5: Run Tests" section

**Content:**
```markdown
### Step 5: Run AVRO Producer-Consumer Test

This test demonstrates AVRO serialization/deserialization using AWS Glue Schema Registry.

**Prerequisites:**
- MSK bootstrap server string (retrieved in Step 1)
- Project built successfully (Step 4)

**Instructions:**

1. **Open two SSM terminal sessions** (one for consumer, one for producer)

2. **Terminal 1: Start the Consumer**
   ```bash
   # Connect to EC2 instance (if not already connected)
   aws ssm start-session --target <EC2_INSTANCE_ID> --region us-east-1 --profile streaming
   
   # Navigate to project directory
   cd <project-directory>/data/glue-schema-registry
   
   # Run the consumer
   java -jar build/libs/glue-schema-registry-testbed-all.jar com.example.AvroConsumer <BOOTSTRAP_SERVERS>
   ```
   
   **Example:**
   ```bash
   java -jar build/libs/glue-schema-registry-testbed-all.jar com.example.AvroConsumer boot-xxxxxx.yy.kafka-serverless.us-east-1.amazonaws.com:9098
   ```
   
   The consumer will start and wait for messages. You should see:
   ```
   Consumer started, waiting for messages...
   ```

3. **Terminal 2: Start the Producer**
   ```bash
   # Connect to EC2 instance in a new terminal
   aws ssm start-session --target <EC2_INSTANCE_ID> --region us-east-1 --profile streaming
   
   # Navigate to project directory
   cd <project-directory>/data/glue-schema-registry
   
   # Run the producer
   java -jar build/libs/glue-schema-registry-testbed-all.jar com.example.AvroProducer <BOOTSTRAP_SERVERS>
   ```
   
   **Example:**
   ```bash
   java -jar build/libs/glue-schema-registry-testbed-all.jar com.example.AvroProducer boot-xxxxxx.yy.kafka-serverless.us-east-1.amazonaws.com:9098
   ```
   
   The producer will send 10 messages and then exit. You should see:
   ```
   Sent payment: paymentId=payment-1, amount=100.50
   Sent payment: paymentId=payment-2, amount=200.75
   ...
   Producer completed. Sent 10 messages.
   ```

4. **Verify Results:**
   - **Terminal 1 (Consumer):** Should display 10 deserialized payment messages:
     ```
     Received payment: paymentId=payment-1, amount=100.50, timestamp=1234567890
     Received payment: paymentId=payment-2, amount=200.75, timestamp=1234567891
     ...
     Consumer completed. Received 10 messages.
     ```
   
   - **AWS Glue Console:** Navigate to AWS Glue → Schema Registry → `PaymentSchemaRegistry` → `payment-schema`
     - You should see Schema Version 1 registered
     - Schema definition should match the `Payment.avsc` file

**Troubleshooting:**
- If consumer doesn't receive messages, ensure producer ran successfully first
- If schema registration fails, verify IAM permissions on EC2 instance role
- If connection fails, verify MSK cluster is in `ACTIVE` state and bootstrap servers are correct
````


#### 5.1.3 Section: "Alternative: Run with Gradle" (Optional)

**Location:** After Step 5

**Content:**

````markdown
### Alternative: Run with Gradle (without building JAR)

Instead of building a JAR, you can run the applications directly with Gradle:

**Producer:**
```bash
./gradlew run --args="com.example.AvroProducer <BOOTSTRAP_SERVERS>"
````

**Consumer:**

```bash
./gradlew run --args="com.example.AvroConsumer <BOOTSTRAP_SERVERS>"
```

**Note:** This requires configuring the `application` plugin with a launcher class, or using a custom run task.

```

### 5.2 Sections to Update

#### 5.2.1 Update "Step 4: Build Project" Section

Replace the placeholder text (lines 264-279) with the detailed build instructions from section 5.1.1 above.

#### 5.2.2 Update "Step 5: Run Tests" Section

Replace the placeholder text (lines 281-299) with the detailed test instructions from section 5.1.2 above.

---

## 6. Implementation Checklist

### 6.1 Project Setup

- [ ] Create `build.gradle` with all required plugins and dependencies
- [ ] Create `settings.gradle` (optional)
- [ ] Generate Gradle wrapper (`gradle wrapper` or include wrapper files)
- [ ] Create directory structure: `src/main/java/com/example/`
- [ ] Create directory structure: `src/main/avro/`

### 6.2 AVRO Schema

- [ ] Create `src/main/avro/Payment.avsc` with complete schema definition
- [ ] Verify schema JSON is valid

### 6.3 Java Applications

- [ ] Implement `AvroProducer.java` with:
                                - [ ] Command-line argument parsing
                                - [ ] Kafka producer configuration (including MSK IAM auth)
                                - [ ] Glue Schema Registry serializer configuration
                                - [ ] Payment object creation and sending logic (10 messages)
                                - [ ] Proper error handling and logging
- [ ] Implement `AvroConsumer.java` with:
                                - [ ] Command-line argument parsing
                                - [ ] Kafka consumer configuration (including MSK IAM auth)
                                - [ ] Glue Schema Registry deserializer configuration
                                - [ ] Topic subscription and polling logic
                                - [ ] Message consumption and logging (10 messages)
                                - [ ] Proper error handling and logging

### 6.4 Build and Test

- [ ] Run `./gradlew build` to verify compilation
- [ ] Verify AVRO classes are generated in `build/generated-main-avro-java/`
- [ ] Run `./gradlew shadowJar` to create fat JAR
- [ ] Verify JAR is created at `build/libs/glue-schema-registry-testbed-all.jar`

### 6.5 Documentation

- [ ] Update README.md with build instructions
- [ ] Update README.md with producer/consumer run commands
- [ ] Add troubleshooting section for common issues

---

## 7. Key Configuration Constants Reference

### 7.1 AWS Glue Schema Registry Constants

**Package:** `com.amazonaws.services.schemaregistry.common.AWSSchemaRegistryConstants`

- `AWS_REGION`: `"aws.region"`
- `DATA_FORMAT`: `"dataFormat"`
- `REGISTRY_NAME`: `"registryName"`
- `SCHEMA_NAME`: `"schemaName"`
- `SCHEMA_AUTO_REGISTRATION_SETTING`: `"schemaAutoRegistrationEnabled"`
- `AVRO_RECORD_TYPE`: `"avroRecordType"`
- `COMPATIBILITY_SETTING`: `"compatibility"`

### 7.2 Kafka Configuration Constants

**Package:** `org.apache.kafka.clients.producer.ProducerConfig` / `org.apache.kafka.clients.consumer.ConsumerConfig`

- `BOOTSTRAP_SERVERS_CONFIG`: `"bootstrap.servers"`
- `KEY_SERIALIZER_CLASS_CONFIG`: `"key.serializer"`
- `VALUE_SERIALIZER_CLASS_CONFIG`: `"value.serializer"`
- `KEY_DESERIALIZER_CLASS_CONFIG`: `"key.deserializer"`
- `VALUE_DESERIALIZER_CLASS_CONFIG`: `"value.deserializer"`
- `GROUP_ID_CONFIG`: `"group.id"`
- `AUTO_OFFSET_RESET_CONFIG`: `"auto.offset.reset"`

### 7.3 MSK IAM Authentication Constants

**Package:** `org.apache.kafka.common.config.SaslConfigs`

- `SASL_MECHANISM`: `"sasl.mechanism"`
- `SASL_JAAS_CONFIG`: `"sasl.jaas.config"`
- `SASL_CLIENT_CALLBACK_HANDLER_CLASS`: `"sasl.client.callback.handler.class"`

**Package:** `org.apache.kafka.common.config.CommonClientConfigs`

- `SECURITY_PROTOCOL_CONFIG`: `"security.protocol"`

---

## 8. Expected Behavior

### 8.1 Producer Execution

1. Producer starts and connects to MSK cluster
2. Producer creates/registers schema in Glue Schema Registry (if auto-registration enabled)
3. Producer sends 10 Payment messages to `payments-avro` topic
4. Each message is serialized using AVRO and schema reference is embedded
5. Producer logs each sent message
6. Producer exits after sending all messages

### 8.2 Consumer Execution

1. Consumer starts and connects to MSK cluster
2. Consumer subscribes to `payments-avro` topic
3. Consumer polls for messages
4. For each message:

                                                - Consumer retrieves schema from Glue Schema Registry (using embedded reference)
                                                - Consumer deserializes message using AVRO schema
                                                - Consumer logs the deserialized Payment object

5. Consumer exits after receiving 10 messages

### 8.3 Schema Registry

1. Schema `payment-schema` is created in registry `PaymentSchemaRegistry`
2. Schema Version 1 is registered automatically by producer
3. Schema definition matches `Payment.avsc` file
4. Consumer retrieves schema version from registry during deserialization

---

## 9. Next Steps After Epic 2

Once Epic 2 is complete and tested:

1. ✅ AVRO producer sends messages with schema registration
2. ✅ AVRO consumer reads and deserializes messages
3. ✅ Schema appears in AWS Glue Schema Registry console
4. ⏭️ Proceed to Epic 3: AVRO Schema Evolution & Error Scenarios

---

## End of Epic 2 Detailed Requirements

This document provides complete specifications for implementing Epic 2. The developer should use this as a checklist when creating the Gradle project and Java applications.