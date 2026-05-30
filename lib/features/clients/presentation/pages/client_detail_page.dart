import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:toastification/toastification.dart';

class ClientDetailPage extends StatefulWidget {
  final String clientId;
  const ClientDetailPage({super.key, required this.clientId});

  @override
  State<ClientDetailPage> createState() => _ClientDetailPageState();
}

class _ClientDetailPageState extends State<ClientDetailPage> {
  Map<String, dynamic>? _client;
  List<dynamic> _sales = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() => _loading = true);
    try {
      final uri = Uri.parse('https://pos-backend.posai.workers.dev/api/clients/${widget.clientId}');
      final req = await HttpClient().getUrl(uri);
      final resp = await req.close();
      final body = await resp.transform(utf8.decoder).join();
      final data = jsonDecode(body);
      if (data != null && data['success'] == true) {
        if (!mounted) return;
        setState(() {
          _client = data['data'] ?? data['client'];
          _sales = data['sales'] ?? data['history'] ?? [];
        });
      } else {
        if (mounted) {
          toastification.show(context: context, type: ToastificationType.error, title: Text('Error'), description: Text(data?['error'] ?? 'Failed'));
        }
      }
    } catch (e) {
      // ignore
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            decoration: const BoxDecoration(color: Colors.black, boxShadow: [BoxShadow(color: Colors.black45, blurRadius: 15, offset: Offset(0, 10))]),
            child: Row(
              children: [
                IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => Navigator.of(context).pop()),
                const SizedBox(width: 24),
                Text('Client Details', style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w700, color: Colors.white)),
                const Spacer(),
                _loading ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const SizedBox.shrink(),
              ],
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 24),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 900),
                padding: const EdgeInsets.all(24),
                child: _client == null
                    ? Center(child: Text('No client found', style: GoogleFonts.inter()))
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_client?['name'] ?? '-', style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 8),
                          Text(_client?['email'] ?? '-', style: GoogleFonts.inter(color: Colors.black54)),
                          const SizedBox(height: 16),

                          Row(
                            children: [
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12)),
                                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Text('Contact', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
                                    const SizedBox(height: 8),
                                    Text('Phone: ${_client?['phone_num'] ?? '-'}', style: GoogleFonts.inter()),
                                    Text('Address: ${_client?['address'] ?? '-'}', style: GoogleFonts.inter()),
                                    Text('Balance: ${_client?['balance'] ?? 0}', style: GoogleFonts.inter()),
                                  ]),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12)),
                                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Text('Summary', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
                                    const SizedBox(height: 8),
                                    Text('Total Price: ${_client?['total_price'] ?? 0}', style: GoogleFonts.inter()),
                                    Text('Profit: ${_client?['profit'] ?? 0}', style: GoogleFonts.inter()),
                                    Text('Created: ${_client?['createdAt'] ?? '-'}', style: GoogleFonts.inter()),
                                  ]),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 24),
                          Text('Recent Purchases', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 12),

                          _sales.isEmpty
                              ? Text('No recent purchases', style: GoogleFonts.inter())
                              : Column(
                                  children: _sales.map((s) {
                                    return Container(
                                      padding: const EdgeInsets.all(12),
                                      margin: const EdgeInsets.only(bottom: 8),
                                      decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(8)),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                              Text(s['product_name'] ?? s['name'] ?? '-', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
                                              const SizedBox(height: 6),
                                              Text('Qty: ${s['quantity'] ?? s['live_selling_count'] ?? '-'}', style: GoogleFonts.inter()),
                                            ]),
                                          ),
                                          Text('${s['total_price'] ?? '-'}', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                )
                        ],
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
