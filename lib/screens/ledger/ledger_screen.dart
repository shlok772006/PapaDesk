import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../models/supplier.dart';
import '../../providers/customer_providers.dart';
import '../../providers/supplier_providers.dart';
import '../../providers/role_provider.dart';
import '../purchases/add_supplier_dialog.dart';
import 'customer_detail_screen.dart';
import 'supplier_detail_screen.dart';
import 'add_edit_customer_screen.dart';

class LedgerScreen extends ConsumerStatefulWidget {
  const LedgerScreen({super.key});

  @override
  ConsumerState<LedgerScreen> createState() => _LedgerScreenState();
}

class _LedgerScreenState extends ConsumerState<LedgerScreen> {
  String _searchQuery = '';
  bool _isCustomerView = true;
  bool _showOnlyWithDues = false;
  bool _showOnlySuppliersWithDues = false;
  final _currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹');

  @override
  Widget build(BuildContext context) {
    final customersAsync = ref.watch(customersProvider);
    final suppliersAsync = ref.watch(suppliersProvider);
    final isAdmin = ref.watch(isAdminProvider).value ?? false;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isCustomerView ? 'Customer Ledger' : 'Supplier Ledger',
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        centerTitle: false,
      ),
      body: Column(
        children: [
          // Toggle View Segmented Selector
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: SizedBox(
              width: double.infinity,
              child: SegmentedButton<bool>(
                segments: const [
                  ButtonSegment<bool>(
                    value: true,
                    label: Text('Customers'),
                    icon: Icon(Icons.people),
                  ),
                  ButtonSegment<bool>(
                    value: false,
                    label: Text('Suppliers'),
                    icon: Icon(Icons.local_shipping),
                  ),
                ],
                selected: {_isCustomerView},
                onSelectionChanged: (Set<bool> selected) {
                  setState(() {
                    _isCustomerView = selected.first;
                    _searchQuery = '';
                  });
                },
              ),
            ),
          ),

          // Search box
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              decoration: InputDecoration(
                hintText: _isCustomerView ? 'Search customer...' : 'Search supplier...',
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

          // Quick filters
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                ChoiceChip(
                  label: const Text('Show All', style: TextStyle(fontWeight: FontWeight.bold)),
                  selected: _isCustomerView ? !_showOnlyWithDues : !_showOnlySuppliersWithDues,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        if (_isCustomerView) {
                          _showOnlyWithDues = false;
                        } else {
                          _showOnlySuppliersWithDues = false;
                        }
                      });
                    }
                  },
                ),
                const SizedBox(width: 12),
                ChoiceChip(
                  label: Text(_isCustomerView ? 'Dues Pending ⚠️' : 'We Owe ⚠️', style: const TextStyle(fontWeight: FontWeight.bold)),
                  selected: _isCustomerView ? _showOnlyWithDues : _showOnlySuppliersWithDues,
                  selectedColor: Theme.of(context).colorScheme.primaryContainer,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        if (_isCustomerView) {
                          _showOnlyWithDues = true;
                        } else {
                          _showOnlySuppliersWithDues = true;
                        }
                      });
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Customer Directory / Supplier Directory
          Expanded(
            child: _isCustomerView
                ? customersAsync.when(
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (error, _) => Center(child: Text('Error loading customers: $error')),
                    data: (customers) {
                      final filtered = _searchQuery.isEmpty
                          ? customers
                          : customers
                              .where((c) =>
                                  c.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                                  c.phone.contains(_searchQuery))
                              .toList();

                      final displayed = _showOnlyWithDues
                          ? filtered.where((c) => c.pendingAmount > 0).toList()
                          : filtered;

                      if (displayed.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.people_outline, size: 80, color: Colors.grey[300]),
                              const SizedBox(height: 16),
                              Text(
                                _searchQuery.isEmpty
                                    ? (_showOnlyWithDues ? 'No customers with pending dues' : 'No customers yet')
                                    : 'No matching customers',
                                style: TextStyle(fontSize: 18, color: Colors.grey[500]),
                              ),
                            ],
                          ),
                        );
                      }

                      return ListView.builder(
                        itemCount: displayed.length,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemBuilder: (context, index) {
                          final customer = displayed[index];
                          final hasPending = customer.pendingAmount > 0;

                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: InkWell(
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => CustomerDetailScreen(customerId: customer.id),
                                  ),
                                );
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 24,
                                      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                                      child: Text(
                                        customer.name.isNotEmpty ? customer.name[0].toUpperCase() : '?',
                                        style: TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            customer.name,
                                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                                          ),
                                          if (customer.phone.isNotEmpty)
                                            Text(
                                              customer.phone,
                                              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                                            ),
                                        ],
                                      ),
                                    ),
                                    if (hasPending)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: Colors.red[50],
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          _currencyFormat.format(customer.pendingAmount),
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
                        },
                      );
                    },
                  )
                : suppliersAsync.when(
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (error, _) => Center(child: Text('Error loading suppliers: $error')),
                    data: (suppliers) {
                      final filtered = _searchQuery.isEmpty
                          ? suppliers
                          : suppliers
                              .where((s) =>
                                  s.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                                  s.phone.contains(_searchQuery))
                              .toList();

                      final displayed = _showOnlySuppliersWithDues
                          ? filtered.where((s) => s.pendingAmount > 0).toList()
                          : filtered;

                      if (displayed.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.local_shipping_outlined, size: 80, color: Colors.grey[300]),
                              const SizedBox(height: 16),
                              Text(
                                _searchQuery.isEmpty
                                    ? (_showOnlySuppliersWithDues ? 'No outstanding supplier dues' : 'No suppliers yet')
                                    : 'No matching suppliers',
                                style: TextStyle(fontSize: 18, color: Colors.grey[500]),
                              ),
                            ],
                          ),
                        );
                      }

                      return ListView.builder(
                        itemCount: displayed.length,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemBuilder: (context, index) {
                          final supplier = displayed[index];
                          final hasPending = supplier.pendingAmount > 0;

                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: InkWell(
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => SupplierDetailScreen(supplierId: supplier.id),
                                  ),
                                );
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 24,
                                      backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
                                      child: Text(
                                        supplier.name.isNotEmpty ? supplier.name[0].toUpperCase() : '?',
                                        style: TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                          color: Theme.of(context).colorScheme.onSecondaryContainer,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            supplier.name,
                                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                                          ),
                                          if (supplier.phone.isNotEmpty)
                                            Text(
                                              supplier.phone,
                                              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                                            ),
                                        ],
                                      ),
                                    ),
                                    if (hasPending)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: Colors.red[50],
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          _currencyFormat.format(supplier.pendingAmount),
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
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: isAdmin
          ? null
          : FloatingActionButton.extended(
              heroTag: 'ledger_fab',
              onPressed: () async {
                if (_isCustomerView) {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const AddEditCustomerScreen(),
                    ),
                  );
                } else {
                  final newSupplier = await showDialog<Supplier>(
                    context: context,
                    builder: (_) => const AddSupplierDialog(),
                  );
                  if (newSupplier != null && mounted) {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => SupplierDetailScreen(supplierId: newSupplier.id),
                      ),
                    );
                  }
                }
              },
              icon: const Icon(Icons.add, size: 28),
              label: Text(
                _isCustomerView ? 'Add Customer' : 'Add Supplier',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
    );
  }
}
