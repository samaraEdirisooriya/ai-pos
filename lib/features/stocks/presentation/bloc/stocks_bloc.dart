import 'package:bloc/bloc.dart';
import 'package:dio/dio.dart';
import 'stocks_event.dart';
import 'stocks_state.dart';
import '../../data/models/stock_item.dart';
import '../../data/models/supplier.dart';

class StocksBloc extends Bloc<StocksEvent, StocksState> {
  final Dio dio;
  final String baseUrl = 'https://pos-backend.posai.workers.dev/api';

  StocksBloc({required this.dio}) : super(StocksInitial()) {
    on<FetchStocks>(_onFetchStocks);
    on<AddStock>(_onAddStock);
  }

  Future<void> _onAddStock(AddStock event, Emitter<StocksState> emit) async {
    List<StockItem> currentStocks = [];
    if (state is StocksLoaded) {
      currentStocks = (state as StocksLoaded).stocks;
    }
    emit(StockAddLoading(currentStocks));
    try {
      final response = await dio.post(
        '$baseUrl/stocks/add',
        data: {
          'product_id': event.productId,
          'quantity': event.quantity,
          'supplier_id': event.supplierId,
          'retail_price': event.retailPrice,
          'selling_price': event.sellingPrice,
        },
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        emit(const StockAddSuccess('Stock added successfully'));
        add(const FetchStocks()); // Refetch stocks to update UI
      } else {
        emit(StockAddError(response.data['error'] ?? 'Failed to add stock'));
        if (currentStocks.isNotEmpty) {
          emit(StocksLoaded(currentStocks)); // Revert to loaded state
        }
      }
    } catch (e) {
      emit(StockAddError(e.toString()));
      if (currentStocks.isNotEmpty) {
        emit(StocksLoaded(currentStocks)); // Revert to loaded state
      }
    }
  }

  Future<void> _onFetchStocks(FetchStocks event, Emitter<StocksState> emit) async {
    emit(StocksLoading());
    try {
      final response = await dio.get(
        '$baseUrl/stocks',
        queryParameters: event.query != null && event.query!.isNotEmpty ? {'q': event.query} : null,
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        final List data = response.data['data'];
        final stocks = data.map((e) => StockItem.fromJson(e)).toList();
        emit(StocksLoaded(stocks));
      } else {
        emit(StocksError(response.data['error'] ?? 'Failed to load stocks'));
      }
    } catch (e) {
      emit(StocksError(e.toString()));
    }
  }

  Future<List<Supplier>> fetchSuppliers() async {
    try {
      final response = await dio.get('$baseUrl/suppliers');
      if (response.statusCode == 200 && response.data['success'] == true) {
        final List data = response.data['data'];
        return data.map((e) => Supplier.fromJson(e)).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }
}