// /Users/edoatley/source/aws-notes/api-deployment/sam/java-ddb-product-api/wrapped-boot-ddb-product-api/src/test/java/com/example/api/AbstractDynamoDbTest.java
package com.example.api; // Assuming this is the correct package

import lombok.extern.slf4j.Slf4j;
import org.junit.jupiter.api.BeforeAll;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;
import org.testcontainers.containers.localstack.LocalStackContainer;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;
import org.testcontainers.utility.DockerImageName;
import software.amazon.awssdk.auth.credentials.AwsBasicCredentials;
import software.amazon.awssdk.auth.credentials.StaticCredentialsProvider;
import software.amazon.awssdk.regions.Region;
import software.amazon.awssdk.services.dynamodb.DynamoDbClient;
import software.amazon.awssdk.services.dynamodb.model.*;

@Testcontainers
public abstract class AbstractDynamoDbTest {

    protected static final String TEST_TABLE_NAME = "my-test-table";
    protected static final String TEST_TABLE_KEY = "id";
    private static final String LOCALSTACK_IMAGE_NAME = "localstack/localstack:3.3.0"; // Or your desired version

    @Container
    // Ensure the container is static to be shared across test methods/classes if needed,
    // and to work correctly with @DynamicPropertySource and static @BeforeAll.
    public static LocalStackContainer localStack = new LocalStackContainer(DockerImageName.parse(LOCALSTACK_IMAGE_NAME))
            .withServices(LocalStackContainer.Service.DYNAMODB)
            .withReuse(true); // Reuse is good for performance

    // This client is for direct use in tests or @BeforeAll setup, not directly by the application context
    protected static DynamoDbClient dynamoDbClientForTestSetup;

    @DynamicPropertySource
    static void overrideProperties(DynamicPropertyRegistry registry) {
        String endpoint = localStack.getEndpointOverride(LocalStackContainer.Service.DYNAMODB).toString();
        String accessKey = localStack.getAccessKey();
        String secretKey = localStack.getSecretKey();
        String region = localStack.getRegion();

        // For Spring context of @SpringBootTest annotated test classes
        registry.add("dynamo.endpoint", () -> endpoint);
        registry.add("dynamo.access-key-id", () -> accessKey);
        registry.add("dynamo.secret-key", () -> secretKey);
        registry.add("dynamo.region", () -> region);
        registry.add("dynamo.table-name", () -> TEST_TABLE_NAME);

        // Also set as system properties for the LambdaHandler's internal Spring context
        // Ensure these property names match exactly what your application's DynamoDBConfig expects
        System.setProperty("dynamo.endpoint", endpoint);
        System.setProperty("dynamo.access-key-id", accessKey);
        System.setProperty("dynamo.secret-key", secretKey);
        System.setProperty("dynamo.region", region);
        System.setProperty("dynamo.table-name", TEST_TABLE_NAME);

        // It can be useful to log these to confirm they are being set with expected values
        System.out.println("AbstractDynamoDbTest: Set system property dynamo.endpoint=" + endpoint);
    }

    @BeforeAll
    static void beforeAll() {
        // Initialize a client for test setup purposes (e.g., creating tables)
        dynamoDbClientForTestSetup = DynamoDbClient.builder()
                .endpointOverride(localStack.getEndpointOverride(LocalStackContainer.Service.DYNAMODB))
                .credentialsProvider(StaticCredentialsProvider.create(
                        AwsBasicCredentials.create(localStack.getAccessKey(), localStack.getSecretKey())))
                .region(Region.of(localStack.getRegion()))
                .build();
        try {
            dynamoDbClientForTestSetup.describeTable(DescribeTableRequest.builder().tableName(TEST_TABLE_NAME).build());
            System.out.println("AbstractDynamoDbTest: Table " + TEST_TABLE_NAME + " already exists.");
        } catch (ResourceNotFoundException e) {
            CreateTableRequest createTableRequest = CreateTableRequest.builder()
                    .tableName(TEST_TABLE_NAME)
                    .keySchema(KeySchemaElement.builder().attributeName(TEST_TABLE_KEY).keyType(KeyType.HASH).build())
                    .attributeDefinitions(AttributeDefinition.builder().attributeName(TEST_TABLE_KEY).attributeType(ScalarAttributeType.S).build())
                    .provisionedThroughput(ProvisionedThroughput.builder().readCapacityUnits(5L).writeCapacityUnits(5L).build())
                    .build();
            dynamoDbClientForTestSetup.createTable(createTableRequest);
            dynamoDbClientForTestSetup.waiter().waitUntilTableExists(DescribeTableRequest.builder().tableName(TEST_TABLE_NAME).build());
            System.out.println("AbstractDynamoDbTest: Table " + TEST_TABLE_NAME + " created.");
        }
    }
}