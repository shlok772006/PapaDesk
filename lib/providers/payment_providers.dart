import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/payment.dart';
import '../models/sale.dart';
import '../models/purchase.dart';
import 'repository_providers.dart';
import 'customer_providers.dart';
import 'supplier_providers.dart';
import '../models/customer.dart';
import '../models/supplier.dart';

enum TransactionType { sale, payment, purchase }

class CashTransaction {
  final String id;
  final String title;
  final String partyName;
  final DateTime date;
  final double amount;
  final TransactionType type;
  final String subtitle;

  CashTransaction({
    required this.id,
    required this.title,
    required this.partyName,
    required this.date,
    required this.amount,
    required this.type,
    required this.subtitle,
  });
}

/// Live stream of payments for a specific customer (for ledger view).
final customerPaymentsProvider =
    StreamProvider.family<List<Payment>, String>((ref, customerId) {
  final repo = ref.watch(paymentRepositoryProvider);
  return repo.getPaymentsForCustomer(customerId);
});

/// Stream providers for last 30 days.
final recentPaymentsStreamProvider = StreamProvider<List<Payment>>((ref) {
  final repo = ref.watch(paymentRepositoryProvider);
  final now = DateTime.now();
  final thirtyDaysAgo = now.subtract(const Duration(days: 30));
  return repo.getPaymentsForDateRange(thirtyDaysAgo, now);
});

final recentSalesStreamProvider = StreamProvider<List<Sale>>((ref) {
  final repo = ref.watch(saleRepositoryProvider);
  final now = DateTime.now();
  final thirtyDaysAgo = now.subtract(const Duration(days: 30));
  return repo.getSalesForDateRange(thirtyDaysAgo, now);
});

final recentPurchasesStreamProvider = StreamProvider<List<Purchase>>((ref) {
  final repo = ref.watch(purchaseRepositoryProvider);
  final now = DateTime.now();
  final thirtyDaysAgo = now.subtract(const Duration(days: 30));
  return repo.getPurchasesForDateRange(thirtyDaysAgo, now);
});

/// Combined sorted list of cash transactions (sales payments, ledger payments, product purchases).
final recentTransactionsProvider = Provider<AsyncValue<List<CashTransaction>>>((ref) {
  final paymentsAsync = ref.watch(recentPaymentsStreamProvider);
  final salesAsync = ref.watch(recentSalesStreamProvider);
  final purchasesAsync = ref.watch(recentPurchasesStreamProvider);
  
  final customersAsync = ref.watch(customersProvider);
  final suppliersAsync = ref.watch(suppliersProvider);

  if (paymentsAsync.isLoading || salesAsync.isLoading || purchasesAsync.isLoading || customersAsync.isLoading || suppliersAsync.isLoading) {
    return const AsyncValue.loading();
  }

  if (paymentsAsync.hasError) return AsyncValue.error(paymentsAsync.error!, paymentsAsync.stackTrace!);
  if (salesAsync.hasError) return AsyncValue.error(salesAsync.error!, salesAsync.stackTrace!);
  if (purchasesAsync.hasError) return AsyncValue.error(purchasesAsync.error!, purchasesAsync.stackTrace!);
  if (customersAsync.hasError) return AsyncValue.error(customersAsync.error!, customersAsync.stackTrace!);
  if (suppliersAsync.hasError) return AsyncValue.error(suppliersAsync.error!, suppliersAsync.stackTrace!);

  final payments = paymentsAsync.value ?? [];
  final sales = salesAsync.value ?? [];
  final purchases = purchasesAsync.value ?? [];
  final customers = customersAsync.value ?? [];
  final suppliers = suppliersAsync.value ?? [];

  final List<CashTransaction> list = [];

  // 1. Dues Payments
  for (final p in payments) {
    final customer = customers.firstWhere(
      (c) => c.id == p.customerId,
      orElse: () => Customer(id: '', name: 'Unknown Customer', phone: '', createdAt: DateTime.now()),
    );
    list.add(CashTransaction(
      id: p.id,
      title: 'Dues Payment',
      partyName: customer.name,
      date: p.paymentDate,
      amount: p.amount,
      type: TransactionType.payment,
      subtitle: 'Method: ${p.method.toUpperCase()}',
    ));
  }

  // 2. Sales Payments (only if paidAmount > 0)
  for (final s in sales) {
    if (s.paidAmount > 0) {
      final customer = customers.firstWhere(
        (c) => c.id == s.customerId,
        orElse: () => Customer(id: '', name: 'Unknown Customer', phone: '', createdAt: DateTime.now()),
      );
      final itemsSummary = s.items.map((i) => '${i.productName} ×${i.quantity}').join(', ');
      list.add(CashTransaction(
        id: '${s.id}_payment',
        title: 'Sale Payment',
        partyName: customer.name,
        date: s.saleDate,
        amount: s.paidAmount,
        type: TransactionType.sale,
        subtitle: itemsSummary,
      ));
    }
  }

  // 3. Purchase Outflows
  for (final pur in purchases) {
    final supplier = suppliers.firstWhere(
      (sup) => sup.id == pur.supplierId,
      orElse: () => Supplier(id: '', name: 'Unknown Supplier', phone: ''),
    );
    final itemsSummary = pur.items.length == 1 
        ? 'Product Purchase' 
        : '${pur.items.length} items purchased';
    list.add(CashTransaction(
      id: pur.id,
      title: 'Purchase Outflow',
      partyName: supplier.name,
      date: pur.purchaseDate,
      amount: -pur.totalCost, // Negative for cash outflow!
      type: TransactionType.purchase,
      subtitle: itemsSummary,
    ));
  }

  // Sort newest first
  list.sort((a, b) => b.date.compareTo(a.date));

  return AsyncValue.data(list);
});
