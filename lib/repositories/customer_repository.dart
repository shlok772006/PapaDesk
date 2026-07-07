import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/customer.dart';
import '../utils/offline_extension.dart';

/// Repository for the `customers` collection.
///
/// NEVER use a Firestore transaction here — transactions fail offline.
/// (AGENTS.md constraint #1, system-design.md §2)
class CustomerRepository {
  final FirebaseFirestore _firestore;
  late final CollectionReference<Map<String, dynamic>> _collection;

  CustomerRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance {
    _collection = _firestore.collection('customers');
  }

  /// Creates a new customer.
  /// Uses fire-and-forget pattern for offline compatibility (AGENTS.md constraint #2).
  Future<String> addCustomer(Customer customer) async {
    final docRef = _collection.doc();
    docRef.set(customer.toFirestore()).catchError((e) {});
    return docRef.id;
  }

  /// Returns a single customer by ID.
  Future<Customer?> getCustomer(String id) async {
    final doc = await _collection.doc(id).getOfflineSafe();
    if (!doc.exists) return null;
    return Customer.fromFirestore(doc);
  }

  /// Returns a live stream of all customers, ordered by name.
  Stream<List<Customer>> getCustomers() {
    return _collection.orderBy('name').snapshots().map(
          (snapshot) => snapshot.docs
              .map((doc) => Customer.fromFirestore(doc))
              .toList(),
        );
  }

  /// Returns a live stream of customers with pending amounts, sorted
  /// highest first — useful for the "money to collect" view.
  Stream<List<Customer>> getCustomersWithPending() {
    return _collection
        .where('pendingAmount', isGreaterThan: 0)
        .orderBy('pendingAmount', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => Customer.fromFirestore(doc))
              .toList(),
        );
  }

  /// Updates only the editable fields (name, phone, address).
  /// Never touches totalPurchases or pendingAmount.
  Future<void> updateCustomer(String id, Map<String, dynamic> fields) async {
    // Safety: strip out aggregate fields if they were accidentally included.
    fields.remove('totalPurchases');
    fields.remove('pendingAmount');
    _collection.doc(id).update(fields).catchError((e) {});
  }

  /// Deletes a customer. Use with caution — only for cleanup of
  /// test data or customers with zero transactions.
  Future<void> deleteCustomer(String id) async {
    _collection.doc(id).delete().catchError((e) {});
  }

  /// Returns a DocumentReference for use in batched writes
  /// (e.g., SaleRepository needs this to increment pendingAmount).
  DocumentReference<Map<String, dynamic>> docRef(String id) {
    return _collection.doc(id);
  }
}
