class Supplier {
  final String supplierId;
  final String name;

  Supplier({required this.supplierId, required this.name});

  factory Supplier.fromJson(Map<String, dynamic> json) {
    return Supplier(
      supplierId: json['supplier_id'] ?? '',
      name: json['name'] ?? 'Unknown',
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Supplier &&
          runtimeType == other.runtimeType &&
          supplierId == other.supplierId;

  @override
  int get hashCode => supplierId.hashCode;
}