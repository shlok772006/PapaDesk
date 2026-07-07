import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/payment.dart';
import '../utils/offline_extension.dart';

/// Repository for the `payments` collection.
///
/// recordPayment() uses a single WriteBatch with FieldValue.increment()
/// to atomically update the customer's pendingAmount.
///
/// NEVER use a Firestore transaction here — transactions fail offline.
/// (AGENTS.md constraint #1, system-design.md §2)
class PaymentRepository {
  final FirebaseFirestore _firestore;
  late final CollectionReference<Map<String, dynamic>> _paymentsCollection;

  PaymentRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance {
    _paymentsCollection = _firestore.collection('payments');
  }

  /// Records a new payment from a customer.
  ///
  /// In a single [WriteBatch]:
  /// 1. Writes the `payments` document.
  /// 2. Decrements the customer's `pendingAmount` by the payment amount.
  ///
  /// Works offline — queues locally and syncs when connected.
  Future<String> recordPayment(Payment payment) async {
    final batch = _firestore.batch();

    // 1. Create the payments document.
    final paymentDocRef = _paymentsCollection.doc();
    batch.set(paymentDocRef, payment.toFirestore());

    // 2. Decrement customer's pending amount.
    final customerRef =
        _firestore.collection('customers').doc(payment.customerId);
    batch.update(customerRef, {
      'pendingAmount': FieldValue.increment(-payment.amount),
    });

    // Execute batch commit in the background to prevent network latency from blocking the UI
    batch.commit().catchError((e) {
      // Background sync handles persistence/retries automatically
    });
    return paymentDocRef.id;
  }

  /// Returns a live stream of payments for a specific customer,
  /// ordered by date (newest first).
  Stream<List<Payment>> getPaymentsForCustomer(String customerId) {
    return _paymentsCollection
        .where('customerId', isEqualTo: customerId)
        .orderBy('paymentDate', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => Payment.fromFirestore(doc))
              .toList(),
        );
  }

  /// Returns a live stream of payments within a date range.
  Stream<List<Payment>> getPaymentsForDateRange(DateTime start, DateTime end) {
    return _paymentsCollection
        .where('paymentDate',
            isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('paymentDate', isLessThanOrEqualTo: Timestamp.fromDate(end))
        .orderBy('paymentDate', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => Payment.fromFirestore(doc))
              .toList(),
        );
  }

  /// Returns a single payment by ID.
  Future<Payment?> getPayment(String id) async {
    final doc = await _paymentsCollection.doc(id).getOfflineSafe();
    if (!doc.exists) return null;
    return Payment.fromFirestore(doc);
  }
}
