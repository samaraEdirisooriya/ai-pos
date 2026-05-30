import 'package:dartz/dartz.dart';
import '../../domain/entities/product.dart';
import '../../domain/repositories/product_repository.dart';
import '../datasources/product_remote_data_source.dart';

class ProductRepositoryImpl implements ProductRepository {
  final ProductRemoteDataSource remoteDataSource;

  ProductRepositoryImpl({required this.remoteDataSource});

  @override
  Future<Either<String, List<Product>>> getProducts({String? query}) async {
    try {
      final products = await remoteDataSource.getProducts(query: query);
      return Right(products);
    } catch (e) {
      return Left(e.toString());
    }
  }

  @override
  Future<Either<String, Product>> addProduct(Product product) async {
    try {
      final newProduct = await remoteDataSource.addProduct(product);
      return Right(newProduct);
    } catch (e) {
      return Left(e.toString());
    }
  }
}
