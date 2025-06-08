package com.example.api.controller;

import com.example.api.AbstractDynamoDbTest;
import com.example.api.model.Product;
import com.example.api.repository.ProductRepository;
import com.fasterxml.jackson.databind.ObjectMapper;

import software.amazon.awssdk.auth.credentials.AwsBasicCredentials;
import software.amazon.awssdk.auth.credentials.StaticCredentialsProvider;
import software.amazon.awssdk.services.dynamodb.DynamoDbClient;
import software.amazon.awssdk.services.dynamodb.model.ResourceNotFoundException;

import org.junit.jupiter.api.BeforeAll;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;
import org.springframework.test.web.servlet.MockMvc;
import org.testcontainers.containers.localstack.LocalStackContainer;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;
import org.testcontainers.utility.DockerImageName;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;
import static org.hamcrest.Matchers.*;

@SpringBootTest
@AutoConfigureMockMvc
public class ProductApiTest extends AbstractDynamoDbTest {
    private static final String API_PRODUCTS = "/api/v1/products";
    
    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private ProductRepository productRepository;

    @Autowired
    private ObjectMapper objectMapper;

    @Test
    void shouldCreateProduct() throws Exception {
        Product product = new Product("1", "Test Product", "Test Description", 99.99);
        String productJson = objectMapper.writeValueAsString(product);

        mockMvc.perform(post(API_PRODUCTS)
                .contentType(MediaType.APPLICATION_JSON)
                .content(productJson))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.id").value("1"))
                .andExpect(jsonPath("$.name").value("Test Product"))
                .andExpect(jsonPath("$.description").value("Test Description"))
                .andExpect(jsonPath("$.price").value(99.99));
    }

    @Test
    void shouldGetProduct() throws Exception {
        Product product = new Product("1", "Test Product", "Test Description", 99.99);
        productRepository.save(product);

        mockMvc.perform(get(API_PRODUCTS + "/1"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.id").value("1"))
                .andExpect(jsonPath("$.name").value("Test Product"));
    }

    @Test
    void shouldGetAllProducts() throws Exception {
        Product product1 = new Product("1", "Product 1", "Description 1", 99.99);
        Product product2 = new Product("2", "Product 2", "Description 2", 149.99);
        productRepository.save(product1);
        productRepository.save(product2);

        mockMvc.perform(get(API_PRODUCTS))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$", hasSize(2)))
                .andExpect(jsonPath("$[*].id", containsInAnyOrder("1", "2")));
    }

    @Test
    void shouldUpdateProduct() throws Exception {
        Product product = new Product("1", "Test Product", "Test Description", 99.99);
        productRepository.save(product);

        Product updatedProduct = new Product("1", "Updated Product", "Updated Description", 149.99);
        String updatedProductJson = objectMapper.writeValueAsString(updatedProduct);

        mockMvc.perform(put(API_PRODUCTS + "/1")
                .contentType(MediaType.APPLICATION_JSON)
                .content(updatedProductJson))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.name").value("Updated Product"))
                .andExpect(jsonPath("$.price").value(149.99));
    }

    @Test
    void shouldDeleteProduct() throws Exception {
        Product product = new Product("1", "Test Product", "Test Description", 99.99);
        productRepository.save(product);

        mockMvc.perform(delete(API_PRODUCTS + "/1"))
                .andExpect(status().isOk());

        mockMvc.perform(get(API_PRODUCTS + "/1"))
                .andExpect(status().isNotFound());
    }

    @Test
    void shouldReturnHealthy() throws Exception {
        mockMvc.perform(get("/actuator/health"))
               .andExpect(status().isOk())
               .andExpect(jsonPath("$.status").value("UP"));
    }
}