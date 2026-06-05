import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:dio/dio.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/product.dart';
import '../bloc/product_bloc.dart';
import '../widgets/add_product_screen.dart';
import '../../data/models/product_model.dart';

class ProductsPage extends StatefulWidget {
  const ProductsPage({super.key});

  @override
  State<ProductsPage> createState() => _ProductsPageState();
}

class _ProductsPageState extends State<ProductsPage> {
  final _searchCtrl = TextEditingController();
  final _searchFocusNode = FocusNode();
  final Dio _dio = Dio();
  final String _baseUrl = 'https://pos-backend.posai.workers.dev/api';
  int _page = 1;
  int _limit = 20;
  int _total = 0;
  bool _isLoadingMore = false;
  final ScrollController _scrollController = ScrollController();
  List<Product> _products = [];

  @override
  void initState() {
    super.initState();
    context.read<ProductBloc>().add(LoadProductsEvent());
    _fetchProducts();
    _scroll_controller_setup();
  }

  void _scroll_controller_setup(){
    _scrollController.addListener(() {
      if (_scrollController.position.maxScrollExtent - _scrollController.position.pixels < 300) {
        if (!_isLoadingMore && (_total == 0 || _products.length < _total)) {
          _fetchProducts(loadMore: true);
        }
      }
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _searchFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchProducts({bool loadMore = false}) async {
    if (loadMore) {
      _isLoadingMore = true;
      _page += 1;
    } else {
      _page = 1;
      _products.clear();
      _isLoadingMore = false;
    }
    try {
      final resp = await _dio.get('$_baseUrl/products', queryParameters: {'page': _page, 'limit': _limit});
      if (mounted && resp.statusCode == 200 && resp.data['success'] == true) {
        final List data = resp.data['data'];
        final meta = resp.data['meta'] ?? {};
        _total = meta['total'] ?? _total;
        final loaded = data.map((e) => ProductModel.fromJson(e)).toList().cast<Product>();
        if (mounted) {
          setState(() {
            _products.addAll(loaded);
          });
        }
      }
    } catch (_) {}
    if (mounted) {
      setState(() { _isLoadingMore = false; });
    }
  }

  void _onSearch(String query) {
    context.read<ProductBloc>().add(LoadProductsEvent(query: query));
  }

  void _showAddProductDialog() {
    showDialog(
      context: context,
      useSafeArea: false, // Full screen
      builder: (_) => AddProductScreen(bloc: context.read<ProductBloc>()),
    );
  }

  Widget _buildSearchBar() {
    return BlocBuilder<ProductBloc, ProductState>(
      builder: (context, state) {
        List<Product> availableProducts = [];
        if (state is ProductLoaded) availableProducts = state.products;

        return RawAutocomplete<Product>(
          textEditingController: _searchCtrl,
          focusNode: _searchFocusNode,
          optionsBuilder: (TextEditingValue textEditingValue) {
             if (textEditingValue.text.isEmpty) {
               return const Iterable<Product>.empty();
             }
             return availableProducts.where((Product option) {
               return option.name.toLowerCase().contains(textEditingValue.text.toLowerCase());
             });
          },
          onSelected: (Product selection) {
             _searchCtrl.text = selection.name;
             _onSearch(selection.name);
          },
          fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
            return TextField(
              controller: controller,
              focusNode: focusNode,
              onChanged: _onSearch,
              style: GoogleFonts.inter(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search products...',
                hintStyle: GoogleFonts.inter(color: Colors.white38),
                prefixIcon: const Icon(Icons.search, color: Colors.white38),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.05),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
              ),
            );
          },
          optionsViewBuilder: (context, onSelected, options) {
            return Align(
              alignment: Alignment.topLeft,
              child: Material(
                elevation: 8.0,
                color: AppColors.secondary,
                borderRadius: BorderRadius.circular(12),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 200, maxWidth: 300),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(8),
                    shrinkWrap: true,
                    itemCount: options.length,
                    itemBuilder: (BuildContext context, int index) {
                      final Product option = options.elementAt(index);
                      return InkWell(
                        onTap: () => onSelected(option),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          child: Text(option.name, style: GoogleFonts.inter(color: Colors.white)),
                        ),
                      );
                    },
                  ),
                ),
              ),
            );
          },
        );
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isMobile = constraints.maxWidth < 600;

        Widget headerContent = Container(
          padding: EdgeInsets.symmetric(
            horizontal: isMobile ? 16 : 24,
            vertical: isMobile ? 12 : 24,
          ),
          child: isMobile 
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Text('Products', 
                          style: GoogleFonts.inter(
                              fontSize: 20, 
                              fontWeight: FontWeight.bold, 
                              color: Colors.white)),
                      const Spacer(),
                      ElevatedButton.icon(
                        onPressed: _showAddProductDialog,
                        icon: const Icon(Icons.add, color: Colors.black, size: 16),
                        label: Text('Add', 
                            style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w600, 
                                color: Colors.black)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          elevation: 0,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: IconButton(
                          constraints: const BoxConstraints(),
                          padding: const EdgeInsets.all(8),
                          icon: const Icon(Icons.filter_list, color: Colors.white, size: 18),
                          onPressed: () {},
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildSearchBar(),
                ],
              )
            : Row(
                children: [
                  Text('Products', style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(width: 24),
                  Expanded(child: _buildSearchBar()),
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    onPressed: _showAddProductDialog,
                    icon: const Icon(Icons.add, color: Colors.black),
                    label: Text('Add Product', style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: Colors.black)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                  ),
                ],
              ),
        );

        return ListView(
          controller: _scrollController,
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.zero,
          children: [
            headerContent,
            BlocBuilder<ProductBloc, ProductState>(
            builder: (context, state) {
              if (state is ProductLoading) {
                return GridView.builder(
                  padding: const EdgeInsets.all(24),
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 180,
                    childAspectRatio: 0.60,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  itemCount: 12,
                  itemBuilder: (context, index) {
                    return Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.02),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.05), width: 1),
                      ),
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            height: 80,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            height: 12,
                            width: 100,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const Spacer(),
                          Container(
                            height: 14,
                            width: 60,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              } else if (state is ProductError) {
                return Center(
                  child: Text('Error: ${state.message}',
                      style: GoogleFonts.inter(color: Colors.redAccent)),
                );
              } else if (state is ProductLoaded) {
                final products = state.products;
                if (products.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.inventory_2_outlined, size: 64, color: Colors.white24),
                        const SizedBox(height: 16),
                        Text('No products found', style: GoogleFonts.inter(color: Colors.white54, fontSize: 18)),
                      ],
                    ),
                  );
                }

                return GridView.builder(
                  padding: const EdgeInsets.all(24),
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 180,
                    childAspectRatio: 0.60,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  itemCount: _products.length,
                  itemBuilder: (context, index) {
                    final product = _products[index];
                    return Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 1),
                      ),
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Image — flexible, takes up remaining space
                          Expanded(
                            child: Container(
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: product.productUrl.isNotEmpty
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: CachedNetworkImage(
                                      imageUrl: product.productUrl,
                                      fit: BoxFit.cover,
                                      placeholder: (c, u) => Container(color: Colors.white12),
                                      errorWidget: (c, u, e) => const Icon(Icons.image, size: 24, color: Colors.white24),
                                    ),
                                  )
                                : const Icon(Icons.image, size: 24, color: Colors.white24),
                            ),
                          ),
                          const SizedBox(height: 6),
                          // Product name
                          Text(product.name,
                              style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 4),
                          // Price + QR row
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              // Pricing Section
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text('LKR ${product.sellingValue.toStringAsFixed(2)}',
                                        style: GoogleFonts.inter(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.white),
                                        overflow: TextOverflow.ellipsis),
                                    if (product.offerHave) ...[
                                      const SizedBox(height: 2),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.green.withValues(alpha: 0.2),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text('-${product.offerPercentage.toStringAsFixed(0)}%',
                                            style: GoogleFonts.inter(color: Colors.greenAccent, fontSize: 9, fontWeight: FontWeight.bold)),
                                      ),
                                    ]
                                  ],
                                ),
                              ),
                              // QR Code Section
                              if (product.productKey.isNotEmpty) 
                                GestureDetector(
                                  onTap: () {
                                    showDialog(
                                      context: context,
                                      barrierColor: Colors.black.withValues(alpha: 0.6),
                                      builder: (context) {
                                        return BackdropFilter(
                                          filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
                                          child: Dialog(
                                            backgroundColor: Colors.transparent,
                                            elevation: 0,
                                            child: Center(
                                              child: Container(
                                                padding: const EdgeInsets.all(32),
                                                decoration: BoxDecoration(
                                                  color: Colors.white,
                                                  borderRadius: BorderRadius.circular(24),
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: Colors.black.withValues(alpha: 0.5),
                                                      blurRadius: 40,
                                                      offset: const Offset(0, 20),
                                                    )
                                                  ],
                                                ),
                                                child: Column(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Text('Product Code', style: GoogleFonts.inter(color: Colors.black45, fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 1.5)),
                                                    const SizedBox(height: 24),
                                                    Container(
                                                      padding: const EdgeInsets.all(8),
                                                      decoration: BoxDecoration(
                                                        borderRadius: BorderRadius.circular(16),
                                                        border: Border.all(color: Colors.black12, width: 2),
                                                      ),
                                                      child: QrImageView(
                                                        data: product.productKey,
                                                        version: QrVersions.auto,
                                                        size: 260.0,
                                                        backgroundColor: Colors.white,
                                                        errorCorrectionLevel: QrErrorCorrectLevel.H,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 24),
                                                    Text(product.name, textAlign: TextAlign.center, style: GoogleFonts.inter(color: Colors.black, fontSize: 18, fontWeight: FontWeight.w800)),
                                                    const SizedBox(height: 4),
                                                    Text(product.productKey, style: GoogleFonts.inter(color: Colors.black54, fontSize: 16, fontWeight: FontWeight.w600)),
                                                    const SizedBox(height: 32),
                                                    SizedBox(
                                                      width: double.infinity,
                                                      child: ElevatedButton(
                                                        style: ElevatedButton.styleFrom(
                                                          backgroundColor: Colors.black,
                                                          foregroundColor: Colors.white,
                                                          padding: const EdgeInsets.symmetric(vertical: 16),
                                                          elevation: 0,
                                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                                        ),
                                                        onPressed: () => Navigator.of(context).pop(),
                                                        child: Text('Close', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16)),
                                                      ),
                                                    )
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                    );
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(8),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.2),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        )
                                      ]
                                    ),
                                    child: QrImageView(
                                      data: product.productKey,
                                      version: QrVersions.auto,
                                      size: 32.0,
                                      backgroundColor: Colors.white,
                                      padding: EdgeInsets.zero,
                                      errorCorrectionLevel: QrErrorCorrectLevel.L,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                );
              }
              return const SizedBox();
            },
          ),
          if (_isLoadingMore)
            Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: SizedBox(height: 48, child: Center(child: CircularProgressIndicator())),
            ),
          ],
        );
      },
    );
  }
}
