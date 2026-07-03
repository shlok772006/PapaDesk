import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/supplier.dart';

/// Repository for the `suppliers` collection.
class SupplierRepository {
  final FirebaseFirestore _firestore;
  late final CollectionReference<Map<String, dynamic>> _collection;

  SupplierRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance {
    _collection = _firestore.collection('suppliers');
  }

  /// Creates a new supplier.
  Future<String> addSupplier(Supplier supplier) async {
    final docRef = await _collection.add(supplier.toFirestore());
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
    final doc = await _collection.doc(id).get();
    if (!doc.exists) return null;
    return Supplier.fromFirestore(doc);
  }

  /// Updates supplier details.
  Future<void> updateSupplier(String id, Map<String, dynamic> fields) async {
    await _collection.doc(id).update(fields);
  }

  /// Deletes a supplier.
  Future<void> deleteSupplier(String id) async {
    await _collection.doc(id).delete();
  }
}
