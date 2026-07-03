import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../models/customer.dart';
import '../../models/product.dart';
import '../../models/sale.dart';
import '../../providers/product_providers.dart';
import '../../providers/repository_providers.dart';
import 'add_customer_dialog.dart';
import '../../widgets/customer_selector.dart';

/// A simplified, multi-product sale screen:
/// 1. Select Customer
/// 2. Pick multiple Products (with inline editable Quantity and Selling Price)
/// 3. Enter Amount Paid
/// 4. Save
class NewSaleScreen extends ConsumerStatefulWidget {
  const NewSaleScreen({super.key});

  @override
  ConsumerState<NewSaleScreen> createState() => _NewSaleScreenState();
}

class _NewSaleScreenState extends ConsumerState<NewSaleScreen> {
  Customer? _selectedCustomer;
  final List<_CartItem> _cartItems = [];
  final _paidController = TextEditingController();
  
  bool _saving = false;
  final _currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹');

  double get _totalAmount {
    return _cartItems.fold(0.0, (sum, item) {
      final price = double.tryParse(item.priceController.text.trim()) ?? 0.0;
      return sum + (price * item.quantity);
    });
  }

  @override
  void dispose() {
    for (final item in _cartItems) {
      item.priceController.dispose();
    }
    _paidController.dispose();
    super.dispose();
  }

  void _selectCustomer(Customer customer) {
    setState(() => _selectedCustomer = customer);
  }

  void _addProduct(Product product) {
    // Check if already in cart
    final existingIndex = _cartItems.indexWhere((item) => item.product.id == product.id);
    if (existingIndex >= 0) {
      setState(() {
        _cartItems[existingIndex].quantity++;
      });
    } else {
      setState(() {
        _cartItems.add(_CartItem(
          product: product,
          quantity: 1,
          initialPrice: 0.0, // Defaults to empty so they enter it dynamically
        ));
      });
    }
    Navigator.of(context).pop(); // Close product picker
  }

  void _removeProduct(int index) {
    setState(() {
      _cartItems[index].priceController.dispose();
      _cartItems.removeAt(index);
    });
  }

  void _showProductPicker() {
    final productsAsync = ref.read(productsProvider);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.7,
          maxChildSize: 0.9,
          minChildSize: 0.4,
          builder: (context, scrollController) {
            return productsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (products) => _ProductPickerSheet(
                products: products,
                scrollController: scrollController,
                currencyFormat: _currencyFormat,
                onSelected: _addProduct,
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _saveSale() async {
    if (_selectedCustomer == null) {
      _showError('Please select a customer');
      return;
    }
    if (_cartItems.isEmpty) {
      _showError('Please add at least one product');
      return;
    }

    final List<SaleItem> items = [];
    for (final item in _cartItems) {
      final priceText = item.priceController.text.trim();
      final price = double.tryParse(priceText) ?? 0.0;
      if (price <= 0) {
        _showError('Please enter a valid price for ${item.product.name}');
        return;
      }
      items.add(SaleItem(
        productId: item.product.id,
        productName: item.product.name,
        quantity: item.quantity,
        unitPrice: price,
        subtotal: price * item.quantity,
      ));
    }

    final total = _totalAmount;
    final paidAmountText = _paidController.text.trim();
    final paidAmount = paidAmountText.isEmpty ? total : (double.tryParse(paidAmountText) ?? 0.0);

    setState(() => _saving = true);

    final saleRepo = ref.read(saleRepositoryProvider);
    final userId = ref.read(currentUserIdProvider);

    final sale = Sale(
      id: '',
      customerId: _selectedCustomer!.id,
      saleDate: DateTime.now(),
      items: items,
      totalAmount: total,
      paidAmount: paidAmount,
      createdBy: userId,
    );

    try {
      await saleRepo.recordSale(sale);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sale recorded successfully ✓'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        _showError('Error saving sale: $e');
        setState(() => _saving = false);
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontSize: 16)),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Step 1: Customer Selection first
    if (_selectedCustomer == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('New Sale - Select Customer', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
        body: CustomerSelector(
          onSelected: _selectCustomer,
          onAddNew: () async {
            final newCustomer = await showDialog<Customer>(
              context: context,
              builder: (_) => const AddCustomerDialog(),
            );
            if (newCustomer != null) {
              _selectCustomer(newCustomer);
            }
          },
        ),
      );
    }

    // Step 2: Customer selected, show products card & billing inputs
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'New Sale',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          // Customer card
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.grey[200]!),
            ),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                child: Icon(Icons.person, color: Theme.of(context).colorScheme.onPrimaryContainer),
              ),
              title: Text(
                _selectedCustomer!.name,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                _selectedCustomer!.phone.isEmpty ? 'No Phone' : _selectedCustomer!.phone,
                style: const TextStyle(fontSize: 14),
              ),
              trailing: TextButton(
                onPressed: () => setState(() {
                  _selectedCustomer = null;
                  _cartItems.clear();
                }),
                child: const Text('Change', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Cart Section Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Selected Products',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey),
              ),
              TextButton.icon(
                onPressed: _showProductPicker,
                icon: const Icon(Icons.add),
                label: const Text('Add Product', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 8),

          if (_cartItems.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 40),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!, style: BorderStyle.solid),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(
                child: Text(
                  'No products added yet. Click Add Product.',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _cartItems.length,
              itemBuilder: (context, index) {
                final item = _cartItems[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.grey[200]!),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                item.product.name,
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                            ),
                            IconButton(
                              onPressed: () => _removeProduct(index),
                              icon: const Icon(Icons.delete_outline, color: Colors.red),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            // Quantity Controls
                            Container(
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey[300]!),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  IconButton(
                                    onPressed: () {
                                      if (item.quantity > 1) {
                                        setState(() => item.quantity--);
                                      }
                                    },
                                    icon: const Icon(Icons.remove),
                                    iconSize: 20,
                                  ),
                                  Text(
                                    '${item.quantity}',
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                  ),
                                  IconButton(
                                    onPressed: () {
                                      setState(() => item.quantity++);
                                    },
                                    icon: const Icon(Icons.add),
                                    iconSize: 20,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            // Selling Price Input Box
                            Expanded(
                              child: TextField(
                                controller: item.priceController,
                                decoration: const InputDecoration(
                                  labelText: 'Selling Price *',
                                  prefixText: '₹ ',
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                ),
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                onChanged: (val) {
                                  // Refresh total
                                  setState(() {});
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),

          if (_cartItems.isNotEmpty) ...[
            const SizedBox(height: 32),
            // Billing Summary
            const Text(
              'Billing Summary',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            
            // Total Amount Display
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total Amount:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                Text(
                  _currencyFormat.format(_totalAmount),
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blue),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Amount Paid Box
            TextField(
              controller: _paidController,
              decoration: InputDecoration(
                labelText: 'Amount Paid Now',
                prefixText: '₹ ',
                hintText: _currencyFormat.format(_totalAmount).replaceAll('₹', '').trim(),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                helperText: 'Leave empty for full payment',
              ),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 40),

            // Save Button
            SizedBox(
              height: 58,
              child: FilledButton.icon(
                onPressed: _saving ? null : _saveSale,
                icon: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.check, size: 26),
                label: const Text('Save Sale', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Product Picker sheet ─────────────────────────────────────────────

class _ProductPickerSheet extends StatefulWidget {
  final List<Product> products;
  final ScrollController scrollController;
  final NumberFormat currencyFormat;
  final ValueChanged<Product> onSelected;

  const _ProductPickerSheet({
    required this.products,
    required this.scrollController,
    required this.currencyFormat,
    required this.onSelected,
  });

  @override
  State<_ProductPickerSheet> createState() => _ProductPickerSheetState();
}

class _ProductPickerSheetState extends State<_ProductPickerSheet> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final filtered = widget.products.where((p) {
      final nameMatches = p.name.toLowerCase().contains(_searchQuery.toLowerCase());
      final catMatches = p.category.toLowerCase().contains(_searchQuery.toLowerCase());
      return nameMatches || catMatches;
    }).toList();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[350],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Select Product',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          TextField(
            decoration: InputDecoration(
              hintText: 'Search product...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            onChanged: (val) => setState(() => _searchQuery = val),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: filtered.isEmpty
                ? const Center(
                    child: Text('No products found', style: TextStyle(fontSize: 16, color: Colors.grey)),
                  )
                : ListView.builder(
                    controller: widget.scrollController,
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final product = filtered[index];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.blue[50],
                          child: Icon(Icons.shopping_bag_outlined, color: Colors.blue[700]),
                        ),
                        title: Text(
                          product.name,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          'Category: ${product.category} • Stock: ${product.currentStock} pcs',
                          style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                        ),
                        onTap: () => widget.onSelected(product),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// ── Local Cart Item Helper ───────────────────────────────────────────

class _CartItem {
  final Product product;
  int quantity;
  final TextEditingController priceController;

  _CartItem({
    required this.product,
    required this.quantity,
    required double initialPrice,
  }) : priceController = TextEditingController(text: initialPrice > 0 ? initialPrice.toStringAsFixed(0) : '');
}
