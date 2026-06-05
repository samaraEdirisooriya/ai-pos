import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:responsive_builder/responsive_builder.dart';

import '../theme/app_colors.dart';

class SplashScreen extends StatefulWidget {
  final VoidCallback onComplete;

  const SplashScreen({super.key, required this.onComplete});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
  with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  late AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();

    // Fade animation for entrance
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(parent: _fadeController, curve: Curves.easeIn);

    // Shimmer controller (repeating)
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();

    _fadeController.forward();

    // Complete splash after fixed duration
    Future.delayed(const Duration(milliseconds: 2400), () {
      if (mounted) widget.onComplete();
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveBuilder(
      builder: (context, sizingInformation) {
        final isMobile = sizingInformation.isMobile;
        final isTablet = sizingInformation.isTablet;
        final screenWidth = sizingInformation.screenSize.width;
        final screenHeight = sizingInformation.screenSize.height;

        final titleFontSize = isMobile
            ? screenWidth * 0.12
            : isTablet
                ? screenWidth * 0.08
                : screenWidth * 0.06;

        final taglineFontSize = isMobile
            ? screenWidth * 0.035
            : isTablet
                ? screenWidth * 0.025
                : screenWidth * 0.018;

        final verticalPadding = screenHeight * 0.06;

        return Scaffold(
          body: Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.primary,
                  AppColors.primary.withValues(alpha: 0.8),
                  Colors.deepPurple,
                ],
              ),
            ),
            child: Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.08, vertical: verticalPadding),
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Single-row title with shimmer
                      AnimatedBuilder(
                        animation: _shimmerController,
                        builder: (context, child) {
                          // animate gradient shift from -1 to 1
                          final shimmerPos = (_shimmerController.value * 2) - 1;
                          return ShaderMask(
                            shaderCallback: (bounds) {
                              return LinearGradient(
                                begin: Alignment(-1 - shimmerPos, 0),
                                end: Alignment(1 - shimmerPos, 0),
                                colors: [
                                  Colors.white.withOpacity(0.18),
                                  Colors.white,
                                  Colors.white.withOpacity(0.18),
                                ],
                                stops: const [0.25, 0.5, 0.75],
                              ).createShader(bounds);
                            },
                            blendMode: BlendMode.srcIn,
                            child: Text(
                              'LankaPOS AI',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(
                                fontSize: titleFontSize,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: 1.2,
                                shadows: [
                                  Shadow(
                                    color: Colors.black.withOpacity(0.25),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),

                      const SizedBox(height: 16),

                      // Optional small tagline (fades in)
                      FadeTransition(
                        opacity: _fadeAnimation,
                        child: Text(
                          'Modern POS & Business Management',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: taglineFontSize,
                            fontWeight: FontWeight.w400,
                            color: Colors.white.withOpacity(0.85),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
