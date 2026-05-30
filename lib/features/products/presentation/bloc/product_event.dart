part of 'product_bloc.dart';

abstract class ProductEvent {}

class LoadProductsEvent extends ProductEvent {
  final String? query;
  LoadProductsEvent({this.query});
}

class AddProductEvent extends ProductEvent {
  final Product product;
  AddProductEvent(this.product);
}
