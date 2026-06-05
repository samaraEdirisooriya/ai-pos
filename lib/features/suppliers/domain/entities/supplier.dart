import 'package:equatable/equatable.dart';

class Supplier extends Equatable {
  final String supplierId;
  final String name;
  final String email;
  final String phoneNum;
  final String address;
  final int? totalStock;
  final String? createdUser;
  final bool active;

  const Supplier({
    required this.supplierId,
    required this.name,
    required this.email,
    required this.phoneNum,
    required this.address,
    this.totalStock,
    this.createdUser,
    this.active = true,
  });

  @override
  List<Object?> get props => [
    supplierId,
    name,
    email,
    phoneNum,
    address,
    totalStock,
    createdUser,
    active,
  ];
}
