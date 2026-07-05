import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../models/sale.dart';
import '../../models/customer.dart';
import '../../providers/sale_providers.dart';
import '../../providers/customer_providers.dart';
import '../../providers/repository_providers.dart';
import '../../providers/role_provider.dart';
import '../../widgets/sync_indicator.dart';
import 'new_sale_screen.dart';

/// Shows today's sales with a FAB to record a new sale.
class SalesScreen extends ConsumerWidget {
  const SalesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final todaysSales = ref.watch(todaysSalesProvider);
    final currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
    final timeFormat = DateFormat.jm();
    final isAdmin = ref.watch(isAdminProvider).value ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Sales',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        centerTitle: false,
      ),
      body: todaysSales.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Error loading sales: $error',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ),
        data: (sales) {
          if (sales.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.receipt_long_outlined, size: 80, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text(
                    'No sales today',
                    style: TextStyle(fontSize: 20, color: Colors.grey[500]),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tap + to record a sale',
                    style: TextStyle(fontSize: 16, color: Colors.grey[400]),
                  ),
                ],
              ),
            );
          }

          // Today's total at the top
          final todaysTotal = sales.fold<double>(0, (sum, sale) => sum + sale.totalAmount);

          return Column(
            children: [
              // Summary card
              Container(
                width: double.infinity,
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Text(
                      "Today's Sales",
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).colorScheme.onPrimaryContainer.withValues(alpha: 0.7),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      currencyFormat.format(todaysTotal),
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    ),
                    Text(
                      '${sales.length} sale${sales.length == 1 ? '' : 's'}',
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).colorScheme.onPrimaryContainer.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),

              // Sales list
              Expanded(
                child: ListView.builder(
                  itemCount: sales.length,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemBuilder: (context, index) {
                    final sale = sales[index];
                    return _SaleTile(
                      sale: sale,
                      currencyFormat: currencyFormat,
                      timeFormat: timeFormat,
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: isAdmin
          ? null
          : FloatingActionButton.extended(
              heroTag: 'sales_fab',
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const NewSaleScreen()),
                );
              },
              icon: const Icon(Icons.add, size: 28),
              label: const Text(
                'New Sale',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
    );
  }
}

class _SaleTile extends ConsumerWidget {
  final Sale sale;
  final NumberFormat currencyFormat;
  final DateFormat timeFormat;

  const _SaleTile({
    required this.sale,
    required this.currencyFormat,
    required this.timeFormat,
  });

  void _showSaleDetails(
    BuildContext context,
    WidgetRef ref,
    String customerName,
    double saleDues,
    double customerDues,
  ) {
    final isAdmin = ref.read(isAdminProvider).value ?? false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.6,
          maxChildSize: 0.9,
          minChildSize: 0.4,
          builder: (context, scrollController) {
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Drag Handle
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Sale Details',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Buyer: $customerName',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Date: ${DateFormat('dd MMM yyyy, hh:mm a').format(sale.saleDate)}',
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                  const Divider(height: 24),
                  const Text(
                    'Items Sold:',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView.builder(
                      controller: scrollController,
                      itemCount: sale.items.length,
                      itemBuilder: (context, idx) {
                        final item = sale.items[idx];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(item.productName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          subtitle: Text('Quantity: ${item.quantity} × ${currencyFormat.format(item.unitPrice)}'),
                          trailing: Text(
                            currencyFormat.format(item.subtotal),
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        );
                      },
                    ),
                  ),
                  const Divider(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total Amount:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                      Text(
                        currencyFormat.format(sale.totalAmount),
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Amount Paid Initially:', style: TextStyle(fontSize: 15, color: Colors.grey)),
                      Text(
                        currencyFormat.format(sale.paidAmount),
                        style: const TextStyle(fontSize: 15, color: Colors.green, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Sale Dues Remaining:', style: TextStyle(fontSize: 15, color: Colors.grey)),
                      Text(
                        currencyFormat.format(saleDues),
                        style: TextStyle(
                          fontSize: 15,
                          color: saleDues <= 0 ? Colors.green : Colors.orange[800],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total Customer Dues:', style: TextStyle(fontSize: 15, color: Colors.grey)),
                      Text(
                        currencyFormat.format(customerDues),
                        style: TextStyle(
                          fontSize: 15,
                          color: customerDues <= 0 ? Colors.green : Colors.red[700],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  if (!isAdmin) ...[
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: OutlinedButton.icon(
                        onPressed: () => _confirmDelete(context, ref),
                        icon: const Icon(Icons.delete_forever, color: Colors.red),
                        label: const Text('Void/Delete Sale', style: TextStyle(color: Colors.red, fontSize: 16, fontWeight: FontWeight.bold)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.red),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Delete Sale?', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text(
          'Are you sure you want to delete this sale? This will automatically add the stock back to the inventory and adjust the customer\'s balance dues.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final repo = ref.read(saleRepositoryProvider);
              repo.deleteSale(sale);
              
              Navigator.of(dialogCtx).pop(); // close dialog
              Navigator.of(context).pop();    // close bottom sheet
              
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Sale deleted successfully ✓'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customers = ref.watch(customersProvider).value ?? [];
    final customer = customers.firstWhere((c) => c.id == sale.customerId, orElse: () => Customer(id: '', name: 'Unknown Customer', phone: '', createdAt: DateTime.now()));
    final customerName = customer.name;
    final customerPending = customer.pendingAmount;

    // C4 fix: Show each sale's own balanceDue independently.
    // Don't cross-reference with customer.pendingAmount — that caused
    // "cross-contamination" where paid sales showed dues from other sales.
    final saleDue = sale.balanceDue;
    final isSalePaid = saleDue <= 0;

    final itemsSummary = sale.items.map((i) => '${i.productName} ×${i.quantity}').join(', ');

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => _showSaleDetails(context, ref, customerName, saleDue, customerPending),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Sale info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Buyer Name
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            customerName,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (sale.hasPendingWrites) ...[
                          const SizedBox(width: 8),
                          SyncIndicator(hasPendingWrites: true),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    // Product Summary
                    Text(
                      itemsSummary,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    // Time
                    Text(
                      timeFormat.format(sale.saleDate),
                      style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 12),

              // Amount and status
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    currencyFormat.format(sale.totalAmount),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: isSalePaid ? Colors.green[50] : Colors.orange[50],
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      isSalePaid ? 'Paid' : 'Unpaid: ${currencyFormat.format(saleDue)}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isSalePaid ? Colors.green[700] : Colors.orange[700],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
