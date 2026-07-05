import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a customer of the business.
///
/// [totalPurchases] and [pendingAmount] are read-only from the app's
/// perspective — they are never set directly, only updated via
/// FieldValue.increment() in batched writes (see SaleRepository,
/// PaymentRepository).
class Customer {
  final String id;
  final String name;
  final String phone;
  final String address;
  final double totalPurchases;
  final double pendingAmount;
  final DateTime createdAt;
  final bool hasPendingWrites;

  const Customer({
    required this.id,
    required this.name,
    required this.phone,
    this.address = '',
    this.totalPurchases = 0,
    this.pendingAmount = 0,
    required this.createdAt,
    this.hasPendingWrites = false,
  });

  /// Creates a Customer from a Firestore document snapshot.
  factory Customer.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return Customer(
      id: doc.id,
      name: data['name'] as String? ?? '',
      phone: data['phone'] as String? ?? '',
      address: data['address'] as String? ?? '',
      totalPurchases: (data['totalPurchases'] as num?)?.toDouble() ?? 0,
      pendingAmount: (data['pendingAmount'] as num?)?.toDouble() ?? 0,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      hasPendingWrites: doc.metadata.hasPendingWrites,
    );
  }

  /// Converts to a Firestore-friendly map for creating a new customer.
  /// Does NOT include totalPurchases or pendingAmount — those start at 0
  /// and are only ever changed via FieldValue.increment().
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'phone': phone,
      'address': address,
      'totalPurchases': 0,
      'pendingAmount': 0,
      'createdAt': Timestamp.fromDate(DateTime.now()), // Device clock — works offline (H7 fix)
    };
  }

  /// Returns a map of only the editable fields (name, phone, address).
  /// Used by updateCustomer — never touches aggregate fields.
  Map<String, dynamic> toEditableMap() {
    return {
      'name': name,
      'phone': phone,
      'address': address,
    };
  }
}
