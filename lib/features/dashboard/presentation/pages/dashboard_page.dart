import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(left: 16.0, right: 32.0, top: 16.0, bottom: 32.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Breadcrumb & Title
            Text(
              'Activities',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Dashboard Overview',
              style: Theme.of(context).textTheme.displayMedium,
            ),
            const SizedBox(height: 24),
            
            // Tabs and Info Right
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  children: [
                    _buildTab(context, 'Terminal', false),
                    const SizedBox(width: 32),
                    _buildTab(context, 'Related', false),
                    const SizedBox(width: 32),
                    _buildTab(context, 'Sales Insights', true),
                  ],
                ),
                Row(
                  children: [
                    _buildInfoColumn('Priority', 'High'),
                    const SizedBox(width: 32),
                    _buildInfoColumn('Due', '24.02.2026 - 12 pm'),
                    const SizedBox(width: 32),
                    _buildInfoColumn('Status', 'Open'),
                    const SizedBox(width: 32),
                    Row(
                      children: [
                        const CircleAvatar(
                          radius: 12,
                          backgroundImage: NetworkImage('https://i.pravatar.cc/100?img=11'),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Owner', style: Theme.of(context).textTheme.bodySmall),
                            Text('Samar Smith', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textPrimary)),
                          ],
                        )
                      ],
                    )
                  ],
                )
              ],
            ),
            const Divider(color: AppColors.border, height: 2),
            const SizedBox(height: 24),
            
            // 6 Cards Grid as requested by user
            GridView.count(
              crossAxisCount: MediaQuery.of(context).size.width > 1200 ? 4 : (MediaQuery.of(context).size.width > 800 ? 2 : 1),
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 2.5,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildStatCard('Total Sales today', '37', '/63', '%'),
                _buildStatCard('Average checkout speed', '44', '', 'sec'),
                _buildStatCard('Transactions per hour', '40', '', 'switches'),
                _buildStatCard('Average queue time', '78', '', 'ms'),
                // Adding 2 more to make 6 cards as requested
                _buildStatCard('Active Terminals', '4', '/5', 'online'),
                _buildStatCard('Daily Target', '85', '', '%'),
              ],
            ),
            const SizedBox(height: 24),
            
            // Bottom Section Layout (Left lists, Right gradient panel)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left Column
                Expanded(
                  flex: 1,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // People Card
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Row(
                          children: [
                            const CircleAvatar(radius: 16, backgroundImage: NetworkImage('https://i.pravatar.cc/100?img=5')),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Halle Griffiths', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                                  Text('Sales rep', style: Theme.of(context).textTheme.bodySmall),
                                ],
                              ),
                            ),
                            const Icon(Icons.play_arrow, size: 16),
                            const SizedBox(width: 12),
                            const CircleAvatar(radius: 16, backgroundImage: NetworkImage('https://i.pravatar.cc/100?img=12')),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Josiah Love', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                                  Text('Customer', style: Theme.of(context).textTheme.bodySmall),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // List Card
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceLight,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Categories (3)', style: Theme.of(context).textTheme.titleMedium),
                                Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.filter_alt_outlined, size: 16),
                                )
                              ],
                            ),
                            const SizedBox(height: 16),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _buildChip('Electronics (3)'),
                                _buildChip('Accessories (1)'),
                                _buildChip('Audio (1)'),
                              ],
                            ),
                            const SizedBox(height: 24),
                            Text('Brands (2)', style: Theme.of(context).textTheme.titleMedium),
                            const SizedBox(height: 16),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _buildChip('Apple (1)'),
                                _buildChip('Samsung (1)'),
                              ],
                            ),
                            const SizedBox(height: 24),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Action Items (2)', style: Theme.of(context).textTheme.titleMedium),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                _buildChip('Restock inventory (1)'),
                                const SizedBox(width: 8),
                                _buildChip('...'),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                _buildChip('Generate report (1)'),
                                const SizedBox(width: 8),
                                _buildChip('...'),
                              ],
                            ),
                          ],
                        ),
                      )
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                
                // Right Gradient Panel
                Expanded(
                  flex: 2,
                  child: Container(
                    height: 500, // Fixed height to match layout roughly
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [AppColors.secondary, AppColors.secondaryEnd],
                      ),
                    ),
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.search, color: Colors.white70),
                            const SizedBox(width: 12),
                            Text('Search in Transcript', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white70)),
                          ],
                        ),
                        const SizedBox(height: 32),
                        Row(
                          children: [
                            Text('Customer sentiment', style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.white)),
                            const SizedBox(width: 8),
                            const Icon(Icons.info_outline, color: Colors.white70, size: 16),
                            const SizedBox(width: 32),
                            _buildLegendItem(Icons.circle, 'Positive', Colors.white),
                            const SizedBox(width: 16),
                            _buildLegendItem(Icons.diamond_outlined, 'Neutral', Colors.white70),
                            const SizedBox(width: 16),
                            _buildLegendItem(Icons.circle, 'Negative', Colors.white54),
                          ],
                        ),
                        const SizedBox(height: 24),
                        // Mock wave form
                        Container(
                          height: 40,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Stack(
                            children: [
                              Positioned(
                                left: 60,
                                top: 0,
                                bottom: 0,
                                child: Container(width: 2, color: Colors.white),
                              ),
                              Positioned(
                                left: 55,
                                top: -10,
                                child: const Icon(Icons.arrow_drop_down, color: Colors.white),
                              )
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),
                        Text('Description', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white)),
                        const SizedBox(height: 16),
                        _buildTranscriptRow('Halle Griffiths', 'Hello this is Lydia from Northwind. How are you?', '00:00:24', 'https://i.pravatar.cc/100?img=5'),
                        const SizedBox(height: 16),
                        _buildTranscriptRow('Halle Griffiths', 'Good, how are you?', '00:00:36', 'https://i.pravatar.cc/100?img=12'),
                      ],
                    ),
                  ),
                )
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildTab(BuildContext context, String title, bool isActive) {
    return Column(
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: isActive ? AppColors.textPrimary : AppColors.textSecondary,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 2,
          width: isActive ? 40 : 0,
          color: isActive ? AppColors.primary : Colors.transparent,
        )
      ],
    );
  }

  Widget _buildInfoColumn(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 10)),
        Text(value, style: const TextStyle(color: AppColors.textPrimary, fontSize: 12, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildStatCard(String title, String mainValue, String subValue, String unit) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                mainValue,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 32,
                  fontWeight: FontWeight.w400, // Lighter weight for big numbers
                ),
              ),
              if (subValue.isNotEmpty)
                Text(
                  subValue,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 24,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              const SizedBox(width: 4),
              Padding(
                padding: const EdgeInsets.only(bottom: 6.0),
                child: Text(
                  unit,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
      ),
      child: Text(
        label,
        style: const TextStyle(color: AppColors.textPrimary, fontSize: 12),
      ),
    );
  }

  Widget _buildLegendItem(IconData icon, String label, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 12),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(color: color, fontSize: 12)),
      ],
    );
  }

  Widget _buildTranscriptRow(String name, String text, String time, String imgUrl) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(radius: 16, backgroundImage: NetworkImage(imgUrl)),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
              Text(time, style: const TextStyle(color: Colors.white54, fontSize: 10)),
            ],
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 14)),
          ),
          const Icon(Icons.more_horiz, color: Colors.white54),
        ],
      ),
    );
  }
}
