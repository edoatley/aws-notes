package product;

import java.io.BufferedReader;
import java.io.IOException;
import java.io.InputStreamReader;
import java.net.URL;
import java.util.HashMap;
import java.util.Map;
import java.util.stream.Collectors;

import com.amazonaws.services.lambda.runtime.Context;
import com.amazonaws.services.lambda.runtime.RequestHandler;
import com.amazonaws.services.lambda.runtime.events.APIGatewayProxyRequestEvent;
import com.amazonaws.services.lambda.runtime.events.APIGatewayProxyResponseEvent;

/**
 * Handler for requests to Lambda function.
 */
public class ProductApiApp implements RequestHandler<APIGatewayProxyRequestEvent, APIGatewayProxyResponseEvent> {

    public APIGatewayProxyResponseEvent handleRequest(final APIGatewayProxyRequestEvent input, final Context context) {
        Map<String, String> headers = new HashMap<>();
        headers.put("Content-Type", "application/json");
        headers.put("X-Custom-Header", "application/json");
        APIGatewayProxyResponseEvent response = new APIGatewayProxyResponseEvent().withHeaders(headers);

        String output = "";

        try {
            output = switch (input.getHttpMethod()) {
                case "GET" -> this.get();
                case "PUT" -> this.put();
                default -> "{}";
            };
            return response
                    .withStatusCode(200)
                    .withBody(output);
        } catch (IOException e) {
            return response
                    .withBody("{}")
                    .withStatusCode(500);
        }
    }

    private String get() throws IOException {
        final String ip = this.getPageContents("https://checkip.amazonaws.com");
        return String.format("""
                {
                  "location": %s,
                  "method": "GET",
                  "message": "Hello World"
                }
                """, ip);
    }
    private String put() throws IOException {
        final String ip = this.getPageContents("https://checkip.amazonaws.com");
        return String.format("""
                {
                  "location": %s,
                  "method": "PUT",
                  "message": "Hello World!!!"
                }
                """, ip);
    }


    private String getPageContents(String address) throws IOException{
        URL url = new URL(address);
        try(BufferedReader br = new BufferedReader(new InputStreamReader(url.openStream()))) {
            return br.lines().collect(Collectors.joining(System.lineSeparator()));
        }
    }
}
