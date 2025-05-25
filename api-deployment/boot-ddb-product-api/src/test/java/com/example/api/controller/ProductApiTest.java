package com.example.api.controller;

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
@Testcontainers
public class ProductApiTest {
    private static final String API_PRODUCTS = "/api/v1/products";
    private static final String LOCALSTACK_IMAGE_NAME = "localstack/localstack:3.3.0"; // Or your desired version
    private static final String TEST_TABLE_NAME = "my-test-table";
    private static final String TEST_TABLE_KEY = "id";
    
    @Container
    static LocalStackContainer localStack = new LocalStackContainer(DockerImageName.parse(LOCALSTACK_IMAGE_NAME))
            .withServices(LocalStackContainer.Service.DYNAMODB)
            // You can add .withEnv("DEBUG", "1") for more LocalStack logs
            .withReuse(true); // Good for speeding up local test runs

    private static DynamoDbClient dynamoDbClient; // AWS SDK v2 client

    @DynamicPropertySource
    static void overrideProperties(DynamicPropertyRegistry registry) {
        registry.add("dynamo.endpoint", () -> localStack.getEndpointOverride(LocalStackContainer.Service.DYNAMODB).toString());
        registry.add("dynamo.access-key-id", localStack::getAccessKey);
        registry.add("dynamo.secret-key", localStack::getSecretKey);
        registry.add("dynamo.region", localStack::getRegion);
        registry.add("dynamo.table-name", () -> TEST_TABLE_NAME);
    }

    @BeforeAll
    static void beforeAll() {
        // Initialize the DynamoDbClient to interact with LocalStack
        dynamoDbClient = DynamoDbClient.builder()
                .endpointOverride(localStack.getEndpointOverride(LocalStackContainer.Service.DYNAMODB))
                .credentialsProvider(StaticCredentialsProvider.create(
                        AwsBasicCredentials.create(localStack.getAccessKey(), localStack.getSecretKey())))
                .region(software.amazon.awssdk.regions.Region.of(localStack.getRegion()))
                .build();
        try {
            dynamoDbClient.describeTable(software.amazon.awssdk.services.dynamodb.model.DescribeTableRequest.builder()
                    .tableName(TEST_TABLE_NAME)
                    .build());
            // Table exists, optionally delete and recreate or just use it
            System.out.println("Table " + TEST_TABLE_NAME + " already exists.");
        } catch (ResourceNotFoundException e) {
            software.amazon.awssdk.services.dynamodb.model.CreateTableRequest createTableRequest = software.amazon.awssdk.services.dynamodb.model.CreateTableRequest.builder()
                    .tableName(TEST_TABLE_NAME)
                    .keySchema(software.amazon.awssdk.services.dynamodb.model.KeySchemaElement.builder().attributeName(TEST_TABLE_KEY).keyType(software.amazon.awssdk.services.dynamodb.model.KeyType.HASH).build())
                    .attributeDefinitions(software.amazon.awssdk.services.dynamodb.model.AttributeDefinition.builder().attributeName(TEST_TABLE_KEY).attributeType(software.amazon.awssdk.services.dynamodb.model.ScalarAttributeType.S).build())
                    .provisionedThroughput(software.amazon.awssdk.services.dynamodb.model.ProvisionedThroughput.builder().readCapacityUnits(5L).writeCapacityUnits(5L).build())
                    .build();
            dynamoDbClient.createTable(createTableRequest);
            // Wait for table to become active
            dynamoDbClient.waiter().waitUntilTableExists(software.amazon.awssdk.services.dynamodb.model.DescribeTableRequest.builder().tableName(TEST_TABLE_NAME).build());
            System.out.println("Table " + TEST_TABLE_NAME + " created.");
        }
    }
    
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