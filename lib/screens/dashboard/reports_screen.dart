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

                // Top Selling Products Section
                _buildSectionHeader('Top Selling Products'),
                const SizedBox(height: 8),
                if (report.topProducts.isEmpty)
                  _buildEmptyState('No items sold in this period')
                else
                  ...report.topProducts.map((item) => _buildTopProductTile(item)),

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

  Widget _buildTopProductTile(TopProductEntry item) {
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Colors.grey[200]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        title: Text(
          item.name,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text('Sold: ${item.quantity} units'),
        trailing: Text(
          _currencyFormat.format(item.revenue),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
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
