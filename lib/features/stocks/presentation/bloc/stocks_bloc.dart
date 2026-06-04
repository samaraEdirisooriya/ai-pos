import 'package:bloc/bloc.dart';
import 'package:dio/dio.dart';
import 'stocks_event.dart';
import 'stocks_state.dart';
import '../../data/models/stock_item.dart';
import '../../data/models/supplier.dart';

class StocksBloc extends Bloc<StocksEvent, StocksState> {
  final Dio dio;
  final String baseUrl = 'https://pos-backend.posai.workers.dev/api';
  int _page = 1;
  int _limit = 50;
  int _total = 0;

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
          emit(StocksLoaded(currentStocks, total: _total)); // Revert to loaded state
        }
      }
    } catch (e) {
      emit(StockAddError(e.toString()));
      if (currentStocks.isNotEmpty) {
        emit(StocksLoaded(currentStocks, total: _total)); // Revert to loaded state
      }
    }
  }

  Future<void> _onFetchStocks(FetchStocks event, Emitter<StocksState> emit) async {
    // support pagination: page & limit can be passed in event
    final page = event.page ?? 1;
    final limit = event.limit ?? _limit;

    // if first page, show loading state; otherwise keep current list while loading
    if (page == 1) emit(StocksLoading());
    try {
      final qp = <String, dynamic>{'page': page, 'limit': limit};
      if (event.query != null && event.query!.isNotEmpty) qp['q'] = event.query;

      final response = await dio.get('$baseUrl/stocks', queryParameters: qp);

      if (response.statusCode == 200 && response.data['success'] == true) {
        final List data = response.data['data'];
        final stocks = data.map((e) => StockItem.fromJson(e)).toList();

        // update total from meta if available
        final meta = response.data['meta'] ?? {};
        _total = meta['total'] ?? _total;

        if (page == 1) {
          _page = 1;
          _limit = limit;
          emit(StocksLoaded(stocks, total: _total));
        } else {
          // append to existing list
          List<StockItem> currentStocks = [];
          if (state is StocksLoaded) currentStocks = (state as StocksLoaded).stocks;
          final all = [...currentStocks, ...stocks];
          _page = page;
          _limit = limit;
          emit(StocksLoaded(all, total: _total));
        }
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
