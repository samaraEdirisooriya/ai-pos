import '../../domain/entities/supplier.dart';

class SupplierModel extends Supplier {
  const SupplierModel({
    required super.supplierId,
    required super.name,
    required super.email,
    required super.phoneNum,
    required super.address,
    super.totalStock,
    super.createdUser,
    super.active = true,
  });

  factory SupplierModel.fromJson(Map<String, dynamic> json) {
    return SupplierModel(
      supplierId: json['supplier_id'] ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      phoneNum: json['phone_num'] ?? '',
      address: json['address'] ?? '',
      totalStock: json['total_stock'] as int?,
      createdUser: json['created_user'] as String?,
      active: json['active'] == 1 || json['active'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'supplier_id': supplierId,
      'name': name,
      'email': email,
      'phone_num': phoneNum,
      'address': address,
      'total_stock': totalStock,
      'created_user': createdUser,
      'active': active ? 1 : 0,
    };
  }

  SupplierModel copyWith({
    String? supplierId,
    String? name,
    String? email,
    String? phoneNum,
    String? address,
    int? totalStock,
    String? createdUser,
    bool? active,
  }) {
    return SupplierModel(
      supplierId: supplierId ?? this.supplierId,
      name: name ?? this.name,
      email: email ?? this.email,
      phoneNum: phoneNum ?? this.phoneNum,
      address: address ?? this.address,
      totalStock: totalStock ?? this.totalStock,
      createdUser: createdUser ?? this.createdUser,
      active: active ?? this.active,
    );
  }
}
