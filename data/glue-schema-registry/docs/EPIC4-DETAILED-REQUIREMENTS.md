# Epic 4: JSON Schema Producer-Consumer Flow - Detailed Requirements

## Overview

This document provides detailed specifications for Epic 4: JSON Schema Producer-Consumer Flow. It serves as a developer "to-do" list for implementing a Java application that demonstrates JSON Schema serialization/deserialization using AWS Glue Schema Registry with Kafka, mirroring the AVRO implementation from Epic 2.

**User Story (JSON Flow):** As a developer, I want to repeat the successful producer/consumer flow using JSON Schema instead of AVRO.

**Acceptance Criteria:**

1. A `JsonProducer` is created, configured for `DataFormat.JSON`.
2. A JSON Schema definition is provided for a simple object (e.g., `SensorReading`).
3. The producer sends 10 JSON messages to a `sensors-json` topic. The schema is registered in Glue.
4. A `JsonConsumer` is created, configured for `DataFormat.JSON`.
5. The consumer successfully reads the 10 messages and logs the deserialized data.

---

## 1. Project Structure

The following files and directories must be created or modified:

```
aws-notes/
└── data/
    └── glue-schema-registry/
        ├── src/
        │   └── main/
        │       ├── java/
        │       │   └── com/
        │       │       └── example/
        │       │           ├── JsonProducer.java (new)
        │       │           ├── JsonConsumer.java (new)
        │       │           └── SensorReading.java (new)
        │       └── resources/
        │           └── schemas/
        │               └── SensorReading.json (new - JSON Schema definition)
        ├── README.md (update existing)
        ├── application.properties.template (update existing or create application-json.properties.template)
        └── [other existing files]
```

### 1.1 Files to Create

#### `src/main/resources/schemas/SensorReading.json`

- **Location:** `/Users/edoatley/source/aws-notes/data/glue-schema-registry/src/main/resources/schemas/SensorReading.json`
- **Purpose:** JSON Schema definition for the SensorReading record
- **Format:** JSON (JSON Schema format, not AVRO)
- **Note:** Unlike AVRO, JSON Schema does not generate Java classes automatically. We'll use POJOs (Plain Old Java Objects) or Map/GenericRecord structures.

#### `src/main/java/com/example/SensorReading.java`

- **Location:** `/Users/edoatley/source/aws-notes/data/glue-schema-registry/src/main/java/com/example/SensorReading.java`
- **Purpose:** Plain Java class (POJO) representing the SensorReading data structure
- **Package:** `com.example`
- **Note:** This is a manually created POJO class, not generated from schema

#### `src/main/java/com/example/JsonProducer.java`

- **Location:** `/Users/edoatley/source/aws-notes/data/glue-schema-registry/src/main/java/com/example/JsonProducer.java`
- **Purpose:** Kafka producer application that serializes SensorReading objects using JSON Schema and Glue Schema Registry
- **Package:** `com.example`

#### `src/main/java/com/example/JsonConsumer.java`

- **Location:** `/Users/edoatley/source/aws-notes/data/glue-schema-registry/src/main/java/com/example/JsonConsumer.java`
- **Purpose:** Kafka consumer application that deserializes SensorReading objects from Kafka using Glue Schema Registry
- **Package:** `com.example`

---

## 2. JSON Schema Definition

### 2.1 SensorReading.json File

**Location:** `src/main/resources/schemas/SensorReading.json`

**Complete Schema Definition:**

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "type": "object",
  "title": "SensorReading",
  "description": "Schema for sensor reading data",
  "properties": {
    "sensorId": {
      "type": "string",
      "description": "Unique identifier for the sensor"
    },
    "temperature": {
      "type": "number",
      "description": "Temperature reading in Celsius"
    },
    "humidity": {
      "type": "number",
      "description": "Humidity reading as percentage"
    },
    "timestamp": {
      "type": "integer",
      "description": "Unix timestamp in milliseconds"
    }
  },
  "required": ["sensorId", "temperature", "humidity", "timestamp"],
  "additionalProperties": false
}
```

### 2.2 Schema Details

- **Type:** `object` (JSON Schema object type)
- **Title:** `SensorReading` (name for the schema)
- **Properties:**
                                - `sensorId` (string): Unique identifier for the sensor
                                - `temperature` (number): Temperature reading in Celsius
                                - `humidity` (number): Humidity reading as percentage
                                - `timestamp` (integer): Unix timestamp in milliseconds
- **Required Fields:** All fields are required
- **Additional Properties:** `false` (strict schema validation)

### 2.3 Differences from AVRO

- **No Code Generation:** JSON Schema does not automatically generate Java classes like AVRO
- **Manual POJO:** We must create a `SensorReading.java` POJO class manually
- **Schema Location:** JSON Schema files are typically stored in `src/main/resources/schemas/` rather than `src/main/avro/`
- **Schema Format:** Uses JSON Schema draft-07 format, not AVRO schema format

---

## 3. Java POJO Class

### 3.1 SensorReading.java

**Location:** `src/main/java/com/example/SensorReading.java`

**Complete Class Definition:**

```java
package com.example;

import com.fasterxml.jackson.annotation.JsonProperty;

public class SensorReading {
    @JsonProperty("sensorId")
    private String sensorId;
    
    @JsonProperty("temperature")
    private Double temperature;
    
    @JsonProperty("humidity")
    private Double humidity;
    
    @JsonProperty("timestamp")
    private Long timestamp;
    
    // Default constructor (required for JSON deserialization)
    public SensorReading() {
    }
    
    // Constructor with all fields
    public SensorReading(String sensorId, Double temperature, Double humidity, Long timestamp) {
        this.sensorId = sensorId;
        this.temperature = temperature;
        this.humidity = humidity;
        this.timestamp = timestamp;
    }
    
    // Getters and setters
    public String getSensorId() {
        return sensorId;
    }
    
    public void setSensorId(String sensorId) {
        this.sensorId = sensorId;
    }
    
    public Double getTemperature() {
        return temperature;
    }
    
    public void setTemperature(Double temperature) {
        this.temperature = temperature;
    }
    
    public Double getHumidity() {
        return humidity;
    }
    
    public void setHumidity(Double humidity) {
        this.humidity = humidity;
    }
    
    public Long getTimestamp() {
        return timestamp;
    }
    
    public void setTimestamp(Long timestamp) {
        this.timestamp = timestamp;
    }
    
    @Override
    public String toString() {
        return String.format("SensorReading{sensorId='%s', temperature=%.2f, humidity=%.2f, timestamp=%d}",
                sensorId, temperature, humidity, timestamp);
    }
}
```

### 3.2 Class Details

- **Package:** `com.example`
- **Annotations:** Uses Jackson `@JsonProperty` for JSON serialization/deserialization
- **Fields:** Match the JSON Schema properties exactly
- **Constructors:** Default constructor required for deserialization
- **Getters/Setters:** Required for Jackson serialization
- **toString():** For logging purposes

### 3.3 Dependencies

The project will need Jackson library for JSON processing (if not already included):

- `com.fasterxml.jackson.core:jackson-databind` (for POJO serialization)
- Jackson is typically already included in the Glue Schema Registry SerDe library

---

## 4. Java Application Design

### 4.1 JsonProducer.java

#### 4.1.1 Main Method Logic

1. **Command-Line Arguments:**

                                                - `args[0]`: Properties file path (e.g., `application-json.properties`)
                                                - `args[1]`: Optional bootstrap server string override
                                                - Validate that at least one argument is provided

2. **Topic Configuration:**

                                                - Topic name: `sensors-json` (different from AVRO topic)
                                                - Key type: `String`
                                                - Value type: `SensorReading` (POJO)

3. **Producer Initialization:**

                                                - Create `Properties` object
                                                - Load properties from file (same pattern as `AvroProducer.java`)
                                                - Set all required Kafka and Glue Schema Registry properties
                                                - **Important:** Set `DATA_FORMAT` to `"JSON"` instead of `"AVRO"`
                                                - **Important:** Use schema name `sensor-schema` (different from `payment-schema`)
                                                - Create `KafkaProducer<String, SensorReading>` instance

4. **Schema Registration:**

                                                - Load JSON Schema from `src/main/resources/schemas/SensorReading.json`
                                                - Register schema with Glue Schema Registry (or rely on auto-registration)
                                                - **Note:** Schema can be loaded as a string from the JSON file

5. **Message Production:**

                                                - Loop 10 times (send 10 messages)
                                                - For each iteration:
                                                                                - Create a new `SensorReading` object with:
                                                                                                                - `sensorId`: Unique string (e.g., `"sensor-1"`, `"sensor-2"`, etc.)
                                                                                                                - `temperature`: Random or sequential double value (e.g., `22.5`, `23.1`, etc.)
                                                                                                                - `humidity`: Random or sequential double value (e.g., `45.0`, `46.5`, etc.)
                                                                                                                - `timestamp`: Current system time in milliseconds
                                                                                - Create `ProducerRecord<String, SensorReading>` with:
                                                                                                                - Topic: `sensors-json`
                                                                                                                - Key: Sensor ID string
                                                                                                                - Value: SensorReading object
                                                                                - Send record using `producer.send(record)`
                                                                                - Log the sent message (e.g., `"Sent sensor reading: sensorId=sensor-1, temperature=22.5, humidity=45.0"`)
                                                                                - Optional: Add small delay between messages

6. **Cleanup:**

                                                - Call `producer.flush()` to ensure all messages are sent
                                                - Call `producer.close()` to close the producer
                                                - Log completion message

#### 4.1.2 Key Configuration Properties

**Kafka Producer Properties (same as AVRO):**

- `BOOTSTRAP_SERVERS_CONFIG`: Bootstrap server string
- `KEY_SERIALIZER_CLASS_CONFIG`: `StringSerializer`
- `VALUE_SERIALIZER_CLASS_CONFIG`: `GlueSchemaRegistryKafkaSerializer`
- MSK IAM authentication properties (same as AVRO)

**Glue Schema Registry Properties (JSON-specific):**

- `AWSSchemaRegistryConstants.AWS_REGION`: `"us-east-1"`
- `AWSSchemaRegistryConstants.DATA_FORMAT`: `DataFormat.JSON.toString()` or `"JSON"` (KEY DIFFERENCE)
- `AWSSchemaRegistryConstants.REGISTRY_NAME`: `"PaymentSchemaRegistry"` (same registry as AVRO)
- `AWSSchemaRegistryConstants.SCHEMA_NAME`: `"sensor-schema"` (different schema name)
- `AWSSchemaRegistryConstants.SCHEMA_AUTO_REGISTRATION_SETTING`: `true`
- `AWSSchemaRegistryConstants.COMPATIBILITY_SETTING`: `"BACKWARD"` (optional)

**Schema Loading:**

- Load JSON Schema from classpath: `src/main/resources/schemas/SensorReading.json`
- Read schema as string for registration
- Use `ClassLoader.getResourceAsStream()` to load schema file

#### 4.1.3 Imports Required

- `org.apache.kafka.clients.producer.*`
- `org.apache.kafka.clients.admin.*` (for topic creation)
- `org.apache.kafka.common.config.SaslConfigs`
- `org.apache.kafka.clients.CommonClientConfigs`
- `com.amazonaws.services.schemaregistry.serializers.GlueSchemaRegistryKafkaSerializer`
- `com.amazonaws.services.schemaregistry.common.AWSSchemaRegistryConstants`
- `com.amazonaws.services.schemaregistry.common.configs.DataFormat`
- `com.example.SensorReading`
- `java.io.InputStream`
- `java.nio.charset.StandardCharsets`
- `java.util.Properties`
- `org.slf4j.Logger`
- `org.slf4j.LoggerFactory`

### 4.2 JsonConsumer.java

#### 4.2.1 Main Method Logic

1. **Command-Line Arguments:**

                                                - `args[0]`: Properties file path (e.g., `application-json.properties`)
                                                - `args[1]`: Optional bootstrap server string override
                                                - Validate that at least one argument is provided

2. **Topic Configuration:**

                                                - Topic name: `sensors-json`
                                                - Subscribe to this topic

3. **Consumer Initialization:**

                                                - Create `Properties` object
                                                - Load properties from file
                                                - Set all required Kafka and Glue Schema Registry properties
                                                - **Important:** Set `DATA_FORMAT` to `"JSON"`
                                                - Create `KafkaConsumer<String, SensorReading>` instance
                                                - Subscribe to `sensors-json` topic

4. **Message Consumption Loop:**

                                                - Enter loop until 10 messages received
                                                - Call `consumer.poll(Duration.ofSeconds(1))` to poll for records
                                                - For each `ConsumerRecord<String, SensorReading>` in the poll result:
                                                                                - Extract `SensorReading` object from `record.value()`
                                                                                - Log the deserialized sensor reading:
                                                                                                                - `"Received sensor reading: sensorId={}, temperature={}, humidity={}, timestamp={}"`
                                                                                                                - Use getter methods: `sensorReading.getSensorId()`, `getTemperature()`, etc.
                                                                                - Increment message counter
                                                                                - If 10 messages received, break from loop

5. **Cleanup:**

                                                - Call `consumer.close()` to close the consumer
                                                - Log completion message

#### 4.2.2 Key Configuration Properties

**Kafka Consumer Properties (same as AVRO):**

- `BOOTSTRAP_SERVERS_CONFIG`: Bootstrap server string
- `KEY_DESERIALIZER_CLASS_CONFIG`: `StringDeserializer`
- `VALUE_DESERIALIZER_CLASS_CONFIG`: `GlueSchemaRegistryKafkaDeserializer`
- `GROUP_ID_CONFIG`: `"sensor-consumer-group"` (different from AVRO group)
- `AUTO_OFFSET_RESET_CONFIG`: `"earliest"`
- MSK IAM authentication properties (same as AVRO)

**Glue Schema Registry Properties (JSON-specific):**

- `AWSSchemaRegistryConstants.AWS_REGION`: `"us-east-1"`
- `AWSSchemaRegistryConstants.DATA_FORMAT`: `"JSON"` (KEY DIFFERENCE)
- `AWSSchemaRegistryConstants.REGISTRY_NAME`: `"PaymentSchemaRegistry"` (same registry)
- **Note:** JSON Schema deserialization does not require `AVRO_RECORD_TYPE` (that's AVRO-specific)

#### 4.2.3 Imports Required

- `org.apache.kafka.clients.consumer.*`
- `org.apache.kafka.common.config.SaslConfigs`
- `org.apache.kafka.clients.CommonClientConfigs`
- `com.amazonaws.services.schemaregistry.deserializers.GlueSchemaRegistryKafkaDeserializer`
- `com.amazonaws.services.schemaregistry.common.AWSSchemaRegistryConstants`
- `com.example.SensorReading`
- `java.io.FileInputStream`
- `java.io.IOException`
- `java.io.InputStream`
- `java.time.Duration`
- `java.util.Collections`
- `java.util.Properties`
- `org.slf4j.Logger`
- `org.slf4j.LoggerFactory`

---

## 5. Application Properties Configuration

### 5.1 Properties File Structure

The `application.properties` file should support both AVRO and JSON configurations. Options:

**Option A: Separate Properties Files**

- `application.properties` (for AVRO)
- `application-json.properties` (for JSON)

**Option B: Single Properties File with Comments**

- Keep single `application.properties` with sections for AVRO and JSON
- Users comment/uncomment relevant sections

**Option C: Override via Command Line**

- Use same `application.properties` but override `data.format` and `schema.name` via command line

**Recommended:** Option A (separate files) for clarity, but support both.

### 5.2 JSON-Specific Properties

Create `application-json.properties`:

```properties
# AWS Glue Schema Registry Configuration (JSON)
# Copy this file to application-json.properties and update with your values

# MSK Configuration
bootstrap.servers=boot-xxxxxx.yy.kafka-serverless.us-east-1.amazonaws.com:9098

# AWS Region
aws.region=us-east-1

# Glue Schema Registry Configuration (JSON)
registry.name=PaymentSchemaRegistry
schema.name=sensor-schema
data.format=JSON
schema.auto.registration.enabled=true
compatibility=BACKWARD

# Consumer-specific
consumer.group.id=sensor-consumer-group

# MSK IAM Authentication
security.protocol=SASL_SSL
sasl.mechanism=AWS_MSK_IAM
sasl.jaas.config=software.amazon.msk.auth.iam.IAMLoginModule required;
sasl.client.callback.handler.class=software.amazon.msk.auth.iam.IAMClientCallbackHandler
```

### 5.3 Key Differences from AVRO Properties

- `data.format=JSON` (instead of `AVRO`)
- `schema.name=sensor-schema` (instead of `payment-schema`)
- `consumer.group.id=sensor-consumer-group` (instead of `payment-consumer-group`)
- No `avro.record.type` property (AVRO-specific)

---

## 6. Build Configuration Updates

### 6.1 build.gradle Dependencies

Verify that the following dependencies are present (they should already be in `build.gradle` from Epic 2):

- `org.apache.kafka:kafka-clients:3.5.1`
- `software.amazon.glue:schema-registry-serde:1.1.15`
- `software.amazon.msk:aws-msk-iam-auth:1.1.9`
- `org.slf4j:slf4j-simple:1.7.36`

**Additional Dependency (if not already included):**

- `com.fasterxml.jackson.core:jackson-databind:2.15.2` (or latest compatible)
                                - **Note:** This may already be a transitive dependency of the Glue Schema Registry library

### 6.2 No Code Generation Needed

Unlike AVRO, JSON Schema does not require:

- AVRO Gradle plugin
- Code generation tasks
- Generated Java classes

The `SensorReading.java` class is manually created.

---

## 7. Test Procedures

### 7.1 Prerequisites

- Infrastructure deployed (Epic 1)
- Epic 2 and Epic 3 completed (optional, but good for comparison)
- Project built successfully
- MSK bootstrap server string available

### 7.2 Test Procedure

**Step 1: Create Topic (First Run Only)**

```bash
# Connect to EC2 instance
aws ssm start-session --target <EC2_INSTANCE_ID> --region us-east-1 --profile streaming

# Navigate to project directory
cd ~/aws-notes/data/glue-schema-registry

# Create the topic (if CreateTopic utility supports JSON topic)
java -cp build/libs/glue-schema-registry-testbed-all.jar com.example.CreateTopic application-json.properties
```

**Step 2: Setup Properties File**

```bash
# Copy template and create JSON-specific properties
cp application.properties.template application-json.properties

# Edit the file
nano application-json.properties
```

Update with:

- `bootstrap.servers=<your-msk-bootstrap-servers>`
- `data.format=JSON`
- `schema.name=sensor-schema`
- `consumer.group.id=sensor-consumer-group`

**Step 3: Start Consumer**

```bash
# Terminal 1: Start consumer
java -cp build/libs/glue-schema-registry-testbed-all.jar com.example.JsonConsumer application-json.properties
```

Consumer should start and wait for messages.

**Step 4: Start Producer**

```bash
# Terminal 2: Start producer
java -cp build/libs/glue-schema-registry-testbed-all.jar com.example.JsonProducer application-json.properties
```

Producer should send 10 messages and exit.

**Step 5: Verify Results**

- **Consumer Terminal:** Should display 10 deserialized sensor readings
- **AWS Glue Console:** Navigate to `PaymentSchemaRegistry` → `sensor-schema`
                                - Schema Version 1 should be registered
                                - Schema definition should match `SensorReading.json`

---

## 8. README.md Updates

### 8.1 New Section: "Step 7: Run JSON Schema Producer-Consumer Test"

**Location:** After "Step 6: Run AVRO Schema Evolution Tests" section

**Complete Content:**

````markdown
### Step 7: Run JSON Schema Producer-Consumer Test

This test demonstrates JSON Schema serialization/deserialization using AWS Glue Schema Registry.

**Prerequisites:**
- MSK bootstrap server string (retrieved in Step 1)
- Project built successfully (Step 4)
- Epic 4 code implemented (JsonProducer, JsonConsumer, SensorReading POJO, SensorReading.json schema)

**Setup Properties File:**

Create a JSON-specific properties file with your configuration values:

```bash
# Copy the template
cp application.properties.template application-json.properties

# Edit the file with your values
nano application-json.properties  # or use vi, vim, etc.
```

Update the properties in `application-json.properties` with your MSK bootstrap server string and JSON-specific settings:

```properties
bootstrap.servers=boot-xxxxxx.yy.kafka-serverless.us-east-1.amazonaws.com:9098
aws.region=us-east-1
registry.name=PaymentSchemaRegistry
schema.name=sensor-schema
data.format=JSON
schema.auto.registration.enabled=true
compatibility=BACKWARD
consumer.group.id=sensor-consumer-group
security.protocol=SASL_SSL
sasl.mechanism=AWS_MSK_IAM
sasl.jaas.config=software.amazon.msk.auth.iam.IAMLoginModule required;
sasl.client.callback.handler.class=software.amazon.msk.auth.iam.IAMClientCallbackHandler
```

**Key Differences from AVRO Properties:**
- `data.format=JSON` (instead of `AVRO`)
- `schema.name=sensor-schema` (instead of `payment-schema`)
- `consumer.group.id=sensor-consumer-group` (instead of `payment-consumer-group`)
- No `avro.record.type` property (AVRO-specific)

**Note:** The `application-json.properties` file contains all necessary configuration for JSON Schema. The applications will read from this file.

**Instructions:**

**Important:** The topic `sensors-json` must exist before messages can be sent or consumed. The producer will automatically create the topic, but for the first run, it's recommended to create it explicitly.

**Procedure Using tmux (Recommended - More Stable):**

Using `tmux` in a single SSM session is more stable than trying to maintain two separate SSM sessions. Here's how to do it:

1. **Connect to EC2 and Start tmux:**
   ```bash
   # Connect to EC2 instance
   aws ssm start-session --target <EC2_INSTANCE_ID> --region us-east-1 --profile streaming
   
   # Switch to ec2-user
   bash
   sudo su - ec2-user
   
   # Install tmux if not already installed
   sudo dnf install -y tmux
   
   # Navigate to project directory
   cd ~/aws-notes/data/glue-schema-registry
   
   # Start tmux
   tmux
   ```

2. **Split the tmux window into two panes:**
   - Press `Ctrl+b` (release both keys), then press `"` (double quote) to split horizontally
   - **On Mac:** You may need to press `Shift+"` to get the double quote character
   - You'll now have two panes: top and bottom

3. **Navigate between panes:**
   - Press `Ctrl+b` then arrow keys to switch between panes
   - Or: `Ctrl+b` then `o` to cycle through panes

4. **Top Pane - Create the Topic (First Run Only):**
   ```bash
   # Make sure you're in the project directory
   cd ~/aws-notes/data/glue-schema-registry
   
   # Create the topic
   java -cp build/libs/glue-schema-registry-testbed-all.jar com.example.CreateTopic application-json.properties
   ```
   
   **Note:** The producer will also create the topic automatically if it doesn't exist, but creating it first ensures it's ready before starting the consumer.

5. **Top Pane - Start the Consumer:**
   ```bash
   # Make sure you're in the project directory
   cd ~/aws-notes/data/glue-schema-registry
   
   # Start the consumer
   java -cp build/libs/glue-schema-registry-testbed-all.jar com.example.JsonConsumer application-json.properties
   ```
   
   **Optional:** You can override bootstrap servers if needed:
   ```bash
   java -cp build/libs/glue-schema-registry-testbed-all.jar com.example.JsonConsumer application-json.properties boot-xxxxxx.yy.kafka-serverless.us-east-1.amazonaws.com:9098
   ```
   
   The consumer will start and wait for messages. You should see:
   ```
   Consumer started, waiting for messages...
   ```

6. **Bottom Pane - Start the Producer:**
   - Switch to the bottom pane (Ctrl+b then down arrow)
   ```bash
   # Make sure you're in the project directory
   cd ~/aws-notes/data/glue-schema-registry
   
   # Run the producer (it will create the topic automatically if it doesn't exist)
   java -cp build/libs/glue-schema-registry-testbed-all.jar com.example.JsonProducer application-json.properties
   ```
   
   **Optional:** You can override bootstrap servers if needed:
   ```bash
   java -cp build/libs/glue-schema-registry-testbed-all.jar com.example.JsonProducer application-json.properties boot-xxxxxx.yy.kafka-serverless.us-east-1.amazonaws.com:9098
   ```
   
   The producer will send 10 messages and then exit. You should see:
   ```
   Sent sensor reading: sensorId=sensor-1, temperature=22.5, humidity=45.0, timestamp=1234567890
   Sent sensor reading: sensorId=sensor-2, temperature=23.1, humidity=46.5, timestamp=1234567891
   ...
   Producer completed. Sent 10 messages.
   ```

**Useful tmux Commands:**
- `Ctrl+b` then `"` (or `Shift+"` on Mac) - Split pane horizontally
- `Ctrl+b` then `%` (or `Shift+5` on Mac) - Split pane vertically
- `Ctrl+b` then arrow keys - Navigate between panes
- `Ctrl+b` then `x` - Close current pane (after confirming)
- `Ctrl+b` then `d` - Detach from tmux (sessions keep running)
- `tmux attach` - Reattach to existing tmux session
- `Ctrl+b` then `z` - Zoom/unzoom current pane (full screen toggle)

**Alternative: Using Two Separate SSM Sessions**

If you prefer separate terminals (though less stable with SSM):

1. **Terminal 1: Create the Topic (First Run Only)**
   ```bash
   # Connect to EC2 instance
   aws ssm start-session --target <EC2_INSTANCE_ID> --region us-east-1 --profile streaming
   
   # Navigate to project directory
   cd ~/aws-notes/data/glue-schema-registry
   
   # Create the topic
   java -cp build/libs/glue-schema-registry-testbed-all.jar com.example.CreateTopic application-json.properties
   ```

2. **Terminal 1: Start the Consumer** (after topic exists)
   ```bash
   # Connect to EC2 instance (if not already connected)
   aws ssm start-session --target <EC2_INSTANCE_ID> --region us-east-1 --profile streaming
   
   # Navigate to project directory
   cd ~/aws-notes/data/glue-schema-registry
   
   # Run the consumer (using properties file)
   java -cp build/libs/glue-schema-registry-testbed-all.jar com.example.JsonConsumer application-json.properties
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
   cd ~/aws-notes/data/glue-schema-registry
   
   # Run the producer (it will create the topic automatically if it doesn't exist)
   java -cp build/libs/glue-schema-registry-testbed-all.jar com.example.JsonProducer application-json.properties
   ```
   
   The producer will send 10 messages and then exit.

4. **Verify Results:**
   - **Terminal 1 (Consumer):** Should display 10 deserialized sensor reading messages:
     ```
     Received sensor reading: sensorId=sensor-1, temperature=22.5, humidity=45.0, timestamp=1234567890
     Received sensor reading: sensorId=sensor-2, temperature=23.1, humidity=46.5, timestamp=1234567891
     ...
     Consumer completed. Received 10 messages.
     ```
   
   - **AWS Glue Console:** Navigate to AWS Glue → Schema Registry → `PaymentSchemaRegistry` → `sensor-schema`
     - You should see Schema Version 1 registered
     - Schema definition should match the `SensorReading.json` file
     - Verify the schema shows JSON Schema format (not AVRO)

**Expected Behavior:**
- JSON producer successfully sends 10 messages with sensor reading data
- Schema Version 1 is registered in Glue Schema Registry with JSON Schema format
- JSON consumer successfully reads all 10 messages and deserializes them correctly
- Consumer logs show all fields: `sensorId`, `temperature`, `humidity`, `timestamp`
- Schema appears in Glue console with JSON Schema structure

**Troubleshooting:**
- If consumer doesn't receive messages, ensure producer ran successfully first
- If schema registration fails, verify IAM permissions on EC2 instance role
- If connection fails, verify MSK cluster is in `ACTIVE` state and bootstrap servers are correct
- If you see `UNKNOWN_TOPIC_OR_PARTITION`, create the topic first using `CreateTopic` utility
- If you see `AccessDeniedException` for Glue operations, wait 30-60 seconds after stack update for IAM permissions to propagate
- If deserialization fails, verify that `SensorReading.java` POJO class matches the JSON Schema structure exactly
- If you see JSON parsing errors, verify the JSON Schema file is valid and properly formatted
- If properties file is not found, ensure you're using `application-json.properties` (not `application.properties`)
````

### 8.2 Update "Next Steps" Section

**Location:** Update the "Next Steps" section at the end of README.md

**Content:**

```markdown
## Next Steps

Epic 1 (Infrastructure Deployment), Epic 2 (AVRO Producer-Consumer Flow), Epic 3 (AVRO Schema Evolution & Error Scenarios), and Epic 4 (JSON Schema Producer-Consumer Flow) are complete:

1. ✅ Infrastructure deployed
2. ✅ MSK Bootstrap Servers retrieved
3. ✅ Connected to EC2 instance
4. ✅ Verified Java 11 and Gradle installation
5. ✅ AVRO Producer-Consumer Flow implemented and tested
6. ✅ Glue Schema Registry integration working
7. ✅ End-to-end message flow validated
8. ✅ Backward compatibility testing (optional field addition)
9. ✅ Incompatible change rejection testing (field renaming)
10. ✅ JSON Schema Producer-Consumer Flow implemented and tested
11. ✅ JSON Schema serialization/deserialization validated

**Future enhancements:**
- JSON Schema evolution scenarios (similar to Epic 3)
- Performance benchmarking (AVRO vs JSON Schema)
- Multi-region schema replication testing
- Additional schema formats (Protobuf, etc.)
```