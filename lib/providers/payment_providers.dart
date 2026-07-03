import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/payment.dart';
import 'repository_providers.dart';

/// Live stream of payments for a specific customer (for ledger view).
final customerPaymentsProvider =
    StreamProvider.family<List<Payment>, String>((ref, customerId) {
  final repo = ref.watch(paymentRepositoryProvider);
  return repo.getPaymentsForCustomer(customerId);
});
