package com.example.api.config;

import org.springframework.boot.context.properties.ConfigurationProperties;

@ConfigurationProperties(prefix = "dynamo")
public record DynamoProperties(
    String accessKeyId,
    String secretKey,
    String region,
    String endpoint,
    String tableName
) {
    public boolean accessKeyAuth() {
        return accessKeyId != null && !accessKeyId.isEmpty() &&
               secretKey != null && !secretKey.isEmpty();
    }
    public boolean dynamoDBEndpointOverride() {
        return endpoint != null && !endpoint.isEmpty();
    }
}
