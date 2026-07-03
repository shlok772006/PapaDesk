import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/sale.dart';

/// Repository for the `sales` collection.
///
/// ╔══════════════════════════════════════════════════════════════════╗
/// ║  recordSale() is the MOST CRITICAL method in the entire app.   ║
/// ║  It uses a single WriteBatch with FieldValue.increment() to    ║
/// ║  atomically update stock and customer balances.                 ║
/// ║                                                                ║
/// ║  NEVER use a Firestore transaction here — transactions fail    ║
/// ║  offline, and this app MUST work offline.                      ║
/// ║  (AGENTS.md constraint #1, system-design.md §2)                ║
/// ╚══════════════════════════════════════════════════════════════════╝
class SaleRepository {
  final FirebaseFirestore _firestore;
  late final CollectionReference<Map<String, dynamic>> _salesCollection;

  SaleRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance {
    _salesCollection = _firestore.collection('sales');
  }

  /// Records a new sale.
  ///
  /// In a single [WriteBatch]:
  /// 1. Writes the `sales` document.
  /// 2. For each item: decrements the product's `currentStock` by quantity.
  /// 3. Increments the customer's `totalPurchases` by the total amount.
  /// 4. Increments the customer's `pendingAmount` by (totalAmount - paidAmount).
  ///
  /// No discount field — price adjustments happen per-item via unitPrice.
  ///
  /// This batch queues locally if offline and syncs when connectivity
  /// returns — no data is lost, and the operator sees it as "saved"
  /// immediately.
  Future<String> recordSale(Sale sale) async {
    final batch = _firestore.batch();

    // 1. Create the sales document.
    final saleDocRef = _salesCollection.doc();
    batch.set(saleDocRef, sale.toFirestore());

    // 2. Decrement stock for each product in the sale.
    for (final item in sale.items) {
      final productRef = _firestore.collection('products').doc(item.productId);
      batch.update(productRef, {
        'currentStock': FieldValue.increment(-item.quantity),
      });
    }

    // 3. Update customer aggregates.
    final pendingIncrease = sale.totalAmount - sale.paidAmount;
    final customerRef =
        _firestore.collection('customers').doc(sale.customerId);

    batch.update(customerRef, {
      'totalPurchases': FieldValue.increment(sale.totalAmount),
      'pendingAmount': FieldValue.increment(pendingIncrease),
    });

    // 4. Commit — works offline, queues locally.
    await batch.commit();
    return saleDocRef.id;
  }

  /// Returns a live stream of sales for a specific customer,
  /// ordered by date (newest first).
  Stream<List<Sale>> getSalesForCustomer(String customerId) {
    return _salesCollection
        .where('customerId', isEqualTo: customerId)
        .orderBy('saleDate', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => Sale.fromFirestore(doc)).toList(),
        );
  }

  /// Returns a live stream of sales within a date range.
  /// Used for reports (weekly, monthly, yearly views).
  Stream<List<Sale>> getSalesForDateRange(DateTime start, DateTime end) {
    return _salesCollection
        .where('saleDate',
            isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('saleDate', isLessThanOrEqualTo: Timestamp.fromDate(end))
        .orderBy('saleDate', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => Sale.fromFirestore(doc)).toList(),
        );
  }

  /// Returns a live stream of today's sales.
  Stream<List<Sale>> getTodaysSales() {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));
    return getSalesForDateRange(startOfDay, endOfDay);
  }

  /// Returns a single sale by ID.
  Future<Sale?> getSale(String id) async {
    final doc = await _salesCollection.doc(id).get();
    if (!doc.exists) return null;
    return Sale.fromFirestore(doc);
  }
}
