import 'package:equatable/equatable.dart';

abstract class StocksEvent extends Equatable {
  const StocksEvent();

  @override
  List<Object?> get props => [];
}

class FetchStocks extends StocksEvent {
  final String? query;
  final int? page;
  final int? limit;
  const FetchStocks({this.query, this.page, this.limit});

  @override
  List<Object?> get props => [query];
}

class AddStock extends StocksEvent {
  final String productId;
  final int quantity;
  final String? supplierId;
  final double retailPrice;
  final double sellingPrice;

  const AddStock({
    required this.productId,
    required this.quantity,
    this.supplierId,
    required this.retailPrice,
    required this.sellingPrice,
  });

  @override
  List<Object?> get props => [productId, quantity, supplierId, retailPrice, sellingPrice];
}