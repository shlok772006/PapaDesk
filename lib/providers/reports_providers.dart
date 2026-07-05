import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'repository_providers.dart';
import 'product_providers.dart';

class ReportData {
  final double totalRevenue;
  final double totalProfit;
  final List<TopProductEntry> topProducts;

  const ReportData({
    required this.totalRevenue,
    required this.totalProfit,
    required this.topProducts,
  });
}

class TopProductEntry {
  final String name;
  final int quantity;
  final double revenue;

  const TopProductEntry({
    required this.name,
    required this.quantity,
    required this.revenue,
  });
}

/// Stream provider for fetching and aggregating reports data in a date range.
final reportsProvider = StreamProvider.family<ReportData, DateTimeRange>((ref, range) {
  final salesRepo = ref.watch(saleRepositoryProvider);
  final productsAsync = ref.watch(productsProvider);

  // Stream of sales in range
  final salesStream = salesRepo.getSalesForDateRange(range.start, range.end);

  return salesStream.map((sales) {
    final products = productsAsync.value ?? [];
    
    // Create product lookup map for purchase price calculation
    final productMap = {for (var p in products) p.id: p};

    double revenueSum = 0;
    double profitSum = 0;
    final Map<String, _ProductAggregator> itemAggregates = {};

    for (final sale in sales) {
      revenueSum += sale.totalAmount;

      for (final item in sale.items) {
        final product = productMap[item.productId];
        // Use historic cost recorded on item, fallback to live product price for legacy sales
        final purchasePrice = item.purchasePrice > 0 
            ? item.purchasePrice 
            : (product?.purchasePrice ?? 0.0);
        
        // Profit per item = (sellingPrice - purchasePrice) * quantity
        final itemProfit = (item.unitPrice - purchasePrice) * item.quantity;
        profitSum += itemProfit;

        // Aggregate top selling products
        itemAggregates.update(
          item.productName,
          (val) => val..quantity += item.quantity..revenue += item.subtotal,
          ifAbsent: () => _ProductAggregator(
            name: item.productName,
            quantity: item.quantity,
            revenue: item.subtotal,
          ),
        );
      }
    }

    // Sort top products by quantity sold
    final topProducts = itemAggregates.values
        .map((agg) => TopProductEntry(
              name: agg.name,
              quantity: agg.quantity,
              revenue: agg.revenue,
            ))
        .toList()
      ..sort((a, b) => b.quantity.compareTo(a.quantity));

    return ReportData(
      totalRevenue: revenueSum,
      totalProfit: profitSum,
      topProducts: topProducts.take(5).toList(), // top 5
    );
  });
});

class _ProductAggregator {
  final String name;
  int quantity;
  double revenue;

  _ProductAggregator({
    required this.name,
    required this.quantity,
    required this.revenue,
  });
}
