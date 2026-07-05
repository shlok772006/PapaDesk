import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a supplier / vendor where products are purchased from.
class Supplier {
  final String id;
  final String name;
  final String phone;

  final bool hasPendingWrites;

  const Supplier({
    required this.id,
    required this.name,
    this.phone = '',
    this.hasPendingWrites = false,
  });

  factory Supplier.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return Supplier(
      id: doc.id,
      name: data['name'] as String? ?? '',
      phone: data['phone'] as String? ?? '',
      hasPendingWrites: doc.metadata.hasPendingWrites,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'phone': phone,
    };
  }
}
