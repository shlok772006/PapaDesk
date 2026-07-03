import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repositories/customer_repository.dart';
import '../repositories/product_repository.dart';
import '../repositories/supplier_repository.dart';
import '../repositories/sale_repository.dart';
import '../repositories/payment_repository.dart';
import '../repositories/purchase_repository.dart';

/// Provides a singleton FirebaseFirestore instance.
final firestoreProvider = Provider<FirebaseFirestore>((ref) {
  return FirebaseFirestore.instance;
});

/// Provides the current Firebase Auth user (for createdBy on transactions).
final authProvider = Provider<FirebaseAuth>((ref) {
  return FirebaseAuth.instance;
});

/// Returns the current user's UID, or 'anonymous' if not logged in.
/// Used as the `createdBy` field on sales, payments, and purchases.
final currentUserIdProvider = Provider<String>((ref) {
  final auth = ref.watch(authProvider);
  return auth.currentUser?.uid ?? 'anonymous';
});

// ── Repository providers ──────────────────────────────────────────────

final customerRepositoryProvider = Provider<CustomerRepository>((ref) {
  return CustomerRepository(firestore: ref.watch(firestoreProvider));
});

final productRepositoryProvider = Provider<ProductRepository>((ref) {
  return ProductRepository(firestore: ref.watch(firestoreProvider));
});

final supplierRepositoryProvider = Provider<SupplierRepository>((ref) {
  return SupplierRepository(firestore: ref.watch(firestoreProvider));
});

final saleRepositoryProvider = Provider<SaleRepository>((ref) {
  return SaleRepository(firestore: ref.watch(firestoreProvider));
});

final paymentRepositoryProvider = Provider<PaymentRepository>((ref) {
  return PaymentRepository(firestore: ref.watch(firestoreProvider));
});

final purchaseRepositoryProvider = Provider<PurchaseRepository>((ref) {
  return PurchaseRepository(firestore: ref.watch(firestoreProvider));
});
