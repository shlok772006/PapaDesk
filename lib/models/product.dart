import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a product in inventory.
///
/// [currentStock] is read-only from the app's perspective — it is only
/// updated via FieldValue.increment() in batched writes when a sale
/// (decrement) or purchase (increment) is recorded.
///
/// No barcode field in Phase 1 (AGENTS.md constraint #3).
class Product {
  final String id;
  final String name;
  final String category;
  final String supplierId;
  final double purchasePrice;
  final double sellingPrice;
  final int currentStock;
  final int minStock;
  final String? imageBase64; // Base64 Data URL for optional product image

  const Product({
    required this.id,
    required this.name,
    this.category = '',
    this.supplierId = '',
    required this.purchasePrice,
    required this.sellingPrice,
    this.currentStock = 0,
    this.minStock = 0,
    this.imageBase64,
  });

  /// Whether this product is below its minimum stock threshold.
  bool get isLowStock => currentStock <= minStock;

  /// Creates a Product from a Firestore document snapshot.
  factory Product.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return Product(
      id: doc.id,
      name: data['name'] as String? ?? '',
      category: data['category'] as String? ?? '',
      supplierId: data['supplierId'] as String? ?? '',
      purchasePrice: (data['purchasePrice'] as num?)?.toDouble() ?? 0,
      sellingPrice: (data['sellingPrice'] as num?)?.toDouble() ?? 0,
      currentStock: (data['currentStock'] as num?)?.toInt() ?? 0,
      minStock: (data['minStock'] as num?)?.toInt() ?? 0,
      imageBase64: data['imageBase64'] as String?,
    );
  }

  /// Converts to a Firestore-friendly map for creating a new product.
  /// Allows an initial [currentStock] value on creation — this is a
  /// one-time setup convenience for existing inventory, not a manual
  /// stock edit (which should go through Purchases).
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'category': category,
      'supplierId': supplierId,
      'purchasePrice': purchasePrice,
      'sellingPrice': sellingPrice,
      'currentStock': currentStock,
      'minStock': minStock,
      'imageBase64': imageBase64,
    };
  }

  /// Returns a map of only the editable fields.
  /// Used by updateProduct — never touches currentStock.
  Map<String, dynamic> toEditableMap() {
    return {
      'name': name,
      'category': category,
      'supplierId': supplierId,
      'purchasePrice': purchasePrice,
      'sellingPrice': sellingPrice,
      'minStock': minStock,
      'imageBase64': imageBase64,
    };
  }
}
