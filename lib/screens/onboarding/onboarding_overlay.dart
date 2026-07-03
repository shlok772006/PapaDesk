import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class OnboardingOverlay extends StatefulWidget {
  final VoidCallback onDismiss;

  const OnboardingOverlay({super.key, required this.onDismiss});

  @override
  State<OnboardingOverlay> createState() => _OnboardingOverlayState();
}

class _OnboardingOverlayState extends State<OnboardingOverlay> {
  int _currentIndex = 0;

  final List<_OnboardingPageData> _pages = const [
    _OnboardingPageData(
      title: 'Welcome to PapaDesk!',
      desc: 'A simple manager for tracking your shop sales, payments, and stock.',
      icon: Icons.storefront,
      color: Colors.indigo,
    ),
    _OnboardingPageData(
      title: 'Sales & Payments',
      desc: 'Use the Sales and Payments tabs to quickly record transactions in one click.',
      icon: Icons.monetization_on,
      color: Colors.green,
    ),
    _OnboardingPageData(
      title: 'Stock & Ledger',
      desc: 'See customer running balances in the Ledger and check product quantities in the Inventory.',
      icon: Icons.inventory_2,
      color: Colors.blue,
    ),
    _OnboardingPageData(
      title: 'Works 100% Offline',
      desc: 'Save sales even without a network. Everything saves locally and uploads automatically later.',
      icon: Icons.cloud_off,
      color: Colors.orange,
    ),
  ];

  Future<void> _finishOnboarding() async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? 'anonymous';
    // Save onboarded state on Firestore (works offline, queues locally)
    await FirebaseFirestore.instance.collection('users').doc(uid).set({
      'onboarded': true,
    }, SetOptions(merge: true));
    widget.onDismiss();
  }

  @override
  Widget build(BuildContext context) {
    final page = _pages[_currentIndex];
    final isLast = _currentIndex == _pages.length - 1;

    return Center(
      child: Card(
        margin: const EdgeInsets.all(24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        elevation: 24,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon Circle
              CircleAvatar(
                radius: 48,
                backgroundColor: page.color.withValues(alpha: 0.1),
                child: Icon(page.icon, size: 48, color: page.color),
              ),
              const SizedBox(height: 28),

              // Title
              Text(
                page.title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),

              // Description
              Text(
                page.desc,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 32),

              // Slide dots indicator
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_pages.length, (index) {
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: _currentIndex == index ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _currentIndex == index ? page.color : Colors.grey[300],
                      borderRadius: BorderRadius.circular(4),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 32),

              // Navigation Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Skip / Back button
                  TextButton(
                    onPressed: _currentIndex > 0
                        ? () => setState(() => _currentIndex--)
                        : _finishOnboarding,
                    child: Text(
                      _currentIndex > 0 ? 'Back' : 'Skip',
                      style: const TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  ),

                  // Next / Finish button
                  FilledButton(
                    onPressed: isLast ? _finishOnboarding : () => setState(() => _currentIndex++),
                    style: FilledButton.styleFrom(
                      backgroundColor: page.color,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    ),
                    child: Text(
                      isLast ? 'Get Started' : 'Next',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OnboardingPageData {
  final String title;
  final String desc;
  final IconData icon;
  final Color color;

  const _OnboardingPageData({
    required this.title,
    required this.desc,
    required this.icon,
    required this.color,
  });
}
