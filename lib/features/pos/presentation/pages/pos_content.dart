import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:responsive_builder/responsive_builder.dart';
import '../bloc/pos_bloc.dart';
import '../widgets/pos_cart_section.dart';
import '../widgets/pos_products_grid.dart';

/// Standalone POS content designed to live inside the gradient bottom panel.
class PosContent extends StatelessWidget {
  const PosContent({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => PosBloc(),
      child: ResponsiveBuilder(
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
      ),
    );
  }

  // Desktop Layout: Side by side
  Widget _buildDesktopPOS(BuildContext context) {
    return Column(
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
          Text('POS',
              style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white)),
          const SizedBox(height: 8),
          TabBar(
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white54,
            tabs: [
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.inventory_2, size: 18),
                    const SizedBox(width: 6),
                    Text('Products',
                        style: GoogleFonts.inter(fontSize: 12)),
                  ],
                ),
              ),
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.shopping_cart, size: 18),
                    const SizedBox(width: 6),
                    Text('Cart',
                        style: GoogleFonts.inter(fontSize: 12)),
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
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  padding: const EdgeInsets.all(12),
                  child: const PosProductsGrid(),
                ),
                // Cart Tab
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
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
