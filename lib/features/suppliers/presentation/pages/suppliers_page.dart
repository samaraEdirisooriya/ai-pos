import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:responsive_builder/responsive_builder.dart';
import 'supplier_detail_page.dart';
import 'add_supplier_screen.dart';

class SuppliersPage extends StatefulWidget {
  const SuppliersPage({super.key});

  @override
  State<SuppliersPage> createState() => _SuppliersPageState();
}

class _SuppliersPageState extends State<SuppliersPage> with SingleTickerProviderStateMixin {
  List<dynamic> _suppliers = [];
  bool _loading = false;
  bool _isLoadingMore = false;
  final TextEditingController _searchController = TextEditingController();
  int _page = 1;
  final int _limit = 20;
  int _total = 0;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _fetchSuppliers();
    _shimmerController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat();
    _scrollController.addListener(() {
      try {
        if (_scrollController.position.maxScrollExtent - _scrollController.position.pixels < 300) {
          if (!_loading && !_isLoadingMore && _suppliers.length < _total) {
            _isLoadingMore = true;
            setState(() { _page += 1; });
            _fetchSuppliers();
          }
        }
      } catch (_) {}
    });
  }

  late AnimationController _shimmerController;
  final _dio = Dio();

  Future<void> _fetchSuppliers({String? q}) async {
    setState(() => _loading = true);
    try {
      final url = 'https://pos-backend.posai.workers.dev/api/suppliers${q != null && q.isNotEmpty ? '?q=${Uri.encodeComponent(q)}&page=1&limit=$_limit' : '?page=$_page&limit=$_limit'}';
      final resp = await _dio.get(url);
      final data = resp.data;
      if (mounted && data != null && data['success'] == true) {
        final List newItems = List.from(data['data'] ?? []);
        final meta = data['meta'] ?? {};
        if (mounted) {
          setState(() {
            if (q != null && q.isNotEmpty) {
              _suppliers = newItems;
              _page = 1;
              _isLoadingMore = false;
            } else {
              if (_page == 1) {
                _suppliers = newItems;
              } else {
                _suppliers.addAll(newItems);
              }
            }
            _total = meta['total'] ?? _suppliers.length;
          });
        }
      }
    } catch (e) {
      // ignore
    }
    if (mounted) {
      setState(() { 
        _loading = false;
        _isLoadingMore = false;
      });
    }
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
    _scrollController.dispose();
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
    return ResponsiveBuilder(
      builder: (context, sizingInformation) {
        final isMobile = sizingInformation.deviceScreenType == DeviceScreenType.mobile;
        final isTablet = sizingInformation.deviceScreenType == DeviceScreenType.tablet;
        final padding = isMobile ? 12.0 : (isTablet ? 20.0 : 24.0);
        final horizontalPadding = isMobile ? 12.0 : (isTablet ? 16.0 : 24.0);

        Widget headerContent = Padding(
          padding: EdgeInsets.symmetric(
            horizontal: horizontalPadding,
            vertical: padding,
          ),
          child: isMobile
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: 12,
                  children: [
                    _buildSearchField(),
                    _buildAddButton(),
                  ],
                )
              : Row(
                  spacing: 16,
                  children: [
                    Expanded(child: _buildSearchField()),
                    _buildAddButton(),
                  ],
                ),
        );

        final crossAxisCount = isMobile ? 1 : (isTablet ? 2 : 3);

        return ListView(
          controller: _scrollController,
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.zero,
          children: [
            headerContent,
            _loading && _suppliers.isEmpty
              ? GridView.builder(
                  padding: EdgeInsets.all(padding),
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    childAspectRatio: 3.2,
                    crossAxisSpacing: padding,
                    mainAxisSpacing: padding,
                  ),
                  itemCount: 8,
                  itemBuilder: (context, index) => _buildShimmerCard(),
                )
              : Column(
                  children: [
                    GridView.builder(
                      padding: EdgeInsets.all(padding),
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        childAspectRatio: 3.2,
                        crossAxisSpacing: padding,
                        mainAxisSpacing: padding,
                      ),
                      itemCount: _suppliers.length,
                      itemBuilder: (context, index) {
                        final s = _suppliers[index];
                        return InkWell(
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SupplierDetailPage(supplierId: s['supplier_id']))),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: padding,
                              vertical: padding * 0.75,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.08),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              spacing: padding,
                              children: [
                                Container(
                                  width: isMobile ? 40 : 48,
                                  height: isMobile ? 40 : 48,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.04),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Center(
                                    child: Icon(
                                      Icons.local_shipping,
                                      size: 24,
                                      color: Colors.white70,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    spacing: 2,
                                    children: [
                                      Text(
                                        s['name'] ?? '',
                                        style: GoogleFonts.inter(
                                          fontSize: isMobile ? 13 : 14,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Text(
                                        s['email'] ?? '-',
                                        style: GoogleFonts.inter(
                                          color: Colors.white54,
                                          fontSize: isMobile ? 11 : 12,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(
                                  Icons.chevron_right,
                                  color: Colors.white54,
                                  size: isMobile ? 16 : 18,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                    if (_suppliers.length < _total)
                      Padding(
                        padding: EdgeInsets.all(padding),
                        child: _isLoadingMore
                            ? const SizedBox(
                                height: 48,
                                child: Center(
                                  child: CircularProgressIndicator(),
                                ),
                              )
                            : const SizedBox.shrink(),
                      )
                  ],
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
        return ShaderMask(
          shaderCallback: (rect) {
            return LinearGradient(
              begin: Alignment(-1.0 - (1.0 - _shimmerController.value) * 2, 0),
              end: Alignment(1.0 + (1.0 - _shimmerController.value) * 2, 0),
              colors: [Colors.white.withValues(alpha: 0.06), Colors.white.withValues(alpha: 0.18), Colors.white.withValues(alpha: 0.06)],
              stops: const [0.25, 0.5, 0.75],
            ).createShader(rect);
          },
          blendMode: BlendMode.srcATop,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Container(width: 48, height: 48, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(10))),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(height: 14, width: double.infinity, color: Colors.white.withValues(alpha: 0.05)),
                      const SizedBox(height: 8),
                      Container(height: 10, width: 100, color: Colors.white.withValues(alpha: 0.05)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
