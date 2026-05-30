import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import '../../domain/entities/cart_item.dart';
import '../../domain/entities/product.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

// Events
abstract class PosEvent extends Equatable {
  const PosEvent();
  @override
  List<Object> get props => [];
}

class AddProductToCart extends PosEvent {
  final Product product;
  const AddProductToCart(this.product);
  @override
  List<Object> get props => [product];
}

class RemoveProductFromCart extends PosEvent {
  final Product product;
  const RemoveProductFromCart(this.product);
  @override
  List<Object> get props => [product];
}

class ClearCart extends PosEvent {}

// State
class PosState extends Equatable {
  final List<CartItem> cartItems;
  final double discount;
  
  const PosState({
    this.cartItems = const [],
    this.discount = 0.0,
  });

  double get subtotal => cartItems.fold(0, (sum, item) => sum + (item.product.price * item.quantity));
  double get total => subtotal - discount;

  PosState copyWith({
    List<CartItem>? cartItems,
    double? discount,
  }) {
    return PosState(
      cartItems: cartItems ?? this.cartItems,
      discount: discount ?? this.discount,
    );
  }

  @override
  List<Object> get props => [cartItems, discount];
}

// BLoC
class PosBloc extends Bloc<PosEvent, PosState> {
  PosBloc() : super(const PosState()) {
    on<AddProductToCart>(_onAddProduct);
    on<RemoveProductFromCart>(_onRemoveProduct);
    on<ClearCart>((event, emit) => emit(const PosState()));
  }

  Future<void> _onAddProduct(AddProductToCart event, Emitter<PosState> emit) async {
    final List<CartItem> updatedCart = List.from(state.cartItems);
    final existingIndex = updatedCart.indexWhere((item) => item.product.id == event.product.id);
    
    if (existingIndex >= 0) {
      final existingItem = updatedCart[existingIndex];
      updatedCart[existingIndex] = existingItem.copyWith(quantity: existingItem.quantity + 1);
    } else {
      updatedCart.add(CartItem(product: event.product));
    }
    
    emit(state.copyWith(cartItems: updatedCart));

    // Persist usage counts and recent list for POS convenience
    try {
      final prefs = await SharedPreferences.getInstance();

      // Usage map stored as JSON string { productId: count }
      final usageRaw = prefs.getString('pos_usage') ?? '{}';
      final Map<String, dynamic> usage = jsonDecode(usageRaw);
      final current = (usage[event.product.id]?.toInt() ?? 0) + 1;
      usage[event.product.id] = current;
      prefs.setString('pos_usage', jsonEncode(usage));

      // Recent list: keep most recent 20 product ids
      final recentRaw = prefs.getStringList('pos_recent') ?? <String>[];
      final newRecent = [event.product.id, ...recentRaw.where((id) => id != event.product.id)];
      prefs.setStringList('pos_recent', newRecent.take(20).toList());
    } catch (_) {}
  }

  void _onRemoveProduct(RemoveProductFromCart event, Emitter<PosState> emit) {
    final List<CartItem> updatedCart = List.from(state.cartItems);
    final existingIndex = updatedCart.indexWhere((item) => item.product.id == event.product.id);
    
    if (existingIndex >= 0) {
      final existingItem = updatedCart[existingIndex];
      if (existingItem.quantity > 1) {
        updatedCart[existingIndex] = existingItem.copyWith(quantity: existingItem.quantity - 1);
      } else {
        updatedCart.removeAt(existingIndex);
      }
    }
    
    emit(state.copyWith(cartItems: updatedCart));
  }
}
