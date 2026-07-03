import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/customer.dart';
import 'repository_providers.dart';

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
