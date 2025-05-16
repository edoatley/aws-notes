package com.example.api.model;

import software.amazon.awssdk.enhanced.dynamodb.mapper.annotations.DynamoDbBean;
import software.amazon.awssdk.enhanced.dynamodb.mapper.annotations.DynamoDbPartitionKey;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@AllArgsConstructor
@NoArgsConstructor
@DynamoDbBean
public class Product {
    private String id;
    private String name;
    private String description;
    private Double price;

    @DynamoDbPartitionKey
    public String getId() {
        return id;
    }
}