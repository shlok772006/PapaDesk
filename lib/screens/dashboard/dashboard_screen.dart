import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../providers/dashboard_providers.dart';
import 'search_screen.dart';
import 'reports_screen.dart';

import '../settings/settings_screen.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(dashboardStatsProvider);
    final currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹');

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
                    color: Theme.of(context).colorScheme.primaryContainer,
                    textColor: Theme.of(context).colorScheme.onPrimaryContainer,
                    onTap: () {
                      // Switch to Sales Tab (index 1)
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
                    color: stats.totalPendingDues > 0 ? Colors.red[50]! : Colors.green[50]!,
                    textColor: stats.totalPendingDues > 0 ? Colors.red[700]! : Colors.green[700]!,
                    onTap: () {
                      // Switch to Ledger Tab (index 3)
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
                    title: 'Stock Valuation',
                    value: currencyFormat.format(stats.stockValue),
                    icon: Icons.inventory,
                    color: Colors.blue[50]!,
                    iconColor: Colors.blue[700]!,
                  ),
                ),
                const SizedBox(width: 16),

                // Active Customers
                Expanded(
                  child: _buildSummaryMiniCard(
                    title: 'Active Customers',
                    value: '${stats.totalCustomers}',
                    icon: Icons.people,
                    color: Colors.purple[50]!,
                    iconColor: Colors.purple[700]!,
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
    required Color color,
    required Color textColor,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2,
      color: color,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: textColor.withValues(alpha: 0.8),
                ),
              ),
              const SizedBox(height: 8),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Text(
                    'View list',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.arrow_forward, size: 14, color: textColor),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryMiniCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required Color iconColor,
  }) {
    return Card(
      elevation: 0,
      color: color,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[700],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      value,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[900],
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

    return Card(
      elevation: 0,
      color: hasLowStock ? Colors.orange[50] : Colors.grey[50],
      shape: RoundedRectangleBorder(
        side: BorderSide(color: hasLowStock ? Colors.orange[200]! : Colors.grey[200]!),
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () {
          // Switch to Inventory Tab (index 4)
          ref.read(activeTabProvider.notifier).setTab(4);
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: Row(
            children: [
              Icon(
                hasLowStock ? Icons.warning_amber : Icons.check_circle_outline,
                color: hasLowStock ? Colors.orange[700] : Colors.green[700],
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
                        color: hasLowStock ? Colors.orange[800] : Colors.green[800],
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      hasLowStock
                          ? '$lowStockCount products are below minimum warning threshold.'
                          : 'All items are currently above safety stock minimums.',
                      style: TextStyle(
                        fontSize: 13,
                        color: hasLowStock ? Colors.orange[700] : Colors.green[700],
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: hasLowStock ? Colors.orange[700] : Colors.green[700],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
