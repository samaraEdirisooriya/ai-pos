import 'package:dartz/dartz.dart';
import '../entities/product.dart';

abstract class ProductRepository {
  Future<Either<String, List<Product>>> getProducts({String? query});
  Future<Either<String, Product>> addProduct(Product product);
}
