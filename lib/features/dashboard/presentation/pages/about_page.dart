import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:responsive_builder/responsive_builder.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_colors.dart';

class AboutPage extends StatefulWidget {
  const AboutPage({super.key});

  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> {
  late Future<Map<String, String>> platformLinks;

  @override
  void initState() {
    super.initState();
    platformLinks = _fetchPlatformLinks();
  }

  Future<Map<String, String>> _fetchPlatformLinks() async {
    // In real scenario, fetch from KV store via backend API
    // For now, return placeholder links
    return {
      'windows': 'https://example.com/download/windows',
      'android': 'https://play.google.com/store/apps/details?id=com.lankpos.ai',
      'ios': 'https://apps.apple.com/app/lankpos-ai',
      'web': 'https://app.lankpos.ai',
    };
  }

  Future<void> _launchURL(String url) async {
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveBuilder(
      builder: (context, sizingInformation) {
        final isMobile = sizingInformation.isMobile;
        
        return SingleChildScrollView(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.secondary,
                  AppColors.secondary.withAlpha(220),
                ],
              ),
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 16 : 32,
                vertical: isMobile ? 20 : 40,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // App Logo/Icon
                  Container(
                    width: isMobile ? 80 : 120,
                    height: isMobile ? 80 : 120,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AppColors.primary,
                          AppColors.primary.withAlpha(180),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withAlpha(100),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Icon(
                        Icons.shopping_cart,
                        size: isMobile ? 40 : 60,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // App Title
                  Text(
                    'LankaPOS AI',
                    style: GoogleFonts.inter(
                      fontSize: isMobile ? 28 : 40,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Version
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Version 1.0.0',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.white70,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Description
                  Container(
                    padding: EdgeInsets.all(isMobile ? 16 : 24),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.1),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      'A modern AI-powered Point of Sale and Business Management platform designed for retailers, supermarkets, restaurants and wholesale businesses.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: isMobile ? 13 : 15,
                        color: Colors.white.withValues(alpha: 0.87),
                        height: 1.6,
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),

                  // Platform Icons Section
                  Text(
                    'Download for All Platforms',
                    style: GoogleFonts.inter(
                      fontSize: isMobile ? 16 : 20,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Platform Icons Grid
                  FutureBuilder<Map<String, String>>(
                    future: platformLinks,
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                              AppColors.primary,
                            ),
                          ),
                        );
                      }

                      final links = snapshot.data!;
                      final platforms = [
                        {
                          'name': 'Windows',
                          'icon': Icons.desktop_mac,
                          'link': links['windows'],
                        },
                        {
                          'name': 'Android',
                          'icon': Icons.phone_android,
                          'link': links['android'],
                        },
                        {
                          'name': 'iOS',
                          'icon': Icons.phone_iphone,
                          'link': links['ios'],
                        },
                        {
                          'name': 'Web',
                          'icon': Icons.language,
                          'link': links['web'],
                        },
                      ];

                      return Wrap(
                        spacing: isMobile ? 12 : 20,
                        runSpacing: isMobile ? 12 : 20,
                        alignment: WrapAlignment.center,
                        children: platforms.map((platform) {
                          return _buildPlatformCard(
                            name: platform['name'] as String,
                            icon: platform['icon'] as IconData,
                            link: platform['link'] as String,
                            isMobile: isMobile,
                          );
                        }).toList(),
                      );
                    },
                  ),
                  const SizedBox(height: 48),

                  // Developer Info
                  Column(
                    children: [
                      Text(
                        'Developed by',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Colors.white54,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Maduvantha Edirisooriya',
                        style: GoogleFonts.inter(
                          fontSize: isMobile ? 14 : 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // Platforms Info
                  Container(
                    padding: EdgeInsets.all(isMobile ? 12 : 16),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Windows • Android • iOS • Web',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: Colors.white70,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),

                  // Copyright
                  Column(
                    children: [
                      Text(
                        '© 2026 LankaPOS AI',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Colors.white54,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'All Rights Reserved',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: Colors.white38,
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
    );
  }

  Widget _buildPlatformCard({
    required String name,
    required IconData icon,
    required String link,
    required bool isMobile,
  }) {
    return GestureDetector(
      onTap: () => _launchURL(link),
      child: Container(
        width: isMobile ? 85 : 120,
        padding: EdgeInsets.all(isMobile ? 12 : 16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.15),
            width: 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: isMobile ? 50 : 70,
              height: isMobile ? 50 : 70,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.primary,
                    AppColors.primary.withAlpha(180),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                size: isMobile ? 28 : 40,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              name,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: isMobile ? 11 : 13,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'View',
              style: GoogleFonts.inter(
                fontSize: 9,
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
