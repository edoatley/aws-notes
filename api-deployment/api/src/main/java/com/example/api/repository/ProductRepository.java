package com.example.api.repository;

import com.example.api.config.DynamoProperties;
import com.example.api.model.Product;

import lombok.extern.slf4j.Slf4j;

import org.springframework.stereotype.Repository;
import software.amazon.awssdk.enhanced.dynamodb.DynamoDbEnhancedClient;
import software.amazon.awssdk.enhanced.dynamodb.DynamoDbTable;
import software.amazon.awssdk.enhanced.dynamodb.TableSchema;

import java.util.ArrayList;
import java.util.List;

@Slf4j
@Repository
public class ProductRepository {

    private final DynamoDbTable<Product> productTable;

    public ProductRepository(DynamoDbEnhancedClient enhancedClient, DynamoProperties dynamoProperties) {
        // Initialize the DynamoDB table using the enhanced client and the table name from properties
        log.warn("========= Using DynamoDB table: {} =========", dynamoProperties.tableName());
        this.productTable = enhancedClient.table(dynamoProperties.tableName(), TableSchema.fromBean(Product.class));
    }

    public Product save(Product product) {
        productTable.putItem(product);
        return product;
    }

    public Product findById(String id) {
        return productTable.getItem(r -> r.key(k -> k.partitionValue(id)));
    }

    public List<Product> findAll() {
        List<Product> products = new ArrayList<>();
        productTable.scan().items().forEach(products::add);
        return products;
    }

    public void deleteById(String id) {
        productTable.deleteItem(r -> r.key(k -> k.partitionValue(id)));
    }
}