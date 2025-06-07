package uk.edoatley.springfunction.product.api;

import uk.edoatley.springfunction.product.api.config.DynamoProperties;
import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.boot.context.properties.EnableConfigurationProperties;

@Slf4j
@SpringBootApplication
@EnableConfigurationProperties(DynamoProperties.class)
public class ProductApiApplication {

    public static void main(String[] args) {
        // This main method allows running it as a standard Spring Boot app (e.g., for local testing if needed)
        // However, for Lambda, spring.main.web-application-type=none is set.
        SpringApplication.run(ProductApiApplication.class, args);
    }

}