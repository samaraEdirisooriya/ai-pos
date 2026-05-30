part of 'product_bloc.dart';

abstract class ProductState {}

class ProductInitial extends ProductState {}

class ProductLoading extends ProductState {}

class ProductLoaded extends ProductState {
  final List<Product> products;
  ProductLoaded(this.products);
}

class ProductError extends ProductState {
  final String message;
  ProductError(this.message);
}

class ProductAddLoading extends ProductState {}

class ProductAddSuccess extends ProductState {
  final Product product;
  ProductAddSuccess(this.product);
}

class ProductAddError extends ProductState {
  final String message;
  ProductAddError(this.message);
}
