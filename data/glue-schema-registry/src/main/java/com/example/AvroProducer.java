package com.example;

import org.apache.kafka.clients.producer.KafkaProducer;
import org.apache.kafka.clients.producer.ProducerConfig;
import org.apache.kafka.clients.producer.ProducerRecord;
import org.apache.kafka.clients.admin.AdminClient;
import org.apache.kafka.clients.admin.AdminClientConfig;
import org.apache.kafka.clients.admin.NewTopic;
import org.apache.kafka.common.config.SaslConfigs;
import org.apache.kafka.clients.CommonClientConfigs;
import com.amazonaws.services.schemaregistry.serializers.GlueSchemaRegistryKafkaSerializer;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.io.FileInputStream;
import java.io.IOException;
import java.io.InputStream;
import java.util.Collections;
import java.util.Properties;
import java.util.concurrent.ExecutionException;

public class AvroProducer {
    private static final Logger logger = LoggerFactory.getLogger(AvroProducer.class);
    private static final String TOPIC_NAME = "payments-avro";
    private static final String REGISTRY_NAME = "PaymentSchemaRegistry";
    private static final String SCHEMA_NAME = "payment-schema";
    private static final String AWS_REGION = "us-east-1";

    public static void main(String[] args) {
        if (args.length < 1) {
            System.err.println("Usage: AvroProducer <properties-file> [bootstrap-servers-override]");
            System.err.println("  properties-file: Path to application.properties file");
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

        // Set Kafka producer properties (if not already in properties file)
        if (!props.containsKey(ProducerConfig.BOOTSTRAP_SERVERS_CONFIG)) {
            logger.error("bootstrap.servers not found in properties file");
            System.exit(1);
        }
        props.putIfAbsent(ProducerConfig.KEY_SERIALIZER_CLASS_CONFIG, 
                  org.apache.kafka.common.serialization.StringSerializer.class.getName());
        props.putIfAbsent(ProducerConfig.VALUE_SERIALIZER_CLASS_CONFIG, 
                  GlueSchemaRegistryKafkaSerializer.class.getName());
        props.putIfAbsent(ProducerConfig.ACKS_CONFIG, "all");
        props.putIfAbsent(ProducerConfig.RETRIES_CONFIG, "3");

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
        props.putIfAbsent("dataFormat", "AVRO");
        props.putIfAbsent("registryName", props.getProperty("registry.name", REGISTRY_NAME));
        props.putIfAbsent("schemaName", props.getProperty("schema.name", SCHEMA_NAME));
        props.putIfAbsent("schemaAutoRegistrationEnabled", "true");
        props.putIfAbsent("compatibility", "BACKWARD");
        
        logger.info("Using AWS Region: {}", region);
        logger.info("Using Registry: {}", props.getProperty("registryName"));
        logger.info("Using Schema: {}", props.getProperty("schemaName"));

        // Ensure topic exists (MSK Serverless doesn't auto-create topics)
        ensureTopicExists(props, TOPIC_NAME);

        // Create producer
        KafkaProducer<String, Payment> producer = new KafkaProducer<>(props);

        try {
            // Send 10 messages
            for (int i = 1; i <= 10; i++) {
                // Create Payment object
                Payment payment = Payment.newBuilder()
                    .setPaymentId("payment-" + i)
                    .setAmount(100.0 * i + (i * 0.5))
                    .setTimestamp(System.currentTimeMillis())
                    .build();

                // Create producer record
                ProducerRecord<String, Payment> record = new ProducerRecord<>(
                    TOPIC_NAME,
                    payment.getPaymentId(),
                    payment
                );

                // Send record
                producer.send(record);
                logger.info("Sent payment: paymentId={}, amount={}, timestamp={}", 
                           payment.getPaymentId(), payment.getAmount(), payment.getTimestamp());

                // Small delay between messages
                Thread.sleep(100);
            }

            // Flush and close
            producer.flush();
            logger.info("Producer completed. Sent 10 messages.");

        } catch (Exception e) {
            logger.error("Error sending messages", e);
            System.exit(1);
        } finally {
            producer.close();
        }
    }

    private static void ensureTopicExists(Properties props, String topicName) {
        // Create admin client with same properties as producer
        Properties adminProps = new Properties();
        adminProps.putAll(props);
        adminProps.put(AdminClientConfig.BOOTSTRAP_SERVERS_CONFIG, props.getProperty("bootstrap.servers"));
        
        AdminClient admin = AdminClient.create(adminProps);
        
        try {
            // Check if topic exists
            boolean topicExists = admin.listTopics().names().get().contains(topicName);
            
            if (!topicExists) {
                logger.info("Topic '{}' does not exist. Creating it...", topicName);
                // Create topic with 1 partition (MSK Serverless handles replication)
                NewTopic newTopic = new NewTopic(topicName, 1, (short) 1);
                admin.createTopics(Collections.singletonList(newTopic)).all().get();
                logger.info("Topic '{}' created successfully", topicName);
            } else {
                logger.info("Topic '{}' already exists", topicName);
            }
        } catch (InterruptedException | ExecutionException e) {
            logger.error("Error ensuring topic exists: {}", topicName, e);
            // Don't exit - let producer try anyway, it might work
            logger.warn("Continuing despite topic creation error...");
        } finally {
            admin.close();
        }
    }
}

