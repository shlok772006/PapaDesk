import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import '../../providers/auth_providers.dart';
import '../../providers/customer_providers.dart';
import '../../providers/product_providers.dart';
import '../../providers/supplier_providers.dart';
import '../../providers/sale_providers.dart';
import '../../providers/payment_providers.dart';
import '../../utils/backup_helper.dart';
import '../../utils/excel_export_helper.dart';
import 'package:intl/intl.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  
  bool _saving = false;
  late final DocumentReference<Map<String, dynamic>> _userDocRef;

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    _userDocRef = FirebaseFirestore.instance.collection('users').doc(user?.uid ?? 'anonymous');
    _loadBusinessInfo();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _loadBusinessInfo() async {
    try {
      final snap = await _userDocRef.get();
      if (snap.exists && snap.data() != null) {
        final data = snap.data()!;
        _nameController.text = data['businessName'] as String? ?? '';
        _phoneController.text = data['businessPhone'] as String? ?? '';
      } else {
        _nameController.text = 'PapaDesk Accessories';
        _phoneController.text = FirebaseAuth.instance.currentUser?.phoneNumber ?? '';
      }
    } catch (e) {
      // Fallback defaults
      _nameController.text = 'PapaDesk Accessories';
      _phoneController.text = FirebaseAuth.instance.currentUser?.phoneNumber ?? '';
    }
  }

  Future<void> _saveBusinessInfo() async {
    setState(() => _saving = true);

    try {
      _userDocRef.set({
        'businessName': _nameController.text.trim(),
        'businessPhone': _phoneController.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true)).catchError((e) {});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Settings saved ✓'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _exportBackup() async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('Generating backup file...'),
            ],
          ),
        ),
      );
      
      await BackupHelper.exportBackupToFile();
      if (!mounted) return;
      
      Navigator.pop(context); // close loader
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Backup file exported successfully ✓'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 4),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // close loader
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export failed: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _importBackup() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Restore Database?', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text(
          'Selecting a backup file will restore historical sales, customers, and inventory configurations.\n\n'
          'Warning: This may overwrite existing data if the document IDs match.',
          style: TextStyle(fontSize: 15),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogCtx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.orange[800]),
            child: const Text('Choose Backup File'),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    if (!mounted) return;

    try {
      // 1. Trigger file picker first to keep loader from obscuring file dialog
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result == null || result.files.single.path == null) {
        return; // User cancelled, do nothing
      }

      if (!mounted) return;

      // 2. Show loading spinner
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('Restoring database cache...'),
            ],
          ),
        ),
      );

      // 3. Read and parse file
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

      await BackupHelper.restoreBackupJson(jsonStr);
      if (!mounted) return;
      
      // Force refresh all stream providers with restored cache records
      ref.invalidate(customersProvider);
      ref.invalidate(productsProvider);
      ref.invalidate(suppliersProvider);
      ref.invalidate(todaysSalesProvider);
      ref.invalidate(recentTransactionsProvider);

      Navigator.pop(context); // close loader
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Database restored successfully! ✓ All data loaded.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // close loader if it was shown
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Restore failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _exportExcel() async {
    // Default to the current month
    int selectedYear = DateTime.now().year;
    int selectedMonth = DateTime.now().month;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            final monthName = DateFormat('MMMM yyyy').format(DateTime(selectedYear, selectedMonth));
            return AlertDialog(
              title: const Text('Export Monthly Excel', style: TextStyle(fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Pick a month to export all sales, payments, purchases, customers, products, and suppliers into one Excel file.',
                    style: TextStyle(fontSize: 15),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chevron_left, size: 32),
                        onPressed: () {
                          setDialogState(() {
                            if (selectedMonth == 1) {
                              selectedMonth = 12;
                              selectedYear--;
                            } else {
                              selectedMonth--;
                            }
                          });
                        },
                      ),
                      const SizedBox(width: 8),
                      Text(
                        monthName,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.chevron_right, size: 32),
                        onPressed: () {
                          // Don't allow going past current month
                          final now = DateTime.now();
                          if (selectedYear < now.year || (selectedYear == now.year && selectedMonth < now.month)) {
                            setDialogState(() {
                              if (selectedMonth == 12) {
                                selectedMonth = 1;
                                selectedYear++;
                              } else {
                                selectedMonth++;
                              }
                            });
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx, false),
                  child: const Text('Cancel'),
                ),
                FilledButton.icon(
                  onPressed: () => Navigator.pop(dialogCtx, true),
                  icon: const Icon(Icons.download),
                  label: const Text('Export'),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed != true || !mounted) return;

    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('Generating Excel file...'),
          ],
        ),
      ),
    );

    try {
      await ExcelExportHelper.exportMonthlyExcel(
        year: selectedYear,
        month: selectedMonth,
      );
      if (!mounted) return;
      Navigator.pop(context); // close loader
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Excel file exported successfully ✓'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 4),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // close loader
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export failed: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Settings',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          // User profile/Account info
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                    child: Icon(
                      Icons.person,
                      size: 32,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Operator Account',
                          style: TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          user?.phoneNumber ?? 'No Phone Number',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),

          // Business Information Form
          const Text(
            'Business Profile',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey),
          ),
          const SizedBox(height: 12),
          
          TextField(
            controller: _nameController,
            decoration: InputDecoration(
              labelText: 'Business Name',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              prefixIcon: const Icon(Icons.store),
            ),
            style: const TextStyle(fontSize: 18),
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 16),
          
          TextField(
            controller: _phoneController,
            decoration: InputDecoration(
              labelText: 'Business Contact Number',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              prefixIcon: const Icon(Icons.phone),
            ),
            style: const TextStyle(fontSize: 18),
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 16),
          
          SizedBox(
            height: 52,
            child: OutlinedButton.icon(
              onPressed: _saving ? null : _saveBusinessInfo,
              icon: _saving
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.save),
              label: const Text('Save Business Info', style: TextStyle(fontSize: 16)),
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 32),

          // Preferences section
          const Text(
            'Preferences',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey),
          ),
          const SizedBox(height: 12),
          
          ListTile(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.grey[200]!),
            ),
            leading: Icon(
              themeMode == ThemeMode.dark ? Icons.dark_mode : Icons.light_mode,
              color: Theme.of(context).colorScheme.primary,
            ),
            title: const Text('Dark Theme Mode', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            trailing: Switch(
              value: themeMode == ThemeMode.dark,
              onChanged: (val) {
                ref.read(themeModeProvider.notifier).toggleTheme();
              },
            ),
          ),
          
          const SizedBox(height: 32),

          // Data Backup & Recovery section
          const Text(
            'Data Backup & Recovery',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey),
          ),
          const SizedBox(height: 12),

          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.grey[200]!),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: Icon(Icons.backup, color: Theme.of(context).colorScheme.primary),
                  title: const Text('Export Backup File', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  subtitle: const Text('Exports your database as a file to share via WhatsApp, Email, etc.', style: TextStyle(fontSize: 13)),
                  onTap: _exportBackup,
                  trailing: const Icon(Icons.chevron_right),
                ),
                const Divider(height: 1, indent: 56),
                ListTile(
                  leading: Icon(Icons.settings_backup_restore, color: Colors.orange[800]),
                  title: const Text('Restore Backup File', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  subtitle: const Text('Select a backup file from your device to restore your database.', style: TextStyle(fontSize: 13)),
                  onTap: _importBackup,
                  trailing: const Icon(Icons.chevron_right),
                ),
                const Divider(height: 1, indent: 56),
                ListTile(
                  leading: Icon(Icons.table_chart, color: Colors.green[700]),
                  title: const Text('Export Monthly Excel', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  subtitle: const Text('Pick a month and export all data as an Excel file.', style: TextStyle(fontSize: 13)),
                  onTap: _exportExcel,
                  trailing: const Icon(Icons.chevron_right),
                ),
              ],
            ),
          ),
          
        ],
      ),
    );
  }
}
