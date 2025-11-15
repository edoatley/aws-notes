package com.example;

import org.apache.kafka.clients.admin.AdminClient;
import org.apache.kafka.clients.admin.AdminClientConfig;
import org.apache.kafka.clients.admin.NewTopic;
import org.apache.kafka.common.config.SaslConfigs;
import org.apache.kafka.clients.CommonClientConfigs;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.io.FileInputStream;
import java.io.IOException;
import java.io.InputStream;
import java.util.Collections;
import java.util.Properties;
import java.util.concurrent.ExecutionException;

public class CreateTopic {
    private static final Logger logger = LoggerFactory.getLogger(CreateTopic.class);
    private static final String TOPIC_NAME = "payments-avro";

    public static void main(String[] args) {
        if (args.length < 1) {
            System.err.println("Usage: CreateTopic <properties-file>");
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

        // Set admin client properties
        if (!props.containsKey(AdminClientConfig.BOOTSTRAP_SERVERS_CONFIG)) {
            logger.error("bootstrap.servers not found in properties file");
            System.exit(1);
        }
        props.putIfAbsent(CommonClientConfigs.SECURITY_PROTOCOL_CONFIG, "SASL_SSL");
        props.putIfAbsent(SaslConfigs.SASL_MECHANISM, "AWS_MSK_IAM");
        props.putIfAbsent(SaslConfigs.SASL_JAAS_CONFIG, "software.amazon.msk.auth.iam.IAMLoginModule required;");
        props.putIfAbsent(SaslConfigs.SASL_CLIENT_CALLBACK_HANDLER_CLASS, 
                  "software.amazon.msk.auth.iam.IAMClientCallbackHandler");

        // Create admin client
        AdminClient admin = AdminClient.create(props);

        try {
            // Check if topic exists
            boolean topicExists = admin.listTopics().names().get().contains(TOPIC_NAME);
            
            if (topicExists) {
                logger.info("Topic '{}' already exists", TOPIC_NAME);
            } else {
                // Create topic
                NewTopic newTopic = new NewTopic(TOPIC_NAME, 1, (short) 1); // 1 partition, replication factor 1 (MSK Serverless handles replication)
                admin.createTopics(Collections.singletonList(newTopic)).all().get();
                logger.info("Topic '{}' created successfully", TOPIC_NAME);
            }

            // List all topics
            logger.info("Available topics: {}", admin.listTopics().names().get());

        } catch (InterruptedException | ExecutionException e) {
            logger.error("Error creating topic", e);
            System.exit(1);
        } finally {
            admin.close();
        }
    }
}

