package product.persist;

import product.model.Product;
import software.amazon.awssdk.auth.credentials.EnvironmentVariableCredentialsProvider;
import software.amazon.awssdk.enhanced.dynamodb.DynamoDbEnhancedClient;
import software.amazon.awssdk.enhanced.dynamodb.DynamoDbTable;
import software.amazon.awssdk.enhanced.dynamodb.TableSchema;
import software.amazon.awssdk.regions.Region;
import software.amazon.awssdk.services.dynamodb.DynamoDbClient;

import java.util.List;

public class ProductDynamoDbStore implements ProductDatastore {

    private final DynamoDbTable<Product> table;

    public ProductDynamoDbStore(String tableName) {
        var ddb = DynamoDbClient.builder()
                .credentialsProvider(EnvironmentVariableCredentialsProvider.create())
                .region(Region.EU_WEST_2)
                .build();
        var enhancedClient = DynamoDbEnhancedClient.builder()
                .dynamoDbClient(ddb)
                .build();
        this.table = enhancedClient.table(tableName, TableSchema.fromBean(Product.class));
    }


    @Override
    public List<Product> listProducts() {
        return table.scan().items().stream().toList();
    }

    @Override
    public Product saveProduct(Product product) {
        table.putItem(product);
        return product;
    }

}
