package com.example.api.model;

import com.amazonaws.services.dynamodbv2.datamodeling.DynamoDBAttribute;
import com.amazonaws.services.dynamodbv2.datamodeling.DynamoDBHashKey;
import com.amazonaws.services.dynamodbv2.datamodeling.DynamoDBTable;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@AllArgsConstructor
@NoArgsConstructor
@DynamoDBTable(tableName = "Product")
public class Product {
    
    @DynamoDBHashKey
    private String id;
    
    @DynamoDBAttribute
    private String name;
    
    @DynamoDBAttribute
    private String description;
    
    @DynamoDBAttribute
    private Double price;
}