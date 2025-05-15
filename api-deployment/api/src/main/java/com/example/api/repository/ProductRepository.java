package com.example.api.repository;

import com.amazonaws.services.dynamodbv2.datamodeling.DynamoDBMapper;
import com.amazonaws.services.dynamodbv2.datamodeling.DynamoDBScanExpression;
import com.example.api.model.Product;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public class ProductRepository {

    @Autowired
    private DynamoDBMapper dynamoDBMapper;

    public Product save(Product product) {
        dynamoDBMapper.save(product);
        return product;
    }

    public Product findById(String id) {
        return dynamoDBMapper.load(Product.class, id);
    }

    public List<Product> findAll() {
        return dynamoDBMapper.scan(Product.class, new DynamoDBScanExpression());
    }

    public void deleteById(String id) {
        Product product = dynamoDBMapper.load(Product.class, id);
        if (product != null) {
            dynamoDBMapper.delete(product);
        }
    }
}