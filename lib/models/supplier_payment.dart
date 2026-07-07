import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a payment made to a supplier (vendor).
///
/// [createdBy] is required on every payment document (AGENTS.md constraint #6).
class SupplierPayment {
  final String id;
  final String supplierId;
  final double amount;
  final DateTime paymentDate;
  final String method; // 'cash', 'upi', 'net_banking', etc.
  final String createdBy;
  final bool hasPendingWrites;

  const SupplierPayment({
    required this.id,
    required this.supplierId,
    required this.amount,
    required this.paymentDate,
    this.method = 'cash',
    required this.createdBy,
    this.hasPendingWrites = false,
  });

  factory SupplierPayment.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return SupplierPayment(
      id: doc.id,
      supplierId: data['supplierId'] as String? ?? '',
      amount: (data['amount'] as num?)?.toDouble() ?? 0.0,
      paymentDate:
          (data['paymentDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      method: data['method'] as String? ?? 'cash',
      createdBy: data['createdBy'] as String? ?? 'anonymous',
      hasPendingWrites: doc.metadata.hasPendingWrites,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'supplierId': supplierId,
      'amount': amount,
      'paymentDate': Timestamp.fromDate(paymentDate),
      'method': method,
      'createdBy': createdBy,
    };
  }
}
