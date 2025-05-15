package com.example.api.controller;

import com.example.api.ProductApiApplication;
import com.example.api.config.TestDynamoDBConfig;
import com.example.api.model.Product;
import com.example.api.repository.ProductRepository;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;
import static org.hamcrest.Matchers.*;

@SpringBootTest(classes = {TestDynamoDBConfig.class, ProductApiApplication.class})
@AutoConfigureMockMvc
public class ProductControllerTest {

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

        mockMvc.perform(post("/api/products")
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

        mockMvc.perform(get("/api/products/1"))
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

        mockMvc.perform(get("/api/products"))
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

        mockMvc.perform(put("/api/products/1")
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

        mockMvc.perform(delete("/api/products/1"))
                .andExpect(status().isOk());

        mockMvc.perform(get("/api/products/1"))
                .andExpect(status().isNotFound());
    }
}