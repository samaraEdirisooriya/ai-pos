import 'package:dartz/dartz.dart';
import '../entities/product.dart';
import '../repositories/product_repository.dart';

class AddProduct {
  final ProductRepository repository;

  AddProduct(this.repository);

  Future<Either<String, Product>> call(Product product) async {
    return await repository.addProduct(product);
  }
}
