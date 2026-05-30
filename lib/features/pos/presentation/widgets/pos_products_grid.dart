import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:responsive_builder/responsive_builder.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/product.dart' as PosProduct;
import '../../../products/data/models/product_model.dart';
import '../../../products/data/datasources/product_remote_data_source.dart';
import '../bloc/pos_bloc.dart';

// Local lightweight model used by POS UI (maps from ProductModel)
class POSItem {
  final String id;
  final String name;
  final double price;
  final String imageUrl;
  POSItem({required this.id, required this.name, required this.price, required this.imageUrl});
}

class PosProductsGrid extends StatefulWidget {
  const PosProductsGrid({super.key});

  @override
  State<PosProductsGrid> createState() => _PosProductsGridState();
}

class _PosProductsGridState extends State<PosProductsGrid> {
  final NumberFormat _lkr = NumberFormat.currency(locale: 'en_LK', symbol: 'LKR ');
  int _selectedCategory = 0;
  final categories = ['All', 'Laptops', 'Phones', 'Audio', 'Tablets', 'Accessories'];
  final Dio _dio = Dio();
  final ProductRemoteDataSourceImpl _remote = ProductRemoteDataSourceImpl(dio: Dio());
  final List<POSItem> _products = [];
  bool _loading = false;
  String _query = '';
  Timer? _debounce;
  int _page = 1;
  int _limit = 50;
  int _total = 0;
  List<POSItem> _mostUsed = [];

  @override
  Widget build(BuildContext context) {
    return ResponsiveBuilder(
      builder: (context, sizingInformation) {
        bool isMobile =
            sizingInformation.deviceScreenType == DeviceScreenType.mobile;

        return LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxHeight < 80 || constraints.maxWidth < 60) {
              return const SizedBox.shrink();
            }
            return Column(
              children: [
                _buildSearchBar(isMobile),
                const SizedBox(height: 8),
                SizedBox(
                  height: 30,
                  child: _buildCategories(isMobile),
                ),
                const SizedBox(height: 8),
                if (_mostUsed.isNotEmpty) _buildMostUsed(isMobile),
                const SizedBox(height: 8),
                const SizedBox(height: 8),
                Expanded(
                  child: SingleChildScrollView(
                    child: _loading && _products.isEmpty
                      ? GridView.builder(
                          padding: EdgeInsets.zero,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: isMobile ? 160 : 220,
                            childAspectRatio: isMobile ? 0.95 : 1.05,
                            crossAxisSpacing: isMobile ? 8 : 12,
                            mainAxisSpacing: isMobile ? 8 : 12,
                          ),
                          itemCount: 8,
                          itemBuilder: (context, index) {
                            return Container(
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.03),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
                              ),
                              padding: const EdgeInsets.all(8),
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Container(height: isMobile ? 40 : 50, color: Colors.white.withValues(alpha: 0.02)),
                                const SizedBox(height: 8),
                                Container(height: 10, width: double.infinity, color: Colors.white.withValues(alpha: 0.02)),
                                const SizedBox(height: 6),
                                Container(height: 12, width: 60, color: Colors.white.withValues(alpha: 0.02)),
                              ]),
                            );
                          },
                        )
                      : GridView.builder(
                          padding: EdgeInsets.zero,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: isMobile ? 120 : 160,
                            childAspectRatio: isMobile ? 0.85 : 0.9,
                            crossAxisSpacing: isMobile ? 6 : 8,
                            mainAxisSpacing: isMobile ? 6 : 8,
                          ),
                          itemCount: _products.length,
                          itemBuilder: (context, index) {
                            // lazy load next page
                            if (index >= _products.length - 4 && _products.length < _total) {
                              _fetchProducts(loadMore: true);
                            }
                            return _draggableCard(_products[index], isMobile);
                          },
                        ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    _fetchMostUsed();
    _fetchProducts();
  }

  Future<void> _fetchMostUsed() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final usageRaw = prefs.getString('pos_usage') ?? '{}';
      final Map<String, dynamic> usage = jsonDecode(usageRaw);
      final ids = usage.keys.toList()
        ..sort((a, b) => (usage[b] as int).compareTo(usage[a] as int));
      // map to product details by fetching product info for top 6
      final top = ids.take(6).toList();
      final items = <POSItem>[];
      for (final id in top) {
        try {
          final resp = await _dio.get('${_remote.baseUrl}/products', queryParameters: {'q': id, 'page': 1, 'limit': 1});
          if (resp.statusCode == 200 && resp.data['success'] == true) {
            final data = resp.data['data'];
            if (data is List && data.isNotEmpty) {
              final model = ProductModel.fromJson(data[0]);
              items.add(POSItem(id: model.productId, name: model.name, price: model.sellingValue, imageUrl: model.productUrl));
            }
          }
        } catch (_) {}
      }
      setState(() { _mostUsed = items; });
    } catch (_) {}
  }

  Future<void> _fetchProducts({bool loadMore = false}) async {
    if (_loading) return;
    setState(() { _loading = true; });
    try {
      if (!loadMore) { _page = 1; _products.clear(); }
      final response = await _dio.get('${_remote.baseUrl}/products', queryParameters: _query.isNotEmpty ? {'q': _query, 'page': _page, 'limit': _limit} : {'page': _page, 'limit': _limit});
      if (response.statusCode == 200 && response.data['success'] == true) {
        final List data = response.data['data'];
        final meta = response.data['meta'] ?? {};
        _total = meta['total'] ?? _total;
        final mapped = data.map((e) {
          final model = ProductModel.fromJson(Map<String, dynamic>.from(e));
          return POSItem(id: model.productId, name: model.name, price: model.sellingValue, imageUrl: model.productUrl);
        }).toList();
        setState(() {
          _products.addAll(mapped);
          _page += 1;
        });
      }
    } catch (e) {
      // ignore
    } finally {
      setState(() { _loading = false; });
    }
  }

  Widget _buildSearchBar(bool isMobile) {
    return Container(
      height: isMobile ? 32 : 36,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextField(
        style: GoogleFonts.inter(fontSize: isMobile ? 11 : 12, color: Colors.white),
        decoration: InputDecoration(
          hintText: 'Search...',
          hintStyle: GoogleFonts.inter(fontSize: 11, color: Colors.white38),
          prefixIcon: const Icon(Icons.search, color: Colors.white38, size: 16),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
        onChanged: (v) {
          _debounce?.cancel();
          _debounce = Timer(const Duration(milliseconds: 350), () {
            _query = v.trim();
            _page = 1;
            _fetchProducts();
          });
        },
      ),
    );
  }

  Widget _buildMostUsed(bool isMobile) {
    return SizedBox(
      height: 64,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _mostUsed.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final it = _mostUsed[index];
          return GestureDetector(
            onTap: () {
              // map to pos product and add
              final p = PosProduct.Product(id: it.id, name: it.name, category: '', price: it.price, imageUrl: it.imageUrl);
              context.read<PosBloc>().add(AddProductToCart(p));
            },
            child: Container(
              width: 120,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(it.name, style: GoogleFonts.inter(fontSize: 11, color: Colors.white), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const Spacer(),
                                Text(_lkr.format(it.price), style: GoogleFonts.inter(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCategories(bool isMobile) {
    return ListView.separated(
      scrollDirection: Axis.horizontal,
      itemCount: categories.length,
      separatorBuilder: (_, a) => const SizedBox(width: 6),
      itemBuilder: (context, index) {
        final sel = _selectedCategory == index;
        return GestureDetector(
          onTap: () => setState(() => _selectedCategory = index),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: isMobile ? 10 : 12),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: sel ? Colors.white : Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              categories[index],
              style: GoogleFonts.inter(
                  fontSize: isMobile ? 10 : 11,
                  fontWeight: sel ? FontWeight.w600 : FontWeight.w400,
                  color: sel ? AppColors.primary : Colors.white70),
            ),
          ),
        );
      },
    );
  }

  Widget _draggableCard(POSItem product, bool isMobile) {
    final posProduct = PosProduct.Product(id: product.id, name: product.name, category: '', price: product.price, imageUrl: product.imageUrl);
    final card = Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: Colors.white.withValues(alpha: 0.1), width: 1),
      ),
      padding: EdgeInsets.all(isMobile ? 10 : 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            height: isMobile ? 70 : 100,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.image,
                size: isMobile ? 28 : 36,
                color: Colors.white24),
          ),
          const SizedBox(height: 4),
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: isMobile ? 40 : 48),
              child: Text(product.name,
                style: GoogleFonts.inter(
                  fontSize: isMobile ? 11 : 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.white),
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
            ),
          const SizedBox(height: 2),
            Text(_lkr.format(product.price),
              style: GoogleFonts.inter(
                fontSize: isMobile ? 12 : 14,
                fontWeight: FontWeight.w700,
                color: AppColors.primary)),
        ],
      ),
    );

    return Draggable<PosProduct.Product>(
      data: posProduct,
      feedback: Material(
        color: Colors.transparent,
        child: Opacity(
          opacity: 0.9,
          child: SizedBox(
            width: isMobile ? 120 : 160,
            height: isMobile ? 140 : 180,
            child: card,
          ),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.3, child: card),
      child: GestureDetector(
        onTap: () {
          context.read<PosBloc>().add(AddProductToCart(posProduct));
        },
        child: card,
      ),
    );
  }
}
