import 'package:dartz/dartz.dart';
import '../entities/product.dart';
import '../repositories/product_repository.dart';

class GetProducts {
  final ProductRepository repository;

  GetProducts(this.repository);

  Future<Either<String, List<Product>>> call({String? query}) async {
    return await repository.getProducts(query: query);
  }
}
