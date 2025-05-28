package product.persist;

import product.exception.ProductNotFoundException;
import product.model.Product;
import software.amazon.awssdk.auth.credentials.EnvironmentVariableCredentialsProvider;
import software.amazon.awssdk.enhanced.dynamodb.DynamoDbEnhancedClient;
import software.amazon.awssdk.enhanced.dynamodb.DynamoDbTable;
import software.amazon.awssdk.enhanced.dynamodb.Key;
import software.amazon.awssdk.enhanced.dynamodb.TableSchema;
import software.amazon.awssdk.regions.Region;
import software.amazon.awssdk.services.dynamodb.DynamoDbClient;
import software.amazon.awssdk.services.dynamodb.endpoints.internal.GetAttr;

import java.util.List;
import java.util.Optional;

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

    @Override
    public Product updateProduct(Product product)  throws ProductNotFoundException {
        getProductById(product.getId()); // ensures what we are updating exists
        table.putItem(product);
        return product;
    }

    @Override
    public Product getProductById(String id) throws ProductNotFoundException {
        Key key = Key.builder().partitionValue(id).build();
        Product product = table.getItem(key);
        if (product == null) {
            throw new ProductNotFoundException("Product not found with id " + id);
        }
        return product;
    }

    @Override
    public void deleteProduct(String id) throws ProductNotFoundException {
        Product productToDelete = getProductById(id);
        table.deleteItem(productToDelete);
    }

}
