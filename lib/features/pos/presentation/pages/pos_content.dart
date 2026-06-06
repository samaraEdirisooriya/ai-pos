import 'dart:ui';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:responsive_builder/responsive_builder.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';
import 'package:toastification/toastification.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/services/active_scanner.dart';
import '../../../../core/services/scan_broadcast.dart';
import '../../domain/entities/product.dart' as PosProduct;
import '../../../stocks/data/models/stock_item.dart';
import '../bloc/pos_bloc.dart';
import '../widgets/pos_cart_section.dart';
import '../widgets/pos_products_grid.dart';

/// Standalone POS content designed to live inside the gradient bottom panel.
class PosContent extends StatefulWidget {
  const PosContent({super.key});

  @override
  State<PosContent> createState() => _PosContentState();
}

class _PosContentState extends State<PosContent> {
  Timer? _pollTimer;
  String? _currentSessionId;
  final Set<String> _seenScanIds = {};
  bool _isScannerDialogOpen = false;

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  void _openCloudScanner(BuildContext parentContext) async {
    // 1. Generate new session (old one stops working for this instance)
    final sessionId = DateTime.now().millisecondsSinceEpoch.toString();
    _currentSessionId = sessionId;
    _seenScanIds.clear();

    // 2. Stop old timer
    _pollTimer?.cancel();

    final workerUrl =
        Uri.parse('https://pos-backend.posai.workers.dev/scanner/$sessionId');

    // 3. Start background polling (persists until session changes or widget disposed)
    _startBackgroundPolling(parentContext, sessionId);

    // 4. Update Global scanner state
    ActiveScanner.setSession(sessionId);

    // 5. Open dialog
    _isScannerDialogOpen = true;
    if (!mounted) return;

    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (dialogContext, a1, a2) {
        return Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: 420,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.secondary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Mobile POS Link',
                      style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Container(
                        width: 200,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12)),
                        child: QrImageView(
                            data: workerUrl.toString(),
                            version: QrVersions.auto,
                            size: 180),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Scan with Phone',
                                style: GoogleFonts.inter(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            Text(
                                'Once connected, you can scan items in the background. Dialog will close on first scan.',
                                style: GoogleFonts.inter(
                                    color: Colors.white70, fontSize: 13)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            if (await canLaunchUrl(workerUrl)) {
                              await launchUrl(workerUrl,
                                  mode: LaunchMode.externalApplication);
                            }
                          },
                          child:
                              Text('Open on Phone', style: GoogleFonts.inter()),
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 92,
                        child: OutlinedButton(
                          onPressed: () {
                            Navigator.pop(dialogContext);
                          },
                          child: Text('Close',
                              style: GoogleFonts.inter(color: Colors.white)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    ).then((_) {
      _isScannerDialogOpen = false;
    });
  }

  void _startBackgroundPolling(BuildContext parentContext, String sessionId) {
    _pollTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
      // Ensure we only process if this is still the active session
      if (_currentSessionId != sessionId) return;

      try {
        final uri = Uri.parse(
            'https://pos-backend.posai.workers.dev/api/scanner/status/$sessionId');
        final resp = await HttpClient().getUrl(uri).then((r) => r.close());
        final body = await resp.transform(utf8.decoder).join();
        final data = jsonDecode(body);

        if (data != null && data['success'] == true && data['scans'] is List) {
          final List scans = List.from(data['scans']);
          for (final s in scans) {
            final id = s['id']?.toString();
            if (id != null && !_seenScanIds.contains(id)) {
              _seenScanIds.add(id);
              
              // Handle adding to cart
              await _handleNewScan(parentContext, sessionId, s);

              // Auto-close dialog on first scan
              if (_isScannerDialogOpen && mounted) {
                Navigator.of(context, rootNavigator: true).pop();
              }
            }
          }
          ActiveScanner.pendingCount.value = scans.length;
        }
      } catch (e) {
        debugPrint('Polling background error: $e');
      }
    });
  }

  Future<void> _handleNewScan(
      BuildContext parentContext, String sessionId, dynamic scanData) async {
    try {
      SystemSound.play(SystemSoundType.click);
    } catch (_) {}

    final scannedCode = scanData['code'];

    try {
      // Try fast lookup by key first (supports full-catalog scans without loading all items)
      Map<String, dynamic>? item = await _lookupProductRaw(scannedCode);
      if (item != null) {
        final posProduct = PosProduct.Product(
          id: item['product_id'],
          name: item['name'],
          category: 'Scanned',
          price: (item['selling_value'] as num).toDouble(),
          imageUrl: item['product_url'] ?? '',
        );

        if (mounted) {
          parentContext.read<PosBloc>().add(AddProductToCart(posProduct));

          toastification.show(
            context: parentContext,
            type: ToastificationType.success,
            style: ToastificationStyle.flatColored,
            title: Text('Added to Cart',
                style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
            description: Text('${posProduct.name} added via mobile',
                style: GoogleFonts.inter()),
            alignment: Alignment.topCenter,
            autoCloseDuration: const Duration(seconds: 2),
          );
        }

        // Clean up scan from backend
        final uriDel = Uri.parse(
            'https://pos-backend.posai.workers.dev/api/scanner/status/$sessionId/${scanData['id']}');
        final req = await HttpClient().deleteUrl(uriDel);
        await req.close();
      } else {
        toastification.show(
          context: parentContext,
          type: ToastificationType.error,
          style: ToastificationStyle.flatColored,
          title: Text('Product not found',
              style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
          description: Text('Code $scannedCode not in database',
              style: GoogleFonts.inter()),
          alignment: Alignment.topCenter,
          autoCloseDuration: const Duration(seconds: 4),
        );
      }
    } catch (e) {
      debugPrint('Error handling scan: $e');
    }
  }

  Future<Map<String, dynamic>?> _lookupProductRaw(String key) async {
    try {
      final uri = Uri.parse('https://pos-backend.posai.workers.dev/api/products/lookup?key=${Uri.encodeComponent(key)}');
      final resp = await HttpClient().getUrl(uri).then((r) => r.close());
      final body = await resp.transform(utf8.decoder).join();
      final data = jsonDecode(body);
      if (data != null && data['success'] == true && data['data'] != null) {
        return Map<String, dynamic>.from(data['data']);
      }
    } catch (_) {}
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => PosBloc(),
      child: Builder(builder: (context) {
        return ResponsiveBuilder(
          builder: (context, sizingInformation) {
            bool isMobile =
                sizingInformation.deviceScreenType == DeviceScreenType.mobile;

            return LayoutBuilder(
              builder: (context, constraints) {
                // If not enough vertical space, show a compact message
                if (constraints.maxHeight < 120) {
                  return Center(
                    child: Text('Expand panel to use POS',
                        style: GoogleFonts.inter(
                            fontSize: 13, color: Colors.white54)),
                  );
                }

                if (isMobile) {
                  return _buildMobilePOS(context);
                } else {
                  return _buildDesktopPOS(context);
                }
              },
            );
          },
        );
      }),
    );
  }

  // Desktop Layout: Side by side
  Widget _buildDesktopPOS(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Point of Sale',
                    style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: Colors.white)),
                const SizedBox(height: 4),
                Text('Drag products to cart or tap to add',
                    style: GoogleFonts.inter(fontSize: 12, color: Colors.white70)),
              ],
            ),
            // QR Scanner Button for Desktop
            ElevatedButton.icon(
              onPressed: () => _openCloudScanner(context),
              icon: const Icon(Icons.qr_code_scanner, size: 18),
              label: Text('Mobile Scan', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white.withValues(alpha: 0.1),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Products (2/3)
              Expanded(
                flex: 2,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  padding: const EdgeInsets.all(12),
                  child: const PosProductsGrid(),
                ),
              ),
              const SizedBox(width: 12),
              // Cart (1/3)
              Expanded(
                flex: 1,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const PosCartSection(),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Mobile Layout: Tabbed interface
  Widget _buildMobilePOS(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Point of Sale',
                    style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white)),
                IconButton(
                  icon: const Icon(Icons.qr_code_scanner, color: Colors.white),
                  onPressed: () => _openCloudScanner(context),
                ),
              ],
            ),
          ),
          TabBar(
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white54,
            indicatorSize: TabBarIndicatorSize.label,
            tabs: [
              Tab(
                height: 40,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.inventory_2, size: 16),
                    const SizedBox(width: 8),
                    Text('Products',
                        style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
              Tab(
                height: 40,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.shopping_cart, size: 16),
                    const SizedBox(width: 8),
                    Text('Cart',
                        style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
            ],
          ),
          const Divider(color: Colors.white12, height: 1),
          Expanded(
            child: TabBarView(
              children: [
                // Products Tab
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(16),
                      bottomRight: Radius.circular(16),
                    ),
                  ),
                  padding: const EdgeInsets.all(12),
                  child: const PosProductsGrid(),
                ),
                // Cart Tab
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(16),
                      bottomRight: Radius.circular(16),
                    ),
                  ),
                  child: const PosCartSection(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
