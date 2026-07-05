import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a payment received from a customer.
///
/// [saleId] is optional — for the operator's own reference, never required.
/// [createdBy] is required on every payments document (AGENTS.md constraint #6).
class Payment {
  final String id;
  final String customerId;
  final String? saleId;
  final double amount;
  final DateTime paymentDate;
  final String method;
  final String createdBy;
  final bool hasPendingWrites;

  const Payment({
    required this.id,
    required this.customerId,
    this.saleId,
    required this.amount,
    required this.paymentDate,
    this.method = 'cash',
    required this.createdBy,
    this.hasPendingWrites = false,
  });

  factory Payment.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return Payment(
      id: doc.id,
      customerId: data['customerId'] as String? ?? '',
      saleId: data['saleId'] as String?,
      amount: (data['amount'] as num?)?.toDouble() ?? 0,
      paymentDate:
          (data['paymentDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      method: data['method'] as String? ?? 'cash',
      createdBy: data['createdBy'] as String? ?? '',
      hasPendingWrites: doc.metadata.hasPendingWrites,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'customerId': customerId,
      'saleId': saleId,
      'amount': amount,
      'paymentDate': Timestamp.fromDate(paymentDate),
      'method': method,
      'createdBy': createdBy,
    };
  }
}
