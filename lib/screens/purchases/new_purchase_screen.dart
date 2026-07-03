import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../models/supplier.dart';
import '../../models/product.dart';
import '../../models/purchase.dart';
import '../../providers/product_providers.dart';
import '../../providers/repository_providers.dart';
import 'add_supplier_dialog.dart';
import '../../widgets/supplier_selector.dart';

class NewPurchaseScreen extends ConsumerStatefulWidget {
  const NewPurchaseScreen({super.key});

  @override
  ConsumerState<NewPurchaseScreen> createState() => _NewPurchaseScreenState();
}

class _NewPurchaseScreenState extends ConsumerState<NewPurchaseScreen> {
  Supplier? _selectedSupplier;
  final List<_PurchaseCartItem> _cartItems = [];
  bool _saving = false;

  final _currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹');

  double get _totalCost =>
      _cartItems.fold(0, (sum, item) => sum + item.subtotal);

  void _selectSupplier(Supplier supplier) {
    setState(() => _selectedSupplier = supplier);
  }

  void _addProduct(Product product) {
    final existing = _cartItems.indexWhere((i) => i.product.id == product.id);
    if (existing >= 0) {
      setState(() => _cartItems[existing].quantity++);
    } else {
      setState(() {
        _cartItems.add(_PurchaseCartItem(
          product: product,
          quantity: 1,
          unitCost: product.purchasePrice,
        ));
      });
    }
    Navigator.of(context).pop();
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

  Future<void> _savePurchase() async {
    if (_selectedSupplier == null) {
      _showError('Please select a supplier');
      return;
    }
    if (_cartItems.isEmpty) {
      _showError('Please add at least one product');
      return;
    }

    setState(() => _saving = true);

    final userId = ref.read(currentUserIdProvider);

    final purchase = Purchase(
      id: '',
      supplierId: _selectedSupplier!.id,
      purchaseDate: DateTime.now(),
      items: _cartItems
          .map((item) => PurchaseItem(
                productId: item.product.id,
                quantity: item.quantity,
                unitCost: item.unitCost,
              ))
          .toList(),
      totalCost: _totalCost,
      createdBy: userId,
    );

    try {
      await ref.read(purchaseRepositoryProvider).recordPurchase(purchase);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Purchase recorded ✓'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        _showError('Error recording purchase: $e');
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
    // Step 1: Supplier selection
    if (_selectedSupplier == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text(
            'Select Supplier',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ),
        body: SupplierSelector(
          onSelected: _selectSupplier,
          onAddNew: () async {
            final newSupplier = await showDialog<Supplier>(
              context: context,
              builder: (_) => const AddSupplierDialog(),
            );
            if (newSupplier != null) {
              _selectSupplier(newSupplier);
            }
          },
        ),
      );
    }

    // Step 2+: Build purchase details
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Purchase from ${_selectedSupplier!.name}',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            onPressed: () => setState(() => _selectedSupplier = null),
            icon: const Icon(Icons.swap_horiz),
            tooltip: 'Change supplier',
          ),
        ],
      ),
      body: Column(
        children: [
          // Items in purchase
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
                          style: TextStyle(fontSize: 18, color: Colors.grey[500]),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Tap the button below to add products',
                          style: TextStyle(fontSize: 14, color: Colors.grey[400]),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _cartItems.length,
                    itemBuilder: (context, index) {
                      final item = _cartItems[index];
                      return _PurchaseItemTile(
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
                        onCostChanged: (cost) {
                          setState(() => item.unitCost = cost);
                        },
                        onRemove: () {
                          setState(() => _cartItems.removeAt(index));
                        },
                      );
                    },
                  ),
          ),

          // Add Product button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton.icon(
                onPressed: _showProductPicker,
                icon: const Icon(Icons.add_shopping_cart, size: 24),
                label: const Text('Add Product', style: TextStyle(fontSize: 16)),
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Save Summary
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Total Cost',
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                        Text(
                          _currencyFormat.format(_totalCost),
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Save purchase button
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: FilledButton.icon(
                        onPressed: _saving ? null : _savePurchase,
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
                          _saving ? 'Saving...' : 'Record Purchase',
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

class _PurchaseCartItem {
  final Product product;
  int quantity;
  double unitCost;

  _PurchaseCartItem({
    required this.product,
    required this.quantity,
    required this.unitCost,
  });

  double get subtotal => unitCost * quantity;
}

class _PurchaseItemTile extends StatelessWidget {
  final _PurchaseCartItem item;
  final NumberFormat currencyFormat;
  final ValueChanged<int> onQuantityChanged;
  final ValueChanged<double> onCostChanged;
  final VoidCallback onRemove;

  const _PurchaseItemTile({
    required this.item,
    required this.currencyFormat,
    required this.onQuantityChanged,
    required this.onCostChanged,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
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
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
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
                // Purchase Cost (editable)
                Expanded(
                  child: GestureDetector(
                    onTap: () => _editCost(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Cost: ₹${item.unitCost.toStringAsFixed(0)}',
                        style: const TextStyle(fontSize: 15),
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
                        onPressed: () => onQuantityChanged(item.quantity - 1),
                        icon: const Icon(Icons.remove),
                        iconSize: 20,
                        constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                      ),
                      Text(
                        '${item.quantity}',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        onPressed: () => onQuantityChanged(item.quantity + 1),
                        icon: const Icon(Icons.add),
                        iconSize: 20,
                        constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
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
          ],
        ),
      ),
    );
  }

  void _editCost(BuildContext context) {
    final controller = TextEditingController(text: item.unitCost.toStringAsFixed(0));
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Cost: ${item.product.name}'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            prefixText: '₹ ',
            labelText: 'Purchase cost per unit',
          ),
          style: const TextStyle(fontSize: 20),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final newCost = double.tryParse(controller.text);
              if (newCost != null && newCost >= 0) {
                onCostChanged(newCost);
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
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          'Stock: ${product.currentStock} pcs  •  ${product.category}',
                          style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                        ),
                        trailing: Text(
                          widget.currencyFormat.format(product.purchasePrice),
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
