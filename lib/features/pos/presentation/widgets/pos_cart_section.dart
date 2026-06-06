import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'dart:async';
import 'package:google_fonts/google_fonts.dart';
import 'package:responsive_builder/responsive_builder.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/product.dart';
import '../bloc/pos_bloc.dart';
import 'package:dio/dio.dart';
import 'dart:ui';
import '../../../clients/presentation/pages/add_client_screen.dart';
import '../../../clients/data/clients_api.dart';

class PosCartSection extends StatefulWidget {
  const PosCartSection({super.key});

  @override
  State<PosCartSection> createState() => _PosCartSectionState();
}

class _PosCartSectionState extends State<PosCartSection> {
  final NumberFormat _lkr = NumberFormat.currency(locale: 'en_LK', symbol: 'LKR ');
  Map<String, dynamic>? _selectedClient;
  List<Map<String, dynamic>> _clientSuggestions = [];
  Timer? _clientSearchDebounce;

  @override
  Widget build(BuildContext context) {
    return ResponsiveBuilder(
      builder: (context, sizingInformation) {
        final isDesktopOrWeb = sizingInformation.isDesktop || sizingInformation.isTablet;
        
        return LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxHeight < 10 || constraints.maxWidth < 10) {
              return const SizedBox.shrink();
            }
            
            // Apply minimum height only on desktop/web if height is very small
            final shouldApplyMinHeight = isDesktopOrWeb && constraints.maxHeight < 10;
            
            return DragTarget<Product>(
              onAcceptWithDetails: (details) {
                context.read<PosBloc>().add(AddProductToCart(details.data));
              },
              builder: (context, candidateData, rejectedData) {
                final isDragging = candidateData.isNotEmpty;
                return ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    constraints: BoxConstraints(
                      minHeight: shouldApplyMinHeight ? 652 : 0,
                    ),
                    child: Stack(
                      children: [
                         
                        Column(
                          children: [
                            constraints.maxHeight < 10 ? const SizedBox() : _header(context),
                            Divider(color: Colors.white.withValues(alpha: 0.15), height: 1),
                            Expanded(
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(minHeight: 0),
                                child: shouldApplyMinHeight 
                                  ? SingleChildScrollView(
                                      child: _buildCartContent(context),
                                    )
                                  : _buildCartContent(context),
                              ),
                            ),
                            constraints.maxHeight < 10 ? const SizedBox() : _totals(context, constraints.maxHeight < 500),
                          ],
                        ),
                        if (isDragging)
                          Positioned.fill(
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.12),
                                border: Border.all(color: Colors.white, width: 2),
                              ),
                              child: Center(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text('Drop to Add',
                                      style: GoogleFonts.inter(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.primary)),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Future<void> _selectClient(BuildContext context) async {
    final TextEditingController ctrl = TextEditingController();
    Map<String, dynamic>? picked;

    

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setDlgState) {
          return AlertDialog(
            title: const Text('Select Client'),
            content: SizedBox(
              width: 440,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: ctrl,
                    decoration: const InputDecoration(hintText: 'Search name or email'),
                    onChanged: (v) {
                      _clientSearchDebounce?.cancel();
                      _clientSearchDebounce = Timer(const Duration(milliseconds: 300), () async {
                        final api = ClientsApi();
                        final res = await api.fetchClients(q: v, page: 1, limit: 10);
                        final items = res?['data'] as List? ?? [];
                        setDlgState(() { _clientSuggestions = items.map((e) => Map<String, dynamic>.from(e)).toList(); });
                      });
                    },
                  ),
                  const SizedBox(height: 8),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 220),
                    child: _clientSuggestions.isEmpty
                      ? const Center(child: Text('No suggestions', style: TextStyle(color: Colors.white54)))
                      : ListView.separated(
                          shrinkWrap: true,
                          itemCount: _clientSuggestions.length,
                          separatorBuilder: (_, _) => const Divider(),
                          itemBuilder: (context, i) {
                            final c = _clientSuggestions[i];
                            return ListTile(
                              title: Text(c['name'] ?? ''),
                              subtitle: Text(c['email'] ?? ''),
                              onTap: () {
                                picked = c;
                                Navigator.of(ctx).pop();
                              },
                            );
                          },
                        ),
                  ),
                  const SizedBox(height: 8),
                  Row(children: [
                    ElevatedButton.icon(onPressed: () async { Navigator.of(ctx).pop(); final res = await Navigator.push(context, MaterialPageRoute(builder: (_) => const AddClientScreen())); if (res == true) { /* refresh the clients list next time */ } }, icon: const Icon(Icons.person_add), label: const Text('Add Client')),
                    const SizedBox(width: 8),
                    TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel'))
                  ])
                ],
              ),
            ),
          );
        });
      }
    );

    if (picked != null) setState(() { _selectedClient = picked; });
  }

  Widget _buildCartContent(BuildContext context) {
    return BlocBuilder<PosBloc, PosState>(
      builder: (context, state) {
        if (state.cartItems.isEmpty) {
          return Center(
            child: SingleChildScrollView(
              child: SizedBox(
                height: 200,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(height: 20,),
                    const Icon(Icons.shopping_cart_checkout,
                        size: 36, color: Colors.white24),
                    const SizedBox(height: 8),
                    Text('Cart is empty',
                        style: GoogleFonts.inter(
                            fontSize: 12, color: Colors.white38)),
                    Text('Drag products here',
                        style: GoogleFonts.inter(
                            fontSize: 10, color: Colors.white24)),
                  ],
                ),
              ),
            ),
          );
        }
        return ListView.separated(
          shrinkWrap: true,
          padding: const EdgeInsets.all(10),
          itemCount: state.cartItems.length,
          separatorBuilder: (_, a) =>
              Divider(color: Colors.white.withValues(alpha: 0.1)),
          itemBuilder: (context, index) {
            final item = state.cartItems[index];
            return _cartRow(context, item);
          },
        );
      },
    );
  }

  Widget _header(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('Current Order',
              style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white)),
          GestureDetector(
            onTap: () => context.read<PosBloc>().add(ClearCart()),
            child: const Icon(Icons.delete_outline,
                color: Colors.white54, size: 16),
          ),
        ],
      ),
    );
  }

  Widget _cartRow(BuildContext context, dynamic item) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Icon(Icons.devices, color: Colors.white38, size: 14),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item.product.name,
                  style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.white),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
                Text(_lkr.format(item.product.price),
                  style: GoogleFonts.inter(
                    fontSize: 10, color: Colors.white70),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
        GestureDetector(
          onTap: () =>
              context.read<PosBloc>().add(RemoveProductFromCart(item.product)),
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.remove_circle_outline,
                color: Colors.white38, size: 24),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text('${item.quantity}',
              style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.white)),
        ),
        GestureDetector(
          onTap: () =>
              context.read<PosBloc>().add(AddProductToCart(item.product)),
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.add_circle_outline,
                color: Colors.white, size: 24),
          ),
        ),
      ],
    );
  }

  Widget _totals(BuildContext context, bool isSmallHeight) {
            if (isSmallHeight) {
              // Compact view for small screens on desktop/web
              return Container(
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  border: const Border(top: BorderSide(color: Colors.white10)),
                ),
                child: BlocBuilder<PosBloc, PosState>(
                  builder: (context, state) {
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('TOTAL',
                                  style: GoogleFonts.inter(
                                      fontSize: 10, color: Colors.white54)),
                              Flexible(
                                child: Text(_lkr.format(state.total),
                                    style: GoogleFonts.inter(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.primary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          height: 32,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: AppColors.primary,
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16)),
                            ),
                            onPressed: state.cartItems.isEmpty ? null : () => _handleCharge(context, state),
                            child: Text('CHARGE',
                                style: GoogleFonts.inter(
                                    fontSize: 11, fontWeight: FontWeight.w800),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              );
            }
            
            // Full view for normal screens (mobile and desktop with enough height)
            return Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
              ),
              child: BlocBuilder<PosBloc, PosState>(
                builder: (context, state) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Subtotal',
                              style: GoogleFonts.inter(
                                  fontSize: 11, color: Colors.white54)),
                          Flexible(
                            child: Text(_lkr.format(state.subtotal),
                                style: GoogleFonts.inter(
                                    fontSize: 11, color: Colors.white),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Discount',
                              style: GoogleFonts.inter(
                                  fontSize: 11, color: Colors.white54)),
                          Flexible(
                            child: Text('-${_lkr.format(state.discount)}',
                                style: GoogleFonts.inter(
                                    fontSize: 11, color: Colors.greenAccent),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                          ),
                        ],
                      ),
                      Divider(color: Colors.white.withValues(alpha: 0.15), height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Total',
                              style: GoogleFonts.inter(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white)),
                          Flexible(
                            child: Text(_lkr.format(state.total),
                                style: GoogleFonts.inter(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Client selector
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: () => _selectClient(context),
                          icon: const Icon(Icons.person_outline, color: Colors.white70),
                          label: Text(_selectedClient == null ? 'Select Client' : (_selectedClient!['name'] ?? 'Client'), style: GoogleFonts.inter(color: Colors.white70)),
                        ),
                      ),
                      SizedBox(
                        width: double.infinity,
                        height: 36,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: AppColors.primary,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18)),
                            elevation: 0,
                          ),
                          onPressed: state.cartItems.isEmpty ? null : () => _handleCharge(context, state),
                          child: Text('Charge',
                              style: GoogleFonts.inter(
                                  fontSize: 13, fontWeight: FontWeight.w700),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                        ),
                      ),
                    ],
                  );
                },
              ),
            );
  }

  Future<void> _handleCharge(BuildContext context, PosState state) async {
    final posBloc = context.read<PosBloc>();
    _showProcessingDialog(context);

    try {
      final dio = Dio();
      final items = state.cartItems.map((ci) => {
            'product_id': ci.product.id,
            'quantity': ci.quantity,
            // set retail_price to 0 to let backend fallback to STOCKS latest prices
            'retail_price': 0,
            'selling_price': ci.product.price,
            'discount_price': 0,
          }).toList();

      final resp = await dio.post('https://pos-backend.posai.workers.dev/api/sales', data: {
        'items': items,
        'client_id': _selectedClient == null ? null : _selectedClient!['client_id'],
        'created_user': 'admin'
      });

      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop(); // close processing

      final success = resp.statusCode == 201 && resp.data['success'] == true;
      if (success) {
        posBloc.add(ClearCart());
        setState(() {
          _selectedClient = null;
        });
        await _showResultDialog(context, true, 'Sale recorded');
      } else {
        final detail = resp.data != null ? resp.data.toString() : 'No body';
        await _showResultDialog(context, false, 'Status ${resp.statusCode}: $detail');
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        await _showResultDialog(context, false, '$e');
      }
    }
  }

  void _showProcessingDialog(BuildContext context) {
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'processing',
      pageBuilder: (ctx, anim1, anim2) {
        return WillPopScope(
          onWillPop: () async => false,
          child: Stack(
            children: [
              // blurred backdrop
              Positioned.fill(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                  child: Container(color: Colors.black.withValues(alpha: 0.35)),
                ),
              ),
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                  decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(12)),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    SizedBox(
                      width: 48,
                      height: 48,
                      child: CircularProgressIndicator(
                        strokeWidth: 4,
                        valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text('Processing', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white, decoration: TextDecoration.none)),
                  ]),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showResultDialog(BuildContext context, bool success, [String? message]) async {
    final color = success ? Colors.green.shade600 : Colors.red.shade600;
    final icon = success ? Icons.check_circle : Icons.cancel;

    final dialogFuture = showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'result',
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (ctx, anim1, anim2) {
        return Stack(
          children: [
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                child: Container(color: Colors.black.withValues(alpha: 0.35)),
              ),
            ),
            Center(
              child: Container(
                width: 260,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(16)),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(icon, size: 72, color: Colors.white),
                  const SizedBox(height: 12),
                  Text(success ? 'Success' : 'Failed', style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white, decoration: TextDecoration.none)),
                  if (message != null) ...[
                    const SizedBox(height: 8),
                    Text(message, style: GoogleFonts.inter(fontSize: 12, color: Colors.white70, decoration: TextDecoration.none), textAlign: TextAlign.center),
                  ],
                ]),
              ),
            ),
          ],
        );
      },
    );

    // Auto-close after a short delay
    Future.delayed(const Duration(milliseconds: 900), () {
      if (Navigator.of(context, rootNavigator: true).canPop()) Navigator.of(context, rootNavigator: true).pop();
    });

    await dialogFuture;
  }

  @override
  void dispose() {
    _clientSearchDebounce?.cancel();
    super.dispose();
  }
}
