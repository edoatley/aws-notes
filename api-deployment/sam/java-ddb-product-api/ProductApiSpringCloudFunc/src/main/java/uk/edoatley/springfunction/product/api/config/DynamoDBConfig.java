package uk.edoatley.springfunction.product.api.config;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import software.amazon.awssdk.auth.credentials.AwsBasicCredentials;
import software.amazon.awssdk.auth.credentials.DefaultCredentialsProvider;
import software.amazon.awssdk.auth.credentials.StaticCredentialsProvider;
import software.amazon.awssdk.enhanced.dynamodb.DynamoDbEnhancedClient;
import software.amazon.awssdk.regions.Region;
import software.amazon.awssdk.services.dynamodb.DynamoDbClient;
import software.amazon.awssdk.services.dynamodb.DynamoDbClientBuilder;

import java.net.URI;

@Slf4j
@Configuration
@RequiredArgsConstructor
public class DynamoDBConfig {

    private final DynamoProperties dynamoProperties;

    @Bean
    DynamoDbClient dynamoDbClient() {
        DynamoDbClientBuilder builder = DynamoDbClient.builder()
                .region(Region.of(dynamoProperties.region()));

        // Use static credentials if accessKey and secretKey are provided
        if (dynamoProperties.accessKeyAuth()) {
            log.warn("========= Using static credentials for DynamoDB client =========");
            builder.credentialsProvider(StaticCredentialsProvider.create(
                        AwsBasicCredentials.create(dynamoProperties.accessKeyId(), dynamoProperties.secretKey())));
        }
        else {
            // Use default credentials provider chain for production
            builder.credentialsProvider(DefaultCredentialsProvider.create());
        }

        // If the endpoint is provided, override the default endpoint
        if (dynamoProperties.dynamoDBEndpointOverride()) {
            builder.endpointOverride(URI.create(dynamoProperties.endpoint()));
        }

        return builder.build();
    }

    @Bean
    public DynamoDbEnhancedClient dynamoDbEnhancedClient(DynamoDbClient dynamoDbClient) {
        return DynamoDbEnhancedClient.builder()
                .dynamoDbClient(dynamoDbClient)
                .build();
    }
}