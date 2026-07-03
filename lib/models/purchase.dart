import 'package:cloud_firestore/cloud_firestore.dart';

/// A single line item within a purchase (stock inward).
class PurchaseItem {
  final String productId;
  final int quantity;
  final double unitCost;

  const PurchaseItem({
    required this.productId,
    required this.quantity,
    required this.unitCost,
  });

  factory PurchaseItem.fromMap(Map<String, dynamic> map) {
    return PurchaseItem(
      productId: map['productId'] as String? ?? '',
      quantity: (map['quantity'] as num?)?.toInt() ?? 0,
      unitCost: (map['unitCost'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'quantity': quantity,
      'unitCost': unitCost,
    };
  }
}

/// Represents a purchase of stock from a supplier.
///
/// [createdBy] is required on every purchases document (AGENTS.md constraint #6).
class Purchase {
  final String id;
  final String supplierId;
  final DateTime purchaseDate;
  final List<PurchaseItem> items;
  final double totalCost;
  final String createdBy;

  const Purchase({
    required this.id,
    required this.supplierId,
    required this.purchaseDate,
    required this.items,
    required this.totalCost,
    required this.createdBy,
  });

  factory Purchase.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return Purchase(
      id: doc.id,
      supplierId: data['supplierId'] as String? ?? '',
      purchaseDate:
          (data['purchaseDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      items: (data['items'] as List<dynamic>?)
              ?.map(
                  (item) => PurchaseItem.fromMap(item as Map<String, dynamic>))
              .toList() ??
          [],
      totalCost: (data['totalCost'] as num?)?.toDouble() ?? 0,
      createdBy: data['createdBy'] as String? ?? '',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'supplierId': supplierId,
      'purchaseDate': Timestamp.fromDate(purchaseDate),
      'items': items.map((item) => item.toMap()).toList(),
      'totalCost': totalCost,
      'createdBy': createdBy,
    };
  }
}
