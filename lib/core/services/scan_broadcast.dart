import 'dart:async';
import '../../features/stocks/data/models/stock_item.dart';

class ScanBroadcast {
  static final _controller = StreamController<StockItem>.broadcast();
  static Stream<StockItem> get stream => _controller.stream;
  static void add(StockItem item) => _controller.add(item);
}
