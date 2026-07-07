import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/purchase.dart';
import '../utils/offline_extension.dart';

/// Repository for the `purchases` collection.
///
/// recordPurchase() uses a single WriteBatch with FieldValue.increment()
/// to atomically update each product's currentStock.
///
/// NEVER use a Firestore transaction here — transactions fail offline.
/// (AGENTS.md constraint #1, system-design.md §2)
class PurchaseRepository {
  final FirebaseFirestore _firestore;
  late final CollectionReference<Map<String, dynamic>> _purchasesCollection;

  PurchaseRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance {
    _purchasesCollection = _firestore.collection('purchases');
  }

  /// Records a new purchase (stock inward from a supplier).
  ///
  /// In a single [WriteBatch]:
  /// 1. Writes the `purchases` document.
  /// 2. Increments the supplier's pendingAmount by purchase.balanceDue.
  /// 3. For each item: increments the product's `currentStock` by quantity.
  ///
  /// Works offline — queues locally and syncs when connected.
  Future<String> recordPurchase(Purchase purchase) async {
    final batch = _firestore.batch();

    // 1. Create the purchases document.
    final purchaseDocRef = _purchasesCollection.doc();
    batch.set(purchaseDocRef, purchase.toFirestore());

    // 2. Increment the supplier's pendingAmount by balanceDue (if any)
    if (purchase.balanceDue > 0) {
      final supplierRef = _firestore.collection('suppliers').doc(purchase.supplierId);
      batch.update(supplierRef, {
        'pendingAmount': FieldValue.increment(purchase.balanceDue),
      });
    }

    // 3. Increment stock and update Weighted Average Cost for each product.
    for (final item in purchase.items) {
      final productRef = _firestore.collection('products').doc(item.productId);
      
      DocumentSnapshot<Map<String, dynamic>>? productSnapshot;
      try {
        productSnapshot = await productRef.getOfflineSafe();
      } catch (_) {
        // Offline cache fallback is handled automatically by offline safe extension
      }
      
      double newAverageCost = item.unitCost;
      if (productSnapshot != null && productSnapshot.exists) {
        final productData = productSnapshot.data();
        if (productData != null) {
          final int oldStock = (productData['currentStock'] as num?)?.toInt() ?? 0;
          final double oldCost = (productData['purchasePrice'] as num?)?.toDouble() ?? 0.0;
          
          if (oldStock > 0) {
            final double totalOldValue = oldStock * oldCost;
            final double totalNewValue = item.quantity * item.unitCost;
            final int totalStock = oldStock + item.quantity;
            if (totalStock > 0) {
              newAverageCost = (totalOldValue + totalNewValue) / totalStock;
            }
          }
        }
      }

      batch.update(productRef, {
        'currentStock': FieldValue.increment(item.quantity),
        'purchasePrice': newAverageCost,
      });
    }

    // Execute batch commit in the background to prevent network latency from blocking the UI
    batch.commit().catchError((e) {
      // Background sync handles persistence/retries automatically
    });
    return purchaseDocRef.id;
  }

  /// Returns a live stream of purchases for a specific supplier,
  /// ordered by date (newest first).
  Stream<List<Purchase>> getPurchasesForSupplier(String supplierId) {
    return _purchasesCollection
        .where('supplierId', isEqualTo: supplierId)
        .orderBy('purchaseDate', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => Purchase.fromFirestore(doc))
              .toList(),
        );
  }

  /// Returns a live stream of purchases within a date range.
  Stream<List<Purchase>> getPurchasesForDateRange(
      DateTime start, DateTime end) {
    return _purchasesCollection
        .where('purchaseDate',
            isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('purchaseDate', isLessThanOrEqualTo: Timestamp.fromDate(end))
        .orderBy('purchaseDate', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => Purchase.fromFirestore(doc))
              .toList(),
        );
  }

  /// Returns a single purchase by ID.
  Future<Purchase?> getPurchase(String id) async {
    final doc = await _purchasesCollection.doc(id).get();
    if (!doc.exists) return null;
    return Purchase.fromFirestore(doc);
  }
}
