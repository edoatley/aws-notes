package com.example;

import org.apache.kafka.clients.consumer.ConsumerConfig;
import org.apache.kafka.clients.consumer.ConsumerRecord;
import org.apache.kafka.clients.consumer.ConsumerRecords;
import org.apache.kafka.clients.consumer.KafkaConsumer;
import org.apache.kafka.common.config.SaslConfigs;
import org.apache.kafka.clients.CommonClientConfigs;
import com.amazonaws.services.schemaregistry.deserializers.GlueSchemaRegistryKafkaDeserializer;
import com.amazonaws.services.schemaregistry.serializers.json.JsonDataWithSchema;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.io.FileInputStream;
import java.io.IOException;
import java.io.InputStream;
import java.time.Duration;
import java.util.Collections;
import java.util.Properties;

public class JsonConsumer {
    private static final Logger logger = LoggerFactory.getLogger(JsonConsumer.class);
    private static final String TOPIC_NAME = "sensors-json";
    private static final String REGISTRY_NAME = "PaymentSchemaRegistry";
    private static final String AWS_REGION = "us-east-1";
    private static final String GROUP_ID = "sensor-consumer-group";
    private static final int EXPECTED_MESSAGE_COUNT = 10;

    public static void main(String[] args) {
        if (args.length < 1) {
            System.err.println("Usage: JsonConsumer <properties-file> [bootstrap-servers-override]");
            System.err.println("  properties-file: Path to application-json.properties file");
            System.err.println("  bootstrap-servers-override: Optional override for bootstrap.servers");
            System.exit(1);
        }

        String propertiesFile = args[0];
        logger.info("Loading properties from: {}", propertiesFile);

        // Load properties from file
        Properties props = new Properties();
        try (InputStream input = new FileInputStream(propertiesFile)) {
            props.load(input);
            logger.info("Properties loaded successfully");
        } catch (IOException e) {
            logger.error("Failed to load properties file: {}", propertiesFile, e);
            System.exit(1);
        }

        // Override bootstrap servers if provided as second argument
        if (args.length >= 2) {
            String bootstrapServers = args[1];
            props.setProperty("bootstrap.servers", bootstrapServers);
            logger.info("Overriding bootstrap.servers with: {}", bootstrapServers);
        }

        // Set Kafka consumer properties (if not already in properties file)
        if (!props.containsKey(ConsumerConfig.BOOTSTRAP_SERVERS_CONFIG)) {
            logger.error("bootstrap.servers not found in properties file");
            System.exit(1);
        }
        props.putIfAbsent(ConsumerConfig.KEY_DESERIALIZER_CLASS_CONFIG, 
                  org.apache.kafka.common.serialization.StringDeserializer.class.getName());
        props.putIfAbsent(ConsumerConfig.VALUE_DESERIALIZER_CLASS_CONFIG, 
                  GlueSchemaRegistryKafkaDeserializer.class.getName());
        props.putIfAbsent(ConsumerConfig.GROUP_ID_CONFIG, props.getProperty("consumer.group.id", GROUP_ID));
        props.putIfAbsent(ConsumerConfig.AUTO_OFFSET_RESET_CONFIG, "earliest");
        props.putIfAbsent(ConsumerConfig.ENABLE_AUTO_COMMIT_CONFIG, "true");

        // MSK IAM Authentication properties (if not already set)
        props.putIfAbsent(CommonClientConfigs.SECURITY_PROTOCOL_CONFIG, "SASL_SSL");
        props.putIfAbsent(SaslConfigs.SASL_MECHANISM, "AWS_MSK_IAM");
        props.putIfAbsent(SaslConfigs.SASL_JAAS_CONFIG, "software.amazon.msk.auth.iam.IAMLoginModule required;");
        props.putIfAbsent(SaslConfigs.SASL_CLIENT_CALLBACK_HANDLER_CLASS, 
                  "software.amazon.msk.auth.iam.IAMClientCallbackHandler");

        // Glue Schema Registry properties - use correct property names
        // The library expects "region" (from AWSSchemaRegistryConstants.AWS_REGION which equals "region")
        String region = props.getProperty("aws.region", AWS_REGION);
        props.setProperty("region", region);  // Library expects property name "region"
        props.putIfAbsent("dataFormat", "JSON");  // KEY DIFFERENCE: JSON instead of AVRO
        props.putIfAbsent("registryName", props.getProperty("registry.name", REGISTRY_NAME));
        
        logger.info("Using AWS Region: {}", region);
        logger.info("Using Registry: {}", props.getProperty("registryName"));
        logger.info("Using Data Format: JSON");

        // Create consumer - Glue Schema Registry returns JsonDataWithSchema for JSON format
        KafkaConsumer<String, JsonDataWithSchema> consumer = new KafkaConsumer<>(props);
        
        // ObjectMapper for deserializing JSON data to POJO
        ObjectMapper objectMapper = new ObjectMapper();

        try {
            // Subscribe to topic
            consumer.subscribe(Collections.singletonList(TOPIC_NAME));
            logger.info("Consumer started, waiting for messages...");

            int messageCount = 0;

            // Poll for messages
            while (messageCount < EXPECTED_MESSAGE_COUNT) {
                ConsumerRecords<String, JsonDataWithSchema> records = consumer.poll(Duration.ofSeconds(1));

                for (ConsumerRecord<String, JsonDataWithSchema> record : records) {
                    // Extract JsonDataWithSchema wrapper
                    JsonDataWithSchema jsonDataWithSchema = record.value();
                    
                    // Get the actual JSON data (as Object, typically a Map or the actual data structure)
                    Object jsonData = jsonDataWithSchema.getPayload();
                    
                    // Deserialize to SensorReading POJO using Jackson
                    SensorReading sensorReading = objectMapper.convertValue(jsonData, SensorReading.class);
                    
                    logger.info("Received sensor reading: sensorId={}, temperature={}, humidity={}, timestamp={}",
                               sensorReading.getSensorId(),
                               sensorReading.getTemperature(),
                               sensorReading.getHumidity(),
                               sensorReading.getTimestamp());
                    messageCount++;

                    if (messageCount >= EXPECTED_MESSAGE_COUNT) {
                        break;
                    }
                }
            }

            logger.info("Consumer completed. Received {} messages.", messageCount);

        } catch (Exception e) {
            logger.error("Error consuming messages", e);
            System.exit(1);
        } finally {
            consumer.close();
        }
    }
}

