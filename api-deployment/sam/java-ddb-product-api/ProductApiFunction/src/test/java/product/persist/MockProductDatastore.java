package product.persist;

import product.model.Product;

import java.util.List;
import java.util.UUID;

public class MockProductDatastore implements ProductDatastore {
    @Override
    public List<Product> listProducts() {
        return List.of(aProduct());
    }

    @Override
    public Product saveProduct(Product product) {
        if (product == null || product.getId() == null) {
            throw new RuntimeException();
        }
        return product;
    }

    Product aProduct() {
        Product product = new Product();
        product.setId(UUID.randomUUID().toString());
        product.setName("Some product");
        product.setDescription("This is a simple product");
        product.setPrice(Double.valueOf("12.99"));
        return product;
    }
}
