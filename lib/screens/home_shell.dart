import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/dashboard_providers.dart';
import 'sales/sales_screen.dart';
import 'payments/payments_screen.dart';
import 'ledger/ledger_screen.dart';
import 'inventory/inventory_screen.dart';
import 'dashboard/dashboard_screen.dart';

import 'package:firebase_auth/firebase_auth.dart';
import '../providers/auth_providers.dart';
import 'onboarding/onboarding_overlay.dart';

/// The main scaffold with bottom navigation bar.
/// Hosts the tab screens: Dashboard, Sales, Payments, Ledger, Inventory.
/// Navigation state is managed globally via [activeTabProvider].
class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  /// Local flag so onboarding dismisses instantly without waiting for Firestore sync (H8 fix).
  bool _onboardingDismissed = false;

  @override
  void initState() {
    super.initState();
    // Silent anonymous auth in the background to ensure Firestore rules are satisfied
    _initSilentAuth();
  }

  Future<void> _initSilentAuth() async {
    if (FirebaseAuth.instance.currentUser == null) {
      try {
        await FirebaseAuth.instance.signInAnonymously();
      } catch (e) {
        debugPrint('Silent anonymous sign-in failed: $e');
      }
    }
  }

  final _screens = const [
    DashboardScreen(),
    SalesScreen(),
    PaymentsScreen(),
    LedgerScreen(),
    InventoryScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final currentIndex = ref.watch(activeTabProvider);
    final profileAsync = ref.watch(userProfileProvider);
    
    // Check if onboarding needs to be shown (default to false if loading/error)
    final showOnboarding = !_onboardingDismissed && profileAsync.maybeWhen(
      data: (data) => data == null || !(data['onboarded'] as bool? ?? false),
      orElse: () => false,
    );

    final mainScaffold = Scaffold(
      body: IndexedStack(
        index: currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.transparent,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 24,
              offset: const Offset(0, -8),
            ),
          ],
        ),
        padding: const EdgeInsets.only(left: 16, right: 16, bottom: 20),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: NavigationBar(
            selectedIndex: currentIndex,
            onDestinationSelected: (index) {
              ref.read(activeTabProvider.notifier).setTab(index);
            },
            destinations: [
              NavigationDestination(
                icon: AnimatedScale(
                  scale: currentIndex == 0 ? 1.2 : 1.0,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutBack,
                  child: const Icon(Icons.home_outlined),
                ),
                selectedIcon: AnimatedScale(
                  scale: currentIndex == 0 ? 1.2 : 1.0,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutBack,
                  child: const Icon(Icons.home),
                ),
                label: 'Home',
              ),
              NavigationDestination(
                icon: AnimatedScale(
                  scale: currentIndex == 1 ? 1.2 : 1.0,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutBack,
                  child: const Icon(Icons.receipt_long_outlined),
                ),
                selectedIcon: AnimatedScale(
                  scale: currentIndex == 1 ? 1.2 : 1.0,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutBack,
                  child: const Icon(Icons.receipt_long),
                ),
                label: 'Sales',
              ),
              NavigationDestination(
                icon: AnimatedScale(
                  scale: currentIndex == 2 ? 1.2 : 1.0,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutBack,
                  child: const Icon(Icons.payments_outlined),
                ),
                selectedIcon: AnimatedScale(
                  scale: currentIndex == 2 ? 1.2 : 1.0,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutBack,
                  child: const Icon(Icons.payments),
                ),
                label: 'Payments',
              ),
              NavigationDestination(
                icon: AnimatedScale(
                  scale: currentIndex == 3 ? 1.2 : 1.0,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutBack,
                  child: const Icon(Icons.people_alt_outlined),
                ),
                selectedIcon: AnimatedScale(
                  scale: currentIndex == 3 ? 1.2 : 1.0,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutBack,
                  child: const Icon(Icons.people_alt),
                ),
                label: 'Ledger',
              ),
              NavigationDestination(
                icon: AnimatedScale(
                  scale: currentIndex == 4 ? 1.2 : 1.0,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutBack,
                  child: const Icon(Icons.inventory_2_outlined),
                ),
                selectedIcon: AnimatedScale(
                  scale: currentIndex == 4 ? 1.2 : 1.0,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutBack,
                  child: const Icon(Icons.inventory_2),
                ),
                label: 'Inventory',
              ),
            ],
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            height: 72,
            elevation: 0,
            backgroundColor: Theme.of(context).cardTheme.color,
            surfaceTintColor: Colors.transparent,
          ),
        ),
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
              // Dismiss immediately via local state — Firestore write is fire-and-forget
              setState(() => _onboardingDismissed = true);
            },
          ),
        ],
      );
    }

    return mainScaffold;
  }
}
