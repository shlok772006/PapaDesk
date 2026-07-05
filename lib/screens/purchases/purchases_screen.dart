import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../models/purchase.dart';
import '../../models/supplier.dart';
import '../../models/product.dart';
import '../../providers/repository_providers.dart';
import '../../providers/supplier_providers.dart';
import '../../providers/product_providers.dart';
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
    final suppliersAsync = ref.watch(suppliersProvider);
    final productsAsync = ref.watch(productsProvider);

    final supplierName = suppliersAsync.maybeWhen(
      data: (list) {
        final supplier = list.firstWhere(
          (s) => s.id == purchase.supplierId,
          orElse: () => Supplier(id: '', name: 'Unknown Supplier', phone: ''),
        );
        return supplier.name;
      },
      orElse: () => 'Loading...',
    );

    // Build items description list
    final List<String> itemNames = [];
    final List<String> detailedItemNames = [];
    int totalQty = 0;

    for (final item in purchase.items) {
      totalQty += item.quantity;
      final product = productsAsync.maybeWhen(
        data: (productsList) => productsList.firstWhere(
          (p) => p.id == item.productId,
          orElse: () => Product(id: '', name: 'Unknown Product', category: 'None', purchasePrice: 0, sellingPrice: 0, currentStock: 0, minStock: 0),
        ),
        orElse: () => null,
      );

      final prodName = product?.name ?? 'Product (${item.productId.substring(0, min(5, item.productId.length))})';
      final prodCategory = product?.category ?? 'None';
      itemNames.add('$prodName ×${item.quantity}');
      detailedItemNames.add('$prodName ($prodCategory)\n   • Qty: ${item.quantity} | Cost: ${currencyFormat.format(item.unitCost)} each');
    }

    final itemsSummary = itemNames.join(', ');
    final detailedSummary = detailedItemNames.join('\n\n');

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => _showPurchaseDetails(context, supplierName, totalQty, detailedSummary),
        borderRadius: BorderRadius.circular(12),
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
                    Text(
                      supplierName,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      itemsSummary.isNotEmpty ? itemsSummary : '$totalQty pcs',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey[700]),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${dateFormat.format(purchase.purchaseDate)} • $totalQty pcs',
                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
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
      ),
    );
  }

  void _showPurchaseDetails(BuildContext context, String supplierName, int totalQty, String detailedSummary) {
    final fullDateFormat = DateFormat('dd MMMM yyyy, hh:mm a');

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2.5),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Supplier Stock Purchase',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey),
                ),
                const SizedBox(height: 12),
                Text(
                  currencyFormat.format(purchase.totalCost),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[800],
                  ),
                ),
                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Supplier Name:', style: TextStyle(fontSize: 15, color: Colors.grey)),
                    Text(
                      supplierName,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Purchase Date:', style: TextStyle(fontSize: 15, color: Colors.grey)),
                    Text(
                      fullDateFormat.format(purchase.purchaseDate),
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'Purchased Products ($totalQty pcs):',
                  style: const TextStyle(fontSize: 15, color: Colors.grey, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Container(
                  constraints: const BoxConstraints(maxHeight: 180),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: SingleChildScrollView(
                    child: Align(
                      alignment: Alignment.topLeft,
                      child: Text(
                        detailedSummary.isNotEmpty ? detailedSummary : 'No items details.',
                        style: const TextStyle(fontSize: 14, height: 1.4),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  height: 52,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // helper to get min value
  int min(int a, int b) => a < b ? a : b;
}
