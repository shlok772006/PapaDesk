import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../providers/payment_providers.dart';
import '../../providers/role_provider.dart';
import '../../widgets/sync_indicator.dart';
import 'new_payment_screen.dart';

/// Shows unified cash transactions ( ledger dues payments, sales payments, and product purchases).
class PaymentsScreen extends ConsumerWidget {
  const PaymentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactionsAsync = ref.watch(recentTransactionsProvider);
    final currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
    final dateFormat = DateFormat('dd MMM, hh:mm a');
    final isAdmin = ref.watch(isAdminProvider).value ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Cash Book / Payments',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        centerTitle: false,
      ),
      body: transactionsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Error loading transactions: $error',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ),
        data: (transactions) {
          if (transactions.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.payments_outlined, size: 80, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text(
                    'No recent cash flow events',
                    style: TextStyle(fontSize: 20, color: Colors.grey[500]),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tap + to record a customer payment',
                    style: TextStyle(fontSize: 16, color: Colors.grey[400]),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: transactions.length,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemBuilder: (context, index) {
              final tx = transactions[index];
              final isOutflow = tx.type == TransactionType.purchase;
              final amountColor = isOutflow ? Colors.red[700] : Colors.green[700];
              final leadingColor = isOutflow ? Colors.red[50] : Colors.green[50];
              final leadingIcon = isOutflow ? Icons.arrow_upward : Icons.arrow_downward;
              final leadingIconColor = isOutflow ? Colors.red[700] : Colors.green[700];

              final absAmount = tx.amount.abs();
              final sign = isOutflow ? '-' : '+';

              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.grey[100]!),
                ),
                child: InkWell(
                  onTap: () => _showTransactionDetails(context, tx),
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Arrow indicator
                        CircleAvatar(
                          radius: 22,
                          backgroundColor: leadingColor,
                          child: Icon(leadingIcon, color: leadingIconColor, size: 20),
                        ),
                        const SizedBox(width: 16),

                        // Details
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    tx.title,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: isOutflow ? Colors.red[700] : Colors.blue[800],
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      '•  ${dateFormat.format(tx.date)}',
                                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (tx.hasPendingWrites) ...[
                                    const SizedBox(width: 6),
                                    SyncIndicator(hasPendingWrites: true),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                tx.partyName,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                tx.subtitle,
                                style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),

                        // Amount
                        Text(
                          '$sign ${currencyFormat.format(absAmount)}',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: amountColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: isAdmin
          ? null
          : FloatingActionButton.extended(
              heroTag: 'payments_fab',
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const NewPaymentScreen()),
                );
              },
              icon: const Icon(Icons.add, size: 28),
              label: const Text(
                'New Payment',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
    );
  }

  void _showTransactionDetails(BuildContext context, CashTransaction tx) {
    final fullDateFormat = DateFormat('dd MMMM yyyy, hh:mm a');
    final currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
    final isOutflow = tx.type == TransactionType.purchase;
    final amountColor = isOutflow ? Colors.red[700] : Colors.green[700];
    final sign = isOutflow ? '-' : '+';

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2.5),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  tx.title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey),
                ),
                const SizedBox(height: 12),
                Text(
                  '$sign ${currencyFormat.format(tx.amount.abs())}',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: amountColor,
                  ),
                ),
                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Party Name:', style: TextStyle(fontSize: 15, color: Colors.grey)),
                    Text(
                      tx.partyName,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Date & Time:', style: TextStyle(fontSize: 15, color: Colors.grey)),
                    Text(
                      fullDateFormat.format(tx.date),
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Reference ID:', style: TextStyle(fontSize: 15, color: Colors.grey)),
                    Text(
                      tx.id,
                      style: const TextStyle(fontSize: 12, fontFamily: 'monospace', color: Colors.grey),
                    ),
                  ],
                ),
                if (tx.subtitle.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text('Details / Remarks:', style: TextStyle(fontSize: 15, color: Colors.grey, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: Text(
                      tx.subtitle,
                      style: const TextStyle(fontSize: 15, height: 1.4),
                    ),
                  ),
                ],
                const SizedBox(height: 28),
                SizedBox(
                  height: 52,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
