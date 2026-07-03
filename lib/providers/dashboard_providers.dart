import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'customer_providers.dart';
import 'product_providers.dart';
import 'sale_providers.dart';

class DashboardStats {
  final double todaysSales;
  final double totalPendingDues;
  final double stockValue;
  final int lowStockCount;
  final int totalCustomers;

  const DashboardStats({
    required this.todaysSales,
    required this.totalPendingDues,
    required this.stockValue,
    required this.lowStockCount,
    required this.totalCustomers,
  });
}

/// Computes the aggregate metrics for the Dashboard.
/// Watches customers, products, and today's sales streams.
final dashboardStatsProvider = Provider<AsyncValue<DashboardStats>>((ref) {
  final customersAsync = ref.watch(customersProvider);
  final productsAsync = ref.watch(productsProvider);
  final todaysSalesAsync = ref.watch(todaysSalesProvider);

  if (customersAsync.isLoading || productsAsync.isLoading || todaysSalesAsync.isLoading) {
    return const AsyncValue.loading();
  }
  if (customersAsync.hasError) {
    return AsyncValue.error(customersAsync.error!, customersAsync.stackTrace!);
  }
  if (productsAsync.hasError) {
    return AsyncValue.error(productsAsync.error!, productsAsync.stackTrace!);
  }
  if (todaysSalesAsync.hasError) {
    return AsyncValue.error(todaysSalesAsync.error!, todaysSalesAsync.stackTrace!);
  }

  final customers = customersAsync.value ?? [];
  final products = productsAsync.value ?? [];
  final todaysSales = todaysSalesAsync.value ?? [];

  // Calculate stats
  final todaysSalesTotal = todaysSales.fold<double>(0, (sum, sale) => sum + sale.totalAmount);
  final pendingDuesTotal = customers.fold<double>(0, (sum, cust) => sum + cust.pendingAmount);
  final inventoryValuation = products.fold<double>(0, (sum, prod) => sum + (prod.currentStock * prod.purchasePrice));
  final lowStockCounter = products.where((prod) => prod.isLowStock).length;

  return AsyncValue.data(DashboardStats(
    todaysSales: todaysSalesTotal,
    totalPendingDues: pendingDuesTotal,
    stockValue: inventoryValuation,
    lowStockCount: lowStockCounter,
    totalCustomers: customers.length,
  ));
});

/// Active tab notifier class.
class ActiveTabNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void setTab(int index) {
    state = index;
  }
}

/// Reactive provider to track the active bottom nav tab index.
/// 0 = Dashboard (Home), 1 = Sales, 2 = Payments, 3 = Ledger, 4 = Inventory
final activeTabProvider = NotifierProvider<ActiveTabNotifier, int>(() {
  return ActiveTabNotifier();
});
