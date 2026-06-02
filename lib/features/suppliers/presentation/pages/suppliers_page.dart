import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/services/active_scanner.dart';
import 'supplier_detail_page.dart';
import 'add_supplier_screen.dart';
import '../../../../core/services/scan_broadcast.dart';
import 'package:toastification/toastification.dart';

class SuppliersPage extends StatefulWidget {
  const SuppliersPage({super.key});

  @override
  State<SuppliersPage> createState() => _SuppliersPageState();
}

class _SuppliersPageState extends State<SuppliersPage> with SingleTickerProviderStateMixin {
  List<dynamic> _suppliers = [];
  bool _loading = false;
  final TextEditingController _searchController = TextEditingController();
  int _page = 1;
  int _limit = 20;
  int _total = 0;

  @override
  void initState() {
    super.initState();
    _fetchSuppliers();
    _shimmerController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat();
  }

  late AnimationController _shimmerController;

  Future<void> _fetchSuppliers({String? q}) async {
    setState(() => _loading = true);
    try {
      final uri = Uri.parse('https://pos-backend.posai.workers.dev/api/suppliers' + (q != null && q.isNotEmpty ? '?q=${Uri.encodeComponent(q)}&page=1&limit=$_limit' : '?page=$_page&limit=$_limit'));
      final req = await HttpClient().getUrl(uri);
      final resp = await req.close();
      final body = await resp.transform(utf8.decoder).join();
      final data = jsonDecode(body);
      if (data != null && data['success'] == true) {
        final List newItems = List.from(data['data'] ?? []);
        final meta = data['meta'] ?? {};
        setState(() {
          if (q != null && q.isNotEmpty) {
            _suppliers = newItems;
            _page = 1;
          } else {
            if (_page == 1) _suppliers = newItems; else _suppliers.addAll(newItems);
          }
          _total = meta['total'] ?? _suppliers.length;
        });
      }
    } catch (e) {
      // ignore
    }
    setState(() => _loading = false);
  }

  Future<void> _openAddSupplier() async {
    // open full screen AddSupplierScreen
    final res = await Navigator.push(context, MaterialPageRoute(builder: (_) => const AddSupplierScreen()));
    if (res == true) {
      _page = 1;
      _fetchSuppliers();
    }
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Widget _buildSearchField() {
    return TextField(
      controller: _searchController,
      onChanged: (v) => _fetchSuppliers(q: v),
      style: GoogleFonts.inter(color: Colors.white),
      cursorColor: Colors.white,
      decoration: InputDecoration(
        hintText: 'Search suppliers...',
        hintStyle: GoogleFonts.inter(color: Colors.white38),
        prefixIcon: const Icon(Icons.search, color: Colors.white38),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.05),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.18)),
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
      ),
    );
  }

  Widget _buildAddButton() {
    return ElevatedButton.icon(
      onPressed: _openAddSupplier,
      icon: const Icon(Icons.person_add, color: Colors.black),
      label: Text('Add Supplier', style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: Colors.black)),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 0,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isMobile = constraints.maxWidth < 600;

        Widget headerContent = Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: isMobile
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildSearchField(),
                    const SizedBox(height: 12),
                    _buildAddButton(),
                  ],
                )
              : Row(
                  children: [
                    Expanded(child: _buildSearchField()),
                    const SizedBox(width: 12),
                    _buildAddButton(),
                  ],
                ),
        );

        return CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: headerContent,
            ),
            SliverFillRemaining(
              hasScrollBody: true,
              child: _loading
            ? GridView.builder(
                padding: const EdgeInsets.all(24),
                // Compact cards: similar sizing to product/stock cards for responsiveness
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 180,
                  childAspectRatio: 1.5,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                ),
                itemCount: 8,
                itemBuilder: (context, index) => _buildShimmerCard(),
              )
            : Column(
                children: [
                  Expanded(
                    child: GridView.builder(
                padding: const EdgeInsets.all(24),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 180, childAspectRatio: 1.5, crossAxisSpacing: 16, mainAxisSpacing: 16),
                      itemCount: _suppliers.length,
                          itemBuilder: (context, index) {
                      final s = _suppliers[index];
                      return InkWell(
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SupplierDetailPage(supplierId: s['supplier_id']))),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.08), width: 1),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.04),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Center(child: Icon(Icons.local_shipping, size: 28, color: Colors.white70)),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(s['name'] ?? '', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white), maxLines: 2, overflow: TextOverflow.ellipsis),
                                    const SizedBox(height: 6),
                                    Text(s['email'] ?? '-', style: GoogleFonts.inter(color: Colors.white54, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(Icons.chevron_right, color: Colors.white54),
                            ],
                          ),
                        ),
                      );
                          },
                    ),
                  ),
                  if (_suppliers.length < _total)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: ElevatedButton(
                        onPressed: _loading ? null : () {
                          setState(() { _page += 1; });
                          _fetchSuppliers();
                        },
                        child: _loading ? const SizedBox(width:16,height:16,child:CircularProgressIndicator(strokeWidth:2)) : Text('Load more'),
                      ),
                    )
                ],
              ),
        ),
      ],
    );
      },
    );
  }

  Widget _buildShimmerCard() {
    return AnimatedBuilder(
      animation: _shimmerController,
      builder: (context, child) {
        final shimmerWidth = MediaQuery.of(context).size.width;
        return SizedBox(
          height: 120,
          child: ShaderMask(
            shaderCallback: (rect) {
              return LinearGradient(
                begin: Alignment(-1.0 - (1.0 - _shimmerController.value) * 2, 0),
                end: Alignment(1.0 + (1.0 - _shimmerController.value) * 2, 0),
                colors: [Colors.white.withOpacity(0.06), Colors.white.withOpacity(0.18), Colors.white.withOpacity(0.06)],
                stops: const [0.25, 0.5, 0.75],
              ).createShader(Rect.fromLTWH(0, 0, shimmerWidth, rect.height));
            },
            blendMode: BlendMode.srcATop,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(height: 16, width: 120, color: Colors.white.withOpacity(0.02)),
                  const SizedBox(height: 12),
                  Container(height: 12, width: 200, color: Colors.white.withOpacity(0.02)),
                  const SizedBox(height: 8),
                  Container(height: 12, width: 150, color: Colors.white.withOpacity(0.02)),
                  const Spacer(),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Container(height: 12, width: 100, color: Colors.white.withOpacity(0.02)),
                    Container(height: 12, width: 40, color: Colors.white.withOpacity(0.02)),
                  ])
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
