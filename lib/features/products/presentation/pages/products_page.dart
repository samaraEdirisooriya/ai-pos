import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:dio/dio.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:responsive_builder/responsive_builder.dart';
import 'package:flutter/foundation.dart';

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
  final int _limit = 20;
  int _total = 0;
  bool _isLoadingMore = false;
  final ScrollController _scrollController = ScrollController();
  final List<Product> _products = [];

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
    return ResponsiveBuilder(
      builder: (context, sizingInformation) {
        final isMobile = sizingInformation.deviceScreenType == DeviceScreenType.mobile;
        final isTablet = sizingInformation.deviceScreenType == DeviceScreenType.tablet;
        final padding = isMobile ? 12.0 : (isTablet ? 20.0 : 24.0);
        final horizontalPadding = isMobile ? 12.0 : (isTablet ? 16.0 : 24.0);
        final titleFontSize = isMobile ? 20.0 : (isTablet ? 28.0 : 32.0);
        final crossAxisCount = isMobile ? 1 : (isTablet ? 2 : 3);

        Widget headerContent = Container(
          padding: EdgeInsets.symmetric(
            horizontal: horizontalPadding,
            vertical: padding,
          ),
          child: isMobile 
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 12,
                children: [
                  // Title + Add Button
                  Row(
                    children: [
                      Expanded(
                        child: Text('Products', 
                            style: GoogleFonts.inter(
                                fontSize: titleFontSize, 
                                fontWeight: FontWeight.bold, 
                                color: Colors.white)),
                      ),
                      CompactIconButton(onPressed: () {}, icon: Icons.filter_list),
                    ],
                  ),
                  // Search + Add
                  Row(
                    spacing: 8,
                    children: [
                      Expanded(child: _buildSearchBar()),
                      CompactIconButton(onPressed: _showAddProductDialog, icon: Icons.add),
                    ],
                  ),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 16,
                children: [
                  // Title row
                  Row(
                    children: [
                      Expanded(
                        child: Text('Products', 
                            style: GoogleFonts.inter(
                                fontSize: titleFontSize, 
                                fontWeight: FontWeight.bold, 
                                color: Colors.white)),
                      ),
                    ],
                  ),
                  // Search + Add row
                  Row(
                    spacing: 16,
                    children: [
                      Expanded(child: _buildSearchBar()),
                      ElevatedButton.icon(
                        onPressed: _showAddProductDialog,
                        icon: const Icon(Icons.add, color: Colors.black),
                        label: Text('Add Product', 
                            style: GoogleFonts.inter(
                                fontWeight: FontWeight.w600, 
                                color: Colors.black,
                                fontSize: isTablet ? 14 : 16)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          padding: EdgeInsets.symmetric(
                              horizontal: 20, 
                              vertical: isTablet ? 12 : 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                      ),
                    ],
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
                    padding: EdgeInsets.all(padding),
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      mainAxisExtent: 110,
                      crossAxisSpacing: padding,
                      mainAxisSpacing: padding,
                    ),
                    itemCount: 12,
                    itemBuilder: (context, index) => _buildShimmerCard(isMobile),
                  );
                } else if (state is ProductError) {
                  return Center(
                    child: Padding(
                      padding: EdgeInsets.all(padding),
                      child: Text('Error: ${state.message}',
                          style: GoogleFonts.inter(color: Colors.redAccent)),
                    ),
                  );
                } else if (state is ProductLoaded) {
                  final products = state.products;
                  if (products.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: EdgeInsets.all(padding),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          spacing: 16,
                          children: [
                            const Icon(Icons.inventory_2_outlined, size: 64, color: Colors.white24),
                            Text('No products found', 
                                style: GoogleFonts.inter(
                                    color: Colors.white54, 
                                    fontSize: isMobile ? 16 : 18)),
                          ],
                        ),
                      ),
                    );
                  }

                  return GridView.builder(
                    padding: EdgeInsets.all(padding),
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      mainAxisExtent: 110,
                      crossAxisSpacing: padding,
                      mainAxisSpacing: padding,
                    ),
                    itemCount: _products.length,
                    itemBuilder: (context, index) =>
                        _buildProductCard(_products[index], isMobile),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
            if (_isLoadingMore)
              Padding(
                padding: EdgeInsets.all(padding),
                child: const Center(child: CircularProgressIndicator()),
              ),
          ],
        );
      },
    );
  }

  Widget _buildShimmerCard(bool isMobile) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05), width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: 110,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: const BorderRadius.horizontal(left: Radius.circular(16)),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    height: 14,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    height: 14,
                    width: 80,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Container(
            width: 80,
            height: 80,
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductCard(Product product, bool isMobile) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08), width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Image Section
          SizedBox(
            width: 110,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Container(
                  color: Colors.white.withValues(alpha: 0.02),
                  child: product.productUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: product.productUrl,
                        fit: BoxFit.cover,
                        placeholder: (c, u) => Container(color: Colors.white.withValues(alpha: 0.02)),
                        errorWidget: (c, u, e) => const Icon(Icons.image, size: 32, color: Colors.white24),
                      )
                    : const Icon(Icons.image, size: 32, color: Colors.white24),
                ),
                if (product.offerHave)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          )
                        ]
                      ),
                      child: Text(
                        '-${product.offerPercentage.toStringAsFixed(0)}%',
                        style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // Info Section
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    product.name,
                    style: GoogleFonts.inter(
                        fontSize: isMobile ? 14 : 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.9)),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'LKR ${product.sellingValue.toStringAsFixed(0)}',
                    style: GoogleFonts.inter(
                        fontSize: isMobile ? 13 : 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.greenAccent),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
          // QR Code Section
          if (product.productKey.isNotEmpty)
            GestureDetector(
              onTap: () => _showQRDialog(product),
              child: Container(
                width: 80,
                height: 80,
                margin: const EdgeInsets.only(right: 12),
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
                  ],
                ),
                child: QrImageView(
                  data: product.productKey,
                  version: QrVersions.auto,
                  padding: EdgeInsets.zero,
                  errorCorrectionLevel: QrErrorCorrectLevel.M,
                ),
              ),
            )
          else
            const SizedBox(width: 92), // placeholder to maintain alignment
        ],
      ),
    );
  }

  void _showQRDialog(Product product) {
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
                  spacing: 16,
                  children: [
                    Text('Product Code',
                        style: GoogleFonts.inter(
                            color: Colors.black45,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.5)),
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
                    Column(
                      spacing: 4,
                      children: [
                        Text(product.name,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                                color: Colors.black,
                                fontSize: 18,
                                fontWeight: FontWeight.w800)),
                        Text(product.productKey,
                            style: GoogleFonts.inter(
                                color: Colors.black54,
                                fontSize: 14,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text('Close',
                            style: GoogleFonts.inter(
                                fontWeight: FontWeight.w700, fontSize: 16)),
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
  }
}

// Helper widget for compact icon buttons
class CompactIconButton extends StatelessWidget {
  final VoidCallback onPressed;
  final IconData icon;
  const CompactIconButton({
    required this.onPressed,
    required this.icon,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: IconButton(
        constraints: const BoxConstraints(),
        padding: const EdgeInsets.all(8),
        icon: Icon(icon, color: Colors.white, size: 18),
        onPressed: onPressed,
      ),
    );
  }
}

