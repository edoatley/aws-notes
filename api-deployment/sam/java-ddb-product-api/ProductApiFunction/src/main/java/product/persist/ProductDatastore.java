package product.persist;

import product.exception.ProductNotFoundException;
import product.model.Product;

import java.util.List;
import java.util.Optional;

public interface ProductDatastore {

    List<Product> listProducts();

    Product saveProduct(Product product);

    Product updateProduct(Product product) throws ProductNotFoundException;

    Product getProductById(String id) throws ProductNotFoundException;

    void deleteProduct(String id) throws ProductNotFoundException;
}
