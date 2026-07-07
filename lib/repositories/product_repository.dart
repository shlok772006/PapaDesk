import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/product.dart';
import '../utils/offline_extension.dart';

/// Repository for the `products` collection.
///
/// currentStock is NEVER written directly from this class after creation —
/// it is only updated via FieldValue.increment() in SaleRepository
/// (decrement) and PurchaseRepository (increment).
class ProductRepository {
  final FirebaseFirestore _firestore;
  late final CollectionReference<Map<String, dynamic>> _collection;

  ProductRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance {
    _collection = _firestore.collection('products');
  }

  /// Creates a new product. Allows an initial currentStock value —
  /// this is a one-time setup convenience for existing inventory.
  Future<String> addProduct(Product product) async {
    final docRef = _collection.doc();
    docRef.set(product.toFirestore()).catchError((e) {});
    return docRef.id;
  }

  /// Returns a single product by ID.
  Future<Product?> getProduct(String id) async {
    final doc = await _collection.doc(id).getOfflineSafe();
    if (!doc.exists) return null;
    return Product.fromFirestore(doc);
  }

  /// Returns a live stream of all products, ordered by name.
  Stream<List<Product>> getProducts() {
    return _collection.orderBy('name').snapshots().map(
          (snapshot) => snapshot.docs
              .map((doc) => Product.fromFirestore(doc))
              .toList(),
        );
  }

  /// Returns a live stream of products below their minimum stock threshold.
  Stream<List<Product>> getLowStockProducts() {
    // Firestore doesn't support comparing two fields in a query,
    // so we filter client-side after fetching all products.
    // At this business's scale (hundreds of products, not thousands),
    // this is perfectly fine.
    return _collection.snapshots().map(
          (snapshot) => snapshot.docs
              .map((doc) => Product.fromFirestore(doc))
              .where((product) => product.isLowStock)
              .toList(),
        );
  }

  /// Updates only the editable fields (name, price, category, etc.).
  /// Never touches currentStock.
  Future<void> updateProduct(String id, Map<String, dynamic> fields) async {
    // Safety: strip out currentStock if accidentally included.
    fields.remove('currentStock');
    _collection.doc(id).update(fields).catchError((e) {});
  }

  /// Deletes a product.
  Future<void> deleteProduct(String id) async {
    _collection.doc(id).delete().catchError((e) {});
  }


  /// Returns a DocumentReference for use in batched writes
  /// (e.g., SaleRepository needs this to decrement currentStock).
  DocumentReference<Map<String, dynamic>> docRef(String id) {
    return _collection.doc(id);
  }
}
