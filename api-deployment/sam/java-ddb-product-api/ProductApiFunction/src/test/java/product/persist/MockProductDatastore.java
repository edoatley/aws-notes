package product.persist;

import product.exception.ProductNotFoundException;
import product.model.Product;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;

public class MockProductDatastore implements ProductDatastore {
    // Use a Map to store products by ID for easier lookup, update, and delete
    private final Map<String, Product> products = new HashMap<>();

    public MockProductDatastore() {
        // Optionally pre-populate with some data for tests that need existing products
        Product initialProduct = aProduct();
        products.put(initialProduct.getId(), initialProduct);
    }

    @Override
    public List<Product> listProducts() {
        return new ArrayList<>(products.values());
    }

    @Override
    public Product updateProduct(Product product) throws ProductNotFoundException {
        if (!products.containsKey(product.getId())) {
            throw new ProductNotFoundException("");
        }
        products.put(product.getId(), product);
        return cloneProduct(product);
    }

    @Override
    public Product saveProduct(Product product) {
        product.setId(UUID.randomUUID().toString());
        products.put(product.getId(), product);
        return cloneProduct(product);
    }

    @Override
    public Product getProductById(String id) throws ProductNotFoundException{
        Product product = products.get(id);
        if (product == null) {
            throw new ProductNotFoundException("Product with ID " + id + " not found");
        }
        return cloneProduct(product);
    }

    @Override
    public void deleteProduct(String id) throws ProductNotFoundException {
        if(!products.containsKey(id)) {
            throw new ProductNotFoundException("");
        }
        products.remove(id);
    }

    // Helper to create a sample product, used for initial data or by tests
    public Product aProduct() {
        Product product = new Product();
        product.setId(UUID.randomUUID().toString()); // Ensure it has an ID for map storage
        product.setName("Some Mocked Product");
        product.setDescription("This is a simple mocked product");
        product.setPrice(Double.valueOf("12.99"));
        return product;
    }

    // Utility to clear all products, useful for test setup
    public void clear() {
        products.clear();
    }

    // Helper to clone product if you want to ensure tests don't modify the stored instance directly
     private Product cloneProduct(Product original) {
         Product clone = new Product();
         clone.setId(original.getId());
         clone.setName(original.getName());
         clone.setDescription(original.getDescription());
         clone.setPrice(original.getPrice());
         return clone;
     }
}