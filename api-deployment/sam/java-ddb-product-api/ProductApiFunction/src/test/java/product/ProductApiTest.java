package product;

import com.amazonaws.services.lambda.runtime.events.APIGatewayProxyRequestEvent;
import com.amazonaws.services.lambda.runtime.events.APIGatewayProxyResponseEvent;
import org.junit.jupiter.api.Test;
import product.ProductApiApp;

import static org.junit.jupiter.api.Assertions.*;



public class ProductApiTest {

  final private ProductApiApp classUnderTest = new ProductApiApp();

  @Test
  void shouldReturnValidGetResponse() {
    APIGatewayProxyRequestEvent event = new APIGatewayProxyRequestEvent();
    event.setHttpMethod("GET");

    APIGatewayProxyResponseEvent result = classUnderTest.handleRequest(event, null);
    String content = result.getBody();

    assertAll(
            () -> assertNotNull(content),
            () -> assertEquals(200, result.getStatusCode().intValue()),
            () -> assertEquals("application/json", result.getHeaders().get("Content-Type")),
            () -> assertTrue(content.contains("\"message\"")),
            () -> assertTrue(content.contains("\"Hello World\"")),
            () -> assertTrue(content.contains("\"GET\"")),
            () -> assertTrue(content.contains("\"location\""))
    );
  }
  @Test
  void shouldReturnValidPutResponse() {
    APIGatewayProxyRequestEvent event = new APIGatewayProxyRequestEvent();
    event.setHttpMethod("PUT");

    APIGatewayProxyResponseEvent result = classUnderTest.handleRequest(event, null);
    String content = result.getBody();

    assertAll(
            () -> assertNotNull(content),
            () -> assertEquals(200, result.getStatusCode().intValue()),
            () -> assertEquals("application/json", result.getHeaders().get("Content-Type")),
            () -> assertTrue(content.contains("\"message\"")),
            () -> assertTrue(content.contains("\"Hello World!!!\"")),
            () -> assertTrue(content.contains("\"PUT\"")),
            () -> assertTrue(content.contains("\"location\""))
    );
  }
}
