import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/sale.dart';
import 'repository_providers.dart';

/// Live stream of today's sales.
final todaysSalesProvider = StreamProvider<List<Sale>>((ref) {
  final repo = ref.watch(saleRepositoryProvider);
  return repo.getTodaysSales();
});

/// Live stream of sales for a specific customer (for ledger view).
final customerSalesProvider =
    StreamProvider.family<List<Sale>, String>((ref, customerId) {
  final repo = ref.watch(saleRepositoryProvider);
  return repo.getSalesForCustomer(customerId);
});
