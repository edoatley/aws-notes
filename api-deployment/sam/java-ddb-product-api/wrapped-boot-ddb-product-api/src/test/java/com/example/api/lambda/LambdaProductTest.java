package com.example.api.lambda;

import com.amazonaws.serverless.proxy.model.*;
import com.example.api.AbstractDynamoDbTest;
import com.example.api.handler.LambdaHandler;
import com.example.api.model.Product;
import com.example.api.repository.ProductRepository;
import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.HttpMethod;

import java.io.IOException;
import java.util.List;
import java.util.UUID;
import static org.junit.jupiter.api.Assertions.*;

@SpringBootTest
public class LambdaProductTest extends AbstractDynamoDbTest {

    @Autowired
    private ProductRepository productRepository;

    @Autowired
    private ObjectMapper objectMapper;

    @Test
    void shouldReturnEmptyProductListWhenTableIsEmpty() throws IOException {
        LambdaHandler lambdaHandler = new LambdaHandler();

        AwsProxyRequest req = createRequest("/api/v1/products", HttpMethod.GET.name(), null);
        AwsProxyResponse resp = lambdaHandler.handleRequest(req, null);

        assertNotNull(resp.getBody(), "Response body should not be null");
        assertEquals(200, resp.getStatusCode(), "Status code should be 200");
        assertEquals("[]", resp.getBody(), "Response body should be an empty JSON array");
    }

    @Test
    void shouldGetProductWhenPresent() throws Exception {
        LambdaHandler lambdaHandler = new LambdaHandler();
        Product product = new Product("1", "Test Product", "Test Description", 99.99);
        productRepository.save(product);

        AwsProxyRequest req = createRequest("/api/v1/products/1", HttpMethod.GET.name(), null);
        AwsProxyResponse resp = lambdaHandler.handleRequest(req, null);

        Product retrievedProduct = objectMapper.readValue(resp.getBody(), new TypeReference<>() {});

        assertAll(
                () -> assertEquals(200, resp.getStatusCode()),
                () -> assertNotNull(retrievedProduct),
                () -> assertEquals(product, retrievedProduct)
        );
    }

    @Test
    void shouldGetAllProducts() throws Exception {
        LambdaHandler lambdaHandler = new LambdaHandler();
        Product product1 = new Product("1", "Product 1", "Description 1", 99.99);
        Product product2 = new Product("2", "Product 2", "Description 2", 149.99);
        productRepository.save(product1);
        productRepository.save(product2);

        AwsProxyRequest req = createRequest("/api/v1/products", HttpMethod.GET.name(), null);
        AwsProxyResponse resp = lambdaHandler.handleRequest(req, null);

        List<Product> products = objectMapper.readValue(resp.getBody(), new TypeReference<>() {});

        assertAll(
                () -> assertEquals(200, resp.getStatusCode()),
                () -> assertNotNull(products),
                () -> assertFalse(products.isEmpty(), "Should return at least one product from mock"),
                () -> assertTrue(products.contains(product1)),
                () -> assertTrue(products.contains(product2))
        );
    }

    @Test
    void shouldUpdateProduct() throws Exception {
        LambdaHandler lambdaHandler = new LambdaHandler();
        Product product = new Product("1", "Test Product", "Test Description", 99.99);
        productRepository.save(product);

        Product updatedProduct = new Product("1", "Updated Product", "Updated Description", 149.99);
        String updatedProductJson = objectMapper.writeValueAsString(updatedProduct);
        AwsProxyRequest req = createRequest("/api/v1/products/1", HttpMethod.PUT.name(), updatedProductJson);
        AwsProxyResponse resp = lambdaHandler.handleRequest(req, null);
        assertEquals(200, resp.getStatusCode());

        AwsProxyRequest req2 = createRequest("/api/v1/products/1", HttpMethod.GET.name(), null);
        AwsProxyResponse resp2 = lambdaHandler.handleRequest(req2, null);
        Product retrievedProduct  = objectMapper.readValue(resp2.getBody(), new TypeReference<>() {});

        assertAll(
                () -> assertEquals(200, resp2.getStatusCode()),
                () -> assertEquals(updatedProduct, retrievedProduct)
        );
    }

    /**
     * This method mimics com.amazonaws.serverless.proxy.model.AwsProxyRequestBuilder found here
     * https://github.com/aws/serverless-java-container/blob/main/aws-serverless-java-container-core/src/test/java/com/amazonaws/serverless/proxy/internal/testutils/AwsProxyRequestBuilder.java
     * Unfortunately I could not get this to import correctly likely due to https://github.com/aws/serverless-java-container/blob/main/aws-serverless-java-container-core/pom.xml#L96
     *
     * @param path path for the request
     * @param httpMethod HTTP method
     * @return AwsProxyRequest as requested
     */
    private AwsProxyRequest createRequest(String path, String httpMethod, String body) {
        AwsProxyRequest request = new AwsProxyRequest();
        // Use SingleValueHeaders for simplicity if you don't need multiple values for the same header key
        SingleValueHeaders headers = new SingleValueHeaders();
        request.setHeaders(headers); // Set single-value headers

        // Initialize multiValueHeaders as well, as some internal logic might expect it
        request.setMultiValueHeaders(new Headers());


        request.setHttpMethod(httpMethod);
        request.setPath(path);

        if (body != null) {
            request.setBody(body);
            // Set Content-Type header for requests with a body (e.g., POST, PUT)
            headers.put("Content-Type", "application/json");
        }

        request.setMultiValueQueryStringParameters(new MultiValuedTreeMap<>());
        request.setRequestContext(new AwsProxyRequestContext());
        request.getRequestContext().setRequestId(UUID.randomUUID().toString());
        request.getRequestContext().setExtendedRequestId(UUID.randomUUID().toString());
        request.getRequestContext().setStage("test");
        request.getRequestContext().setProtocol("HTTP/1.1");
        request.getRequestContext().setRequestTimeEpoch(System.currentTimeMillis());
        ApiGatewayRequestIdentity identity = new ApiGatewayRequestIdentity();
        identity.setSourceIp("127.0.0.1");
        request.getRequestContext().setIdentity(identity);
        return request;
    }
}
