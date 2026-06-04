import '../../domain/entities/product.dart';

class ProductModel extends Product {
  ProductModel({
    required super.productId,
    required super.productKey,
    required super.name,
    required super.category,
    required super.description,
    required super.retailValue,
    required super.sellingValue,
    required super.active,
    required super.offerHave,
    required super.offerPercentage,
    required super.productUrl,
    required super.createdUser,
  });

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    return ProductModel(
      productId: json['product_id'] ?? '',
      productKey: json['product_key'] ?? '',
      name: json['name'] ?? '',
      category: json['category'] ?? 'General',
      description: json['description'] ?? '',
      retailValue: (json['retail_value'] ?? 0.0).toDouble(),
      sellingValue: (json['selling_value'] ?? 0.0).toDouble(),
      active: json['active'] == 1,
      offerHave: json['offer_have'] == 1,
      offerPercentage: (json['offer_percentage'] ?? 0.0).toDouble(),
      productUrl: json['product_url'] ?? '',
      createdUser: json['created_user'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'product_id': productId,
      'product_key': productKey,
      'name': name,
      'category': category,
      'description': description,
      'retail_value': retailValue,
      'selling_value': sellingValue,
      'active': active ? 1 : 0,
      'offer_have': offerHave ? 1 : 0,
      'offer_percentage': offerPercentage,
      'product_url': productUrl,
      'created_user': createdUser,
    };
  }
}
