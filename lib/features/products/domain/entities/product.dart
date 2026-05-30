class Product {
  final String productId;
  final String productKey;
  final String name;
  final double retailValue;
  final double sellingValue;
  final bool active;
  final bool offerHave;
  final double offerPercentage;
  final String productUrl;
  final String createdUser;

  Product({
    required this.productId,
    required this.productKey,
    required this.name,
    required this.retailValue,
    required this.sellingValue,
    required this.active,
    required this.offerHave,
    required this.offerPercentage,
    required this.productUrl,
    required this.createdUser,
  });
}
