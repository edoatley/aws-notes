package product;

import com.amazonaws.services.lambda.runtime.Context;
import com.amazonaws.services.lambda.runtime.RequestHandler;
import com.amazonaws.services.lambda.runtime.events.APIGatewayProxyRequestEvent;
import com.amazonaws.services.lambda.runtime.events.APIGatewayProxyResponseEvent;
import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import product.exception.ProductNotFoundException;
import product.model.Product;
import product.persist.ProductDatastore;
import product.persist.ProductDynamoDbStore;
import software.amazon.awssdk.http.HttpStatusCode;

import java.util.HashMap;
import java.util.Map;
import java.util.Optional;
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
                case "GET" -> handleGetRequest(input, context);
                case "POST" -> handlePostRequest(input, context);
                case "PUT" -> handlePutRequest(input, context);
                case "DELETE" -> handleDeleteRequest(input, context);
                default -> createErrorResponse(HttpStatusCode.METHOD_NOT_ALLOWED, "Unsupported HTTP method: " + httpMethod, context);
            };
        }
        catch (ProductNotFoundException e) {
             log(context, () -> "Product Not Found: " + e.getMessage());
             return createErrorResponse(HttpStatusCode.NOT_FOUND, e.getMessage(), context);
        }
        catch (JsonProcessingException e) {
            log(context, () -> "JSON Processing Error: " + e.getMessage());
            return createErrorResponse(HttpStatusCode.BAD_REQUEST, "Invalid request format: " + e.getMessage(), context);
        }
        catch (IllegalArgumentException e) { // Example for other validation errors
            log(context, () -> "Illegal Argument Error: " + e.getMessage());
            return createErrorResponse(HttpStatusCode.BAD_REQUEST, "Invalid input: " + e.getMessage(), context);
        }
        catch (Exception e) { // Catch-all for unexpected errors
            log(context, () -> "Internal Server Error: " + e.getMessage());
            return createErrorResponse(HttpStatusCode.INTERNAL_SERVER_ERROR, "An internal server error occurred.", context);
        }
    }


    /**
     * Handles GET requests. Differentiates between fetching all products and a specific product by ID.
     */
    private APIGatewayProxyResponseEvent handleGetRequest(APIGatewayProxyRequestEvent input, Context context) throws JsonProcessingException, ProductNotFoundException {
        Optional<String> productIdOpt = getProductIdFromPath(input);

        if (productIdOpt.isPresent()) {
            return getProductById(productIdOpt.get(), context);
        } else {
            return getAllProducts(context);
        }
    }

    /**
     * Fetches a specific product by its ID from the datastore.
     */
    private APIGatewayProxyResponseEvent getProductById(String productId, Context context) throws JsonProcessingException, ProductNotFoundException {
        log(context, () -> "Fetching product by ID: " + productId);
        Product product = productDatastore.getProductById(productId);
        return createSuccessResponse(HttpStatusCode.OK, getProductAsString(product));
    }

    private static String getProductAsString(Product product) throws JsonProcessingException {
        return MAPPER.writeValueAsString(product);
    }

    /**
     * Fetches all products from the datastore.
     */
    private APIGatewayProxyResponseEvent getAllProducts(Context context) throws JsonProcessingException {
        log(context, () -> "Fetching all products.");
        String content = MAPPER.writeValueAsString(productDatastore.listProducts());
        return createSuccessResponse(HttpStatusCode.OK, content);
    }

    /**
     * Handles POST requests for creating a new product.
     */
    private APIGatewayProxyResponseEvent handlePostRequest(APIGatewayProxyRequestEvent input, Context context) throws JsonProcessingException, ProductNotFoundException {
        Product product = parseProductFromRequestBody(input);
        // For POST, we typically don't expect an ID in the product body, or if present, it might be ignored
        // and a new one generated by the datastore or here.
        // The current MockProductDatastore and DynamoProductDatastore handle ID generation if not present.
        Product savedProduct = productDatastore.saveProduct(product);
        return createSuccessResponse(HttpStatusCode.CREATED, getProductAsString(savedProduct));
    }

    /**
     * Handles DELETE requests for deleting a product by ID.
     */
    private APIGatewayProxyResponseEvent handleDeleteRequest(APIGatewayProxyRequestEvent input, Context context) throws ProductNotFoundException {
        String productId = getProductIdFromPath(input)
                .orElseThrow(() -> new IllegalArgumentException("Product ID is required in the path for DELETE."));

        productDatastore.deleteProduct(productId);
        return createSuccessResponse(HttpStatusCode.NO_CONTENT, ""); // Or 200 OK with a confirmation message
    }

    /**
     * Extracts the product identifier from the path if possible
     *
     * @param input APIGatewayProxyRequestEvent object containing the path
     * @return an optional containing the id if it exists, empty otherwise
     */
    private Optional<String> getProductIdFromPath(APIGatewayProxyRequestEvent input) {
        Map<String, String> pathParameters = input.getPathParameters();
        if (pathParameters != null) {
            return Optional.ofNullable(pathParameters.get("id"));
        }
        return Optional.empty();
    }

    /**
     * Parses a {@link Product} from the request body.
     *
     * @throws IllegalArgumentException if the request body is empty.
     * @throws JsonProcessingException  if the body cannot be parsed into a Product.
     */
    private Product parseProductFromRequestBody(APIGatewayProxyRequestEvent input) throws JsonProcessingException {
        String requestBody = input.getBody();
        if (requestBody == null || requestBody.trim().isEmpty()) {
            throw new IllegalArgumentException("Request body cannot be empty.");
        }
        return MAPPER.readValue(requestBody, Product.class);
    }


    /**
     * Handles PUT requests for updating an existing product.
     */
    private APIGatewayProxyResponseEvent handlePutRequest(APIGatewayProxyRequestEvent input, Context context) throws JsonProcessingException, ProductNotFoundException {
        String productId = getProductIdFromPath(input)
                .orElseThrow(() -> new IllegalArgumentException("Product ID is required in the path for PUT."));

        Product productToUpdate = parseProductFromRequestBody(input);
        productToUpdate.setId(productId); // Ensure the ID from the path is used for the update

        Product updatedProduct = productDatastore.updateProduct(productToUpdate);
        return createSuccessResponse(HttpStatusCode.OK, getProductAsString(updatedProduct));
    }

    /**
     * Logs a message using the Lambda context logger or a default logger.
     *
     * @param context The Lambda execution context.
     * @param message A supplier for the message string (for lazy evaluation).
     */
    private void log(Context context, Supplier<String> message) {
        if (context != null) {
            context.getLogger().log(message.get());
        } else {
            DEFAULT_LOGGER.info(message.get());
        }
    }


    /**
     * Creates a standard success API Gateway response.
     *
     * @param statusCode The HTTP status code.
     * @param body       The response body string.
     * @return An {@link APIGatewayProxyResponseEvent}.
     */
    private APIGatewayProxyResponseEvent createSuccessResponse(int statusCode, String body) {
        return new APIGatewayProxyResponseEvent()
                .withStatusCode(statusCode)
                .withHeaders(getCommonHeaders())
                .withBody(body);
    }

    /**
     * Creates a standard error API Gateway response.
     *
     * @param statusCode   The HTTP status code.
     * @param errorMessage The error message.
     * @param context      The Lambda execution context (for logging).
     * @return An {@link APIGatewayProxyResponseEvent}.
     */
    private APIGatewayProxyResponseEvent createErrorResponse(int statusCode, String errorMessage, final Context context) {
        log(context, () -> "Error response: " + statusCode + " - " + errorMessage);
        return new APIGatewayProxyResponseEvent()
                .withStatusCode(statusCode)
                .withHeaders(getCommonHeaders())
                .withBody("{\"error\": \"" + errorMessage + "\"}");
    }

    /**
     * Provides common HTTP headers for responses.
     *
     * @return A map of common headers.
     */
    private static Map<String, String> getCommonHeaders() {
        Map<String, String> headers = new HashMap<>();
        headers.put("Content-Type", "application/json");
        return headers;
    }
}