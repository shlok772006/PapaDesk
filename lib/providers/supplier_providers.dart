import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/supplier.dart';
import '../models/purchase.dart';
import '../models/supplier_payment.dart';
import 'repository_providers.dart';

/// Live stream of all suppliers, ordered by name.
/// Used by the Purchases flow to pick a supplier.
final suppliersProvider = StreamProvider<List<Supplier>>((ref) {
  final repo = ref.watch(supplierRepositoryProvider);
  return repo.getSuppliers();
});

/// Future provider to fetch a single supplier by ID (used for list mapping).
final supplierFutureProvider = FutureProvider.family<Supplier?, String>((ref, supplierId) {
  final repo = ref.watch(supplierRepositoryProvider);
  return repo.getSupplier(supplierId);
});

/// Streams purchases made from a specific supplier (newest first).
final supplierPurchasesProvider = StreamProvider.family<List<Purchase>, String>((ref, supplierId) {
  final repo = ref.watch(purchaseRepositoryProvider);
  return repo.getPurchasesForSupplier(supplierId);
});

/// Streams payments made to a specific supplier (newest first).
final supplierPaymentsProvider = StreamProvider.family<List<SupplierPayment>, String>((ref, supplierId) {
  final repo = ref.watch(supplierRepositoryProvider);
  return repo.getSupplierPayments(supplierId);
});

/// Combined model representing a supplier ledger transaction entry (Purchase or SupplierPayment).
class SupplierLedgerEntry {
  final DateTime date;
  final String type; // 'purchase' or 'payment'
  final dynamic entity; // Purchase or SupplierPayment

  const SupplierLedgerEntry({
    required this.date,
    required this.type,
    required this.entity,
  });
}

/// Reactively combines Purchases and Payments for a supplier and sorts them newest first.
final supplierLedgerProvider = Provider.family<AsyncValue<List<SupplierLedgerEntry>>, String>((ref, supplierId) {
  final purchasesAsync = ref.watch(supplierPurchasesProvider(supplierId));
  final paymentsAsync = ref.watch(supplierPaymentsProvider(supplierId));

  if (purchasesAsync.isLoading || paymentsAsync.isLoading) {
    return const AsyncValue.loading();
  }
  if (purchasesAsync.hasError) {
    return AsyncValue.error(purchasesAsync.error!, purchasesAsync.stackTrace!);
  }
  if (paymentsAsync.hasError) {
    return AsyncValue.error(paymentsAsync.error!, paymentsAsync.stackTrace!);
  }

  final purchases = purchasesAsync.value ?? [];
  final payments = paymentsAsync.value ?? [];

  final List<SupplierLedgerEntry> entries = [];
  for (final purchase in purchases) {
    entries.add(SupplierLedgerEntry(date: purchase.purchaseDate, type: 'purchase', entity: purchase));
  }
  for (final payment in payments) {
    entries.add(SupplierLedgerEntry(date: payment.paymentDate, type: 'payment', entity: payment));
  }

  // Sort newest first
  entries.sort((a, b) => b.date.compareTo(a.date));

  return AsyncValue.data(entries);
});
