import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';

class BackupHelper {
  /// Recursively converts Firestore Timestamps to epoch milliseconds for JSON serialization.
  static dynamic _serializeValue(dynamic value) {
    if (value is Timestamp) {
      return value.millisecondsSinceEpoch;
    } else if (value is Map) {
      return value.map((k, v) => MapEntry(k, _serializeValue(v)));
    } else if (value is List) {
      return value.map((v) => _serializeValue(v)).toList();
    }
    return value;
  }

  /// Recursively converts epoch milliseconds back to Firestore Timestamps for fields matching date keys.
  static dynamic _deserializeValue(dynamic key, dynamic value) {
    if (value is int &&
        (key is String) &&
        (key.toLowerCase().contains('date') ||
            key.toLowerCase().contains('createdat') ||
            key.toLowerCase().contains('updatedat'))) {
      return Timestamp.fromMillisecondsSinceEpoch(value);
    } else if (value is Map) {
      return value.map((k, v) => MapEntry(k, _deserializeValue(k, v)));
    } else if (value is List) {
      return value.map((v) => _deserializeValue(key, v)).toList();
    }
    return value;
  }

  /// Generates a Base64-encoded backup code of all Firestore documents.
  static Future<String> generateBackupCode() async {
    final db = FirebaseFirestore.instance;

    Future<List<Map<String, dynamic>>> getCollectionData(String name) async {
      try {
        // Fetches from server if online, automatically falls back to cache if offline
        final snap = await db.collection(name).get();
        return snap.docs.map((doc) {
          final data = doc.data();
          data['id'] = doc.id; // Embed document ID so it can be restored exactly
          return _serializeValue(data) as Map<String, dynamic>;
        }).toList();
      } catch (_) {
        return [];
      }
    }

    final backupMap = {
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'customers': await getCollectionData('customers'),
      'products': await getCollectionData('products'),
      'sales': await getCollectionData('sales'),
      'payments': await getCollectionData('payments'),
      'purchases': await getCollectionData('purchases'),
      'suppliers': await getCollectionData('suppliers'),
    };

    final jsonStr = jsonEncode(backupMap);
    final bytes = utf8.encode(jsonStr);
    return base64Encode(bytes);
  }

  /// Restores collections in batch sets using local-first writes from decoded Base64 code.
  static Future<void> restoreBackupCode(String base64Code) async {
    final trimmed = base64Code.trim().replaceAll('\n', '').replaceAll('\r', '').replaceAll(' ', '');
    final bytes = base64Decode(trimmed);
    final jsonStr = utf8.decode(bytes);
    await restoreBackupJson(jsonStr);
  }

  /// Restores collections in batch sets from a raw JSON string.
  static Future<void> restoreBackupJson(String jsonStr) async {
    final Map<String, dynamic> backupMap = jsonDecode(jsonStr);

    if (backupMap['version'] != 1) {
      throw Exception('Invalid or unsupported backup code version');
    }

    final db = FirebaseFirestore.instance;

    Future<void> restoreCollection(String collectionName, List<dynamic> list) async {
      if (list.isEmpty) return;

      var batch = db.batch();
      var count = 0;

      for (final item in list) {
        final rawMap = Map<String, dynamic>.from(item as Map);
        final id = rawMap.remove('id') as String;

        // Deserialize date/timestamp fields recursively
        final data = rawMap.map((k, v) => MapEntry(k, _deserializeValue(k, v)));

        final docRef = db.collection(collectionName).doc(id);
        batch.set(docRef, data, SetOptions(merge: true));

        count++;
        if (count >= 400) {
          await batch.commit();
          batch = db.batch();
          count = 0;
        }
      }

      if (count > 0) {
        await batch.commit();
      }
    }

    // Restore collections
    await restoreCollection('customers', backupMap['customers'] ?? []);
    await restoreCollection('products', backupMap['products'] ?? []);
    await restoreCollection('suppliers', backupMap['suppliers'] ?? []);
    await restoreCollection('sales', backupMap['sales'] ?? []);
    await restoreCollection('payments', backupMap['payments'] ?? []);
    await restoreCollection('purchases', backupMap['purchases'] ?? []);
  }

  /// Exports the backup to a JSON file and opens the system share sheet.
  static Future<void> exportBackupToFile() async {
    final db = FirebaseFirestore.instance;

    Future<List<Map<String, dynamic>>> getCollectionData(String name) async {
      try {
        final snap = await db.collection(name).get();
        return snap.docs.map((doc) {
          final data = doc.data();
          data['id'] = doc.id;
          return _serializeValue(data) as Map<String, dynamic>;
        }).toList();
      } catch (_) {
        return [];
      }
    }

    final backupMap = {
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'customers': await getCollectionData('customers'),
      'products': await getCollectionData('products'),
      'sales': await getCollectionData('sales'),
      'payments': await getCollectionData('payments'),
      'purchases': await getCollectionData('purchases'),
      'suppliers': await getCollectionData('suppliers'),
    };

    final jsonStr = jsonEncode(backupMap);

    // Save to a temporary file
    final tempDir = await getTemporaryDirectory();
    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').replaceAll('.', '-');
    final file = File('${tempDir.path}/papadesk_backup_$timestamp.json');
    await file.writeAsString(jsonStr);

    // Share the file using share_plus
    await Share.shareXFiles(
      [XFile(file.path)],
      subject: 'PapaDesk Backup - ${DateTime.now().toString().split('.').first}',
    );
  }

  /// Opens the file picker to pick a JSON backup and restores it.
  static Future<void> restoreBackupFromFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );

    if (result == null || result.files.single.path == null) {
      throw Exception('No file selected');
    }

    final file = File(result.files.single.path!);
    final fileContent = await file.readAsString();
    final trimmed = fileContent.trim();

    String jsonStr;
    if (trimmed.startsWith('{')) {
      jsonStr = trimmed;
    } else {
      // Handle legacy base64-encoded backup code pasted into a file or similar format
      final cleanBase64 = trimmed.replaceAll('\n', '').replaceAll('\r', '').replaceAll(' ', '');
      final bytes = base64Decode(cleanBase64);
      jsonStr = utf8.decode(bytes);
    }

    await restoreBackupJson(jsonStr);
  }
}
