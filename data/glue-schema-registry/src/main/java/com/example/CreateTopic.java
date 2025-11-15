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
    private static final String DEFAULT_AVRO_TOPIC = "payments-avro";
    private static final String DEFAULT_JSON_TOPIC = "sensors-json";

    public static void main(String[] args) {
        if (args.length < 1) {
            System.err.println("Usage: CreateTopic <properties-file> [topic-name]");
            System.err.println("  properties-file: Path to application.properties or application-json.properties file");
            System.err.println("  topic-name: Optional topic name (if not provided, inferred from data.format or defaults to payments-avro)");
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

        // Determine topic name
        String topicName;
        if (args.length >= 2) {
            // Topic name provided as command-line argument
            topicName = args[1];
            logger.info("Using topic name from command line: {}", topicName);
        } else if (props.containsKey("topic.name")) {
            // Topic name in properties file
            topicName = props.getProperty("topic.name");
            logger.info("Using topic name from properties file: {}", topicName);
        } else {
            // Infer from data.format
            String dataFormat = props.getProperty("data.format", "AVRO").toUpperCase();
            if ("JSON".equals(dataFormat)) {
                topicName = DEFAULT_JSON_TOPIC;
                logger.info("Inferred topic name from data.format=JSON: {}", topicName);
            } else {
                topicName = DEFAULT_AVRO_TOPIC;
                logger.info("Inferred topic name from data.format=AVRO (or default): {}", topicName);
            }
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
            boolean topicExists = admin.listTopics().names().get().contains(topicName);
            
            if (topicExists) {
                logger.info("Topic '{}' already exists", topicName);
            } else {
                // Create topic
                NewTopic newTopic = new NewTopic(topicName, 1, (short) 1); // 1 partition, replication factor 1 (MSK Serverless handles replication)
                admin.createTopics(Collections.singletonList(newTopic)).all().get();
                logger.info("Topic '{}' created successfully", topicName);
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

