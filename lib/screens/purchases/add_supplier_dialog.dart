import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/supplier.dart';
import '../../providers/repository_providers.dart';

/// Quick dialog to add a new supplier inline during the purchase flow.
class AddSupplierDialog extends ConsumerStatefulWidget {
  const AddSupplierDialog({super.key});

  @override
  ConsumerState<AddSupplierDialog> createState() => _AddSupplierDialogState();
}

class _AddSupplierDialogState extends ConsumerState<AddSupplierDialog> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter the supplier name')),
      );
      return;
    }

    setState(() => _saving = true);

    final repo = ref.read(supplierRepositoryProvider);
    final newSupplier = Supplier(
      id: '', // Set by Firestore
      name: name,
      phone: _phoneController.text.trim(),
    );

    final id = await repo.addSupplier(newSupplier);

    if (mounted) {
      Navigator.of(context).pop(
        Supplier(
          id: id,
          name: name,
          phone: _phoneController.text.trim(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(
        'New Supplier',
        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Supplier Name *',
              hintText: 'Enter name',
              prefixIcon: Icon(Icons.local_shipping),
            ),
            style: const TextStyle(fontSize: 18),
            textCapitalization: TextCapitalization.words,
            autofocus: true,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _phoneController,
            decoration: const InputDecoration(
              labelText: 'Phone (optional)',
              hintText: 'Phone number',
              prefixIcon: Icon(Icons.phone),
            ),
            style: const TextStyle(fontSize: 18),
            keyboardType: TextInputType.phone,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel', style: TextStyle(fontSize: 16)),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Add', style: TextStyle(fontSize: 16)),
        ),
      ],
    );
  }
}
