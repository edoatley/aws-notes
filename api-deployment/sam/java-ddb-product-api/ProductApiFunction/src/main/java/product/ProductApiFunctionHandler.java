package product;

import com.amazonaws.services.lambda.runtime.Context;
import com.amazonaws.services.lambda.runtime.RequestHandler;
import com.amazonaws.services.lambda.runtime.events.APIGatewayProxyRequestEvent;
import com.amazonaws.services.lambda.runtime.events.APIGatewayProxyResponseEvent;
import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import product.model.Product;
import product.persist.ProductDatastore;
import product.persist.ProductDynamoDbStore;
import java.util.HashMap;
import java.util.Map;
import java.util.UUID;
import java.util.function.Supplier;
import java.util.logging.Logger;

public class ProductApiFunctionHandler implements RequestHandler<APIGatewayProxyRequestEvent, APIGatewayProxyResponseEvent> {

    private static final Logger DEFAULT_LOGGER = Logger.getLogger(ProductApiFunctionHandler.class.getName());
    private static final ObjectMapper MAPPER = new ObjectMapper();
    private ProductDatastore productDatastore;

    // Constructor for production
    public ProductApiFunctionHandler() {
        String dynamoTableName = System.getenv("DYNAMO_TABLENAME");
        if (dynamoTableName == null || dynamoTableName.trim().isEmpty()) {
            String errorMessage = "DYNAMO_TABLENAME environment variable is not set or is empty.";
            System.err.println("ERROR: " + errorMessage); // Print to stderr
            DEFAULT_LOGGER.severe(errorMessage);
        }
        this.productDatastore = new ProductDynamoDbStore(dynamoTableName);
    }

    // Constructor for dependency injection (e.g., for testing)
    public ProductApiFunctionHandler(ProductDatastore productDatastore) {
        this.productDatastore = productDatastore;
    }

    @Override
    public APIGatewayProxyResponseEvent handleRequest(final APIGatewayProxyRequestEvent input, final Context context) {
        try {
            String httpMethod = input.getHttpMethod();
            log(context, () -> "Received " + httpMethod + " request for path: " + input.getPath());

            return switch (httpMethod) {
                case "GET" -> getProducts(input, context);
                case "PUT" -> putProduct(input, context);
                default -> createErrorResponse(405, "Unsupported HTTP method: " + httpMethod, context);
            };
        }
        catch (JsonProcessingException e) {
            log(context, () -> "JSON Processing Error: " + e.getMessage());
            return createErrorResponse(400, "Invalid request format: " + e.getMessage(), context);
        }
        catch (IllegalArgumentException e) { // Example for other validation errors
            log(context, () -> "Illegal Argument Error: " + e.getMessage());
            return createErrorResponse(400, "Invalid input: " + e.getMessage(), context);
        }
        catch (Exception e) { // Catch-all for unexpected errors
            log(context, () -> "Internal Server Error: " + e.getMessage());
            return createErrorResponse(500, "An internal server error occurred.", context);
        }
    }

    private APIGatewayProxyResponseEvent getProducts(APIGatewayProxyRequestEvent input, final Context context) throws JsonProcessingException {
        // Here you could check input.getPathParameters() if you were to implement GET /products/{id}
        // For now, it lists all products
        log(context, () -> "Fetching all products.");
        String content = MAPPER.writeValueAsString(productDatastore.listProducts());
        return createSuccessResponse(200, content);
    }

    private APIGatewayProxyResponseEvent putProduct(APIGatewayProxyRequestEvent input, final Context context) throws JsonProcessingException {
        String requestBody = input.getBody();
        if (requestBody == null || requestBody.trim().isEmpty()) {
            return createErrorResponse(400, "Request body cannot be empty for PUT.", context);
        }

        Product productToSave = MAPPER.readValue(requestBody, Product.class);
        String productIdFromPath = (input.getPathParameters() != null) ? input.getPathParameters().get("id") : null;
        int statusCode = 200; // Default to OK for update

        if (productIdFromPath != null) {
            productToSave.setId(productIdFromPath); // Honor ID from path for update
            log(context, () -> "Updating product with ID from path: " + productIdFromPath);
        }
        else if (productToSave.getId() == null || productToSave.getId().trim().isEmpty()) {
            productToSave.setId(UUID.randomUUID().toString());
            statusCode = 201; // Created
            log(context, () -> "Creating new product with generated ID: " + productToSave.getId());
        }
        else {
            // ID provided in body, assume update
            log(context, () -> "Updating product with ID from body: " + productToSave.getId());
        }

        Product savedProduct = productDatastore.saveProduct(productToSave); // saveProduct should handle create vs update
        String responseBody = MAPPER.writeValueAsString(savedProduct);
        return createSuccessResponse(statusCode, responseBody);
    }

    // Helper to log messages
    private void log(Context context, Supplier<String> message) {
        if (context != null) {
            context.getLogger().log(message.get());
        } else {
            DEFAULT_LOGGER.info(message.get());
        }
    }

    // Helper to create standard success responses
    private APIGatewayProxyResponseEvent createSuccessResponse(int statusCode, String body) {
        return new APIGatewayProxyResponseEvent()
                .withStatusCode(statusCode)
                .withHeaders(getCommonHeaders())
                .withBody(body);
    }

    // Helper to create standard error responses
    private APIGatewayProxyResponseEvent createErrorResponse(int statusCode, String errorMessage, final Context context) {
        log(context, () -> "Error response: " + statusCode + " - " + errorMessage);
        return new APIGatewayProxyResponseEvent()
                .withStatusCode(statusCode)
                .withHeaders(getCommonHeaders())
                .withBody("{\"error\": \"" + errorMessage + "\"}");
    }

    // Helper for common headers
    private static Map<String, String> getCommonHeaders() {
        Map<String, String> headers = new HashMap<>();
        headers.put("Content-Type", "application/json");
        return headers;
    }
}