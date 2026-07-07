import 'package:cloud_firestore/cloud_firestore.dart';

extension DocumentReferenceOfflineGet<T> on DocumentReference<T> {
  /// Safely gets the document, trying cache first for instant offline access,
  /// falling back to server if not cached or offline errors occur.
  Future<DocumentSnapshot<T>> getOfflineSafe() async {
    try {
      // Try to get from the local offline cache first (immediate, works offline)
      return await get(const GetOptions(source: Source.cache));
    } catch (_) {
      try {
        // Fall back to server if not cached or if caching is disabled
        return await get();
      } catch (innerError) {
        // If everything fails, try one more time from server (re-throws exception if still offline/error)
        rethrow;
      }
    }
  }
}
