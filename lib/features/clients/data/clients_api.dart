import 'dart:convert';
import 'package:dio/dio.dart';

class ClientsApi {
  final String baseUrl = 'https://pos-backend.posai.workers.dev/api/clients';
  final _dio = Dio();

  Future<Map<String, dynamic>?> fetchClients({String? q, int page = 1, int limit = 20}) async {
    try {
      final url = baseUrl + (q != null && q.isNotEmpty ? '?q=${Uri.encodeComponent(q)}&page=1&limit=$limit' : '?page=$page&limit=$limit');
      final resp = await _dio.get(url);
      return resp.data as Map<String, dynamic>?;
    } catch (e) {
      return {'success': false, 'error': '$e'};
    }
  }

  Future<Map<String, dynamic>?> fetchClientById(String id) async {
    try {
      final url = '$baseUrl/$id';
      final resp = await _dio.get(url);
      return resp.data as Map<String, dynamic>?;
    } catch (e) {
      return {'success': false, 'error': '$e'};
    }
  }

  Future<Map<String, dynamic>?> createClient(Map<String, dynamic> payload) async {
    try {
      final resp = await _dio.post(baseUrl, data: payload);
      return resp.data as Map<String, dynamic>?;
    } catch (e) {
      return {'success': false, 'error': '$e'};
    }
  }
}
