import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/customer.dart';
import '../providers/customer_providers.dart';
import 'package:intl/intl.dart';

/// A reusable searchable customer list used by both Sales and Payments.
///
/// Shows name, phone, and pending balance. Large tap targets.
/// [onSelected] fires when a customer is tapped.
/// [onAddNew] fires when the "Add New Customer" button is tapped.
class CustomerSelector extends ConsumerStatefulWidget {
  final void Function(Customer customer) onSelected;
  final VoidCallback? onAddNew;

  const CustomerSelector({
    super.key,
    required this.onSelected,
    this.onAddNew,
  });

  @override
  ConsumerState<CustomerSelector> createState() => _CustomerSelectorState();
}

class _CustomerSelectorState extends ConsumerState<CustomerSelector> {
  String _searchQuery = '';
  final _currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹');

  @override
  Widget build(BuildContext context) {
    final customersAsync = ref.watch(customersProvider);

    return Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Search customer...',
              prefixIcon: const Icon(Icons.search, size: 28),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
            ),
            style: const TextStyle(fontSize: 18),
            onChanged: (value) => setState(() => _searchQuery = value),
          ),
        ),

        // Add new customer button
        if (widget.onAddNew != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton.icon(
                onPressed: widget.onAddNew,
                icon: const Icon(Icons.person_add, size: 24),
                label: const Text(
                  'Add New Customer',
                  style: TextStyle(fontSize: 16),
                ),
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ),

        const SizedBox(height: 8),

        // Customer list
        Expanded(
          child: customersAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(
              child: Text('Error loading customers: $error'),
            ),
            data: (customers) {
              final filtered = _searchQuery.isEmpty
                  ? customers
                  : customers
                      .where((c) =>
                          c.name
                              .toLowerCase()
                              .contains(_searchQuery.toLowerCase()) ||
                          c.phone.contains(_searchQuery))
                      .toList();

              if (filtered.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.people_outline,
                          size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        _searchQuery.isEmpty
                            ? 'No customers yet'
                            : 'No matching customers',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final customer = filtered[index];
                  return _CustomerTile(
                    customer: customer,
                    currencyFormat: _currencyFormat,
                    onTap: () => widget.onSelected(customer),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _CustomerTile extends StatelessWidget {
  final Customer customer;
  final NumberFormat currencyFormat;
  final VoidCallback onTap;

  const _CustomerTile({
    required this.customer,
    required this.currencyFormat,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasPending = customer.pendingAmount > 0;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Avatar
              CircleAvatar(
                radius: 24,
                backgroundColor:
                    Theme.of(context).colorScheme.primaryContainer,
                child: Text(
                  customer.name.isNotEmpty
                      ? customer.name[0].toUpperCase()
                      : '?',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
              const SizedBox(width: 16),

              // Name and phone
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      customer.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (customer.phone.isNotEmpty)
                      Text(
                        customer.phone,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                  ],
                ),
              ),

              // Pending amount
              if (hasPending)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    currencyFormat.format(customer.pendingAmount),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.red[700],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
