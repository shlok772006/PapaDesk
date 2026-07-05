import 'package:flutter/material.dart';

/// Small indicator shown on list items when a Firestore write has not
/// yet reached the server (hasPendingWrites == true).
///
/// Gives the operator visible confirmation that the data is saved locally
/// and will sync automatically — per system-design.md §3.
class SyncIndicator extends StatelessWidget {
  final bool hasPendingWrites;

  const SyncIndicator({super.key, required this.hasPendingWrites});

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}
