import 'package:cloud_firestore/cloud_firestore.dart';

/// A single line item within a sale.
///
/// [unitPrice] defaults to the product's sellingPrice but can be adjusted
/// per-sale by the operator (e.g., for a negotiated price). This replaces
/// the need for a separate discount field.
class SaleItem {
  final String productId;
  final String productName;
  final int quantity;
  final double unitPrice;
  final double subtotal;

  const SaleItem({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    required this.subtotal,
  });

  factory SaleItem.fromMap(Map<String, dynamic> map) {
    return SaleItem(
      productId: map['productId'] as String? ?? '',
      productName: map['productName'] as String? ?? '',
      quantity: (map['quantity'] as num?)?.toInt() ?? 0,
      unitPrice: (map['unitPrice'] as num?)?.toDouble() ?? 0,
      subtotal: (map['subtotal'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'productName': productName,
      'quantity': quantity,
      'unitPrice': unitPrice,
      'subtotal': subtotal,
    };
  }
}

/// Represents a sale transaction to a customer.
///
/// No discount field — the operator adjusts the unitPrice on individual
/// items if needed. This keeps the sale flow simpler (fewer fields).
///
/// [createdBy] is required on every sales document (AGENTS.md constraint #6).
class Sale {
  final String id;
  final String customerId;
  final DateTime saleDate;
  final List<SaleItem> items;
  final double totalAmount;
  final double paidAmount;
  final String createdBy;
  final bool hasPendingWrites;

  const Sale({
    required this.id,
    required this.customerId,
    required this.saleDate,
    required this.items,
    required this.totalAmount,
    required this.paidAmount,
    required this.createdBy,
    this.hasPendingWrites = false,
  });

  /// The remaining balance the customer owes for this sale.
  double get balanceDue => totalAmount - paidAmount;

  factory Sale.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return Sale(
      id: doc.id,
      customerId: data['customerId'] as String? ?? '',
      saleDate: (data['saleDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      items: (data['items'] as List<dynamic>?)
              ?.map((item) => SaleItem.fromMap(item as Map<String, dynamic>))
              .toList() ??
          [],
      totalAmount: (data['totalAmount'] as num?)?.toDouble() ?? 0,
      paidAmount: (data['paidAmount'] as num?)?.toDouble() ?? 0,
      createdBy: data['createdBy'] as String? ?? '',
      hasPendingWrites: doc.metadata.hasPendingWrites,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'customerId': customerId,
      'saleDate': Timestamp.fromDate(saleDate),
      'items': items.map((item) => item.toMap()).toList(),
      'totalAmount': totalAmount,
      'paidAmount': paidAmount,
      'createdBy': createdBy,
    };
  }
}
