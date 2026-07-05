import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/sale.dart';
import 'repository_providers.dart';

/// Live stream of today's sales.
/// Auto-invalidates every 60 seconds so it always reflects the current day,
/// even if the app is left open past midnight. (C2 fix)
final todaysSalesProvider = StreamProvider<List<Sale>>((ref) {
  final repo = ref.watch(saleRepositoryProvider);
  
  // Compute date range for "today" at stream creation time
  final now = DateTime.now();
  final startOfDay = DateTime(now.year, now.month, now.day);
  final endOfDay = startOfDay.add(const Duration(days: 1));
  
  // Auto-invalidate this provider every 60 seconds.
  // If the day has rolled over, it will re-create with fresh dates.
  final timer = Timer(const Duration(seconds: 60), () {
    ref.invalidateSelf();
  });
  ref.onDispose(timer.cancel);
  
  return repo.getSalesForDateRange(startOfDay, endOfDay);
});

/// Live stream of sales for a specific customer (for ledger view).
final customerSalesProvider =
    StreamProvider.family<List<Sale>, String>((ref, customerId) {
  final repo = ref.watch(saleRepositoryProvider);
  return repo.getSalesForCustomer(customerId);
});
