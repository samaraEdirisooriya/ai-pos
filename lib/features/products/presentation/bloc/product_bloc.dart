import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/product.dart';
import '../../domain/usecases/add_product.dart';
import '../../domain/usecases/get_products.dart';

part 'product_event.dart';
part 'product_state.dart';

class ProductBloc extends Bloc<ProductEvent, ProductState> {
  final GetProducts getProducts;
  final AddProduct addProduct;

  List<Product> _currentProducts = [];

  ProductBloc({
    required this.getProducts,
    required this.addProduct,
  }) : super(ProductInitial()) {
    on<LoadProductsEvent>((event, emit) async {
      emit(ProductLoading());
      final result = await getProducts(query: event.query);
      result.fold(
        (failure) => emit(ProductError(failure)),
        (products) {
          _currentProducts = products;
          emit(ProductLoaded(products));
        },
      );
    });

    on<AddProductEvent>((event, emit) async {
      emit(ProductAddLoading());
      final result = await addProduct(event.product);
      result.fold(
        (failure) => emit(ProductAddError(failure)),
        (product) {
          _currentProducts.insert(0, product); // Add to top
          emit(ProductAddSuccess(product));
          emit(ProductLoaded(_currentProducts)); // Re-emit loaded state
        },
      );
    });
  }
}
