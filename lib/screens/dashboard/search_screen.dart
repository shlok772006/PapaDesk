import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../providers/customer_providers.dart';
import '../../providers/product_providers.dart';
import '../ledger/customer_detail_screen.dart';
import '../inventory/add_edit_product_screen.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  final _currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹');

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final customersAsync = ref.watch(customersProvider);
    final productsAsync = ref.watch(productsProvider);

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          decoration: const InputDecoration(
            hintText: 'Search customer or product...',
            border: InputBorder.none,
            hintStyle: TextStyle(color: Colors.grey),
          ),
          style: const TextStyle(fontSize: 18),
          autofocus: true,
          onChanged: (val) => setState(() => _query = val.trim().toLowerCase()),
        ),
        actions: [
          if (_query.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                _searchController.clear();
                setState(() => _query = '');
              },
            ),
        ],
      ),
      body: _query.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.search, size: 80, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text(
                    'Type to search directory',
                    style: TextStyle(fontSize: 18, color: Colors.grey[500]),
                  ),
                ],
              ),
            )
          : Builder(
              builder: (context) {
                // If either is loading or error, handle cleanly
                if (customersAsync.isLoading || productsAsync.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                final customers = customersAsync.value ?? [];
                final products = productsAsync.value ?? [];

                // Filter Customers
                final filteredCustomers = customers
                    .where((c) =>
                        c.name.toLowerCase().contains(_query) ||
                        c.phone.contains(_query))
                    .toList();

                // Filter Products
                final filteredProducts = products
                    .where((p) =>
                        p.name.toLowerCase().contains(_query) ||
                        p.category.toLowerCase().contains(_query))
                    .toList();

                if (filteredCustomers.isEmpty && filteredProducts.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.search_off, size: 64, color: Colors.grey[300]),
                        const SizedBox(height: 16),
                        Text(
                          'No matches found',
                          style: TextStyle(fontSize: 18, color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  );
                }

                // Render lists
                return ListView(
                  children: [
                    // Customers Section
                    if (filteredCustomers.isNotEmpty) ...[
                      _buildHeaderSection('Customers (${filteredCustomers.length})'),
                      ...filteredCustomers.map((c) => _buildCustomerTile(c)),
                    ],

                    // Products Section
                    if (filteredProducts.isNotEmpty) ...[
                      _buildHeaderSection('Products (${filteredProducts.length})'),
                      ...filteredProducts.map((p) => _buildProductTile(p)),
                    ],
                  ],
                );
              },
            ),
    );
  }

  Widget _buildHeaderSection(String title) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: Colors.grey[100],
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.grey[700],
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildCustomerTile(dynamic customer) {
    final hasPending = customer.pendingAmount > 0;

    return ListTile(
      leading: CircleAvatar(
        radius: 20,
        backgroundColor: Colors.indigo[50],
        child: Text(
          customer.name.isNotEmpty ? customer.name[0].toUpperCase() : '?',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo[800]),
        ),
      ),
      title: Text(
        customer.name,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
      ),
      subtitle: Text(customer.phone.isNotEmpty ? customer.phone : 'No phone number'),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            _currencyFormat.format(customer.pendingAmount),
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: hasPending ? Colors.red[700] : Colors.green[700],
            ),
          ),
          if (hasPending)
            const Text(
              'Owed',
              style: TextStyle(fontSize: 11, color: Colors.red),
            ),
        ],
      ),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => CustomerDetailScreen(customerId: customer.id),
          ),
        );
      },
    );
  }

  Widget _buildProductTile(dynamic product) {
    final isLow = product.isLowStock;

    return ListTile(
      leading: CircleAvatar(
        radius: 20,
        backgroundColor: Colors.blue[50],
        child: Text(
          product.name.isNotEmpty ? product.name[0].toUpperCase() : '?',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue[800]),
        ),
      ),
      title: Text(
        product.name,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
      ),
      subtitle: Text('Stock: ${product.currentStock} pcs • ${product.category}'),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            _currencyFormat.format(product.sellingPrice),
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
          if (isLow)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.warning, size: 10, color: Colors.red[700]),
                const SizedBox(width: 2),
                Text(
                  'Low Stock',
                  style: TextStyle(fontSize: 11, color: Colors.red[700], fontWeight: FontWeight.bold),
                ),
              ],
            ),
        ],
      ),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => AddEditProductScreen(product: product),
          ),
        );
      },
    );
  }
}
