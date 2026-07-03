import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/customer.dart';
import '../../providers/repository_providers.dart';

/// Quick dialog to add a new customer inline during the sale flow.
/// Returns the newly created [Customer] so it's immediately selected.
class AddCustomerDialog extends ConsumerStatefulWidget {
  const AddCustomerDialog({super.key});

  @override
  ConsumerState<AddCustomerDialog> createState() => _AddCustomerDialogState();
}

class _AddCustomerDialogState extends ConsumerState<AddCustomerDialog> {
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
        const SnackBar(content: Text('Please enter the customer name')),
      );
      return;
    }

    setState(() => _saving = true);

    final repo = ref.read(customerRepositoryProvider);
    final newCustomer = Customer(
      id: '', // Will be set by Firestore
      name: name,
      phone: _phoneController.text.trim(),
      createdAt: DateTime.now(),
    );

    final id = await repo.addCustomer(newCustomer);

    if (mounted) {
      Navigator.of(context).pop(
        Customer(
          id: id,
          name: name,
          phone: _phoneController.text.trim(),
          createdAt: DateTime.now(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(
        'New Customer',
        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Name',
              hintText: 'Customer name',
              prefixIcon: Icon(Icons.person),
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
