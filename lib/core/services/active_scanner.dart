import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';

class ActiveScanner {
  static String? sessionId;
  static DateTime? createdAt;
  static final ValueNotifier<int> pendingCount = ValueNotifier<int>(0);
  static Timer? _pollTimer;

  static void setSession(String id) {
    sessionId = id;
    createdAt = DateTime.now();
  }

  static bool isExpired(Duration ttl) {
    if (sessionId == null || createdAt == null) return true;
    return DateTime.now().difference(createdAt!) > ttl;
  }

  static void clear() {
    sessionId = null;
    createdAt = null;
    pendingCount.value = 0;
    stopPolling();
  }

  static void startPolling({Duration interval = const Duration(seconds: 1)}) {
    if (sessionId == null) return;
    if (_pollTimer != null && _pollTimer!.isActive) return;
    _pollTimer = Timer.periodic(interval, (_) async {
      try {
        final sid = sessionId;
        if (sid == null) return;
        final uri = Uri.parse('https://pos-backend.posai.workers.dev/api/scanner/status/$sid');
        final resp = await HttpClient().getUrl(uri).then((r) => r.close());
        final body = await resp.transform(utf8.decoder).join();
        final data = jsonDecode(body);
        if (data != null && data['success'] == true && data['scans'] is List) {
          final List scans = List.from(data['scans']);
          pendingCount.value = scans.length;
        }
      } catch (_) {}
    });
  }

  static void stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }
}
