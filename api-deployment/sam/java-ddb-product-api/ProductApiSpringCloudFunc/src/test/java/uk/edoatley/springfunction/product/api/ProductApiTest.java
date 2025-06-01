package uk.edoatley.springfunction.product.api;

import com.amazonaws.services.lambda.runtime.events.APIGatewayProxyRequestEvent;
import com.amazonaws.services.lambda.runtime.events.APIGatewayProxyResponseEvent;
import com.fasterxml.jackson.core.type.TypeReference;
import uk.edoatley.springfunction.product.api.model.Product;
import uk.edoatley.springfunction.product.api.repository.ProductRepository;
import com.fasterxml.jackson.databind.ObjectMapper;

import software.amazon.awssdk.auth.credentials.AwsBasicCredentials;
import software.amazon.awssdk.auth.credentials.StaticCredentialsProvider;
import software.amazon.awssdk.services.dynamodb.DynamoDbClient;
import software.amazon.awssdk.services.dynamodb.model.ResourceNotFoundException;

import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeAll;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.HttpStatus;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;
import org.testcontainers.containers.localstack.LocalStackContainer;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;
import org.testcontainers.utility.DockerImageName;

import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.function.Function;

import static org.junit.jupiter.api.Assertions.*;
import static org.hamcrest.MatcherAssert.assertThat;
import static org.hamcrest.Matchers.*;

@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.NONE) // No web server needed
@Testcontainers
public class ProductApiTest {
    private static final String API_BASE_PATH = "/api/v1/products";
    private static final String API_BYID_PATH = "/api/v1/products/{id}";
    private static final String LOCALSTACK_IMAGE_NAME = "localstack/localstack:4.4.0";
    private static final String TEST_TABLE_NAME = "my-test-table";
    private static final String TEST_TABLE_KEY = "id";

    @Container
    static LocalStackContainer localStack = new LocalStackContainer(DockerImageName.parse(LOCALSTACK_IMAGE_NAME))
            .withServices(LocalStackContainer.Service.DYNAMODB)
            .withReuse(true);

    private static DynamoDbClient dynamoDbClient;

    @DynamicPropertySource
    static void overrideProperties(DynamicPropertyRegistry registry) {
        registry.add("dynamo.endpoint", () -> localStack.getEndpointOverride(LocalStackContainer.Service.DYNAMODB).toString());
        registry.add("dynamo.access-key-id", localStack::getAccessKey);
        registry.add("dynamo.secret-key", localStack::getSecretKey);
        registry.add("dynamo.region", localStack::getRegion);
        registry.add("dynamo.table-name", () -> TEST_TABLE_NAME);
        registry.add("spring.main.web-application-type", () -> "NONE"); // Ensure no web server
    }

    @BeforeAll
    static void beforeAll() {
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
            System.out.println("Table " + TEST_TABLE_NAME + " already exists.");
        } catch (ResourceNotFoundException e) {
            software.amazon.awssdk.services.dynamodb.model.CreateTableRequest createTableRequest = software.amazon.awssdk.services.dynamodb.model.CreateTableRequest.builder()
                    .tableName(TEST_TABLE_NAME)
                    .keySchema(software.amazon.awssdk.services.dynamodb.model.KeySchemaElement.builder().attributeName(TEST_TABLE_KEY).keyType(software.amazon.awssdk.services.dynamodb.model.KeyType.HASH).build())
                    .attributeDefinitions(software.amazon.awssdk.services.dynamodb.model.AttributeDefinition.builder().attributeName(TEST_TABLE_KEY).attributeType(software.amazon.awssdk.services.dynamodb.model.ScalarAttributeType.S).build())
                    .provisionedThroughput(software.amazon.awssdk.services.dynamodb.model.ProvisionedThroughput.builder().readCapacityUnits(5L).writeCapacityUnits(5L).build())
                    .build();
            dynamoDbClient.createTable(createTableRequest);
            dynamoDbClient.waiter().waitUntilTableExists(software.amazon.awssdk.services.dynamodb.model.DescribeTableRequest.builder().tableName(TEST_TABLE_NAME).build());
            System.out.println("Table " + TEST_TABLE_NAME + " created.");
        }
    }

    @Autowired
    private Function<APIGatewayProxyRequestEvent, APIGatewayProxyResponseEvent> handleProductRequest;

    @Autowired
    private ProductRepository productRepository; // Still useful for setup/verification

    @Autowired
    private ObjectMapper objectMapper;

    @AfterEach
    void tearDown() {
        // Clean up data between tests if necessary, e.g., by deleting all items
        // This is important for test independence.
        List<Product> products = productRepository.findAll();
        for (Product p : products) {
            productRepository.deleteById(p.getId());
        }
    }

    @Test
    void shouldCreateProduct() throws Exception {
        Product productToCreate = new Product(null, "Test Product", "Test Description", 99.99); // ID will be generated
        String productJson = objectMapper.writeValueAsString(productToCreate);

        APIGatewayProxyRequestEvent requestEvent = new APIGatewayProxyRequestEvent()
                .withHttpMethod("POST")
                .withPath(API_BASE_PATH)
                .withBody(productJson)
                .withHeaders(Map.of("Content-Type", "application/json"));

        APIGatewayProxyResponseEvent responseEvent = handleProductRequest.apply(requestEvent);

        assertEquals(HttpStatus.CREATED.value(), responseEvent.getStatusCode());
        assertNotNull(responseEvent.getBody());

        Product createdProduct = objectMapper.readValue(responseEvent.getBody(), Product.class);
        assertNotNull(createdProduct.getId());
        assertEquals(productToCreate.getName(), createdProduct.getName());
        assertEquals(productToCreate.getDescription(), createdProduct.getDescription());
        assertEquals(productToCreate.getPrice(), createdProduct.getPrice());
    }

    @Test
    void shouldGetProduct() throws Exception {
        Product product = new Product(UUID.randomUUID().toString(), "Test Product", "Test Description", 99.99);
        productRepository.save(product);

        APIGatewayProxyResponseEvent responseEvent = getProduct(product.getId());

        assertEquals(HttpStatus.OK.value(), responseEvent.getStatusCode());
        System.err.println(responseEvent.getBody());
        Product fetchedProduct = objectMapper.readValue(responseEvent.getBody(), Product.class);
        assertEquals(product.getId(), fetchedProduct.getId());
        assertEquals(product.getName(), fetchedProduct.getName());
    }


    @Test
    void shouldReturnNotFoundForNonExistentProduct() {
        String nonExistentId = UUID.randomUUID().toString();
        APIGatewayProxyResponseEvent responseEvent = getProduct(nonExistentId);
        assertEquals(HttpStatus.NOT_FOUND.value(), responseEvent.getStatusCode());
    }

    @Test
    void shouldGetAllProducts() throws Exception {
        Product product1 = new Product(UUID.randomUUID().toString(), "Product 1", "Description 1", 99.99);
        Product product2 = new Product(UUID.randomUUID().toString(), "Product 2", "Description 2", 149.99);
        productRepository.save(product1);
        productRepository.save(product2);

        APIGatewayProxyRequestEvent requestEvent = new APIGatewayProxyRequestEvent()
                .withHttpMethod("GET")
                .withPath(API_BASE_PATH);

        APIGatewayProxyResponseEvent responseEvent = handleProductRequest.apply(requestEvent);

        assertEquals(HttpStatus.OK.value(), responseEvent.getStatusCode());
        List<Product> products = objectMapper.readValue(responseEvent.getBody(), new TypeReference<List<Product>>() {});
        assertEquals(2, products.size());
        assertThat(products, containsInAnyOrder(
                hasProperty("id", equalTo(product1.getId())),
                hasProperty("id", equalTo(product2.getId()))
        ));
    }

    @Test
    void shouldUpdateProduct() throws Exception {
        Product product = new Product(UUID.randomUUID().toString(), "Test Product", "Test Description", 99.99);
        productRepository.save(product);

        Product updatedDetails = new Product(null, "Updated Product", "Updated Description", 149.99);
        String updatedProductJson = objectMapper.writeValueAsString(updatedDetails);

        APIGatewayProxyRequestEvent requestEvent = new APIGatewayProxyRequestEvent()
                .withHttpMethod("PUT")
                .withPath(API_BYID_PATH)
                .withPathParameters(Map.of("id", product.getId()))
                .withHeaders(Map.of("Content-Type", "application/json"))
                .withBody(updatedProductJson);

        APIGatewayProxyResponseEvent responseEvent = handleProductRequest.apply(requestEvent);

        assertEquals(HttpStatus.OK.value(), responseEvent.getStatusCode());
        Product resultProduct = objectMapper.readValue(responseEvent.getBody(), Product.class);
        assertEquals(product.getId(), resultProduct.getId()); // ID should remain the same
        assertEquals(updatedDetails.getName(), resultProduct.getName());
        assertEquals(updatedDetails.getPrice(), resultProduct.getPrice());
    }

    @Test
    void shouldReturnNotFoundWhenUpdatingNonExistentProduct() throws Exception {
        String nonExistentId = UUID.randomUUID().toString();
        Product updatedDetails = new Product(null, "Updated Product", "Updated Description", 149.99);
        String updatedProductJson = objectMapper.writeValueAsString(updatedDetails);

        APIGatewayProxyRequestEvent requestEvent = new APIGatewayProxyRequestEvent()
                .withHttpMethod("PUT")
                .withPath(API_BYID_PATH)
                .withPathParameters(Map.of("id", nonExistentId))
                .withHeaders(Map.of("Content-Type", "application/json"))
                .withBody(updatedProductJson);

        APIGatewayProxyResponseEvent responseEvent = handleProductRequest.apply(requestEvent);
        assertEquals(HttpStatus.NOT_FOUND.value(), responseEvent.getStatusCode());
    }


    @Test
    void shouldDeleteProduct() throws Exception {
        // Add a product
        Product product = new Product(UUID.randomUUID().toString(), "Test Product", "Test Description", 99.99);
        productRepository.save(product);

        // Delete the product
        APIGatewayProxyResponseEvent deleteResponseEvent = deleteProduct(product.getId());
        assertEquals(HttpStatus.NO_CONTENT.value(), deleteResponseEvent.getStatusCode());

        // Verify deletion
        APIGatewayProxyResponseEvent getResponseEvent = getProduct(product.getId());
        assertEquals(HttpStatus.NOT_FOUND.value(), getResponseEvent.getStatusCode());
    }

    @Test
    void shouldReturnNotFoundWhenDeletingNonExistentProduct() {
        String nonExistentId = UUID.randomUUID().toString();
        APIGatewayProxyResponseEvent responseEvent = deleteProduct(nonExistentId);
        assertEquals(HttpStatus.NOT_FOUND.value(), responseEvent.getStatusCode());
    }

    // Helper method to simplify GET requests
    private APIGatewayProxyResponseEvent deleteProduct(String id) {
        APIGatewayProxyRequestEvent requestEvent = new APIGatewayProxyRequestEvent()
                .withHttpMethod("DELETE")
                .withPath(API_BYID_PATH)
                .withPathParameters(Map.of("id", id));
        return handleProductRequest.apply(requestEvent);
    }
    // Helper method to simplify DELETE requests
    private APIGatewayProxyResponseEvent getProduct(String id) {
        APIGatewayProxyRequestEvent requestEvent = new APIGatewayProxyRequestEvent()
                .withHttpMethod("GET")
                .withPath(API_BYID_PATH)
                .withPathParameters(Map.of("id", id));
        return handleProductRequest.apply(requestEvent);
    }
}