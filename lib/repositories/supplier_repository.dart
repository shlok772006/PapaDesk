import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/supplier.dart';
import '../models/supplier_payment.dart';
import '../utils/offline_extension.dart';

/// Repository for the `suppliers` collection.
class SupplierRepository {
  final FirebaseFirestore _firestore;
  late final CollectionReference<Map<String, dynamic>> _collection;

  SupplierRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance {
    _collection = _firestore.collection('suppliers');
  }

  /// Creates a new supplier.
  /// Uses fire-and-forget pattern for offline compatibility (AGENTS.md constraint #2).
  Future<String> addSupplier(Supplier supplier) async {
    final docRef = _collection.doc();
    docRef.set(supplier.toFirestore()).catchError((e) {});
    return docRef.id;
  }

  /// Returns a live stream of all suppliers, ordered by name.
  Stream<List<Supplier>> getSuppliers() {
    return _collection.orderBy('name').snapshots().map(
          (snapshot) => snapshot.docs
              .map((doc) => Supplier.fromFirestore(doc))
              .toList(),
        );
  }

  /// Returns a single supplier by ID.
  Future<Supplier?> getSupplier(String id) async {
    final doc = await _collection.doc(id).getOfflineSafe();
    if (!doc.exists) return null;
    return Supplier.fromFirestore(doc);
  }

  /// Updates supplier details.
  Future<void> updateSupplier(String id, Map<String, dynamic> fields) async {
    _collection.doc(id).update(fields).catchError((e) {});
  }

  /// Deletes a supplier.
  Future<void> deleteSupplier(String id) async {
    _collection.doc(id).delete().catchError((e) {});
  }

  /// Records a payment made to a supplier.
  /// Atomic update to write payment doc and decrement supplier's pendingAmount.
  /// Offline reliable using batched write.
  Future<String> recordSupplierPayment(SupplierPayment payment) async {
    final batch = _firestore.batch();
    final paymentDocRef = _firestore.collection('supplier_payments').doc();
    batch.set(paymentDocRef, payment.toFirestore());

    final supplierRef = _collection.doc(payment.supplierId);
    batch.update(supplierRef, {
      'pendingAmount': FieldValue.increment(-payment.amount),
    });

    batch.commit().catchError((e) {});
    return paymentDocRef.id;
  }

  /// Streams payments made to a specific supplier (newest first).
  Stream<List<SupplierPayment>> getSupplierPayments(String supplierId) {
    return _firestore
        .collection('supplier_payments')
        .where('supplierId', isEqualTo: supplierId)
        .orderBy('paymentDate', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => SupplierPayment.fromFirestore(doc))
              .toList(),
        );
  }

  /// Returns a DocumentReference for use in batched writes.
  DocumentReference<Map<String, dynamic>> docRef(String id) {
    return _collection.doc(id);
  }
}
