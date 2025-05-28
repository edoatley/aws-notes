package product;

import com.amazonaws.services.lambda.runtime.events.APIGatewayProxyRequestEvent;
import com.amazonaws.services.lambda.runtime.events.APIGatewayProxyResponseEvent;
import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.core.type.TypeReference;
import org.junit.jupiter.api.Test;
import product.model.Product;
import product.persist.MockProductDatastore;

import static org.junit.jupiter.api.Assertions.*;



public class ProductApiFunctionHandlerTest {
  private final ProductApiFunctionHandler classUnderTest = new ProductApiFunctionHandler(new MockProductDatastore());
  private final ObjectMapper mapper = new ObjectMapper();

  @Test
  void shouldReturnValidGetResponse() throws JsonProcessingException {
    APIGatewayProxyRequestEvent event = new APIGatewayProxyRequestEvent();
    event.setHttpMethod("GET");

    APIGatewayProxyResponseEvent result = classUnderTest.handleRequest(event, null);
    String content = result.getBody();
    Product product = mapper.readValue(content, new TypeReference<Product[]>() {})[0];

    assertAll(
            () -> assertNotNull(content),
            () -> assertEquals(200, result.getStatusCode().intValue()),
            () -> assertEquals("application/json", result.getHeaders().get("Content-Type")),
            () -> assertNotNull(product.getId()),
            () -> assertEquals("Some product", product.getName()),
            () -> assertEquals("This is a simple product", product.getDescription()),
            () -> assertEquals(Double.valueOf("12.99"), product.getPrice())
    );
  }
  @Test
  void createNewProduct() throws JsonProcessingException {
    APIGatewayProxyRequestEvent event = new APIGatewayProxyRequestEvent();
    event.setHttpMethod("PUT");
    Product productToCreate = new Product();
    productToCreate.setId("");
    productToCreate.setName("Test prod");
    productToCreate.setDescription("Describe the prod");
    productToCreate.setPrice(Double.valueOf("1.99"));
    event.setBody(mapper.writeValueAsString(productToCreate));

    APIGatewayProxyResponseEvent result = classUnderTest.handleRequest(event, null);
    String content = result.getBody();
    Product product = mapper.readValue(content, new TypeReference<Product>() {});

    assertAll(
            () -> assertNotNull(content),
            () -> assertEquals(201, result.getStatusCode().intValue()),
            () -> assertEquals("application/json", result.getHeaders().get("Content-Type")),
            () -> assertNotNull(product.getId()),
            () -> assertEquals("Test prod", product.getName()),
            () -> assertEquals("Describe the prod", product.getDescription()),
            () -> assertEquals(Double.valueOf("1.99"), product.getPrice())
    );
  }
}
