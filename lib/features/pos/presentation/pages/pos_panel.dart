import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../bloc/pos_bloc.dart';
import '../widgets/pos_cart_section.dart';
import '../widgets/pos_products_grid.dart';

class PosPanel extends StatelessWidget {
  final ScrollController scrollController;
  final PanelController panelController;

  const PosPanel({super.key, required this.scrollController, required this.panelController});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => PosBloc(),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.bottomSheetBackground,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(AppConstants.borderRadiusLarge),
            topRight: Radius.circular(AppConstants.borderRadiusLarge),
          ),
        ),
        child: Column(
          children: [
            _buildHandle(context),
            const Divider(color: AppColors.glassWhite, height: 1),
            Expanded(
              child: SingleChildScrollView(
                controller: scrollController,
                child: Container(
                  height: (MediaQuery.of(context).size.height * 0.9 - 81).clamp(0.0, double.infinity), // Clamped: never negative
                  padding: const EdgeInsets.all(AppConstants.paddingLarge),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Products Area (2/3 width on desktop)
                      const Expanded(
                        flex: 2,
                        child: PosProductsGrid(),
                      ),
                      const SizedBox(width: AppConstants.paddingLarge),
                      // Cart Area (1/3 width on desktop)
                      Expanded(
                        flex: 1,
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            if (constraints.maxWidth < 300) {
                              // If too narrow, maybe hide or adjust, but responsive_builder in main handles it mostly.
                              return const PosCartSection();
                            }
                            return const PosCartSection();
                          }
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildHandle(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (panelController.isPanelClosed) {
          panelController.open();
        } else {
          panelController.close();
        }
      },
      child: Container(
        height: 80,
        width: double.infinity,
        decoration: const BoxDecoration(
          color: Colors.transparent,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 60,
              height: 6,
              decoration: BoxDecoration(
                color: AppColors.textSecondary.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 10),
            
          ],
        ),
      ),
    );
  }
}
