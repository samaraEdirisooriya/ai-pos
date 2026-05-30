import 'package:dio/dio.dart';
import '../models/product_model.dart';
import '../../domain/entities/product.dart';

abstract class ProductRemoteDataSource {
  Future<List<ProductModel>> getProducts({String? query});
  Future<ProductModel> addProduct(Product product);
}

class ProductRemoteDataSourceImpl implements ProductRemoteDataSource {
  final Dio dio;

  // Change this to your deployed worker URL
  final String baseUrl = 'https://pos-backend.posai.workers.dev/api';

  ProductRemoteDataSourceImpl({required this.dio});

  @override
  Future<List<ProductModel>> getProducts({String? query}) async {
    try {
      final response = await dio.get(
        '$baseUrl/products',
        queryParameters: query != null && query.isNotEmpty ? {'q': query} : null,
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        final List data = response.data['data'];
        return data.map((e) => ProductModel.fromJson(e)).toList();
      } else {
        throw Exception(response.data['error'] ?? 'Failed to load products');
      }
    } on DioException catch (e) {
      if (e.response != null && e.response?.data != null && e.response?.data is Map) {
        throw Exception(e.response?.data['error'] ?? 'Server Error: ${e.response?.statusCode}');
      }
      throw Exception('Network Error: ${e.message}');
    } catch (e) {
      throw Exception('Unknown Error: $e');
    }
  }

  @override
  Future<ProductModel> addProduct(Product product) async {
    try {
      final model = ProductModel(
        productId: product.productId,
        productKey: product.productKey,
        name: product.name,
        retailValue: product.retailValue,
        sellingValue: product.sellingValue,
        active: product.active,
        offerHave: product.offerHave,
        offerPercentage: product.offerPercentage,
        productUrl: product.productUrl,
        createdUser: product.createdUser,
      );

      final response = await dio.post(
        '$baseUrl/products',
        data: model.toJson(),
      );

      if ((response.statusCode == 200 || response.statusCode == 201) && response.data['success'] == true) {
        return ProductModel.fromJson(response.data['data']);
      } else {
        throw Exception(response.data['error'] ?? 'Failed to add product');
      }
    } on DioException catch (e) {
      if (e.response != null && e.response?.data != null && e.response?.data is Map) {
        throw Exception(e.response?.data['error'] ?? 'Server Error: ${e.response?.statusCode}');
      }
      throw Exception('Network Error: ${e.message}');
    } catch (e) {
      throw Exception('Unknown Error: $e');
    }
  }
}
