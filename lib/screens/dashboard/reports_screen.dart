import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../providers/reports_providers.dart';
import '../../providers/customer_providers.dart';
import '../ledger/customer_detail_screen.dart';

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹');

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  DateTimeRange _getDateRange(int tabIndex) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day, 23, 59, 59);

    switch (tabIndex) {
      case 0: // Weekly (last 7 days)
        final start = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 7));
        return DateTimeRange(start: start, end: today);
      case 1: // Monthly (last 30 days)
        final start = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 30));
        return DateTimeRange(start: start, end: today);
      case 2: // Yearly (last 365 days)
      default:
        final start = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 365));
        return DateTimeRange(start: start, end: today);
    }
  }

  @override
  Widget build(BuildContext context) {
    final range = _getDateRange(_tabController.index);
    final reportAsync = ref.watch(reportsProvider(range));
    final customersWithPending = ref.watch(customersWithPendingProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Business Reports',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '7 Days'),
            Tab(text: '30 Days'),
            Tab(text: '1 Year'),
          ],
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        physics: const NeverScrollableScrollPhysics(), // Managed manually by controller
        children: List.generate(3, (index) {
          return reportAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Center(child: Text('Error loading report: $err')),
            data: (report) => ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Revenue & Profit Cards
                Row(
                  children: [
                    // Revenue
                    Expanded(
                      child: _buildMetricCard(
                        title: 'Total Revenue',
                        value: _currencyFormat.format(report.totalRevenue),
                        color: Theme.of(context).colorScheme.primaryContainer,
                        textColor: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Profit
                    Expanded(
                      child: _buildMetricCard(
                        title: 'Estimated Profit',
                        value: _currencyFormat.format(report.totalProfit),
                        color: Colors.green[50]!,
                        textColor: Colors.green[800]!,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                
                // Margin split bar chart
                _buildProfitSplitChart(report),
                
                const SizedBox(height: 24),

                // Top Selling Products Section
                _buildSectionHeader('Top Selling Products'),
                const SizedBox(height: 8),
                if (report.topProducts.isEmpty)
                  _buildEmptyState('No items sold in this period')
                else
                  ...report.topProducts.map(
                    (item) => _buildTopProductTile(
                      item,
                      report.topProducts.isNotEmpty ? report.topProducts.first.revenue : 1.0,
                    ),
                  ),

                const SizedBox(height: 24),

                // Highest Debtor Customers Section
                _buildSectionHeader('Highest Pending Dues'),
                const SizedBox(height: 8),
                customersWithPending.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (err, _) => Text('Error loading debtors: $err'),
                  data: (customers) {
                    final topDebtors = customers.take(5).toList();

                    if (topDebtors.isEmpty) {
                      return _buildEmptyState('No customers owe money ✓');
                    }

                    return Column(
                      children: topDebtors
                          .map((cust) => _buildDebtorTile(context, cust))
                          .toList(),
                    );
                  },
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required Color color,
    required Color textColor,
  }) {
    return Card(
      elevation: 0,
      color: color,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
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
            const SizedBox(height: 6),
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
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Row(
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(String msg) {
    return Card(
      elevation: 0,
      color: Colors.grey[50],
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Colors.grey[200]!),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Text(
            msg,
            style: TextStyle(fontSize: 15, color: Colors.grey[500]),
          ),
        ),
      ),
    );
  }

  Widget _buildProfitSplitChart(ReportData report) {
    final revenue = report.totalRevenue;
    final profit = report.totalProfit;

    final profitPercent = revenue > 0 ? (profit / revenue * 100).clamp(0.0, 100.0) : 0.0;
    final cogsPercent = 100.0 - profitPercent;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Colors.grey[200]!),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Margin Analysis',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Text(
                  '${profitPercent.toStringAsFixed(1)}% Profit Margin',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.green[800],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (revenue <= 0)
              Container(
                height: 16,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Center(
                  child: Text(
                    'No data in this period',
                    style: TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ),
              )
            else ...[
              // The Split Bar Chart
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  height: 16,
                  child: Row(
                    children: [
                      if (profitPercent > 0)
                        Expanded(
                          flex: (profitPercent * 10).toInt(),
                          child: Container(
                            color: Colors.green,
                          ),
                        ),
                      if (cogsPercent > 0)
                        Expanded(
                          flex: (cogsPercent * 10).toInt(),
                          child: Container(
                            color: Colors.orange[300],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Legend
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(width: 12, height: 12, decoration: BoxDecoration(color: Colors.green, borderRadius: BorderRadius.circular(3))),
                      const SizedBox(width: 6),
                      Text('Profit: ${profitPercent.toStringAsFixed(1)}%', style: const TextStyle(fontSize: 13, color: Colors.grey)),
                    ],
                  ),
                  Row(
                    children: [
                      Container(width: 12, height: 12, decoration: BoxDecoration(color: Colors.orange[300], borderRadius: BorderRadius.circular(3))),
                      const SizedBox(width: 6),
                      Text('Cost of Goods: ${cogsPercent.toStringAsFixed(1)}%', style: const TextStyle(fontSize: 13, color: Colors.grey)),
                    ],
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTopProductTile(TopProductEntry item, double maxRevenue) {
    final double barWidthFactor = maxRevenue > 0 ? (item.revenue / maxRevenue).clamp(0.0, 1.0) : 0.0;
    final percent = maxRevenue > 0 ? (item.revenue / maxRevenue * 100) : 0.0;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Colors.grey[200]!),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    item.name,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  _currencyFormat.format(item.revenue),
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${item.quantity} units sold',
                  style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                ),
                Text(
                  '${percent.toStringAsFixed(0)}% of top',
                  style: TextStyle(fontSize: 12, color: Colors.grey[400], fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Custom Bar Chart Representation
            Stack(
              children: [
                Container(
                  height: 8,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                FractionallySizedBox(
                  widthFactor: barWidthFactor,
                  child: Container(
                    height: 8,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Theme.of(context).colorScheme.primary,
                          Theme.of(context).colorScheme.secondary,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDebtorTile(BuildContext context, dynamic customer) {
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Colors.grey[200]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => CustomerDetailScreen(customerId: customer.id),
            ),
          );
        },
        title: Text(
          customer.name,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(customer.phone.isNotEmpty ? customer.phone : 'No phone number'),
        trailing: Text(
          _currencyFormat.format(customer.pendingAmount),
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15,
            color: Colors.red[700],
          ),
        ),
      ),
    );
  }
}
