package com.example.api.config;

import com.amazonaws.auth.AWSStaticCredentialsProvider;
import com.amazonaws.auth.BasicAWSCredentials;
import com.amazonaws.client.builder.AwsClientBuilder.EndpointConfiguration;
import com.amazonaws.services.dynamodbv2.AmazonDynamoDB;
import com.amazonaws.services.dynamodbv2.AmazonDynamoDBClientBuilder;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.annotation.Primary;
import org.testcontainers.containers.localstack.LocalStackContainer;
import org.testcontainers.utility.DockerImageName;
import static org.testcontainers.containers.localstack.LocalStackContainer.Service.DYNAMODB;

@Configuration
public class TestDynamoDBConfig {

    @Bean(initMethod = "start", destroyMethod = "stop")
    public LocalStackContainer localStackContainer() {
        return new LocalStackContainer(DockerImageName.parse("localstack/localstack:latest"))
            .withServices(DYNAMODB);
    }

    @Bean
    @Primary
    public AmazonDynamoDB amazonDynamoDB(LocalStackContainer localStackContainer) {
        return AmazonDynamoDBClientBuilder.standard()
            .withEndpointConfiguration(
                new EndpointConfiguration(
                    localStackContainer.getEndpointOverride(DYNAMODB).toString(),
                    localStackContainer.getRegion()
                )
            )
            .withCredentials(
                new AWSStaticCredentialsProvider(
                    new BasicAWSCredentials(
                        localStackContainer.getAccessKey(),
                        localStackContainer.getSecretKey()
                    )
                )
            )
            .build();
    }
}
