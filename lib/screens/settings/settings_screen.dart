import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import '../../providers/auth_providers.dart';
import '../../utils/backup_helper.dart';

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
              Text('Generating backup code...'),
            ],
          ),
        ),
      );
      
      final code = await BackupHelper.generateBackupCode();
      if (!mounted) return;
      
      Navigator.pop(context); // close loader
      await Clipboard.setData(ClipboardData(text: code));
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Backup code copied to clipboard ✓ Share it via WhatsApp/Email to save it.'),
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
    final controller = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Restore Database?', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Pasting a backup code will restore historical sales, customers, and inventory configurations.\n\n'
              'Warning: This may overwrite existing data if the IDs match.',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              maxLines: 5,
              decoration: InputDecoration(
                hintText: 'Paste the backup code here...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (controller.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please paste a backup code'), backgroundColor: Colors.red),
                );
                return;
              }
              Navigator.pop(dialogCtx, true);
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.orange[800]),
            child: const Text('Restore'),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    if (!mounted) return;

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

    try {
      await BackupHelper.restoreBackupCode(controller.text);
      if (!mounted) return;
      Navigator.pop(context); // close loader
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Database restored successfully! ✓ All data loaded.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // close loader
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Restore failed: Invalid backup code format.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Logout'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await FirebaseAuth.instance.signOut();
      if (mounted) {
        Navigator.of(context).pop(); // Back to dashboard (auth listener will reroute to login)
      }
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
                  title: const Text('Export Backup Code', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  subtitle: const Text('Copies your offline database text code to the clipboard.', style: TextStyle(fontSize: 13)),
                  onTap: _exportBackup,
                  trailing: const Icon(Icons.chevron_right),
                ),
                const Divider(height: 1, indent: 56),
                ListTile(
                  leading: Icon(Icons.settings_backup_restore, color: Colors.orange[800]),
                  title: const Text('Restore Backup Code', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  subtitle: const Text('Pasts a backup code to restore your local database.', style: TextStyle(fontSize: 13)),
                  onTap: _importBackup,
                  trailing: const Icon(Icons.chevron_right),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 48),

          // Log out button
          SizedBox(
            height: 56,
            child: OutlinedButton.icon(
              onPressed: _logout,
              icon: const Icon(Icons.logout, color: Colors.red),
              label: const Text(
                'Log Out / Sign Out',
                style: TextStyle(color: Colors.red, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.red),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
