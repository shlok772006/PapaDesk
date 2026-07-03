import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'auth_providers.dart';

/// Provides a boolean representing whether the authenticated user has an 'admin' role claim.
/// Uses getIdTokenResult(true) to force-refresh claims and catch changes.
final isAdminProvider = FutureProvider<bool>((ref) async {
  final authState = ref.watch(authStateProvider);
  final user = authState.value;
  if (user == null) return false;
  
  try {
    final idTokenResult = await user.getIdTokenResult(true);
    final role = idTokenResult.claims?['role'] as String?;
    return role == 'admin';
  } catch (_) {
    return false;
  }
});
