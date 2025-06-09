package com.example.api.controller;

import com.example.api.model.Product;
import com.example.api.repository.ProductRepository;
import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.UUID;

@Slf4j
@RestController
@RequiredArgsConstructor
@RequestMapping("/api/v1/products")
public class ProductController {

    private final ProductRepository productRepository;
    private final ObjectMapper mapper;

    @PostMapping
    public ResponseEntity<Product> createProduct(@RequestBody String productString) {
        Product product = null;
        try {
            product = mapper.readValue(productString, Product.class);
        } catch (JsonProcessingException e) {
            log.error("Error parsing product JSON", e);
            return ResponseEntity.badRequest().build();
        }
        // If the product ID is not provided in the request body, generate one.
        if (product.getId() == null || product.getId().trim().isEmpty()) {
            product.setId(UUID.randomUUID().toString());
        }
        Product savedProduct = productRepository.save(product);
        return ResponseEntity.ok(savedProduct);
    }

    @GetMapping("/{id}")
    public ResponseEntity<Product> getProductById(@PathVariable("id") String id) {
        Product product = productRepository.findById(id);
        if (product != null) {
            return ResponseEntity.ok(product);
        }
        return ResponseEntity.notFound().build();
    }

    @GetMapping
    public List<Product> getAllProducts() {
        return productRepository.findAll();
    }

    @PutMapping("/{id}")
    public ResponseEntity<Product> updateProduct(@PathVariable("id") String id, @RequestBody String productString) {
        Product product = null;
        try {
            product = mapper.readValue(productString, Product.class);
        } catch (JsonProcessingException e) {
            log.error("Error parsing product JSON", e);
            return ResponseEntity.badRequest().build();
        }

        Product existingProduct = productRepository.findById(id);
        if (existingProduct != null) {
            product.setId(id);
            return ResponseEntity.ok(productRepository.save(product));
        }
        return ResponseEntity.notFound().build();
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> deleteProduct(@PathVariable("id") String id) {
        Product existingProduct = productRepository.findById(id);
        if (existingProduct != null) {
            productRepository.deleteById(id);
            return ResponseEntity.noContent().build();
        }
        return ResponseEntity.notFound().build();
    }
}