import 'package:dio/dio.dart';

class DashboardStats {
  final int productsCount;
  final int stocksCount;
  final int suppliersCount;
  final int clientsCount;
  final int salesCount;
  final double totalRevenue;
  final double totalProfit;

  DashboardStats({
    required this.productsCount,
    required this.stocksCount,
    required this.suppliersCount,
    required this.clientsCount,
    required this.salesCount,
    required this.totalRevenue,
    required this.totalProfit,
  });

  factory DashboardStats.fromJson(Map<String, dynamic> json) {
    return DashboardStats(
      productsCount: json['products_count'] ?? 0,
      stocksCount: json['stocks_count'] ?? 0,
      suppliersCount: json['suppliers_count'] ?? 0,
      clientsCount: json['clients_count'] ?? 0,
      salesCount: json['sales_count'] ?? 0,
      totalRevenue: (json['total_revenue'] ?? 0).toDouble(),
      totalProfit: (json['total_profit'] ?? 0).toDouble(),
    );
  }
}

class DashboardService {
  final Dio dio;
  static const String baseUrl = 'https://pos-backend.posai.workers.dev';

  DashboardService({required this.dio});

  Future<DashboardStats> fetchDashboardStats() async {
    try {
      final response = await dio.get('$baseUrl/api/dashboard/stats');
      return DashboardStats.fromJson(response.data['data'] ?? {});
    } catch (e) {
      // Return default stats on error
      return DashboardStats(
        productsCount: 0,
        stocksCount: 0,
        suppliersCount: 0,
        clientsCount: 0,
        salesCount: 0,
        totalRevenue: 0,
        totalProfit: 0,
      );
    }
  }

  Future<int> getProductsCount() async {
    try {
      final response = await dio.get('$baseUrl/api/products?limit=1');
      return response.data?['meta']?['total'] ?? 0;
    } catch (e) {
      return 0;
    }
  }

  Future<int> getStocksCount() async {
    try {
      final response = await dio.get('$baseUrl/api/stocks?limit=1');
      return response.data?['meta']?['total'] ?? 0;
    } catch (e) {
      return 0;
    }
  }

  Future<int> getSuppliersCount() async {
    try {
      final response = await dio.get('$baseUrl/api/suppliers?limit=1');
      return response.data?['meta']?['total'] ?? 0;
    } catch (e) {
      return 0;
    }
  }

  Future<int> getClientsCount() async {
    try {
      final response = await dio.get('$baseUrl/api/clients?limit=1');
      return response.data?['meta']?['total'] ?? 0;
    } catch (e) {
      return 0;
    }
  }

  Future<int> getSalesCount() async {
    try {
      final response = await dio.get('$baseUrl/api/sales/stats');
      return response.data?['data']?['sales_count'] ?? 0;
    } catch (e) {
      return 0;
    }
  }

  Future<double> getTotalRevenue() async {
    try {
      final response = await dio.get('$baseUrl/api/sales/stats');
      return (response.data?['data']?['total_revenue'] ?? 0).toDouble();
    } catch (e) {
      return 0.0;
    }
  }

  Future<double> getTotalProfit() async {
    try {
      final response = await dio.get('$baseUrl/api/sales/stats');
      return (response.data?['data']?['total_profit'] ?? 0).toDouble();
    } catch (e) {
      return 0.0;
    }
  }
}
