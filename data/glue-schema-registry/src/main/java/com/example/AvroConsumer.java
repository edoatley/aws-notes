package com.example;

import org.apache.kafka.clients.consumer.ConsumerConfig;
import org.apache.kafka.clients.consumer.ConsumerRecord;
import org.apache.kafka.clients.consumer.ConsumerRecords;
import org.apache.kafka.clients.consumer.KafkaConsumer;
import org.apache.kafka.common.config.SaslConfigs;
import org.apache.kafka.clients.CommonClientConfigs;
import com.amazonaws.services.schemaregistry.deserializers.GlueSchemaRegistryKafkaDeserializer;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.time.Duration;
import java.util.Collections;
import java.util.Properties;

public class AvroConsumer {
    private static final Logger logger = LoggerFactory.getLogger(AvroConsumer.class);
    private static final String TOPIC_NAME = "payments-avro";
    private static final String REGISTRY_NAME = "PaymentSchemaRegistry";
    private static final String AWS_REGION = "us-east-1";
    private static final String GROUP_ID = "payment-consumer-group";
    private static final int EXPECTED_MESSAGE_COUNT = 10;

    public static void main(String[] args) {
        if (args.length < 1) {
            System.err.println("Usage: AvroConsumer <bootstrap-servers>");
            System.exit(1);
        }

        String bootstrapServers = args[0];
        logger.info("Starting AvroConsumer with bootstrap servers: {}", bootstrapServers);

        // Create consumer properties
        Properties props = new Properties();

        // Kafka consumer properties
        props.put(ConsumerConfig.BOOTSTRAP_SERVERS_CONFIG, bootstrapServers);
        props.put(ConsumerConfig.KEY_DESERIALIZER_CLASS_CONFIG, 
                  org.apache.kafka.common.serialization.StringDeserializer.class.getName());
        props.put(ConsumerConfig.VALUE_DESERIALIZER_CLASS_CONFIG, 
                  GlueSchemaRegistryKafkaDeserializer.class.getName());
        props.put(ConsumerConfig.GROUP_ID_CONFIG, GROUP_ID);
        props.put(ConsumerConfig.AUTO_OFFSET_RESET_CONFIG, "earliest");
        props.put(ConsumerConfig.ENABLE_AUTO_COMMIT_CONFIG, true);

        // MSK IAM Authentication properties
        props.put(CommonClientConfigs.SECURITY_PROTOCOL_CONFIG, "SASL_SSL");
        props.put(SaslConfigs.SASL_MECHANISM, "AWS_MSK_IAM");
        props.put(SaslConfigs.SASL_JAAS_CONFIG, "software.amazon.msk.auth.iam.IAMLoginModule required;");
        props.put(SaslConfigs.SASL_CLIENT_CALLBACK_HANDLER_CLASS, 
                  "software.amazon.msk.auth.iam.IAMClientCallbackHandler");

        // Glue Schema Registry properties
        props.put("aws.region", AWS_REGION);
        props.put("avroRecordType", "SPECIFIC_RECORD");
        props.put("registryName", REGISTRY_NAME);

        // Create consumer
        KafkaConsumer<String, Payment> consumer = new KafkaConsumer<>(props);

        try {
            // Subscribe to topic
            consumer.subscribe(Collections.singletonList(TOPIC_NAME));
            logger.info("Consumer started, waiting for messages...");

            int messageCount = 0;

            // Poll for messages
            while (messageCount < EXPECTED_MESSAGE_COUNT) {
                ConsumerRecords<String, Payment> records = consumer.poll(Duration.ofSeconds(1));

                for (ConsumerRecord<String, Payment> record : records) {
                    Payment payment = record.value();
                    logger.info("Received payment: paymentId={}, amount={}, timestamp={}", 
                               payment.getPaymentId(), payment.getAmount(), payment.getTimestamp());
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

