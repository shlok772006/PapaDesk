import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/customer.dart';
import 'repository_providers.dart';
import 'sale_providers.dart';
import 'payment_providers.dart';

/// Live stream of all customers, ordered by name.
/// Used by both Sales and Payments to let the operator pick a customer.
final customersProvider = StreamProvider<List<Customer>>((ref) {
  final repo = ref.watch(customerRepositoryProvider);
  return repo.getCustomers();
});

/// Live stream of customers with pending amounts (money to collect).
final customersWithPendingProvider = StreamProvider<List<Customer>>((ref) {
  final repo = ref.watch(customerRepositoryProvider);
  return repo.getCustomersWithPending();
});

/// Combined model representing a ledger transaction entry (Sale or Payment).
class LedgerEntry {
  final DateTime date;
  final String type; // 'sale' or 'payment'
  final dynamic entity; // Sale or Payment

  const LedgerEntry({
    required this.date,
    required this.type,
    required this.entity,
  });
}

/// Reactively combines Sales and Payments for a customer and sorts them newest first.
final customerLedgerProvider = Provider.family<AsyncValue<List<LedgerEntry>>, String>((ref, customerId) {
  final salesAsync = ref.watch(customerSalesProvider(customerId));
  final paymentsAsync = ref.watch(customerPaymentsProvider(customerId));

  if (salesAsync.isLoading || paymentsAsync.isLoading) {
    return const AsyncValue.loading();
  }
  if (salesAsync.hasError) {
    return AsyncValue.error(salesAsync.error!, salesAsync.stackTrace!);
  }
  if (paymentsAsync.hasError) {
    return AsyncValue.error(paymentsAsync.error!, paymentsAsync.stackTrace!);
  }

  final sales = salesAsync.value ?? [];
  final payments = paymentsAsync.value ?? [];

  final List<LedgerEntry> entries = [];
  for (final sale in sales) {
    entries.add(LedgerEntry(date: sale.saleDate, type: 'sale', entity: sale));
  }
  for (final payment in payments) {
    entries.add(LedgerEntry(date: payment.paymentDate, type: 'payment', entity: payment));
  }

  // Sort newest first
  entries.sort((a, b) => b.date.compareTo(a.date));

  return AsyncValue.data(entries);
});

