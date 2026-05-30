class StockItem {
  final String productId;
  final String name;
  final String productKey;
  final String productUrl;
  final double sellingValue;
  final int liveStockCount;
  final int liveSellingCount;

  StockItem({
    required this.productId,
    required this.name,
    required this.productKey,
    required this.productUrl,
    required this.sellingValue,
    required this.liveStockCount,
    required this.liveSellingCount,
  });

  factory StockItem.fromJson(Map<String, dynamic> json) {
    return StockItem(
      productId: json['product_id'] ?? '',
      name: json['name'] ?? '',
      productKey: json['product_key'] ?? '',
      productUrl: json['product_url'] ?? '',
      sellingValue: (json['selling_value'] as num?)?.toDouble() ?? 0.0,
      liveStockCount: json['live_stock_count'] ?? 0,
      liveSellingCount: json['live_selling_count'] ?? 0,
    );
  }
}