import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:responsive_builder/responsive_builder.dart';
import 'package:dio/dio.dart';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
// using external QR widget caused version mismatch on some environments
// we'll use an image QR generator endpoint instead of qr_flutter widget
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/services/dashboard_service.dart';
import '../../../ai_chat/presentation/pages/ai_chat_page.dart';
import '../../../pos/presentation/pages/pos_content.dart';
import '../../../pos/presentation/bloc/pos_bloc.dart';
import '../../../pos/presentation/pages/pos_panel.dart';

// Import Products feature
import '../../../products/data/datasources/product_remote_data_source.dart';
import '../../../products/data/repositories/product_repository_impl.dart';
import '../../../products/domain/usecases/add_product.dart';
import '../../../products/domain/usecases/get_products.dart';
import '../../../products/presentation/bloc/product_bloc.dart';
import '../../../products/presentation/pages/products_page.dart';

// Import Stocks feature
import '../../../stocks/presentation/bloc/stocks_bloc.dart';
import '../../../stocks/presentation/pages/stocks_page.dart';
// Suppliers feature
import '../../../suppliers/presentation/pages/suppliers_page.dart';
import '../../../clients/presentation/pages/clients_page.dart';
import '../../../clients/presentation/bloc/clients_bloc.dart';
import '../../../clients/presentation/bloc/clients_event.dart';
import '../../../clients/data/clients_api.dart';

/// Represents each module / navigation card
enum NavModule {
  posTerminal(Icons.point_of_sale, 'POS Terminal', '0', '', 'sales'),
  product(Icons.inventory_2, 'Products', '44', '', 'items'),
  stocks(Icons.store, 'Stocks', '40', '', 'units'),
  supplier(Icons.local_shipping, 'Supplier', '78', '', 'active'),
  user(Icons.person, 'Clients', '4', '', ''),
  ai(Icons.smart_toy, 'AI Assistant', '85', '', '%');

  final IconData icon;
  final String label;
  final String mainValue;
  final String subValue;
  final String unit;
  const NavModule(this.icon, this.label, this.mainValue, this.subValue, this.unit);
}

class MainLayoutPage extends StatefulWidget {
  const MainLayoutPage({super.key});

  @override
  State<MainLayoutPage> createState() => _MainLayoutPageState();
}

class _MainLayoutPageState extends State<MainLayoutPage>
    with SingleTickerProviderStateMixin {
  NavModule _selectedModule = NavModule.posTerminal;
  bool _mobileMenuOpen = false;

  // Bottom panel height states
  double? _panelCurrentHeight;
  bool _isFullScreen = false;

  // Dashboard data
  late DashboardService _dashboardService;
  int _productsCount = 0;
  int _stocksCount = 0;
  int _suppliersCount = 0;
  int _clientsCount = 0;
  int _salesCount = 0;
  double _totalRevenue = 0.0;
  double _totalProfit = 0.0;
  bool _loadingStats = true;

  @override
  void initState() {
    super.initState();
    _dashboardService = DashboardService(dio: Dio());
    _fetchDashboardStats();
  }

  Future<void> _fetchDashboardStats() async {
    try {
      final products = await _dashboardService.getProductsCount();
      final stocks = await _dashboardService.getStocksCount();
      final suppliers = await _dashboardService.getSuppliersCount();
      final clients = await _dashboardService.getClientsCount();
      final sales = await _dashboardService.getSalesCount();
      final revenue = await _dashboardService.getTotalRevenue();
      final profit = await _dashboardService.getTotalProfit();

      if (mounted) {
        setState(() {
          _productsCount = products;
          _stocksCount = stocks;
          _suppliersCount = suppliers;
          _clientsCount = clients;
          _salesCount = sales;
          _totalRevenue = revenue;
          _totalProfit = profit;
          _loadingStats = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loadingStats = false);
      }
    }
  }

  void _selectModule(NavModule module) {
    setState(() => _selectedModule = module);
  }

  void _toggleFullScreen() {
    setState(() {
      _isFullScreen = !_isFullScreen;
      _panelCurrentHeight = null; // will be recalculated in build
    });
  }

  void _resetPanel() {
    setState(() {
      _isFullScreen = false;
      _panelCurrentHeight = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxHeight < 10) return const SizedBox.shrink();
          return ResponsiveBuilder(
            builder: (context, sizingInformation) {
              bool isMobile =
                  sizingInformation.deviceScreenType == DeviceScreenType.mobile;
              final topNavH = isMobile ? 56.0 : 64.0;
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  // ── MAIN AREA (Content & Side Nav) ──
                  Positioned(
                    top: topNavH,
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Side Nav (hidden on mobile)
                        if (!isMobile)
                          SizedBox(
                            width: 60,
                            child: _buildSideNav(),
                          ),

                        // Content area
                        Expanded(
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final maxH = constraints.maxHeight;
                              // Use fixed minimum heights to prevent internal content scaling/errors
                              final minH = isMobile ? 180.0 : 320.0;
                              
                              // halfH logic: try to split, but never go below minH
                              final halfH = max(minH, maxH * 0.5);
                              
                              // target default: depends on screen state, but respects minH
                              final targetDefaultH = _isFullScreen ? max(maxH, minH) : halfH;
                              
                              // The panel height: uses manual drag height if set, otherwise defaults to full or half.
                              // It is NO LONGER clamped to maxH, allowing it to "overlap" when the screen is small.
                              final currentH = (_panelCurrentHeight ?? targetDefaultH).clamp(minH, double.infinity);

                              return Stack(
                                clipBehavior: Clip.none, // Essential to allow overlapping/sliding "behind" or above boundaries
                                children: [
                                  // ── FIXED DASHBOARD TOP (behind the panel) ──
                                  Positioned.fill(
                                    // Ensure bottom pinning doesn't exceed screen size to avoid layout errors
                                    bottom: currentH.clamp(0.0, max(0.0, maxH)),
                                    child: _buildDashboardTop(context, isMobile),
                                  ),

                                  // ── DRAGGABLE GRADIENT BOTTOM PANEL ──
                                  Positioned(
                                    left: 0,
                                    right: 0,
                                    bottom: 0,
                                    height: currentH,
                                    child: GestureDetector(
                                      onVerticalDragUpdate: (details) {
                                        setState(() {
                                          final newH = currentH - details.delta.dy;
                                          _panelCurrentHeight = newH.clamp(minH, double.infinity);
                                          _isFullScreen = _panelCurrentHeight! >= maxH - 20;
                                        });
                                      },
                                      onVerticalDragEnd: (details) {
                                        setState(() {
                                          final velocity = details.primaryVelocity ?? 0.0;
                                          final snapFullH = max(maxH, minH);
                                          if (velocity < -200 || currentH > halfH + 50) {
                                            _isFullScreen = true;
                                            _panelCurrentHeight = snapFullH;
                                          } else if (velocity > 200 || currentH < snapFullH - 50) {
                                            _isFullScreen = false;
                                            _panelCurrentHeight = halfH;
                                          } else {
                                            if ((currentH - halfH) > (snapFullH - currentH)) {
                                              _isFullScreen = true;
                                              _panelCurrentHeight = snapFullH;
                                            } else {
                                              _isFullScreen = false;
                                              _panelCurrentHeight = halfH;
                                            }
                                          }
                                        });
                                      },
                                      child: AnimatedContainer(
                                        duration: const Duration(milliseconds: 300),
                                        curve: Curves.easeOutCubic,
                                        decoration: const BoxDecoration(
                                          borderRadius: BorderRadius.only(
                                            topLeft: Radius.circular(24),
                                            topRight: Radius.circular(24),
                                          ),
                                          gradient: LinearGradient(
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                            colors: [
                                              AppColors.secondary,
                                              AppColors.secondaryMid,
                                              AppColors.secondaryEnd,
                                            ],
                                          ),
                                        ),
                                        child: Column(
                                          children: [
                                            _buildPanelHandle(),
                                            Expanded(
                                              child: _buildPanelContent(),
                                            ),
                                          ],
                                        ),
                                      ),
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
                  // ── TOP NAV (always visible & on top) ──
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    height: topNavH,
                    child: _buildTopNav(isMobile),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  // ─────────────────────────────────────────────
  // TOP NAV - RESPONSIVE
  // ─────────────────────────────────────────────
  Widget _buildTopNav(bool isMobile) {
    return Container(
      height: isMobile ? 56 : 64,
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 12 : AppConstants.paddingMedium,
        vertical: 0,
      ),
      color: AppColors.background,
      child: isMobile
          ? _buildMobileTopNav()
          : _buildDesktopTopNav(),
    );
  }

  Widget _buildMobileTopNav() {
    return Row(
      children: [
        // Hamburger menu
        IconButton(
          icon: const Icon(Icons.menu, color: AppColors.textPrimary, size: 24),
          onPressed: () {
            setState(() => _mobileMenuOpen = !_mobileMenuOpen);
          },
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
        ),
        const SizedBox(width: 8),
        // Logo
        const Icon(Icons.apps, color: AppColors.textPrimary, size: 20),
        const SizedBox(width: 8),
        // Title
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Lanka POS',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        // Profile dropdown (right side)
          PopupMenuButton<String>(
            icon: CircleAvatar(
              radius: 14,
              backgroundImage: CachedNetworkImageProvider('https://i.pravatar.cc/100?img=33'),
            ),
          itemBuilder: (context) => [
            PopupMenuItem<String>(
              value: 'profile',
              child: Row(
                children: [
                  const Icon(Icons.person, size: 18),
                  const SizedBox(width: 8),
                  Text('Admin User',
                      style: GoogleFonts.inter(fontSize: 12)),
                ],
              ),
            ),
            const PopupMenuDivider(),
            PopupMenuItem<String>(
              value: 'logout',
              child: Row(
                children: [
                  const Icon(Icons.logout, size: 18, color: AppColors.error),
                  const SizedBox(width: 8),
                  Text('Logout',
                      style: GoogleFonts.inter(
                          fontSize: 12, color: AppColors.error)),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDesktopTopNav() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // ── LARGE LOGO (LEFT) ──
        Row(
          children: [
            const Icon(Icons.apps, color: AppColors.textPrimary, size: 24),
            const SizedBox(width: 12),
            Text(
              'Lanka AI',
              style: GoogleFonts.inter(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
                letterSpacing: -0.5,
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12.0),
              child: Text('|',
                  style:
                      TextStyle(color: AppColors.textSecondary, fontSize: 24)),
            ),
            Text(
              'Super POS',
              style: GoogleFonts.inter(
                fontSize: 16,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),

        // ── PROFILE SECTION (RIGHT) ──
        Row(
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('Admin User',
                    style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary)),
                Text('Manager',
                    style: GoogleFonts.inter(
                        fontSize: 10, color: AppColors.textSecondary)),
              ],
            ),
            const SizedBox(width: 12),
            CircleAvatar(
              radius: 16,
              backgroundImage: CachedNetworkImageProvider('https://i.pravatar.cc/100?img=33'),
            ),
            const SizedBox(width: 12),
            IconButton(
              icon: const Icon(Icons.logout, color: AppColors.error, size: 20),
              onPressed: () {},
              tooltip: 'Logout',
            ),
          ],
        ),
      ],
    );
  }

  Future<String> _getOrCreateQrLink() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now().millisecondsSinceEpoch;
    final expiry = prefs.getInt('scanner_link_expiry') ?? 0;
    final existing = prefs.getString('scanner_link');

    if (existing != null && expiry > now) {
      return existing;
    }

    // Generate a new unique id using timestamp + random
    final id = '${DateTime.now().millisecondsSinceEpoch}${Random().nextInt(9999).toString().padLeft(4, '0')}';
    final link = 'https://pos-backend.posai.workers.dev/scanner/$id';
    final newExpiry = now + 3600 * 1000; // 1 hour in ms
    await prefs.setString('scanner_link', link);
    await prefs.setInt('scanner_link_expiry', newExpiry);
    return link;
  }

  void _showQrDialog(BuildContext context, String link) async {
    final prefs = await SharedPreferences.getInstance();
    final expiry = prefs.getInt('scanner_link_expiry') ?? 0;
    final expiresAt = DateTime.fromMillisecondsSinceEpoch(expiry);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.background,
        title: Row(
          children: [
            const Icon(Icons.qr_code, color: Colors.white),
            const SizedBox(width: 8),
            Text('Scanner Link', style: GoogleFonts.inter(color: Colors.white)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(8),
                 child: CachedNetworkImage(
                   imageUrl: 'https://api.qrserver.com/v1/create-qr-code/?size=180x180&data=${Uri.encodeComponent(link)}',
                   width: 180,
                   height: 180,
                   fit: BoxFit.contain,
                   placeholder: (c, u) => SizedBox(width: 180, height: 180, child: Center(child: CircularProgressIndicator())),
                   errorWidget: (c, u, e) => SizedBox(width: 180, height: 180, child: Center(child: Icon(Icons.broken_image, color: Colors.black45))),
                 ),
            ),
            const SizedBox(height: 12),
            SelectableText(link, style: GoogleFonts.inter(color: Colors.white70)),
            const SizedBox(height: 8),
            Text('Expires: ${expiresAt.toLocal()}', style: GoogleFonts.inter(fontSize: 12, color: Colors.white54)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: link));
              Navigator.of(ctx).pop();
            },
            child: Text('Copy', style: GoogleFonts.inter(color: AppColors.primary)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Close', style: GoogleFonts.inter(color: AppColors.textSecondary)),
          ),
        ],
      ),
    );
  }

  Widget _pillBtn(IconData icon, String text, bool isWhite) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      margin: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: isWhite ? Colors.white : Colors.transparent,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Icon(icon,
              size: 14,
              color: isWhite ? AppColors.primary : Colors.white),
          if (text.isNotEmpty) ...[
            const SizedBox(width: 5),
            Text(text,
                style: TextStyle(
                    color: isWhite ? AppColors.primary : Colors.white,
                    fontSize: 11,
                    fontWeight:
                        isWhite ? FontWeight.bold : FontWeight.normal)),
          ]
        ],
      ),
    );
  }

  Widget _pillDiv() =>
      Container(width: 1, height: 16, color: Colors.white24);

  // ─────────────────────────────────────────────
  // SIDE NAV
  // ─────────────────────────────────────────────
  Widget _buildSideNav() {
    return SingleChildScrollView(
      child: Container(
        width: 60,
        color: AppColors.background,
        child: Column(
          children: [
            const SizedBox(height: 16),
            // Back button
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.border),
              ),
              child: const Icon(Icons.arrow_back, size: 16, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),
            // Module nav items synced with cards
            ...NavModule.values.map((m) => _sideNavItem(m)),
      
          ],
        ),
      ),
    );
  }

  Widget _sideNavItem(NavModule module) {
    final isSelected = _selectedModule == module;
    return GestureDetector(
      onTap: () => _selectModule(module),
      child: Container(
        width: 36,
        height: 36,
        margin: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          shape: BoxShape.circle,
        ),
        child: Icon(module.icon,
            size: 18,
            color: isSelected ? Colors.white : AppColors.textSecondary),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // FIXED DASHBOARD TOP (always visible)
  // ─────────────────────────────────────────────
  Widget _buildDashboardTop(BuildContext context, bool isMobile) {
    return Container(
      color: AppColors.background,
      padding: EdgeInsets.only(
        left: isMobile ? 12 : 24,
        right: isMobile ? 12 : 24,
        top: isMobile ? 12 : 16,
        bottom: 8,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Breadcrumb
            Text('Activities',
                style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 4),

            // Title
            Text(
              isMobile ? 'POS AI' : 'LANKA POS AI',
              style: GoogleFonts.inter(
                fontSize: isMobile ? 32 : 48,
                fontWeight: FontWeight.w900,
                color: AppColors.textPrimary,
                letterSpacing: -1.5,
                height: 1.1,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'The next-generation smart storefront framework. Fast, fluid, and completely intuitive.',
              style: GoogleFonts.inter(
                fontSize: isMobile ? 12 : 15,
                fontWeight: FontWeight.w400,
                color: AppColors.textSecondary,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 16),

            // Tabs row - responsive
            if (!isMobile)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _tabLabel(context, 'Dashboard', true),
                    const SizedBox(width: 28),
                    _tabLabel(context, 'About', false),
                  ],
                ),
              ),
            const Divider(color: AppColors.border, height: 24),

            // ── 6 SELECTABLE NAV CARDS ──
            SizedBox(
              height: isMobile ? 200 : 300,
              child: GridView.builder(
                padding: EdgeInsets.zero,
                gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: isMobile ? 160 : 280, // Added responsive max width
                  childAspectRatio: isMobile ? 1.8 : 2.2, // Adjusted for POS card with 2 rows
                  crossAxisSpacing: isMobile ? 8 : 12,
                  mainAxisSpacing: isMobile ? 8 : 12,
                ),
                itemCount: NavModule.values.length,
                itemBuilder: (context, index) {
                  final m = NavModule.values[index];
                  final isSelected = _selectedModule == m;
                  final displayValue = _getDisplayValue(m);
                  
                  return GestureDetector(
                    onTap: () => _selectModule(m),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOut,
                      padding: EdgeInsets.symmetric(
                        horizontal: isMobile ? 12 : 20,
                        vertical: isMobile ? 10 : 14,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.surface,
                        borderRadius: BorderRadius.circular(24),
                        border: isSelected
                            ? null
                            : Border.all(
                                color: AppColors.border.withValues(alpha: 0.3)),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                    color: AppColors.primary
                                        .withValues(alpha: 0.15),
                                    blurRadius: 16,
                                    offset: const Offset(0, 4))
                              ]
                            : [],
                      ),
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(m.icon,
                                    size: isMobile ? 14 : 16,
                                    color: isSelected
                                        ? Colors.white70
                                        : AppColors.textSecondary),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(m.label,
                                      style: GoogleFonts.inter(
                                          fontSize: isMobile ? 9 : 11,
                                          color: isSelected
                                              ? Colors.white70
                                              : AppColors.textSecondary),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis),
                                ),
                              ],
                            ),
                            // For POS Terminal, show stacked layout with sales count and total
                            if (m == NavModule.posTerminal)
                              SizedBox(
                                height: isMobile ? 70 : 75,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    // Sales count row
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.baseline,
                                      textBaseline: TextBaseline.alphabetic,
                                      children: [
                                        Flexible(
                                          child: Text(displayValue,
                                              style: GoogleFonts.inter(
                                                  fontSize: isMobile ? 16 : 24,
                                                  fontWeight: FontWeight.w600,
                                                  color: isSelected
                                                      ? Colors.white
                                                      : AppColors.textPrimary),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis),
                                        ),
                                        const SizedBox(width: 4),
                                        Text('sales',
                                            style: GoogleFonts.inter(
                                                fontSize: isMobile ? 8 : 10,
                                                color: isSelected
                                                    ? Colors.white54
                                                    : AppColors.textSecondary),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    // Revenue row
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.baseline,
                                      textBaseline: TextBaseline.alphabetic,
                                      children: [
                                        Flexible(
                                          child: Text(_formatLargeNumber(_totalRevenue),
                                              style: GoogleFonts.inter(
                                                  fontSize: isMobile ? 14 : 20,
                                                  fontWeight: FontWeight.w500,
                                                  color: isSelected
                                                      ? Colors.white
                                                      : AppColors.textPrimary),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(_getPosUnit(),
                                            style: GoogleFonts.inter(
                                                fontSize: isMobile ? 8 : 10,
                                                fontWeight: FontWeight.w500,
                                                color: isSelected
                                                    ? Colors.white54
                                                    : AppColors.textSecondary),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis),
                                      ],
                                    ),
                                  ],
                                ),
                              )
                            else
                              // Standard layout for other cards
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Flexible(
                                    child: Text(displayValue,
                                        style: GoogleFonts.inter(
                                            fontSize: isMobile ? 18 : 28,
                                            fontWeight: FontWeight.w400,
                                            color: isSelected
                                                ? Colors.white
                                                : AppColors.textPrimary),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis),
                                  ),
                                  if (m.subValue.isNotEmpty)
                                    Flexible(
                                      child: Text(m.subValue,
                                          style: GoogleFonts.inter(
                                              fontSize: isMobile ? 12 : 20,
                                              fontWeight: FontWeight.w400,
                                              color: isSelected
                                                  ? Colors.white54
                                                  : AppColors.textSecondary),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis),
                                    ),
                                  const SizedBox(width: 2),
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 2.0),
                                    child: Text(m.unit,
                                        style: GoogleFonts.inter(
                                            fontSize: isMobile ? 8 : 12,
                                            color: isSelected
                                                ? Colors.white54
                                                : AppColors.textSecondary),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tabLabel(BuildContext context, String title, bool active) {
    return Column(
      children: [
        Text(title,
            style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                color: active
                    ? AppColors.textPrimary
                    : AppColors.textSecondary)),
        const SizedBox(height: 6),
        Container(
          height: 2,
          width: active ? 36 : 0,
          color: active ? AppColors.primary : Colors.transparent,
        ),
      ],
    );
  }

  Widget _infoCol(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: GoogleFonts.inter(
                fontSize: 10, color: AppColors.textMuted)),
        Text(value,
            style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary)),
      ],
    );
  }

  // ─────────────────────────────────────────────
  // BOTTOM PANEL – HANDLE
  // ─────────────────────────────────────────────
  Widget _buildPanelHandle() {
    return ResponsiveBuilder(
      builder: (context, sizingInformation) {
        bool isMobile =
            sizingInformation.deviceScreenType == DeviceScreenType.mobile;

        return Container(
          height: isMobile ? 48 : 60,
          alignment: Alignment.center,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned(
                left: 0,
                right: 80,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    const SizedBox(width: 24),
                    Icon(_selectedModule.icon,
                        color: const Color.fromARGB(192, 255, 255, 255), size: isMobile ? 18 : 20),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        _selectedModule.label,
                        style: GoogleFonts.inter(
                            fontSize: isMobile ? 14 : 18,
                            fontWeight: FontWeight.w600,
                            color: const Color.fromARGB(157, 255, 255, 255)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                top: 8,
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white38,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              if (!isMobile)
                Positioned(
                  right: 24,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(
                            _isFullScreen
                                ? Icons.fullscreen_exit
                                : Icons.fullscreen,
                            color: Colors.white70),
                        onPressed: _toggleFullScreen,
                        tooltip: _isFullScreen
                            ? 'Exit full screen'
                            : 'Full screen',
                      ),
                      IconButton(
                        icon: const Icon(Icons.minimize,
                            color: Colors.white70),
                        onPressed: _resetPanel,
                        tooltip: 'Reset to half screen',
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  // ─────────────────────────────────────────────
  // BOTTOM PANEL – INNER CONTENT (changes per module)
  // ─────────────────────────────────────────────
  Widget _buildPanelContent() {
    return ResponsiveBuilder(
      builder: (context, sizingInformation) {
        bool isMobile =
            sizingInformation.deviceScreenType == DeviceScreenType.mobile;

        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: Container(
            key: ValueKey(_selectedModule),
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 12 : 24,
              vertical: 8,
            ),
            child: _contentForModule(_selectedModule),
          ),
        );
      },
    );
  }

  Widget _contentForModule(NavModule module) {
    switch (module) {
      case NavModule.posTerminal:
        return const PosContent();
      case NavModule.ai:
        return const AiChatPage();
      case NavModule.product:
        return BlocProvider(
          create: (_) => ProductBloc(
            getProducts: GetProducts(ProductRepositoryImpl(
              remoteDataSource: ProductRemoteDataSourceImpl(dio: Dio()),
            )),
            addProduct: AddProduct(ProductRepositoryImpl(
              remoteDataSource: ProductRemoteDataSourceImpl(dio: Dio()),
            )),
          ),
          child: const ProductsPage(),
        );
      case NavModule.stocks:
        return BlocProvider(
          create: (_) => StocksBloc(dio: Dio()),
          child: const StocksPage(),
        );
      case NavModule.supplier:
        return const SuppliersPage();
      case NavModule.user:
        return BlocProvider(
          create: (_) => ClientsBloc(api: ClientsApi())..add(const FetchClients()),
          child: const ClientsPage(),
        );
    }
  }

  Widget _placeholderContent(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: GoogleFonts.inter(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: Colors.white)),
        const SizedBox(height: 8),
        Text(subtitle,
            style: GoogleFonts.inter(
                fontSize: 14, color: Colors.white70)),
        const SizedBox(height: 24),
        Flexible(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20),
            ),
            child: SingleChildScrollView(
              child: Center(
                child: Text('$title module content',
                    style: GoogleFonts.inter(
                        fontSize: 16, color: Colors.white38)),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // Helper method to get display value for each card based on real data
  String _getDisplayValue(NavModule module) {
    if (_loadingStats) return '...';
    
    switch (module) {
      case NavModule.posTerminal:
        return _salesCount.toString(); // Show sales count on POS card
      case NavModule.product:
        return _productsCount.toString();
      case NavModule.stocks:
        return _stocksCount.toString();
      case NavModule.supplier:
        return _suppliersCount.toString();
      case NavModule.user:
        return _clientsCount.toString();
      case NavModule.ai:
        return '85'; // AI assistant statistic
    }
  }

  // Helper method to get profit percentage
  String _getPosUnit() {
    if (_loadingStats) return '';
    if (_totalRevenue == 0) return '0%';
    final profitPercent = ((_totalProfit / _totalRevenue) * 100).toStringAsFixed(0);
    return '$profitPercent%';
  }

  // Format large numbers with K, M, B suffixes
  String _formatLargeNumber(double value) {
    if (value >= 1000000000) {
      return '${(value / 1000000000).toStringAsFixed(1)}B';
    } else if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M';
    } else if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}K';
    } else {
      return value.toStringAsFixed(0);
    }
  }
}
