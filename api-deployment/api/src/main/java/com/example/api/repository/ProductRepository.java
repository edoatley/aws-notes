package com.example.api.repository;

import com.example.api.model.Product;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Repository;
import software.amazon.awssdk.enhanced.dynamodb.DynamoDbEnhancedClient;
import software.amazon.awssdk.enhanced.dynamodb.DynamoDbTable;
import software.amazon.awssdk.enhanced.dynamodb.TableSchema;
import software.amazon.awssdk.enhanced.dynamodb.model.ScanEnhancedRequest;

import java.util.ArrayList;
import java.util.List;

@Repository
public class ProductRepository {

    private final DynamoDbTable<Product> productTable;

    public ProductRepository(DynamoDbEnhancedClient enhancedClient, 
                           @Value("${amazon.dynamodb.tableName}") String tableName) {
        this.productTable = enhancedClient.table(tableName, TableSchema.fromBean(Product.class));
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