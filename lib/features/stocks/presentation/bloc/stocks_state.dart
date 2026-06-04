import 'package:equatable/equatable.dart';
import '../../data/models/stock_item.dart';

abstract class StocksState extends Equatable {
  const StocksState();

  @override
  List<Object?> get props => [];
}

class StocksInitial extends StocksState {}

class StocksLoading extends StocksState {}

class StocksLoaded extends StocksState {
  final List<StockItem> stocks;
  final int total;
  const StocksLoaded(this.stocks, {this.total = 0});

  @override
  List<Object?> get props => [stocks, total];
}

class StocksError extends StocksState {
  final String message;
  const StocksError(this.message);

  @override
  List<Object?> get props => [message];
}

class StockAddLoading extends StocksState {
  final List<StockItem> currentStocks; // to keep displaying the list if needed
  const StockAddLoading(this.currentStocks);
  @override
  List<Object?> get props => [currentStocks];
}

class StockAddSuccess extends StocksState {
  final String message;
  const StockAddSuccess(this.message);
  @override
  List<Object?> get props => [message];
}

class StockAddError extends StocksState {
  final String message;
  const StockAddError(this.message);
  @override
  List<Object?> get props => [message];
}