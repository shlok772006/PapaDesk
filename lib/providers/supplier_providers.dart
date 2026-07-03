import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/supplier.dart';
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
