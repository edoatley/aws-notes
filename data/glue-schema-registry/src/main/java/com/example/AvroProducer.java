package com.example;

import org.apache.kafka.clients.producer.KafkaProducer;
import org.apache.kafka.clients.producer.ProducerConfig;
import org.apache.kafka.clients.producer.ProducerRecord;
import org.apache.kafka.common.config.SaslConfigs;
import org.apache.kafka.clients.CommonClientConfigs;
import com.amazonaws.services.schemaregistry.serializers.GlueSchemaRegistryKafkaSerializer;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.util.Properties;

public class AvroProducer {
    private static final Logger logger = LoggerFactory.getLogger(AvroProducer.class);
    private static final String TOPIC_NAME = "payments-avro";
    private static final String REGISTRY_NAME = "PaymentSchemaRegistry";
    private static final String SCHEMA_NAME = "payment-schema";
    private static final String AWS_REGION = "us-east-1";

    public static void main(String[] args) {
        if (args.length < 1) {
            System.err.println("Usage: AvroProducer <bootstrap-servers>");
            System.exit(1);
        }

        String bootstrapServers = args[0];
        logger.info("Starting AvroProducer with bootstrap servers: {}", bootstrapServers);

        // Create producer properties
        Properties props = new Properties();

        // Kafka producer properties
        props.put(ProducerConfig.BOOTSTRAP_SERVERS_CONFIG, bootstrapServers);
        props.put(ProducerConfig.KEY_SERIALIZER_CLASS_CONFIG, 
                  org.apache.kafka.common.serialization.StringSerializer.class.getName());
        props.put(ProducerConfig.VALUE_SERIALIZER_CLASS_CONFIG, 
                  GlueSchemaRegistryKafkaSerializer.class.getName());
        props.put(ProducerConfig.ACKS_CONFIG, "all");
        props.put(ProducerConfig.RETRIES_CONFIG, 3);

        // MSK IAM Authentication properties
        props.put(CommonClientConfigs.SECURITY_PROTOCOL_CONFIG, "SASL_SSL");
        props.put(SaslConfigs.SASL_MECHANISM, "AWS_MSK_IAM");
        props.put(SaslConfigs.SASL_JAAS_CONFIG, "software.amazon.msk.auth.iam.IAMLoginModule required;");
        props.put(SaslConfigs.SASL_CLIENT_CALLBACK_HANDLER_CLASS, 
                  "software.amazon.msk.auth.iam.IAMClientCallbackHandler");

        // Glue Schema Registry properties
        props.put("aws.region", AWS_REGION);
        props.put("dataFormat", "AVRO");
        props.put("registryName", REGISTRY_NAME);
        props.put("schemaName", SCHEMA_NAME);
        props.put("schemaAutoRegistrationEnabled", true);
        props.put("compatibility", "BACKWARD");

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
}

