import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/dashboard_providers.dart';
import 'sales/sales_screen.dart';
import 'payments/payments_screen.dart';
import 'ledger/ledger_screen.dart';
import 'inventory/inventory_screen.dart';
import 'dashboard/dashboard_screen.dart';

import '../providers/auth_providers.dart';
import 'onboarding/onboarding_overlay.dart';

/// The main scaffold with bottom navigation bar.
/// Hosts the tab screens: Dashboard, Sales, Payments, Ledger, Inventory.
/// Navigation state is managed globally via [activeTabProvider].
class HomeShell extends ConsumerWidget {
  const HomeShell({super.key});

  final _screens = const [
    DashboardScreen(),
    SalesScreen(),
    PaymentsScreen(),
    LedgerScreen(),
    InventoryScreen(),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentIndex = ref.watch(activeTabProvider);
    final profileAsync = ref.watch(userProfileProvider);
    
    // Check if onboarding needs to be shown (default to false if loading/error)
    final showOnboarding = profileAsync.maybeWhen(
      data: (data) => data == null || !(data['onboarded'] as bool? ?? false),
      orElse: () => false,
    );

    final mainScaffold = Scaffold(
      body: IndexedStack(
        index: currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: (index) {
          ref.read(activeTabProvider.notifier).setTab(index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Sales',
          ),
          NavigationDestination(
            icon: Icon(Icons.payments_outlined),
            selectedIcon: Icon(Icons.payments),
            label: 'Payments',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_alt_outlined),
            selectedIcon: Icon(Icons.people_alt),
            label: 'Ledger',
          ),
          NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            selectedIcon: Icon(Icons.inventory_2),
            label: 'Inventory',
          ),
        ],
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        height: 70,
      ),
    );

    if (showOnboarding) {
      return Stack(
        children: [
          mainScaffold,
          // Transparent dark barrier
          ModalBarrier(
            color: Colors.black.withValues(alpha: 0.5),
            dismissible: false,
          ),
          OnboardingOverlay(
            onDismiss: () {
              // Dismiss trigger is handled reactively by the Firestore update stream
            },
          ),
        ],
      );
    }

    return mainScaffold;
  }
}
