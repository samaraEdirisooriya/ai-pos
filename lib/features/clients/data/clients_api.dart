import 'dart:convert';
import 'dart:io';

class ClientsApi {
  final String baseUrl = 'https://pos-backend.posai.workers.dev/api/clients';

  Future<Map<String, dynamic>?> fetchClients({String? q, int page = 1, int limit = 20}) async {
    try {
      final uri = Uri.parse(baseUrl + (q != null && q.isNotEmpty ? '?q=${Uri.encodeComponent(q)}&page=1&limit=$limit' : '?page=$page&limit=$limit'));
      final req = await HttpClient().getUrl(uri);
      final resp = await req.close();
      final body = await resp.transform(utf8.decoder).join();
      return jsonDecode(body) as Map<String, dynamic>?;
    } catch (e) {
      return {'success': false, 'error': '$e'};
    }
  }

  Future<Map<String, dynamic>?> fetchClientById(String id) async {
    try {
      final uri = Uri.parse('$baseUrl/$id');
      final req = await HttpClient().getUrl(uri);
      final resp = await req.close();
      final body = await resp.transform(utf8.decoder).join();
      return jsonDecode(body) as Map<String, dynamic>?;
    } catch (e) {
      return {'success': false, 'error': '$e'};
    }
  }

  Future<Map<String, dynamic>?> createClient(Map<String, dynamic> payload) async {
    try {
      final uri = Uri.parse(baseUrl);
      final req = await HttpClient().postUrl(uri);
      req.headers.set('content-type', 'application/json');
      req.add(utf8.encode(jsonEncode(payload)));
      final resp = await req.close();
      final body = await resp.transform(utf8.decoder).join();
      return jsonDecode(body) as Map<String, dynamic>?;
    } catch (e) {
      return {'success': false, 'error': '$e'};
    }
  }
}
