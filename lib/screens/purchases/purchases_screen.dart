import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../models/purchase.dart';
import '../../providers/repository_providers.dart';
import '../../providers/supplier_providers.dart';
import '../../providers/role_provider.dart';
import 'new_purchase_screen.dart';

class PurchasesScreen extends ConsumerWidget {
  const PurchasesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(purchaseRepositoryProvider);
    final now = DateTime.now();
    final thirtyDaysAgo = now.subtract(const Duration(days: 30));

    final currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
    final dateFormat = DateFormat('dd MMM, hh:mm a');
    final isAdmin = ref.watch(isAdminProvider).value ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Purchase History',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
      ),
      body: StreamBuilder<List<Purchase>>(
        stream: repo.getPurchasesForDateRange(thirtyDaysAgo, now),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error: ${snapshot.error}',
                style: const TextStyle(fontSize: 16),
              ),
            );
          }

          final purchases = snapshot.data ?? [];

          if (purchases.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.history, size: 80, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text(
                    'No purchases recorded',
                    style: TextStyle(fontSize: 20, color: Colors.grey[500]),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tap + to record stock inward',
                    style: TextStyle(fontSize: 16, color: Colors.grey[400]),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: purchases.length,
            padding: const EdgeInsets.all(16),
            itemBuilder: (context, index) {
              final purchase = purchases[index];
              return _PurchaseTile(
                purchase: purchase,
                currencyFormat: currencyFormat,
                dateFormat: dateFormat,
              );
            },
          );
        },
      ),
      floatingActionButton: isAdmin
          ? null
          : FloatingActionButton.extended(
              heroTag: 'purchases_fab',
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const NewPurchaseScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.add, size: 28),
              label: const Text(
                'New Purchase',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
    );
  }
}

class _PurchaseTile extends ConsumerWidget {
  final Purchase purchase;
  final NumberFormat currencyFormat;
  final DateFormat dateFormat;

  const _PurchaseTile({
    required this.purchase,
    required this.currencyFormat,
    required this.dateFormat,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final supplierAsync = ref.watch(supplierFutureProvider(purchase.supplierId));
    final totalQty = purchase.items.fold<int>(0, (sum, item) => sum + item.quantity);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: Colors.blue[50],
              child: Icon(Icons.arrow_upward, color: Colors.blue[700], size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Supplier Name
                  supplierAsync.when(
                    loading: () => const Text('Loading...',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    error: (err, stack) => const Text('Supplier Error',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    data: (supplier) => Text(
                      supplier?.name ?? 'Unknown Supplier',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${dateFormat.format(purchase.purchaseDate)} • $totalQty pcs',
                    style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              currencyFormat.format(purchase.totalCost),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.blue[700],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
