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
    if (!hasPendingWrites) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.orange[50],
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.orange[700],
            ),
          ),
          const SizedBox(width: 6),
          Text(
            'Saving...',
            style: TextStyle(
              fontSize: 12,
              color: Colors.orange[700],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
