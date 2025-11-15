# Epic 3: AVRO Schema Evolution & Error Scenarios - Detailed Requirements

## Overview

This document provides detailed specifications for Epic 3: AVRO Schema Evolution & Error Scenarios. It serves as a developer "to-do" list for implementing schema evolution tests that demonstrate backward compatibility and incompatible schema changes using AWS Glue Schema Registry.

**User Story (Backward Compatibility):** As a developer, I want to evolve the schema in a backward-compatible way and confirm the old consumer is unaffected.

**User Story (Incompatible Change):** As a developer, I want to test an incompatible schema change to see how the producer fails.

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
        │       │           ├── AvroProducer.java (existing)
        │       │           ├── AvroConsumer.java (existing)
        │       │           ├── AvroProducerV2.java (new)
        │       │           └── AvroProducerV3.java (new)
        │       └── avro/
        │           ├── Payment.avsc (existing - V1)
        │           ├── PaymentV2.avsc (new - for backward compatibility test)
        │           └── PaymentV3.avsc (new - for incompatible change test)
        ├── README.md (update existing)
        └── [other existing files]
```

### 1.1 Files to Create

#### `src/main/avro/PaymentV2.avsc`

- **Location:** `/Users/edoatley/source/aws-notes/data/glue-schema-registry/src/main/avro/PaymentV2.avsc`
- **Purpose:** AVRO schema definition for Payment record with backward-compatible change (added optional field)
- **Format:** JSON (AVRO schema format)
- **Note:** This schema will be used by `AvroProducerV2.java` to test backward compatibility

#### `src/main/avro/PaymentV3.avsc`

- **Location:** `/Users/edoatley/source/aws-notes/data/glue-schema-registry/src/main/avro/PaymentV3.avsc`
- **Purpose:** AVRO schema definition for Payment record with incompatible change (renamed required field)
- **Format:** JSON (AVRO schema format)
- **Note:** This schema will be used by `AvroProducerV3.java` to test incompatible change rejection

#### `src/main/java/com/example/AvroProducerV2.java`

- **Location:** `/Users/edoatley/source/aws-notes/data/glue-schema-registry/src/main/java/com/example/AvroProducerV2.java`
- **Purpose:** Kafka producer application that uses PaymentV2 schema (with optional description field) to test backward compatibility
- **Package:** `com.example`

#### `src/main/java/com/example/AvroProducerV3.java`

- **Location:** `/Users/edoatley/source/aws-notes/data/glue-schema-registry/src/main/java/com/example/AvroProducerV3.java`
- **Purpose:** Kafka producer application that uses PaymentV3 schema (with renamed field) to test incompatible change rejection
- **Package:** `com.example`

---

## 2. Schema Definitions

### 2.1 PaymentV2.avsc (Backward Compatible Schema)

**Location:** `src/main/avro/PaymentV2.avsc`

**Complete Schema Definition:**

```json
{
  "type": "record",
  "name": "PaymentV2",
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
    },
    {
      "name": "description",
      "type": ["null", "string"],
      "default": null
    }
  ]
}
```

**Schema Details:**

- **Type:** `record` (AVRO record type)
- **Name:** `PaymentV2` (Java class name will be `PaymentV2`)
- **Namespace:** `com.example` (Java package for generated class)
- **Fields:**
                                - `paymentId` (string): Unique identifier for the payment (unchanged from V1)
                                - `amount` (double): Payment amount (unchanged from V1)
                                - `timestamp` (long): Unix timestamp in milliseconds (unchanged from V1)
                                - `description` (union of null and string, default: null): **NEW OPTIONAL FIELD** - Description of the payment

**Backward Compatibility Rationale:**

- Adding a new optional field with a default value is a backward-compatible change
- Old consumers (using V1 schema) can read V2 messages because:
                                - All V1 fields (`paymentId`, `amount`, `timestamp`) remain unchanged
                                - The new `description` field is optional (union with null) and has a default value
                                - AVRO deserialization will ignore the new field when reading with the old schema

**Generated Java Class:**

After running `./gradlew build`, the AVRO plugin will generate:

- **Class:** `com.example.PaymentV2`
- **Location:** `build/generated-main-avro-java/com/example/PaymentV2.java`
- **Usage:** Import and use in `AvroProducerV2.java`

### 2.2 PaymentV3.avsc (Incompatible Schema)

**Location:** `src/main/avro/PaymentV3.avsc`

**Complete Schema Definition:**

```json
{
  "type": "record",
  "name": "PaymentV3",
  "namespace": "com.example",
  "fields": [
    {
      "name": "paymentId",
      "type": "string"
    },
    {
      "name": "paymentAmount",
      "type": "double"
    },
    {
      "name": "timestamp",
      "type": "long"
    }
  ]
}
```

**Schema Details:**

- **Type:** `record` (AVRO record type)
- **Name:** `PaymentV3` (Java class name will be `PaymentV3`)
- **Namespace:** `com.example` (Java package for generated class)
- **Fields:**
                                - `paymentId` (string): Unique identifier for the payment (unchanged from V1)
                                - `paymentAmount` (double): Payment amount (**RENAMED from `amount` to `paymentAmount`**)
                                - `timestamp` (long): Unix timestamp in milliseconds (unchanged from V1)

**Incompatibility Rationale:**

- Renaming a required field (`amount` → `paymentAmount`) is an **incompatible change** under `BACKWARD` compatibility mode
- The Glue Schema Registry with `BACKWARD` compatibility requires that:
                                - New schema versions can read data written with old schema versions
                                - Renaming a required field breaks this because old consumers expect `amount`, not `paymentAmount`
- The registry will reject this schema version registration with a compatibility error

**Generated Java Class:**

After running `./gradlew build`, the AVRO plugin will generate:

- **Class:** `com.example.PaymentV3`
- **Location:** `build/generated-main-avro-java/com/example/PaymentV3.java`
- **Usage:** Import and use in `AvroProducerV3.java`

---

## 3. Java Application Design

### 3.1 AvroProducerV2.java

#### 3.1.1 Purpose

`AvroProducerV2.java` sends messages using the `PaymentV2` schema (with optional `description` field) to test backward compatibility. This producer will:

1. Register Schema Version 2 in the Glue Schema Registry
2. Send 10 messages with the new schema (including the optional `description` field)
3. Verify that the original `AvroConsumer` (using V1 schema) can still read these messages

#### 3.1.2 Main Method Logic

1. **Command-Line Arguments:**

                                                - `args[0]`: Properties file path (e.g., `application.properties`)
                                                - `args[1]`: Optional bootstrap server string override
                                                - Validate that at least one argument is provided

2. **Topic Configuration:**

                                                - Topic name: `payments-avro` (same topic as V1 producer)
                                                - Key type: `String`
                                                - Value type: `PaymentV2` (AVRO record with optional description field)

3. **Producer Initialization:**

                                                - Create `Properties` object
                                                - Load properties from file (same as `AvroProducer.java`)
                                                - Set all required Kafka and Glue Schema Registry properties
                                                - **Important:** Use the same `registryName` and `schemaName` as V1 (`PaymentSchemaRegistry` and `payment-schema`)
                                                - Set `compatibility` to `BACKWARD` (default, but explicit for clarity)
                                                - Create `KafkaProducer<String, PaymentV2>` instance

4. **Message Production:**

                                                - Loop 10 times (send 10 messages)
                                                - For each iteration:
                                                                                - Create a new `PaymentV2` object with:
                                                                                                                - `paymentId`: Unique string (e.g., `"payment-v2-1"`, `"payment-v2-2"`, etc.)
                                                                                                                - `amount`: Sequential double value (e.g., `150.0`, `250.0`, etc.)
                                                                                                                - `timestamp`: Current system time in milliseconds
                                                                                                                - `description`: Optional string value (e.g., `"Payment for order #" + i` or `null` for some messages)
                                                                                - Create `ProducerRecord<String, PaymentV2>` with:
                                                                                                                - Topic: `payments-avro`
                                                                                                                - Key: Payment ID string
                                                                                                                - Value: PaymentV2 object
                                                                                - Send record using `producer.send(record)`
                                                                                - Log the sent message (e.g., `"Sent payment V2: paymentId=payment-v2-1, amount=150.0, description=Payment for order #1"`)
                                                                                - Optional: Add small delay between messages (e.g., `Thread.sleep(100)`)

5. **Cleanup:**

                                                - Call `producer.flush()` to ensure all messages are sent
                                                - Call `producer.close()` to close the producer
                                                - Log completion message (e.g., `"Producer V2 completed. Sent 10 messages with schema version 2."`)

#### 3.1.3 Key Configuration Properties

**Same as `AvroProducer.java` with these specifics:**

- **Schema Name:** `payment-schema` (same as V1 - this will create Version 2)
- **Registry Name:** `PaymentSchemaRegistry` (same as V1)
- **Compatibility:** `BACKWARD` (default, but explicit)
- **Data Format:** `AVRO`
- **Schema Auto-Registration:** `true` (will automatically register V2 if compatible)

#### 3.1.4 Imports Required

- `org.apache.kafka.clients.producer.*`
- `org.apache.kafka.common.config.SaslConfigs`
- `org.apache.kafka.clients.CommonClientConfigs`
- `com.amazonaws.services.schemaregistry.serializers.GlueSchemaRegistryKafkaSerializer`
- `com.example.PaymentV2` (generated class)
- `java.io.FileInputStream`
- `java.io.IOException`
- `java.io.InputStream`
- `java.util.Properties`
- `org.slf4j.Logger`
- `org.slf4j.LoggerFactory`

#### 3.1.5 Code Structure

The class structure should mirror `AvroProducer.java` but:

- Use `PaymentV2` instead of `Payment`
- Use message IDs like `"payment-v2-1"` to distinguish from V1 messages
- Include `description` field in log messages
- Add "V2" suffix to log messages for clarity

### 3.2 AvroProducerV3.java

#### 3.2.1 Purpose

`AvroProducerV3.java` attempts to send messages using the `PaymentV3` schema (with renamed `amount` field to `paymentAmount`) to test incompatible change rejection. This producer will:

1. Attempt to register Schema Version 3 in the Glue Schema Registry
2. **Expected Outcome:** The registry will reject the schema registration due to incompatible change
3. The producer should catch and log the compatibility exception

#### 3.2.2 Main Method Logic

1. **Command-Line Arguments:**

                                                - `args[0]`: Properties file path (e.g., `application.properties`)
                                                - `args[1]`: Optional bootstrap server string override
                                                - Validate that at least one argument is provided

2. **Topic Configuration:**

                                                - Topic name: `payments-avro` (same topic, but messages will not be sent due to failure)
                                                - Key type: `String`
                                                - Value type: `PaymentV3` (AVRO record with renamed field)

3. **Producer Initialization:**

                                                - Create `Properties` object
                                                - Load properties from file
                                                - Set all required Kafka and Glue Schema Registry properties
                                                - **Important:** Use the same `registryName` and `schemaName` as V1/V2
                                                - Set `compatibility` to `BACKWARD` (default)
                                                - Create `KafkaProducer<String, PaymentV3>` instance

4. **Message Production Attempt:**

                                                - **Expected Behavior:** The producer will fail when attempting to send the first message
                                                - The failure will occur during schema registration/validation
                                                - Wrap message sending in try-catch to handle the exception gracefully
                                                - Loop 10 times (though only first iteration will execute before failure)
                                                - For each iteration:
                                                                                - Create a new `PaymentV3` object with:
                                                                                                                - `paymentId`: Unique string (e.g., `"payment-v3-1"`)
                                                                                                                - `paymentAmount`: Sequential double value (e.g., `300.0`)
                                                                                                                - `timestamp`: Current system time in milliseconds
                                                                                - Create `ProducerRecord<String, PaymentV3>`
                                                                                - Attempt to send record using `producer.send(record)`
                                                                                - **Expected:** Exception will be thrown here

5. **Exception Handling:**

                                                - Catch `com.amazonaws.services.schemaregistry.common.exceptions.AWSSchemaRegistryException` or similar
                                                - Log the exception with clear message:
                                                                                - `"ERROR: Schema registration failed due to incompatible change"`
                                                                                - `"Exception: " + exception.getMessage()`
                                                                                - `"This is expected behavior - renaming a required field breaks BACKWARD compatibility"`
                                                - Exit with error code 1

6. **Cleanup:**

                                                - Call `producer.close()` in finally block
                                                - Log that the test completed (even though it failed as expected)

#### 3.2.3 Key Configuration Properties

**Same as `AvroProducer.java` with these specifics:**

- **Schema Name:** `payment-schema` (same as V1/V2 - this will attempt to create Version 3)
- **Registry Name:** `PaymentSchemaRegistry` (same as V1/V2)
- **Compatibility:** `BACKWARD` (default)
- **Data Format:** `AVRO`
- **Schema Auto-Registration:** `true` (will attempt to register V3, but will fail)

#### 3.2.4 Expected Exception

The producer should catch an exception similar to:

```
com.amazonaws.services.schemaregistry.common.exceptions.AWSSchemaRegistryException: 
Schema compatibility check failed. The new schema is not backward compatible with the existing schema version.
```

Or:

```
software.amazon.awssdk.services.glue.model.GlueException: 
Schema compatibility check failed. Field 'amount' was renamed to 'paymentAmount', which breaks backward compatibility.
```

**Note:** The exact exception type and message may vary based on the Glue Schema Registry library version. The important part is that the exception indicates a compatibility failure.

#### 3.2.5 Imports Required

- `org.apache.kafka.clients.producer.*`
- `org.apache.kafka.common.config.SaslConfigs`
- `org.apache.kafka.clients.CommonClientConfigs`
- `com.amazonaws.services.schemaregistry.serializers.GlueSchemaRegistryKafkaSerializer`
- `com.amazonaws.services.schemaregistry.common.exceptions.AWSSchemaRegistryException` (or similar)
- `com.example.PaymentV3` (generated class)
- `java.io.FileInputStream`
- `java.io.IOException`
- `java.io.InputStream`
- `java.util.Properties`
- `org.slf4j.Logger`
- `org.slf4j.LoggerFactory`

#### 3.2.6 Code Structure

The class structure should mirror `AvroProducer.java` but:

- Use `PaymentV3` instead of `Payment`
- Wrap message sending in try-catch to handle expected exception
- Log clear error messages indicating this is expected behavior
- Exit with error code 1 after catching the exception

---

## 4. Test Procedures

### 4.1 Test Case 1: Backward Compatibility Test

#### 4.1.1 Objective

Verify that adding an optional field to the schema is backward-compatible, and that old consumers can read new messages.

#### 4.1.2 Prerequisites

- Infrastructure deployed (Epic 1)
- Epic 2 completed successfully (V1 producer/consumer working)
- Schema Version 1 exists in Glue Schema Registry
- Project built with new V2 schema and `AvroProducerV2.java`

#### 4.1.3 Test Procedure

**Step 1: Start the Original Consumer (V1 Schema)**

1. Open Terminal 1 (SSM session to EC2 instance)
2. Navigate to project directory:
   ```bash
   cd ~/aws-notes/data/glue-schema-registry
   ```

3. Start the original `AvroConsumer` (uses V1 schema):
   ```bash
   java -cp build/libs/glue-schema-registry-testbed-all.jar com.example.AvroConsumer application.properties
   ```

4. Consumer should start and wait for messages:
   ```
   Consumer started, waiting for messages...
   ```


**Step 2: Run V2 Producer (New Schema with Optional Field)**

1. Open Terminal 2 (new SSM session to EC2 instance)
2. Navigate to project directory:
   ```bash
   cd ~/aws-notes/data/glue-schema-registry
   ```

3. Run `AvroProducerV2`:
   ```bash
   java -cp build/libs/glue-schema-registry-testbed-all.jar com.example.AvroProducerV2 application.properties
   ```

4. Producer should send 10 messages and exit:
   ```
   Sent payment V2: paymentId=payment-v2-1, amount=150.0, description=Payment for order #1
   Sent payment V2: paymentId=payment-v2-2, amount=250.0, description=Payment for order #2
   ...
   Producer V2 completed. Sent 10 messages with schema version 2.
   ```


**Step 3: Verify Consumer Receives V2 Messages**

1. Check Terminal 1 (Consumer):

                                                - Consumer should receive and log 10 messages
                                                - **Expected Output:**
     ```
     Received payment: paymentId=payment-v2-1, amount=150.0, timestamp=1234567890
     Received payment: paymentId=payment-v2-2, amount=250.0, timestamp=1234567891
     ...
     Consumer completed. Received 10 messages.
     ```

                                                - **Note:** The `description` field will NOT appear in the consumer logs because the V1 schema doesn't include it
                                                - **This is correct behavior** - the consumer successfully reads V2 messages using the V1 schema

**Step 4: Verify Schema Registry**

1. Navigate to AWS Glue Console → Schema Registry → `PaymentSchemaRegistry` → `payment-schema`
2. Verify that Schema Version 2 exists
3. Compare Version 1 and Version 2:

                                                - Version 1: `paymentId`, `amount`, `timestamp`
                                                - Version 2: `paymentId`, `amount`, `timestamp`, `description` (optional, default: null)

4. Verify compatibility mode is `BACKWARD`

#### 4.1.4 Success Criteria

- ✅ V2 producer successfully sends 10 messages
- ✅ Schema Version 2 is registered in Glue Schema Registry
- ✅ Original V1 consumer successfully reads all 10 V2 messages
- ✅ Consumer logs show only V1 fields (`paymentId`, `amount`, `timestamp`)
- ✅ No exceptions or errors in consumer logs
- ✅ Schema Version 2 shows as compatible with Version 1 in Glue console

#### 4.1.5 Expected Behavior Explanation

- **Backward Compatibility:** The new schema (V2) is backward-compatible because:
                                - All V1 fields remain unchanged
                                - New field (`description`) is optional (union with null) and has a default value
                                - Old consumers can read new messages by ignoring the new field
- **Consumer Behavior:** The V1 consumer deserializes V2 messages successfully because AVRO handles missing/extra fields gracefully when using compatible schemas

### 4.2 Test Case 2: Incompatible Change Test

#### 4.2.1 Objective

Verify that renaming a required field breaks backward compatibility and causes schema registration to fail.

#### 4.2.2 Prerequisites

- Infrastructure deployed (Epic 1)
- Epic 2 completed successfully (V1 producer/consumer working)
- Schema Version 1 (and optionally Version 2) exists in Glue Schema Registry
- Project built with new V3 schema and `AvroProducerV3.java`

#### 4.2.3 Test Procedure

**Step 1: Attempt to Run V3 Producer (Incompatible Schema)**

1. Open Terminal 1 (SSM session to EC2 instance)
2. Navigate to project directory:
   ```bash
   cd ~/aws-notes/data/glue-schema-registry
   ```

3. Run `AvroProducerV3`:
   ```bash
   java -cp build/libs/glue-schema-registry-testbed-all.jar com.example.AvroProducerV3 application.properties
   ```

4. **Expected Behavior:** Producer should fail immediately with an exception

**Step 2: Verify Exception Details**

1. Check Terminal 1 output:

                                                - **Expected Output:**
     ```
     ERROR: Schema registration failed due to incompatible change
     Exception: Schema compatibility check failed. The new schema is not backward compatible with the existing schema version.
     This is expected behavior - renaming a required field breaks BACKWARD compatibility
     ```

                                                - Or similar exception message indicating compatibility failure

2. Producer should exit with error code 1

**Step 3: Verify Schema Registry**

1. Navigate to AWS Glue Console → Schema Registry → `PaymentSchemaRegistry` → `payment-schema`
2. Verify that Schema Version 3 does NOT exist
3. Only Version 1 (and Version 2 if Test Case 1 was run) should exist
4. Verify that no new version was created

#### 4.2.4 Success Criteria

- ✅ V3 producer fails with a compatibility exception
- ✅ Exception message clearly indicates schema compatibility failure
- ✅ No messages are sent to Kafka topic
- ✅ Schema Version 3 is NOT registered in Glue Schema Registry
- ✅ Only compatible schema versions (V1, V2) exist in the registry
- ✅ Producer exits with error code 1

#### 4.2.5 Expected Behavior Explanation

- **Incompatibility:** Renaming a required field (`amount` → `paymentAmount`) breaks backward compatibility because:
                                - Old consumers expect a field named `amount`
                                - New schema has a field named `paymentAmount`
                                - AVRO field matching is by name, not position
                                - Old consumers cannot deserialize new messages (field name mismatch)
- **Registry Behavior:** The Glue Schema Registry validates schema compatibility before registration
                                - With `BACKWARD` compatibility mode, new schemas must be readable by old consumers
                                - The registry rejects the incompatible schema and throws an exception
                                - No schema version is created, and no messages are sent

---

## 5. README.md Updates

### 5.1 New Section: "Step 6: Run AVRO Schema Evolution Tests"

**Location:** After "Step 5: Run AVRO Producer-Consumer Test" section

**Content:**

````markdown
### Step 6: Run AVRO Schema Evolution Tests

This section demonstrates schema evolution scenarios using AWS Glue Schema Registry.

**Prerequisites:**
- Epic 2 completed successfully (V1 producer/consumer working)
- Schema Version 1 exists in Glue Schema Registry
- Project built with new V2 and V3 schemas

#### Test Case 1: Backward Compatibility Test

This test verifies that adding an optional field is backward-compatible.

**Procedure:**

1. **Terminal 1: Start the Original Consumer (V1 Schema)**
   ```bash
   # Connect to EC2 instance
   aws ssm start-session --target <EC2_INSTANCE_ID> --region us-east-1 --profile streaming
   
   # Navigate to project directory
   cd ~/aws-notes/data/glue-schema-registry
   
   # Start the original consumer (uses V1 schema)
   java -cp build/libs/glue-schema-registry-testbed-all.jar com.example.AvroConsumer application.properties
   ```
   
   The consumer will wait for messages.

2. **Terminal 2: Run V2 Producer (New Schema with Optional Field)**
   ```bash
   # Connect to EC2 instance in a new terminal
   aws ssm start-session --target <EC2_INSTANCE_ID> --region us-east-1 --profile streaming
   
   # Navigate to project directory
   cd ~/aws-notes/data/glue-schema-registry
   
   # Run the V2 producer
   java -cp build/libs/glue-schema-registry-testbed-all.jar com.example.AvroProducerV2 application.properties
   ```
   
   The producer will send 10 messages with the new schema (including optional `description` field) and exit.

3. **Verify Results:**
   - **Terminal 1 (Consumer):** Should display 10 deserialized payment messages (without `description` field, as expected)
   - **AWS Glue Console:** Navigate to AWS Glue → Schema Registry → `PaymentSchemaRegistry` → `payment-schema`
     - You should see Schema Version 2 registered
     - Version 2 should include the new optional `description` field

**Expected Behavior:**
- V2 producer successfully sends messages
- Schema Version 2 is registered in Glue Schema Registry
- Original V1 consumer successfully reads all V2 messages (ignoring the new `description` field)
- This demonstrates backward compatibility

#### Test Case 2: Incompatible Change Test

This test verifies that renaming a required field breaks backward compatibility and is rejected by the registry.

**Procedure:**

1. **Run V3 Producer (Incompatible Schema)**
   ```bash
   # Connect to EC2 instance
   aws ssm start-session --target <EC2_INSTANCE_ID> --region us-east-1 --profile streaming
   
   # Navigate to project directory
   cd ~/aws-notes/data/glue-schema-registry
   
   # Run the V3 producer (will fail as expected)
   java -cp build/libs/glue-schema-registry-testbed-all.jar com.example.AvroProducerV3 application.properties
   ```

2. **Verify Results:**
   - **Terminal Output:** Should show an exception indicating schema compatibility failure:
     ```
     ERROR: Schema registration failed due to incompatible change
     Exception: Schema compatibility check failed. The new schema is not backward compatible with the existing schema version.
     This is expected behavior - renaming a required field breaks BACKWARD compatibility
     ```
   - **AWS Glue Console:** Navigate to AWS Glue → Schema Registry → `PaymentSchemaRegistry` → `payment-schema`
     - Schema Version 3 should NOT exist
     - Only Version 1 (and Version 2 if Test Case 1 was run) should exist

**Expected Behavior:**
- V3 producer fails with a compatibility exception
- No messages are sent to Kafka
- Schema Version 3 is NOT registered in Glue Schema Registry
- This demonstrates that incompatible changes are rejected by the registry

**Troubleshooting:**
- If V3 producer succeeds unexpectedly, verify that compatibility mode is set to `BACKWARD` in the producer configuration
- If exception message is unclear, check AWS Glue Schema Registry logs in CloudWatch
````

### 5.2 Update "Next Steps" Section

**Location:** Update the "Next Steps" section at the end of README.md

**Content:**

```markdown
## Next Steps

Epic 1 (Infrastructure Deployment), Epic 2 (AVRO Producer-Consumer Flow), and Epic 3 (AVRO Schema Evolution & Error Scenarios) are complete:

1. ✅ Infrastructure deployed
2. ✅ MSK Bootstrap Servers retrieved
3. ✅ Connected to EC2 instance
4. ✅ Verified Java 11 and Gradle installation
5. ✅ AVRO Producer-Consumer Flow implemented and tested
6. ✅ Glue Schema Registry integration working
7. ✅ End-to-end message flow validated
8. ✅ Backward compatibility testing (optional field addition)
9. ✅ Incompatible change rejection testing (field renaming)

**Future enhancements:**
- Epic 4: JSON Schema Producer-Consumer Flow
- Additional schema evolution scenarios (field removal, type changes)
- Performance benchmarking
- Multi-region schema replication testing
```

---

## 6. Implementation Checklist

### 6.1 Schema Files

- [ ] Create `src/main/avro/PaymentV2.avsc` with optional `description` field
- [ ] Create `src/main/avro/PaymentV3.avsc` with renamed `amount` field to `paymentAmount`
- [ ] Verify both schema JSON files are valid

### 6.2 Java Applications

- [ ] Implement `AvroProducerV2.java` with:
                                - [ ] Command-line argument parsing (properties file)
                                - [ ] Kafka producer configuration (same as V1)
                                - [ ] Glue Schema Registry serializer configuration (same registry/schema name)
                                - [ ] PaymentV2 object creation with optional `description` field
                                - [ ] Message sending logic (10 messages)
                                - [ ] Proper logging with "V2" identifier
                                - [ ] Error handling
- [ ] Implement `AvroProducerV3.java` with:
                                - [ ] Command-line argument parsing (properties file)
                                - [ ] Kafka producer configuration (same as V1)
                                - [ ] Glue Schema Registry serializer configuration (same registry/schema name)
                                - [ ] PaymentV3 object creation with renamed `paymentAmount` field
                                - [ ] Exception handling for expected compatibility failure
                                - [ ] Clear error logging indicating expected behavior
                                - [ ] Proper cleanup in finally block

### 6.3 Build and Test

- [ ] Run `./gradlew build` to verify compilation
- [ ] Verify AVRO classes are generated:
                                - [ ] `PaymentV2.java` in `build/generated-main-avro-java/com/example/`
                                - [ ] `PaymentV3.java` in `build/generated-main-avro-java/com/example/`
- [ ] Run `./gradlew shadowJar` to create fat JAR
- [ ] Verify JAR includes all new classes

### 6.4 Testing

- [ ] **Test Case 1 (Backward Compatibility):**
                                - [ ] Run original `AvroConsumer` (V1 schema)
                                - [ ] Run `AvroProducerV2` (V2 schema with optional field)
                                - [ ] Verify consumer receives all 10 V2 messages
                                - [ ] Verify consumer logs show only V1 fields (no `description`)
                                - [ ] Verify Schema Version 2 exists in Glue console
                                - [ ] Verify Version 2 shows as compatible with Version 1
- [ ] **Test Case 2 (Incompatible Change):**
                                - [ ] Run `AvroProducerV3` (V3 schema with renamed field)
                                - [ ] Verify producer fails with compatibility exception
                                - [ ] Verify exception message indicates compatibility failure
                                - [ ] Verify no messages are sent to Kafka
                                - [ ] Verify Schema Version 3 does NOT exist in Glue console

### 6.5 Documentation

- [ ] Update README.md with "Step 6: Run AVRO Schema Evolution Tests" section
- [ ] Add test procedures for both test cases
- [ ] Add expected behavior explanations
- [ ] Add troubleshooting tips
- [ ] Update "Next Steps" section

---

## 7. Key Concepts

### 7.1 Backward Compatibility

**Definition:** A new schema version is backward-compatible if old consumers can read messages written with the new schema.

**Allowed Changes (BACKWARD compatibility mode):**

- Adding optional fields (with default values)
- Removing required fields (becomes optional in old schema)
- Changing field types in compatible ways (e.g., int to long)

**Not Allowed Changes:**

- Renaming required fields
- Removing required fields without defaults
- Changing field types incompatibly (e.g., string to int)
- Adding required fields without defaults

### 7.2 Schema Evolution Best Practices

1. **Always use optional fields with defaults** when adding new fields
2. **Never rename fields** - use aliases if field names must change
3. **Test compatibility** before deploying schema changes to production
4. **Document schema evolution** - maintain a changelog of schema versions
5. **Use appropriate compatibility modes** - `BACKWARD`, `FORWARD`, `FULL`, or `NONE`

### 7.3 Glue Schema Registry Compatibility Modes

- **BACKWARD:** New schema can read data written with old schema (old consumers can read new messages)
- **FORWARD:** Old schema can read data written with new schema (new consumers can read old messages)
- **FULL:** Both backward and forward compatible
- **NONE:** No compatibility checks (not recommended for production)

---

## 8. Expected Behavior Summary

### 8.1 Test Case 1: Backward Compatibility

| Component | Behavior |

|-----------|----------|

| **AvroProducerV2** | Successfully sends 10 messages with V2 schema |

| **Glue Schema Registry** | Registers Schema Version 2 (compatible with V1) |

| **AvroConsumer (V1)** | Successfully reads all 10 V2 messages |

| **Consumer Logs** | Show only V1 fields (`paymentId`, `amount`, `timestamp`) |

| **Schema Registry Console** | Shows Version 2 with optional `description` field |

### 8.2 Test Case 2: Incompatible Change

| Component | Behavior |

|-----------|----------|

| **AvroProducerV3** | Fails with compatibility exception before sending messages |

| **Glue Schema Registry** | Rejects Schema Version 3 (incompatible with V1/V2) |

| **Kafka Topic** | Receives no messages from V3 producer |

| **Schema Registry Console** | Shows only Version 1 (and Version 2 if Test Case 1 was run) |

---

## 9. Troubleshooting

### 9.1 Test Case 1 Issues

**Issue:** V1 consumer doesn't receive V2 messages

**Possible Causes:**

- Consumer is using a different consumer group and reading from a different offset
- Topic has multiple partitions and consumer is reading from a different partition
- Messages were sent before consumer started

**Solution:**

- Ensure consumer starts before producer
- Use `AUTO_OFFSET_RESET_CONFIG: "earliest"` to read from beginning
- Check consumer group ID matches

**Issue:** Schema Version 2 not appearing in Glue console

**Possible Causes:**

- IAM permissions missing for `glue:RegisterSchemaVersion`
- Schema registration failed silently

**Solution:**

- Check CloudWatch logs for Glue errors
- Verify IAM role has required permissions
- Check producer logs for registration errors

### 9.2 Test Case 2 Issues

**Issue:** V3 producer succeeds unexpectedly (should fail)

**Possible Causes:**

- Compatibility mode is set to `NONE` instead of `BACKWARD`
- Schema name is different (creating a new schema instead of new version)
- Registry compatibility mode was changed

**Solution:**

- Verify `compatibility` property is set to `BACKWARD` in producer config
- Verify `schemaName` matches V1/V2 (`payment-schema`)
- Check Glue console for schema compatibility settings

**Issue:** Exception message is unclear

**Possible Causes:**

- Exception is wrapped in multiple layers
- Library version differences

**Solution:**

- Log full exception stack trace
- Check AWS Glue Schema Registry documentation for expected exception types
- Verify library version matches documentation

---

## End of Epic 3 Detailed Requirements

This document provides complete specifications for implementing Epic 3. The developer should use this as a checklist when creating the schema evolution tests and Java applications.