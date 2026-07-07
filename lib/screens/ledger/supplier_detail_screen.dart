import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import '../../models/supplier.dart';
import '../../models/purchase.dart';
import '../../models/supplier_payment.dart';
import '../../providers/supplier_providers.dart';
import '../../providers/repository_providers.dart';
import '../../providers/role_provider.dart';
import '../../utils/invoice_helper.dart';
import '../../widgets/sync_indicator.dart';

class SupplierDetailScreen extends ConsumerWidget {
  final String supplierId;

  const SupplierDetailScreen({super.key, required this.supplierId});

  void _copyToClipboard(BuildContext context, String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label copied to clipboard'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ledgerAsync = ref.watch(supplierLedgerProvider(supplierId));
    final supplierRepo = ref.watch(supplierRepositoryProvider);
    final currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
    final dateFormat = DateFormat('dd MMM yyyy, hh:mm a');

    return StreamBuilder<Supplier?>(
      stream: supplierRepo.docRef(supplierId).snapshots().map(
            (snap) => snap.exists ? Supplier.fromFirestore(snap) : null,
          ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final supplier = snapshot.data;
        if (supplier == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Supplier Details')),
            body: const Center(
              child: Text(
                'Supplier not found',
                style: TextStyle(fontSize: 18),
              ),
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(
              supplier.name,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          body: ledgerAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(
              child: Text('Error loading history: $error'),
            ),
            data: (entries) {
              return Column(
                children: [
                  // Summary Header Card
                  _buildHeaderCard(context, supplier, currencyFormat),

                  // Quick Actions Bar
                  _buildActionsBar(context, supplier, entries),

                  const Divider(height: 1),

                  // Transaction Timeline Title
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Row(
                      children: [
                        const Icon(Icons.history, color: Colors.grey),
                        const SizedBox(width: 8),
                        Text(
                          'Ledger History',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Chronological Timeline list
                  Expanded(
                    child: entries.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.receipt_long_outlined,
                                    size: 64, color: Colors.grey[300]),
                                const SizedBox(height: 16),
                                Text(
                                  'No transactions recorded yet',
                                  style: TextStyle(
                                      fontSize: 18, color: Colors.grey[500]),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            itemCount: entries.length,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemBuilder: (context, index) {
                              final entry = entries[index];
                              if (entry.type == 'purchase') {
                                return _buildPurchaseTile(
                                    context, entry.entity as Purchase, currencyFormat, dateFormat);
                              } else {
                                return _buildPaymentTile(
                                    context, entry.entity as SupplierPayment, currencyFormat, dateFormat);
                              }
                            },
                          ),
                  ),
                ],
              );
            },
          ),
          floatingActionButton: (ref.watch(isAdminProvider).value ?? false)
              ? null
              : FloatingActionButton.extended(
                  heroTag: 'supplier_detail_fab',
                  onPressed: () => _showRecordPaymentDialog(context, ref, supplier),
                  icon: const Icon(Icons.payment),
                  label: const Text(
                    'Record Payment',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
        );
      },
    );
  }

  Widget _buildHeaderCard(BuildContext context, Supplier supplier, NumberFormat currencyFormat) {
    final hasPending = supplier.pendingAmount > 0;
    return Card(
      margin: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TOTAL BALANCE WE OWE',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[600],
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      currencyFormat.format(supplier.pendingAmount),
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: hasPending ? Colors.red[700] : Colors.green[700],
                      ),
                    ),
                  ],
                ),
                if (supplier.phone.isNotEmpty)
                  CircleAvatar(
                    backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                    child: IconButton(
                      icon: Icon(Icons.phone, color: Theme.of(context).colorScheme.onPrimaryContainer),
                      onPressed: () => _copyToClipboard(context, supplier.phone, 'Phone number'),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionsBar(BuildContext context, Supplier supplier, List<SupplierLedgerEntry> entries) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        alignment: WrapAlignment.center,
        children: [
          if (supplier.phone.isNotEmpty)
            _ActionButton(
              icon: Icons.phone,
              label: 'Copy Phone',
              onPressed: () => _copyToClipboard(context, supplier.phone, 'Phone number'),
            ),
          _ActionButton(
            icon: Icons.content_copy,
            label: 'Copy Details',
            onPressed: () {
              final details = 'Supplier: ${supplier.name}\n'
                  'Phone: ${supplier.phone}\n'
                  'Outstanding Dues: ${supplier.pendingAmount}';
              _copyToClipboard(context, details, 'Supplier details');
            },
          ),
          _ActionButton(
            icon: Icons.picture_as_pdf,
            label: 'Share PDF',
            onPressed: () async {
              try {
                final pdfBytes = await InvoiceHelper.generateSupplierLedgerStatementPdf(supplier, entries);
                await Printing.sharePdf(
                  bytes: pdfBytes,
                  filename: 'Statement-${supplier.name.replaceAll(' ', '_')}.pdf',
                );
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error generating PDF: $e'), backgroundColor: Colors.red),
                  );
                }
              }
            },
          ),
          _ActionButton(
            icon: Icons.chat_outlined,
            label: 'Share Text',
            onPressed: () async {
              try {
                await InvoiceHelper.shareSupplierLedgerStatement(supplier, entries);
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error sharing statement: $e'), backgroundColor: Colors.red),
                  );
                }
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPurchaseTile(
      BuildContext context, Purchase purchase, NumberFormat currencyFormat, DateFormat dateFormat) {
    final itemsSummary = purchase.items.length == 1
        ? '1 product type'
        : '${purchase.items.length} product types';

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'PURCHASE',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue[700],
                    ),
                  ),
                ),
                Text(
                  dateFormat.format(purchase.purchaseDate),
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              itemsSummary,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total: ${currencyFormat.format(purchase.totalCost)}',
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    ),
                    Text(
                      'Paid: ${currencyFormat.format(purchase.paidAmount)} (${purchase.paymentMethod.toUpperCase()})',
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    ),
                  ],
                ),
                if (purchase.balanceDue > 0)
                  Text(
                    'Dues: ${currencyFormat.format(purchase.balanceDue)}',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.red[700],
                    ),
                  )
                else
                  Text(
                    'FULLY PAID ✓',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.green[700],
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentTile(BuildContext context, SupplierPayment payment,
      NumberFormat currencyFormat, DateFormat dateFormat) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'PAYMENT MADE',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.green[700],
                    ),
                  ),
                ),
                Text(
                  dateFormat.format(payment.paymentDate),
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.payment, size: 16, color: Colors.grey),
                    const SizedBox(width: 8),
                    Text(
                      'Method: ${payment.method.toUpperCase()}',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
                Text(
                  '- ${currencyFormat.format(payment.amount)}',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.red[700],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showRecordPaymentDialog(BuildContext context, WidgetRef ref, Supplier supplier) {
    final formKey = GlobalKey<FormState>();
    final amountController = TextEditingController();
    String method = 'cash';

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('Pay ${supplier.name}', style: const TextStyle(fontWeight: FontWeight.bold)),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: amountController,
                      decoration: const InputDecoration(
                        labelText: 'Payment Amount *',
                        prefixText: '₹ ',
                        border: OutlineInputBorder(),
                      ),
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) return 'Please enter amount';
                        final numVal = double.tryParse(val);
                        if (numVal == null || numVal <= 0) return 'Please enter a valid positive amount';
                        if (numVal > supplier.pendingAmount) return 'Amount exceeds total balance we owe!';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Payment Method:', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey)),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: method,
                      decoration: const InputDecoration(border: OutlineInputBorder()),
                      items: const [
                        DropdownMenuItem(value: 'cash', child: Text('Cash')),
                        DropdownMenuItem(value: 'upi', child: Text('UPI')),
                        DropdownMenuItem(value: 'net_banking', child: Text('Net Banking')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() => method = val);
                        }
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel', style: TextStyle(fontSize: 16)),
                ),
                FilledButton(
                  onPressed: () async {
                    if (!formKey.currentState!.validate()) return;
                    final amount = double.parse(amountController.text.trim());
                    final userId = ref.read(currentUserIdProvider);

                    final payment = SupplierPayment(
                      id: '',
                      supplierId: supplier.id,
                      amount: amount,
                      paymentDate: DateTime.now(),
                      method: method,
                      createdBy: userId,
                    );

                    try {
                      await ref.read(supplierRepositoryProvider).recordSupplierPayment(payment);
                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Payment recorded successfully ✓'), backgroundColor: Colors.green),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error saving payment: $e'), backgroundColor: Colors.red),
                        );
                      }
                    }
                  },
                  child: const Text('Confirm Pay', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 20),
      label: Text(label, style: const TextStyle(fontSize: 14)),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}
