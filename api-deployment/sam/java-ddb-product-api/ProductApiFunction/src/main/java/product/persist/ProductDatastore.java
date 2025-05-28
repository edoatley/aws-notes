package product.persist;

import product.model.Product;

import java.util.List;

public interface ProductDatastore {

    List<Product> listProducts();

    Product saveProduct(Product product);
}
