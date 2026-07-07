import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/product.dart';
import 'repository_providers.dart';

/// Live stream of active products, ordered by name.
/// Excludes one-off/second-hand items that have been sold out.
final productsProvider = StreamProvider<List<Product>>((ref) {
  final repo = ref.watch(productRepositoryProvider);
  return repo.getProducts().map(
        (list) => list.where((p) => !(p.isOneOff && p.currentStock <= 0)).toList(),
      );
});

/// Live stream of low-stock products.
/// Used by Dashboard for alerts.
final lowStockProductsProvider = StreamProvider<List<Product>>((ref) {
  final repo = ref.watch(productRepositoryProvider);
  return repo.getLowStockProducts();
});

/// Provider that extracts unique non-empty category names from the products catalog.
final categoriesProvider = Provider<List<String>>((ref) {
  final products = ref.watch(productsProvider).value ?? [];
  final categories = products
      .map((p) => p.category.trim())
      .where((c) => c.isNotEmpty)
      .toSet()
      .toList();
  categories.sort();
  return categories;
});
