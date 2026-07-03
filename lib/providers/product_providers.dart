import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/product.dart';
import 'repository_providers.dart';

/// Live stream of all products, ordered by name.
/// Used by the Sale flow to pick products with current stock and price.
final productsProvider = StreamProvider<List<Product>>((ref) {
  final repo = ref.watch(productRepositoryProvider);
  return repo.getProducts();
});

/// Live stream of low-stock products.
/// Used by Dashboard for alerts.
final lowStockProductsProvider = StreamProvider<List<Product>>((ref) {
  final repo = ref.watch(productRepositoryProvider);
  return repo.getLowStockProducts();
});
