package uk.edoatley.springfunction.product.api.function;

import com.amazonaws.services.lambda.runtime.events.APIGatewayProxyRequestEvent;
import com.amazonaws.services.lambda.runtime.events.APIGatewayProxyResponseEvent;
import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.HttpStatus;
import uk.edoatley.springfunction.product.api.model.Product;
import uk.edoatley.springfunction.product.api.repository.ProductRepository;
import uk.edoatley.springfunction.product.api.exception.InvalidPathException;

import java.util.Collections;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.function.Function;

@Slf4j
@Configuration
@RequiredArgsConstructor
public class ProductHandlerFunction {
    private static final String START_OF_PATH = "/api/v1/products";
    private final ProductRepository productRepository;
    private final ObjectMapper objectMapper;

    @Bean
    public Function<APIGatewayProxyRequestEvent, APIGatewayProxyResponseEvent> handleProductRequest() {
        return request -> {
            String httpMethod = request.getHttpMethod();
            String path = request.getPath();
            // Inside handleProductRequest lambda
            Map<String, String> pathParameters = request.getPathParameters() != null ? request.getPathParameters() : Collections.emptyMap();
            String id = pathParameters.get("id"); // id will be null if not present

            log.info("Received {} request for path: {} with id: {}", httpMethod, path, id);

            try {
                validatePath(path, id, httpMethod.toUpperCase());
                switch (httpMethod.toUpperCase()) {
                    case "POST":
                        Product product = objectMapper.readValue(request.getBody(), Product.class);
                        product.setId(java.util.UUID.randomUUID().toString()); // Generate Unique ID
                        Product savedProduct = productRepository.save(product);
                        return createResponse(objectMapper.writeValueAsString(savedProduct), HttpStatus.CREATED);
                    case "GET":
                        if (id == null || id.isEmpty()) {
                            List<Product> products = productRepository.findAll();
                            return createResponse(objectMapper.writeValueAsString(products), HttpStatus.OK);
                        }
                        else {
                            Optional<Product> specificProduct = productRepository.findById(id);
                            if (specificProduct.isPresent()) {
                                return createResponse(objectMapper.writeValueAsString(specificProduct.get()), HttpStatus.OK);
                            } else {
                                return createErrorResponse("Product not found", HttpStatus.NOT_FOUND);
                            }
                        }
                    case "PUT":
                        Product newProductDetails = objectMapper.readValue(request.getBody(), Product.class);
                        Optional<Product> existingProduct = productRepository.findById(id);
                        if (existingProduct.isPresent()) {
                            newProductDetails.setId(id); // Ensure ID from path is used
                            Product updatedProduct = productRepository.save(newProductDetails);
                            return createResponse(objectMapper.writeValueAsString(updatedProduct), HttpStatus.OK);
                        } else {
                            return createErrorResponse("Product not found for update", HttpStatus.NOT_FOUND);
                        }
                    case "DELETE":
                        Optional<Product> productToDelete = productRepository.findById(id);
                        if (productToDelete.isPresent()) {
                            productRepository.deleteById(id);
                            return createResponse("", HttpStatus.NO_CONTENT); // Or OK
                        } else {
                            return createErrorResponse("Product not found for delete", HttpStatus.NOT_FOUND);
                        }
                }
                return createErrorResponse("Unsupported operation: " + httpMethod + " " + path, HttpStatus.METHOD_NOT_ALLOWED);
            } catch (JsonProcessingException e) {
                log.error("JSON processing error", e);
                return createErrorResponse("Invalid JSON format: " + e.getMessage(), HttpStatus.BAD_REQUEST);
            } catch (InvalidPathException e) {
                log.warn("Invalid path or parameters: {}", e.getMessage());
                return createErrorResponse(e.getMessage(), HttpStatus.BAD_REQUEST);
            } catch (Exception e) {
                log.error("Internal server error", e);
                return createErrorResponse("Internal server error: " + e.getMessage(), HttpStatus.INTERNAL_SERVER_ERROR);
            }
        };
    }

    private void validatePath(String path, String id, String httpMethod) throws InvalidPathException {
        if (!path.startsWith(START_OF_PATH)) {
            throw new InvalidPathException("Path must start with " + START_OF_PATH + " but found " + path);
        }
        if ((httpMethod.equals("PUT") || httpMethod.equals("DELETE")) && (id == null || id.isEmpty())) {
            throw new InvalidPathException("ID is required for PUT and DELETE requests");
        }
    }

    private APIGatewayProxyResponseEvent createResponse(String body, HttpStatus statusCode) {
        APIGatewayProxyResponseEvent response = new APIGatewayProxyResponseEvent();
        response.setStatusCode(statusCode.value());
        response.setHeaders(Map.of("Content-Type", "application/json"));
        response.setBody(body);
        return response;
    }

    private APIGatewayProxyResponseEvent createErrorResponse(String errorMessage, HttpStatus statusCode) {
        APIGatewayProxyResponseEvent response = new APIGatewayProxyResponseEvent();
        response.setStatusCode(statusCode.value());
        response.setHeaders(Map.of("Content-Type", "application/json"));
        try {
            response.setBody(objectMapper.writeValueAsString(Map.of("error", errorMessage)));
        } catch (JsonProcessingException e) {
            response.setBody("{\"error\":\"Failed to serialize error message\"}");
        }
        return response;
    }
}
