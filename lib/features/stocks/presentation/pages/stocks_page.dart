import 'dart:ui';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/services/active_scanner.dart';
import 'package:toastification/toastification.dart';
import '../../../../core/services/scan_broadcast.dart';
import '../bloc/stocks_bloc.dart';
import '../bloc/stocks_event.dart';
import '../bloc/stocks_state.dart';
import '../../data/models/stock_item.dart';
import 'add_stock_screen.dart';
import '../utils/local_qr_scanner_server.dart';
import '../../../../core/services/scan_broadcast.dart';

class StocksPage extends StatefulWidget {
  const StocksPage({super.key});

  @override
  State<StocksPage> createState() => _StocksPageState();
}

class _StocksPageState extends State<StocksPage> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String _sortOption = 'Date';
  
  LocalQrScannerServer? _qrServer;
  StreamSubscription? _qrSubscription;
  bool _addStockOpen = false;
  int _page = 1;
  int _limit = 20;
  int _total = 0;
  bool _isLoadingMore = false;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _fetchStocks();
    _scrollController.addListener(() {
      if (_scrollController.position.maxScrollExtent - _scroll_controller_position() < 300) {
        if (!_isLoadingMore && (_total == 0 || _page * _limit < _total)) {
          _fetchStocks(loadMore: true);
        }
      }
    });
  }

  double _scroll_controller_position(){
    try { return _scroll_controller_position_safe(); } catch (_) { return 0.0; }
  }
  double _scroll_controller_position_safe(){
    return _scrollController.position.pixels;
  }

  void _fetchStocks({String? query, bool loadMore = false}) {
    if (query != null && query.isNotEmpty) {
      _page = 1;
      _total = 0;
    }
    if (loadMore) {
      _isLoadingMore = true;
      _page += 1;
    } else {
      _isLoadingMore = false;
      _page = 1;
    }
    context.read<StocksBloc>().add(FetchStocks(query: query, page: _page, limit: _limit));
  }

  Future<StockItem?> _lookupProductByKey(String key) async {
    try {
      final uri = Uri.parse('https://pos-backend.posai.workers.dev/api/products/lookup?key=${Uri.encodeComponent(key)}');
      final resp = await HttpClient().getUrl(uri).then((r) => r.close());
      final body = await resp.transform(utf8.decoder).join();
      final data = jsonDecode(body);
      if (data != null && data['success'] == true && data['data'] != null) {
        return StockItem.fromJson(Map<String, dynamic>.from(data['data']));
      }
    } catch (_) {}
    return null;
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _scrollController.dispose();
    _qrSubscription?.cancel();
    _qrServer?.stop();
    super.dispose();
  }

  void _showSortOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Material(
        color: AppColors.secondary,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Sort Stocks By', style: GoogleFonts.inter(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              _buildSortOption('Date', 'Newest First'),
              _buildSortOption('High Stock', 'Highest Quantity First'),
              _buildSortOption('Low Stock', 'Lowest Quantity First'),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSortOption(String value, String subtitle) {
    return ListTile(
      onTap: () {
        setState(() {
          _sortOption = value;
        });
        Navigator.pop(context);
      },
      title: Text(value, style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, style: GoogleFonts.inter(color: Colors.white54)),
      trailing: _sortOption == value ? const Icon(Icons.check, color: Colors.greenAccent) : null,
    );
  }

  void _openRemoteScanner() async {
    // If currently running, stop the old one safely first
    if (_qrServer != null) {
      _qrSubscription?.cancel();
      _qrServer?.stop();
      _qrServer = null;
    }

    _qrServer = LocalQrScannerServer();
    final url = await _qrServer!.start();
    
    // ValueNotifier to update UI when a scan successfully hits our server
    final ValueNotifier<bool> successNotifier = ValueNotifier(false);

    if (!mounted) return;

    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.5),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Center(
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: 340,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.secondary,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white12),
                  boxShadow: const [
                    BoxShadow(color: Colors.black38, blurRadius: 30, spreadRadius: 5)
                  ],
                ),
                child: ValueListenableBuilder<bool>(
                  valueListenable: successNotifier,
                  builder: (context, isSuccess, child) {
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Mobile Scanner', style: GoogleFonts.inter(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                        const SizedBox(height: 24),
                        if (isSuccess) ...[
                          const Icon(Icons.check_circle_outline, color: Colors.greenAccent, size: 100),
                          const SizedBox(height: 16),
                          Text('Scan Successful!', style: GoogleFonts.inter(color: Colors.greenAccent, fontSize: 16, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 8),
                          Text('Safely closing connection...', style: GoogleFonts.inter(color: Colors.white54, fontSize: 13)),
                        ] else ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                            child: QrImageView(
                              data: url,
                              version: QrVersions.auto,
                              size: 180.0,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const SizedBox(
                                width: 16, height: 16, 
                                child: CircularProgressIndicator(color: Colors.purpleAccent, strokeWidth: 2)
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text('Waiting for connection...', style: GoogleFonts.inter(color: Colors.white70, fontSize: 13)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text('1. Connect phone to same WiFi\n2. Scan this QR to open camera\n3. Scan product barcode', 
                            style: GoogleFonts.inter(color: Colors.white54, fontSize: 12), 
                            textAlign: TextAlign.center
                          ),
                          const SizedBox(height: 12),
                          SelectableText(url, style: GoogleFonts.inter(color: Colors.greenAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                        ],
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.redAccent.withOpacity(0.15),
                              foregroundColor: Colors.redAccent,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(vertical: 16)
                            ),
                            onPressed: () {
                              Navigator.pop(dialogContext);
                              _qrSubscription?.cancel();
                              _qrServer?.stop();
                              _qrServer = null;
                            },
                            child: Text('Cancel & Close Port', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                          ),
                        )
                      ],
                    );
                  }
                )
              )
            )
          )
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: animation, 
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.95, end: 1.0).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)), 
            child: child
          )
        );
      },
    );

    _qrSubscription = _qrServer!.onCodeScanned.listen((scannedCode) async {
      if (!mounted) return;
      
      // Update UI to success!
      successNotifier.value = true;
      
      // Wait for success animation to play for the user
      await Future.delayed(const Duration(milliseconds: 1200));
      
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop(); // Close QR dialog safely
      
      // Safely close the port & listener on succeeding
      _qrSubscription?.cancel();
      _qrServer?.stop();
      _qrServer = null;
      
      final state = context.read<StocksBloc>().state;
      StockItem? matched;
      if (state is StocksLoaded) {
        final matches = state.stocks.where((s) => s.productKey == scannedCode);
        matched = matches.isNotEmpty ? matches.first : null;
      }
      // Fallback to backend lookup when not in memory
      if (matched == null) matched = await _lookupProductByKey(scannedCode);

      if (matched != null) {
        _openAddStockScreen(matched);
      } else {
        toastification.show(
          context: context,
          type: ToastificationType.error,
          style: ToastificationStyle.flatColored,
          title: Text('Product not found', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
          description: Text('Product $scannedCode not found!', style: GoogleFonts.inter()),
          alignment: Alignment.topCenter,
          autoCloseDuration: const Duration(seconds: 4),
        );
      }
    });
  }

  void _openCloudScanner() async {
    // Generate a simple session id
    final sessionId = DateTime.now().millisecondsSinceEpoch.toString();

    final workerUrl = Uri.parse('https://pos-backend.posai.workers.dev/scanner/$sessionId');
    // Show a QR dialog and live list of scanned items from the worker
    final scansNotifier = ValueNotifier<List<dynamic>>([]);
    final Set<String> seenScanIds = {};
    // Capture parent context and bloc so dialog (overlay) can access them
    final parentContext = context;
    final stocksBloc = context.read<StocksBloc>();
    Timer? pollTimer;

    Future<void> fetchScans() async {
      try {
        final uri = Uri.parse('https://pos-backend.posai.workers.dev/api/scanner/status/$sessionId');
        final resp = await HttpClient().getUrl(uri).then((r) => r.close());
        final body = await resp.transform(utf8.decoder).join();
        final data = jsonDecode(body);
        if (data != null && data['success'] == true && data['scans'] is List) {
          final List<dynamic> scans = List.from(data['scans']);
          // detect newly arrived scans
          for (final s in scans) {
            final id = s['id']?.toString();
            if (id != null && !seenScanIds.contains(id)) {
              // mark seen immediately to avoid races
              seenScanIds.add(id);
              // play a short system click sound to notify user
              try { SystemSound.play(SystemSoundType.click); } catch (_) {}

              // try to auto-open AddStock if product exists
              final scannedCode = s['code'];
              final state = parentContext.read<StocksBloc>().state;
              if (state is StocksLoaded) {
                final matches = state.stocks.where((st) => st.productKey == scannedCode);
                if (matches.isNotEmpty) {
                  final matched = matches.first;
                  // broadcast matched item so any open AddStockScreen can update selection
                  ScanBroadcast.add(matched);
                  // remove from KV then open, but keep scanner dialog open
                  try {
                    final uriDel = Uri.parse('https://pos-backend.posai.workers.dev/api/scanner/status/$sessionId/${s['id']}');
                    final req = await HttpClient().deleteUrl(uriDel);
                    await req.close();
                    if (ActiveScanner.pendingCount.value > 0) ActiveScanner.pendingCount.value = ActiveScanner.pendingCount.value - 1;
                  } catch (_) {}
                  // open add stock screen without closing scanner dialog
                  if (mounted) {
                    if (!_addStockOpen) _openAddStockScreen(matched);
                  }
                  return;
                } else {
                  // notify not found
                  toastification.show(
                    context: parentContext,
                    type: ToastificationType.error,
                    style: ToastificationStyle.flatColored,
                    title: Text('Product not found', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                    description: Text('Product $scannedCode not found', style: GoogleFonts.inter()),
                    alignment: Alignment.topCenter,
                    autoCloseDuration: const Duration(seconds: 4),
                  );
                }
              }
            }
          }

            scansNotifier.value = scans;
            ActiveScanner.pendingCount.value = scans.length;
        }
      } catch (_) {
        // ignore
      }
    }

    // Expose session globally so AddStock or other screens can fetch
      ActiveScanner.setSession(sessionId);

    // Start periodic polling
    await fetchScans();
    pollTimer = Timer.periodic(const Duration(seconds: 1), (_) => fetchScans());

    if (!mounted) return;

    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.5),
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
                  Text('Scan with Phone', style: GoogleFonts.inter(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Container(
                        width: 200,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                        child: QrImageView(data: workerUrl.toString(), version: QrVersions.auto, size: 180),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Scans received', style: GoogleFonts.inter(color: Colors.white70)),
                            const SizedBox(height: 8),
                            SizedBox(
                              height: 120,
                              child: ValueListenableBuilder<List<dynamic>>(
                                valueListenable: scansNotifier,
                                builder: (context, scans, _) {
                                  if (scans.isEmpty) {
                                    // simple shimmer placeholder
                                    return Center(
                                      child: SizedBox(
                                        width: 160,
                                        height: 20,
                                        child: _ShimmerBox(),
                                      ),
                                    );
                                  }
                                  // show latest scan indicator
                                  final latest = scans.first;
                                  return Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('New scan received', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w700)),
                                      const SizedBox(height: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                                        decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(8)),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(child: Text(latest['code'] ?? '', style: GoogleFonts.inter(color: Colors.white))),
                                            TextButton(
                                              onPressed: () async {
                                                // pop one item and try to open
                                                try {
                                                  final uri = Uri.parse('https://pos-backend.posai.workers.dev/api/scanner/pop/$sessionId');
                                                  final resp = await HttpClient().getUrl(uri).then((r) => r.close());
                                                  final body = await resp.transform(utf8.decoder).join();
                                                  final data = jsonDecode(body);
                                                  if (data != null && data['success'] == true && data['item'] != null) {
                                                    final scan = data['item'];
                                                    final code = scan['code'];
                                                    final state = stocksBloc.state;
                                                    StockItem? matched;
                                                    if (state is StocksLoaded) {
                                                      final matches = state.stocks.where((s) => s.productKey == code);
                                                      matched = matches.isNotEmpty ? matches.first : null;
                                                    }
                                                    // Fallback to backend lookup when not in memory
                                                    if (matched == null) matched = await _lookupProductByKey(code);
                                                    if (matched != null) {
                                                      ScanBroadcast.add(matched);
                                                      if (!_addStockOpen) _openAddStockScreen(matched);
                                                      if (ActiveScanner.pendingCount.value > 0) ActiveScanner.pendingCount.value = ActiveScanner.pendingCount.value - 1;
                                                    } else {
                                                      toastification.show(
                                                        context: parentContext,
                                                        type: ToastificationType.error,
                                                        style: ToastificationStyle.flatColored,
                                                        title: Text('Product not found', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                                                        description: Text('Product $code not found', style: GoogleFonts.inter()),
                                                        alignment: Alignment.topCenter,
                                                        autoCloseDuration: const Duration(seconds: 4),
                                                      );
                                                    }
                                                  } else {
                                                    toastification.show(
                                                      context: parentContext,
                                                      type: ToastificationType.info,
                                                      style: ToastificationStyle.flatColored,
                                                      title: Text('No scans', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                                                      description: Text('No scans available', style: GoogleFonts.inter()),
                                                      alignment: Alignment.topCenter,
                                                      autoCloseDuration: const Duration(seconds: 3),
                                                    );
                                                  }
                                                } catch (e) {
                                                  toastification.show(
                                                    context: parentContext,
                                                    type: ToastificationType.error,
                                                    style: ToastificationStyle.flatColored,
                                                    title: Text('Error', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                                                    description: Text('Error: $e', style: GoogleFonts.inter()),
                                                    alignment: Alignment.topCenter,
                                                    autoCloseDuration: const Duration(seconds: 4),
                                                  );
                                                }
                                              },
                                              child: Text('Fetch', style: GoogleFonts.inter()),
                                            )
                                          ],
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ),
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
                            if (await canLaunchUrl(workerUrl)) await launchUrl(workerUrl, mode: LaunchMode.externalApplication);
                          },
                          child: Text('Open on Phone', style: GoogleFonts.inter()),
                        ),
                      ),
                      const SizedBox(width: 12),
                          SizedBox(
                            width: 92,
                            child: OutlinedButton(
                              onPressed: () {
                                Navigator.pop(dialogContext);
                                pollTimer?.cancel();
                                // keep session active until TTL; do not clear here
                              },
                              child: Text('Close', style: GoogleFonts.inter(color: Colors.white)),
                            ),
                          ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      }
    );
  }

  void _openAddStockScreen(StockItem stock) async {
    final bloc = context.read<StocksBloc>();
    _addStockOpen = true;
    await showGeneralDialog(
      context: context,
      barrierDismissible: false,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        return AddStockScreen(
          stockItem: stock,
          bloc: bloc,
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
          child: child,
        );
      },
    );
    _addStockOpen = false;
  }

  Widget _buildSearchBar() {
    return BlocBuilder<StocksBloc, StocksState>(
      builder: (context, state) {
        List<StockItem> availableStocks = [];
        if (state is StocksLoaded) availableStocks = state.stocks;

        return RawAutocomplete<StockItem>(
          textEditingController: _searchController,
          focusNode: _searchFocusNode,
          optionsBuilder: (TextEditingValue textEditingValue) {
             if (textEditingValue.text.isEmpty) {
               return const Iterable<StockItem>.empty();
             }
             return availableStocks.where((StockItem option) {
               return option.name.toLowerCase().contains(textEditingValue.text.toLowerCase());
             });
          },
          onSelected: (StockItem selection) {
             _searchController.text = selection.name;
             _fetchStocks(query: selection.name);
          },
          fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
            return TextField(
              controller: controller,
              focusNode: focusNode,
              style: GoogleFonts.inter(color: Colors.white),
              onSubmitted: (value) => _fetchStocks(query: value),
              onChanged: (value) => _fetchStocks(query: value),
              decoration: InputDecoration(
                hintText: 'Search stock by name...',
                hintStyle: GoogleFonts.inter(color: Colors.white54),
                prefixIcon: const Icon(Icons.search, color: Colors.white54),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.1),
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
                      final StockItem option = options.elementAt(index);
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

  Widget _buildActionButtons(bool isMobile) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: isMobile ? MainAxisAlignment.end : MainAxisAlignment.start,
      children: [
        // Glassmorphism Scan Button
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: InkWell(
              onTap: () {
                _openCloudScanner();
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: EdgeInsets.all(isMobile ? 12 : 16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                ),
                child: Icon(Icons.qr_code_scanner, color: Colors.white, size: isMobile ? 20 : 24),
              ),
            ),
          ),
        ),
        if (!isMobile) const SizedBox(width: 12),
        // Pending scans indicator (outside dialog shimmer)
        if (!isMobile)
          Flexible(
            child: ValueListenableBuilder<int>(
              valueListenable: ActiveScanner.pendingCount,
              builder: (context, count, _) {
                if (count <= 0) return const SizedBox.shrink();
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(width: 8),
                    SizedBox(width: 80, child: _ShimmerBox()),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text('$count pending', style: GoogleFonts.inter(color: Colors.white70), overflow: TextOverflow.ellipsis),
                    ),
                  ],
                );
              },
            ),
          ),
        
        const SizedBox(width: 8),

        // Filter/Sort Button
        Flexible(
          child: ElevatedButton.icon(
            onPressed: _showSortOptions,
            icon: Icon(Icons.sort, color: Colors.black, size: isMobile ? 16 : 18),
            label: Text(isMobile ? 'Sort' : 'Sort: $_sortOption', 
                style: GoogleFonts.inter(
                    fontSize: isMobile ? 13 : 14,
                    fontWeight: FontWeight.w600, 
                    color: Colors.black), 
                overflow: TextOverflow.ellipsis),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 12 : 20, 
                  vertical: isMobile ? 8 : 16),
              minimumSize: isMobile ? Size.zero : const Size(64, 48),
              tapTargetSize: isMobile ? MaterialTapTargetSize.shrinkWrap : MaterialTapTargetSize.padded,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(isMobile ? 8 : 12)),
              elevation: 0,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isMobile = constraints.maxWidth < 600;

        Widget headerContent = Padding(
          padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 16.0 : 24.0, 
              vertical: isMobile ? 12.0 : 16.0),
          child: isMobile 
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(child: _buildSearchBar()),
                      const SizedBox(width: 8),
                      _buildActionButtons(true),
                    ],
                  ),
                ],
              )
            : Row(
                children: [
                  Expanded(child: _buildSearchBar()),
                  const SizedBox(width: 16),
                  _buildActionButtons(false),
                ],
              ),
        );

        return CustomScrollView(
              controller: _scrollController,
              physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: headerContent,
            ),
            SliverFillRemaining(
              hasScrollBody: true,
              child: BlocBuilder<StocksBloc, StocksState>(
            builder: (context, state) {
              if (state is StocksLoading) {
                return GridView.builder(
                  padding: EdgeInsets.all(isMobile ? 12 : 24),
                  gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: isMobile ? double.infinity : 320,
                    childAspectRatio: isMobile ? 3.5 : 1.8,
                    crossAxisSpacing: isMobile ? 8 : 16,
                    mainAxisSpacing: isMobile ? 8 : 16,
                  ),
                  itemCount: 12,
                  itemBuilder: (context, index) {
                    return Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.02),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.05),
                            width: 1),
                      ),
                      padding: EdgeInsets.all(isMobile ? 12 : 16),
                      child: Row(
                        children: [
                          Container(
                            width: isMobile ? 48 : 64,
                            height: isMobile ? 48 : 64,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          SizedBox(width: isMobile ? 12 : 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  height: isMobile ? 14 : 16,
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.05),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Container(
                                  height: isMobile ? 10 : 12,
                                  width: 100,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.05),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              } else if (state is StocksError) {
                return Center(
                  child: Text('Error: ${state.message}',
                      style: GoogleFonts.inter(color: Colors.redAccent)),
                );
              } else if (state is StocksLoaded) {
                if (_isLoadingMore) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) setState(() { _isLoadingMore = false; });
                  });
                }
                final stocks = List<StockItem>.from(state.stocks);
                // update local total if available from bloc (handled in meta)
                // note: StocksBloc updates internal _total; we keep page tracking in this UI
                
                // Active Sort Logic
                if (_sortOption == 'High Stock') {
                  stocks.sort((a, b) => b.liveStockCount.compareTo(a.liveStockCount));
                } else if (_sortOption == 'Low Stock') {
                  stocks.sort((a, b) => a.liveStockCount.compareTo(b.liveStockCount));
                }

                if (stocks.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.inventory_2_outlined, size: 64, color: Colors.white24),
                        const SizedBox(height: 16),
                        Text('No stocks found', style: GoogleFonts.inter(color: Colors.white54, fontSize: 18)),
                      ],
                    ),
                  );
                }

                return Column(
                  children: [
                    Expanded(
                      child: GridView.builder(
                        padding: EdgeInsets.all(isMobile ? 12 : 24),
                        gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: isMobile ? double.infinity : 340,
                          childAspectRatio: isMobile ? 3.5 : 2.0,
                          crossAxisSpacing: isMobile ? 8 : 16,
                          mainAxisSpacing: isMobile ? 8 : 16,
                        ),
                        itemCount: stocks.length,
                        itemBuilder: (context, index) {
                          final stock = stocks[index];
                          return InkWell(
                            onTap: () => _openAddStockScreen(stock),
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.1),
                                    width: 1),
                              ),
                              padding: EdgeInsets.all(isMobile ? 12 : 16),
                              child: Row(
                                children: [
                                  // Product Image Thumbnail
                                  Container(
                                    width: isMobile ? 48 : 64,
                                    height: isMobile ? 48 : 64,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: stock.productUrl.isNotEmpty
                                        ? ClipRRect(
                                            borderRadius: BorderRadius.circular(8),
                                            child: CachedNetworkImage(
                                              imageUrl: stock.productUrl,
                                              fit: BoxFit.cover,
                                              placeholder: (c, u) => Container(color: Colors.white12),
                                              errorWidget: (c, u, e) => const Icon(Icons.image, size: 20, color: Colors.white24),
                                            ),
                                          )
                                        : Icon(Icons.image,
                                            size: isMobile ? 20 : 24,
                                            color: Colors.white24),
                                  ),
                                  SizedBox(width: isMobile ? 12 : 16),

                                  // Product Info
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(stock.name,
                                            style: GoogleFonts.inter(
                                                fontSize: isMobile ? 14 : 15,
                                                fontWeight: FontWeight.w700,
                                                color: Colors.white),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis),
                                        const SizedBox(height: 4),
                                        Text(stock.productKey,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: GoogleFonts.inter(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w500,
                                                color: Colors.white54)),
                                        const SizedBox(height: 6),
                                        Text(
                                            'LKR ${stock.sellingValue.toStringAsFixed(2)}',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: GoogleFonts.inter(
                                                fontSize: isMobile ? 12 : 13,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.white70)),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),

                                  // Live Stock Display
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                        horizontal: isMobile ? 10 : 16,
                                        vertical: isMobile ? 4 : 8),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(alpha: 0.3),
                                      borderRadius: BorderRadius.circular(12),
                                      border:
                                          Border.all(color: Colors.white24, width: 2),
                                    ),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text('LIVE',
                                            style: GoogleFonts.inter(
                                                fontSize: isMobile ? 8 : 10,
                                                fontWeight: FontWeight.w800,
                                                letterSpacing: 1.5,
                                                color: Colors.greenAccent)),
                                        const SizedBox(height: 4),
                                        Text('${stock.liveStockCount}',
                                            style: GoogleFonts.inter(
                                                fontSize: isMobile ? 20 : 24,
                                                fontWeight: FontWeight.w900,
                                                color: Colors.white)),
                                      ],
                                    ),
                                  )
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    if (stocks.length < (state.total ?? 0))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16.0),
                        child: _isLoadingMore
                            ? SizedBox(height: 48, child: Center(child: CircularProgressIndicator()))
                            : ElevatedButton(
                                onPressed: () {
                                  _fetchStocks(loadMore: true);
                                },
                                child: const Text('Load more'),
                              ),
                      )
                  ],
                );
              }
              return const SizedBox();
            },
          ),
        ),
      ],
    );
      },
    );
  }
}

class _ShimmerBox extends StatefulWidget {
  const _ShimmerBox({Key? key}) : super(key: key);
  @override
  State<_ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<_ShimmerBox> with SingleTickerProviderStateMixin {
  late final AnimationController _ctl = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();
  @override
  void dispose() { _ctl.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctl,
      builder: (context, child) {
        return ShaderMask(
          shaderCallback: (bounds) {
            return LinearGradient(
              colors: [Colors.white.withOpacity(0.1), Colors.white.withOpacity(0.25), Colors.white.withOpacity(0.1)],
              stops: [0.0, 0.5, 1.0],
              begin: Alignment(-1.0 + _ctl.value * 2, 0),
              end: Alignment(1.0 + _ctl.value * 2, 0),
            ).createShader(bounds);
          },
          child: Container(decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(6))),
          blendMode: BlendMode.srcATop,
        );
      },
    );
  }
}
