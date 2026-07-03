import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../models/customer.dart';
import '../../models/payment.dart';
import '../../providers/repository_providers.dart';
import '../../widgets/customer_selector.dart';

/// New Payment flow:
/// 1. Select customer (shows pending balance)
/// 2. Enter amount + pick method (Cash / UPI / Bank Transfer)
/// 3. Save
class NewPaymentScreen extends ConsumerStatefulWidget {
  const NewPaymentScreen({super.key});

  @override
  ConsumerState<NewPaymentScreen> createState() => _NewPaymentScreenState();
}

class _NewPaymentScreenState extends ConsumerState<NewPaymentScreen> {
  Customer? _selectedCustomer;
  final _amountController = TextEditingController();
  String _method = 'Cash';
  bool _saving = false;

  final _currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹');

  static const _methods = ['Cash', 'UPI', 'Bank Transfer'];

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _savePayment() async {
    final amountText = _amountController.text.trim();
    final amount = double.tryParse(amountText);

    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid amount'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _saving = true);

    final userId = ref.read(currentUserIdProvider);
    final payment = Payment(
      id: '',
      customerId: _selectedCustomer!.id,
      amount: amount,
      paymentDate: DateTime.now(),
      method: _method.toLowerCase(),
      createdBy: userId,
    );

    try {
      await ref.read(paymentRepositoryProvider).recordPayment(payment);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment saved ✓'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Step 1: Customer selection
    if (_selectedCustomer == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Select Customer',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        ),
        body: CustomerSelector(
          onSelected: (customer) {
            setState(() => _selectedCustomer = customer);
          },
        ),
      );
    }

    // Step 2: Enter payment details
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Payment ← ${_selectedCustomer!.name}',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            onPressed: () => setState(() => _selectedCustomer = null),
            icon: const Icon(Icons.swap_horiz),
            tooltip: 'Change customer',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Pending balance display
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _selectedCustomer!.pendingAmount > 0
                    ? Colors.red[50]
                    : Colors.green[50],
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Text(
                    'Pending Balance',
                    style: TextStyle(
                      fontSize: 14,
                      color: _selectedCustomer!.pendingAmount > 0
                          ? Colors.red[400]
                          : Colors.green[400],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _currencyFormat.format(_selectedCustomer!.pendingAmount),
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: _selectedCustomer!.pendingAmount > 0
                          ? Colors.red[700]
                          : Colors.green[700],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Amount input
            TextField(
              controller: _amountController,
              decoration: InputDecoration(
                labelText: 'Amount Received',
                prefixText: '₹ ',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 20,
                ),
              ),
              style: const TextStyle(fontSize: 24),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
            ),
            const SizedBox(height: 24),

            // Payment method picker
            const Text(
              'Payment Method',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            Row(
              children: _methods.map((method) {
                final selected = _method == method;
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      right: method != _methods.last ? 8 : 0,
                    ),
                    child: ChoiceChip(
                      label: SizedBox(
                        width: double.infinity,
                        child: Text(
                          method,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: selected
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                      selected: selected,
                      onSelected: (_) => setState(() => _method = method),
                      showCheckmark: false,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                );
              }).toList(),
            ),

            const Spacer(),

            // Save button
            SizedBox(
              height: 56,
              child: FilledButton.icon(
                onPressed: _saving ? null : _savePayment,
                icon: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.check, size: 24),
                label: Text(
                  _saving ? 'Saving...' : 'Save Payment',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
