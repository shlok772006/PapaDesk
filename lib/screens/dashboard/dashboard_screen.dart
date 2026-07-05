import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../providers/dashboard_providers.dart';
import 'search_screen.dart';
import 'reports_screen.dart';

import '../settings/settings_screen.dart';
import '../../providers/role_provider.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(dashboardStatsProvider);
    final currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
    final isAdmin = ref.watch(isAdminProvider).value ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'PapaDesk Dashboard',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.bar_chart, size: 28),
            tooltip: 'Business Reports',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const ReportsScreen(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings, size: 28),
            tooltip: 'Settings',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const SettingsScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: statsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
        data: (stats) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (isAdmin) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  border: Border.all(color: Colors.orange[200]!),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.orange[800], size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Admin Mode (Read-Only)',
                        style: TextStyle(
                          color: Colors.orange[900],
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            // Search Box trigger
            GestureDetector(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const SearchScreen(),
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.search, color: Colors.grey, size: 24),
                    SizedBox(width: 12),
                    Text(
                      'Search customer or product...',
                      style: TextStyle(color: Colors.grey, fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Large main actions/stats
            Row(
              children: [
                // Today's Sales
                Expanded(
                  child: _buildActionStatCard(
                    context: context,
                    title: "Today's Sales",
                    value: currencyFormat.format(stats.todaysSales),
                    gradientColors: [const Color(0xFF2E5BFF), const Color(0xFF7C4DFF)],
                    icon: Icons.trending_up,
                    onTap: () {
                      ref.read(activeTabProvider.notifier).setTab(1);
                    },
                  ),
                ),
                const SizedBox(width: 16),

                // Money to Collect
                Expanded(
                  child: _buildActionStatCard(
                    context: context,
                    title: 'Money to Collect',
                    value: currencyFormat.format(stats.totalPendingDues),
                    gradientColors: stats.totalPendingDues > 0
                        ? [const Color(0xFFFF4D77), const Color(0xFFFF7C4D)]
                        : [const Color(0xFF43A047), const Color(0xFF66BB6A)],
                    icon: Icons.account_balance_wallet,
                    onTap: () {
                      ref.read(activeTabProvider.notifier).setTab(3);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Stats grid
            Row(
              children: [
                // Stock Valuation
                Expanded(
                  child: _buildSummaryMiniCard(
                    context: context,
                    title: 'Stock Valuation',
                    value: currencyFormat.format(stats.stockValue),
                    icon: Icons.inventory,
                    iconBgColor: const Color(0xFFE3F2FD),
                    iconColor: const Color(0xFF1E88E5),
                  ),
                ),
                const SizedBox(width: 16),

                // Active Customers
                Expanded(
                  child: _buildSummaryMiniCard(
                    context: context,
                    title: 'Active Customers',
                    value: '${stats.totalCustomers}',
                    icon: Icons.people,
                    iconBgColor: const Color(0xFFF3E5F5),
                    iconColor: const Color(0xFF8E24AA),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Low Stock Warnings
            _buildLowStockWarningCard(context, ref, stats.lowStockCount),
          ],
        ),
      ),
    );
  }

  Widget _buildActionStatCard({
    required BuildContext context,
    required String title,
    required String value,
    required List<Color> gradientColors,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: gradientColors[0].withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      title.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.white70,
                        letterSpacing: 0.8,
                      ),
                    ),
                    Icon(icon, color: Colors.white70, size: 20),
                  ],
                ),
                const SizedBox(height: 16),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    value,
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Row(
                  children: [
                    Text(
                      'View Details',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(width: 4),
                    Icon(Icons.arrow_forward, size: 14, color: Colors.white),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryMiniCard({
    required BuildContext context,
    required String title,
    required String value,
    required IconData icon,
    required Color iconBgColor,
    required Color iconColor,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isDark ? const Color(0xFF22283A) : const Color(0xFFEBEFF9),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconBgColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? const Color(0xFFA0A7B5) : const Color(0xFF6E7582),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      value,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDark ? const Color(0xFFE2E6F0) : const Color(0xFF1E2229),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLowStockWarningCard(BuildContext context, WidgetRef ref, int lowStockCount) {
    final hasLowStock = lowStockCount > 0;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Resolve colors dynamically for Dark Mode support
    final Color bgColor = hasLowStock
        ? (isDark ? const Color(0xFF2E1C0F) : Colors.orange[50]!)
        : (isDark ? const Color(0xFF151824) : const Color(0xFFF8F9FD));

    final Color borderColor = hasLowStock
        ? (isDark ? const Color(0xFF6E3C18) : Colors.orange[200]!)
        : (isDark ? const Color(0xFF20253B) : const Color(0xFFEBEFF9));

    final Color iconColor = hasLowStock
        ? (isDark ? Colors.orange[300]! : Colors.orange[700]!)
        : (isDark ? Colors.green[400]! : Colors.green[700]!);

    final Color titleColor = hasLowStock
        ? (isDark ? Colors.orange[300]! : Colors.orange[800]!)
        : (isDark ? Colors.green[400]! : Colors.green[800]!);

    final Color subtitleColor = hasLowStock
        ? (isDark ? Colors.orange[200]! : Colors.orange[700]!)
        : (isDark ? Colors.green[300]! : Colors.green[700]!);

    return Card(
      elevation: 0,
      color: bgColor,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: borderColor),
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: () {
          // Switch to Inventory Tab (index 4)
          ref.read(activeTabProvider.notifier).setTab(4);
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: Row(
            children: [
              Icon(
                hasLowStock ? Icons.warning_amber : Icons.check_circle_outline,
                color: iconColor,
                size: 32,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hasLowStock ? 'Low Stock Alert!' : 'Stock Levels Good',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: titleColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      hasLowStock
                          ? '$lowStockCount products are below minimum warning threshold.'
                          : 'All items are currently above safety stock minimums.',
                      style: TextStyle(
                        fontSize: 13,
                        color: subtitleColor,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: iconColor,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
