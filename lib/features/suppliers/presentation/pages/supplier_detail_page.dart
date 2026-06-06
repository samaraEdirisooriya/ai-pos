import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import 'package:toastification/toastification.dart';

class SupplierDetailPage extends StatefulWidget {
  final String supplierId;
  const SupplierDetailPage({super.key, required this.supplierId});

  @override
  State<SupplierDetailPage> createState() => _SupplierDetailPageState();
}

class _SupplierDetailPageState extends State<SupplierDetailPage> {
  Map<String, dynamic>? _supplier;
  List<dynamic> _history = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchDetails();
  }

  Future<void> _fetchDetails() async {
    setState(() => _loading = true);
    try {
      final uri = Uri.parse('https://pos-backend.posai.workers.dev/api/suppliers/${widget.supplierId}');
      final req = await HttpClient().getUrl(uri);
      final resp = await req.close();
      final body = await resp.transform(utf8.decoder).join();
      final data = jsonDecode(body);
      if (data != null && data['success'] == true) {
        setState(() {
          _supplier = data['supplier'];
          _history = List.from(data['history'] ?? []);
        });
      }
    } catch (e) {
      toastification.show(context: context, type: ToastificationType.error, title: Text('Error'), description: Text('$e'));
    }
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // Header like AddProductScreen
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            decoration: const BoxDecoration(
              color: Colors.black,
              boxShadow: [BoxShadow(color: Colors.black45, blurRadius: 15, offset: Offset(0, 10))],
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                  style: IconButton.styleFrom(backgroundColor: Colors.white12, padding: const EdgeInsets.all(12)),
                ),
                const SizedBox(width: 24),
                Text('Supplier Details', style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w700, color: Colors.white)),
                const Spacer(),
                if (_loading)
                  const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                else
                  const SizedBox.shrink()
              ],
            ),
          ),
          Expanded(
            child: _loading
              ? const Center(child: CircularProgressIndicator())
              : Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 900),
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(_supplier?['name'] ?? '', style: GoogleFonts.inter(color: Colors.black, fontSize: 22, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 12),
                        Row(children: [
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('Supplier ID', style: GoogleFonts.inter(color: Colors.black54, fontSize: 12)),
                            const SizedBox(height: 6),
                            Text(_supplier?['supplier_id'] ?? '-', style: GoogleFonts.inter(color: Colors.black, fontWeight: FontWeight.w700)),
                          ])),
                          const SizedBox(width: 24),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('Total Stock', style: GoogleFonts.inter(color: Colors.black54, fontSize: 12)),
                            const SizedBox(height: 6),
                            Text('${_supplier?['total_stock'] ?? '-'}', style: GoogleFonts.inter(color: Colors.black, fontWeight: FontWeight.w700)),
                          ])),
                        ]),
                        const SizedBox(height: 20),
                        Text('Contact', style: GoogleFonts.inter(color: Colors.black, fontSize: 16, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(12)),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('Email', style: GoogleFonts.inter(color: Colors.black54, fontSize: 12)),
                            const SizedBox(height: 6),
                            Text(_supplier?['email'] ?? '-', style: GoogleFonts.inter(color: Colors.black, fontWeight: FontWeight.w700)),
                            const SizedBox(height: 12),
                            Text('Phone', style: GoogleFonts.inter(color: Colors.black54, fontSize: 12)),
                            const SizedBox(height: 6),
                            Text(_supplier?['phone_num'] ?? '-', style: GoogleFonts.inter(color: Colors.black, fontWeight: FontWeight.w700)),
                            const SizedBox(height: 12),
                            Text('Address', style: GoogleFonts.inter(color: Colors.black54, fontSize: 12)),
                            const SizedBox(height: 6),
                            Text(_supplier?['address'] ?? '-', style: GoogleFonts.inter(color: Colors.black, fontWeight: FontWeight.w700)),
                          ]),
                        ),
                        const SizedBox(height: 24),
                        Text('Recent Stock History', style: GoogleFonts.inter(color: Colors.black, fontSize: 16, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 12),
                        ..._history.map((h) => Container(
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0,4))]),
                          child: Row(children: [
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(h['product_name'] ?? h['product_id'] ?? '', style: GoogleFonts.inter(color: Colors.black, fontWeight: FontWeight.w800)),
                              const SizedBox(height: 6),
                              Text('Code: ${h['product_key'] ?? h['product_id']}', style: GoogleFonts.inter(color: Colors.black54)),
                            ])),
                            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                              Text('Qty: ${h['count']}', style: GoogleFonts.inter(color: Colors.black)),
                              const SizedBox(height: 6),
                              Text('Price: ${h['retail_price'] ?? '-'}', style: GoogleFonts.inter(color: Colors.black54)),
                            ])
                          ]),
                        )),
                      ]),
                    ),
                  ),
                ),
          )
        ],
      ),
    );
  }
}
