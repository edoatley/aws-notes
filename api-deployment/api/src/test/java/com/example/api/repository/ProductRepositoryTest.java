package com.example.api.repository;

import com.example.api.model.Product;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.ActiveProfiles;

import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;

@SpringBootTest
@ActiveProfiles("test")
public class ProductRepositoryTest {

    @Autowired
    private ProductRepository productRepository;

    @Test
    void shouldSaveAndRetrieveProduct() {
        // given
        Product product = new Product("1", "Test Product", "Test Description", 99.99);

        // when
        productRepository.save(product);
        Product retrievedProduct = productRepository.findById("1");

        // then
        assertThat(retrievedProduct).isNotNull();
        assertThat(retrievedProduct.getId()).isEqualTo(product.getId());
        assertThat(retrievedProduct.getName()).isEqualTo(product.getName());
        assertThat(retrievedProduct.getDescription()).isEqualTo(product.getDescription());
        assertThat(retrievedProduct.getPrice()).isEqualTo(product.getPrice());
    }

    @Test
    void shouldFindAllProducts() {
        // given
        Product product1 = new Product("1", "Product 1", "Description 1", 99.99);
        Product product2 = new Product("2", "Product 2", "Description 2", 149.99);
        productRepository.save(product1);
        productRepository.save(product2);

        // when
        List<Product> products = productRepository.findAll();

        // then
        assertThat(products).hasSize(2);
        assertThat(products).extracting("id").containsExactlyInAnyOrder("1", "2");
    }

    @Test
    void shouldDeleteProduct() {
        // given
        Product product = new Product("1", "Test Product", "Test Description", 99.99);
        productRepository.save(product);

        // when
        productRepository.deleteById("1");

        // then
        Product deletedProduct = productRepository.findById("1");
        assertThat(deletedProduct).isNull();
    }
}