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

/// The multi-step sale flow on one scrollable screen:
/// 1. Select customer
/// 2. Pick products (with editable price and quantity)
/// 3. Enter amount paid
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

  double get _totalAmount =>
      _cartItems.fold(0, (sum, item) => sum + item.subtotal);

  @override
  void dispose() {
    _paidController.dispose();
    super.dispose();
  }

  void _selectCustomer(Customer customer) {
    setState(() => _selectedCustomer = customer);
  }

  void _addProduct(Product product) {
    // Check if product is already in cart
    final existing = _cartItems.indexWhere((i) => i.product.id == product.id);
    if (existing >= 0) {
      setState(() => _cartItems[existing].quantity++);
    } else {
      setState(() {
        _cartItems.add(_CartItem(
          product: product,
          quantity: 1,
          unitPrice: product.sellingPrice,
        ));
      });
    }
    Navigator.of(context).pop(); // Close the product picker
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
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
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

    setState(() => _saving = true);

    final paidAmount =
        double.tryParse(_paidController.text.trim()) ?? _totalAmount;
    final userId = ref.read(currentUserIdProvider);

    final sale = Sale(
      id: '',
      customerId: _selectedCustomer!.id,
      saleDate: DateTime.now(),
      items: _cartItems
          .map((item) => SaleItem(
                productId: item.product.id,
                productName: item.product.name,
                quantity: item.quantity,
                unitPrice: item.unitPrice,
                subtotal: item.subtotal,
              ))
          .toList(),
      totalAmount: _totalAmount,
      paidAmount: paidAmount,
      createdBy: userId,
    );

    try {
      await ref.read(saleRepositoryProvider).recordSale(sale);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sale saved ✓'),
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
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
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

    // Step 2+: Build the sale
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Sale → ${_selectedCustomer!.name}',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        actions: [
          // Change customer
          IconButton(
            onPressed: () => setState(() => _selectedCustomer = null),
            icon: const Icon(Icons.swap_horiz),
            tooltip: 'Change customer',
          ),
        ],
      ),
      body: Column(
        children: [
          // Cart items
          Expanded(
            child: _cartItems.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.shopping_cart_outlined,
                            size: 64, color: Colors.grey[300]),
                        const SizedBox(height: 16),
                        Text(
                          'No products added yet',
                          style: TextStyle(
                              fontSize: 18, color: Colors.grey[500]),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Tap the button below to add products',
                          style: TextStyle(
                              fontSize: 14, color: Colors.grey[400]),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _cartItems.length,
                    itemBuilder: (context, index) {
                      final item = _cartItems[index];
                      return _CartItemTile(
                        item: item,
                        currencyFormat: _currencyFormat,
                        onQuantityChanged: (qty) {
                          setState(() {
                            if (qty <= 0) {
                              _cartItems.removeAt(index);
                            } else {
                              item.quantity = qty;
                            }
                          });
                        },
                        onPriceChanged: (price) {
                          setState(() => item.unitPrice = price);
                        },
                        onRemove: () {
                          setState(() => _cartItems.removeAt(index));
                        },
                      );
                    },
                  ),
          ),

          // Add product button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton.icon(
                onPressed: _showProductPicker,
                icon: const Icon(Icons.add_shopping_cart, size: 24),
                label: const Text('Add Product',
                    style: TextStyle(fontSize: 16)),
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Bottom section: total, paid, save
          if (_cartItems.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Total
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Total',
                            style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold)),
                        Text(
                          _currencyFormat.format(_totalAmount),
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Amount paid
                    TextField(
                      controller: _paidController,
                      decoration: InputDecoration(
                        labelText: 'Amount Paid Now',
                        hintText: _currencyFormat.format(_totalAmount),
                        prefixText: '₹ ',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                        helperText: 'Leave blank for full payment',
                      ),
                      style: const TextStyle(fontSize: 20),
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                    ),
                    const SizedBox(height: 16),

                    // Save button
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: FilledButton.icon(
                        onPressed: _saving ? null : _saveSale,
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
                          _saving ? 'Saving...' : 'Save Sale',
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
            ),
        ],
      ),
    );
  }
}

// ── Cart item model (local, not persisted) ──────────────────────────

class _CartItem {
  final Product product;
  int quantity;
  double unitPrice;

  _CartItem({
    required this.product,
    required this.quantity,
    required this.unitPrice,
  });

  double get subtotal => unitPrice * quantity;
}

// ── Cart item tile ──────────────────────────────────────────────────

class _CartItemTile extends StatelessWidget {
  final _CartItem item;
  final NumberFormat currencyFormat;
  final ValueChanged<int> onQuantityChanged;
  final ValueChanged<double> onPriceChanged;
  final VoidCallback onRemove;

  const _CartItemTile({
    required this.item,
    required this.currencyFormat,
    required this.onQuantityChanged,
    required this.onPriceChanged,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final stockWarning =
        item.quantity > item.product.currentStock;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    item.product.name,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
                IconButton(
                  onPressed: onRemove,
                  icon: Icon(Icons.close, color: Colors.red[400]),
                  iconSize: 20,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                // Price (editable)
                Expanded(
                  child: GestureDetector(
                    onTap: () => _editPrice(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '₹${item.unitPrice.toStringAsFixed(0)}',
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                const Text('×', style: TextStyle(fontSize: 18)),
                const SizedBox(width: 12),

                // Quantity controls
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        onPressed: () =>
                            onQuantityChanged(item.quantity - 1),
                        icon: const Icon(Icons.remove),
                        iconSize: 20,
                        constraints: const BoxConstraints(
                          minWidth: 44,
                          minHeight: 44,
                        ),
                      ),
                      Text(
                        '${item.quantity}',
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        onPressed: () =>
                            onQuantityChanged(item.quantity + 1),
                        icon: const Icon(Icons.add),
                        iconSize: 20,
                        constraints: const BoxConstraints(
                          minWidth: 44,
                          minHeight: 44,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),

                // Subtotal
                Text(
                  currencyFormat.format(item.subtotal),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),

            // Stock warning
            if (stockWarning)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber, size: 16, color: Colors.orange[700]),
                    const SizedBox(width: 4),
                    Text(
                      'Only ${item.product.currentStock} in stock',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.orange[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _editPrice(BuildContext context) {
    final controller =
        TextEditingController(text: item.unitPrice.toStringAsFixed(0));
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Price: ${item.product.name}'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            prefixText: '₹ ',
            labelText: 'Selling price',
          ),
          style: const TextStyle(fontSize: 20),
          keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final newPrice = double.tryParse(controller.text);
              if (newPrice != null && newPrice > 0) {
                onPriceChanged(newPrice);
              }
              Navigator.pop(context);
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }
}

// ── Product picker bottom sheet ─────────────────────────────────────

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
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final filtered = _search.isEmpty
        ? widget.products
        : widget.products
            .where((p) =>
                p.name.toLowerCase().contains(_search.toLowerCase()) ||
                p.category.toLowerCase().contains(_search.toLowerCase()))
            .toList();

    return Column(
      children: [
        // Handle bar
        Container(
          margin: const EdgeInsets.only(top: 8),
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: Colors.grey[300],
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Search product...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            style: const TextStyle(fontSize: 16),
            onChanged: (v) => setState(() => _search = v),
          ),
        ),
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Text(
                    'No products found',
                    style: TextStyle(fontSize: 16, color: Colors.grey[500]),
                  ),
                )
              : ListView.builder(
                  controller: widget.scrollController,
                  itemCount: filtered.length,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemBuilder: (context, index) {
                    final product = filtered[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 6),
                      child: ListTile(
                        onTap: () => widget.onSelected(product),
                        title: Text(
                          product.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          'Stock: ${product.currentStock}  •  ${product.category}',
                          style: TextStyle(
                            fontSize: 14,
                            color: product.isLowStock
                                ? Colors.red[600]
                                : Colors.grey[600],
                          ),
                        ),
                        trailing: Text(
                          widget.currencyFormat
                              .format(product.sellingPrice),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
