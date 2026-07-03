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

/// A simplified, single-item sale screen:
/// 1. If no customer is picked, displays CustomerSelector.
/// 2. Once selected, prompts to pick a Product and enter Selling Price & Amount Paid.
class NewSaleScreen extends ConsumerStatefulWidget {
  const NewSaleScreen({super.key});

  @override
  ConsumerState<NewSaleScreen> createState() => _NewSaleScreenState();
}

class _NewSaleScreenState extends ConsumerState<NewSaleScreen> {
  Customer? _selectedCustomer;
  Product? _selectedProduct;
  
  final _sellingPriceController = TextEditingController();
  final _paidController = TextEditingController();
  
  bool _saving = false;
  final _currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹');

  @override
  void dispose() {
    _sellingPriceController.dispose();
    _paidController.dispose();
    super.dispose();
  }

  void _selectCustomer(Customer customer) {
    setState(() => _selectedCustomer = customer);
  }

  void _selectProduct(Product product) {
    setState(() {
      _selectedProduct = product;
      _sellingPriceController.clear();
      _paidController.clear();
    });
    Navigator.of(context).pop(); // Close product picker
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
                onSelected: _selectProduct,
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
    if (_selectedProduct == null) {
      _showError('Please select a product');
      return;
    }

    final sellingPriceText = _sellingPriceController.text.trim();
    if (sellingPriceText.isEmpty || double.tryParse(sellingPriceText) == null) {
      _showError('Please enter a valid selling price');
      return;
    }

    final sellingPrice = double.parse(sellingPriceText);
    final paidAmountText = _paidController.text.trim();
    final paidAmount = paidAmountText.isEmpty ? sellingPrice : (double.tryParse(paidAmountText) ?? 0.0);

    setState(() => _saving = true);

    final saleRepo = ref.read(saleRepositoryProvider);
    final userId = ref.read(currentUserIdProvider);

    final sale = Sale(
      id: '',
      customerId: _selectedCustomer!.id,
      saleDate: DateTime.now(),
      items: [
        SaleItem(
          productId: _selectedProduct!.id,
          productName: _selectedProduct!.name,
          quantity: 1,
          unitPrice: sellingPrice,
          subtotal: sellingPrice,
        ),
      ],
      totalAmount: sellingPrice,
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
    // Step 1: Force customer selection first if none is selected
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

    // Step 2 & 3: Customer selected. Show product selection and prices inputs.
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
          // Selected Customer Card
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
                  _selectedProduct = null;
                }),
                child: const Text('Change', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Select Product Section
          const Text(
            'Select Product',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey),
          ),
          const SizedBox(height: 12),
          if (_selectedProduct == null)
            OutlinedButton.icon(
              onPressed: _showProductPicker,
              icon: const Icon(Icons.add_shopping_cart, size: 24),
              label: const Text('Pick Product', style: TextStyle(fontSize: 18)),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(60),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            )
          else
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Theme.of(context).colorScheme.primaryContainer),
              ),
              color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.1),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  child: const Icon(Icons.shopping_bag, color: Colors.white),
                ),
                title: Text(
                  _selectedProduct!.name,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  'Category: ${_selectedProduct!.category} • Stock: ${_selectedProduct!.currentStock} pcs',
                  style: const TextStyle(fontSize: 14),
                ),
                trailing: TextButton(
                  onPressed: _showProductPicker,
                  child: const Text('Change', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ),
          
          if (_selectedProduct != null) ...[
            const SizedBox(height: 32),
            // Enter Sale Pricing
            const Text(
              'Enter Sale Pricing',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            
            // Box 1: Selling Price
            TextField(
              controller: _sellingPriceController,
              decoration: InputDecoration(
                labelText: 'Selling Price *',
                prefixText: '₹ ',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                helperText: 'Enter price sold to this customer',
              ),
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
              onChanged: (val) {
                // Pre-fill Amount Paid Now with Selling Price as they type
                setState(() {});
              },
            ),
            const SizedBox(height: 20),

            // Box 2: Amount Paid Now
            TextField(
              controller: _paidController,
              decoration: InputDecoration(
                labelText: 'Amount Paid Now',
                prefixText: '₹ ',
                hintText: _sellingPriceController.text.isEmpty ? '0' : _sellingPriceController.text,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                helperText: 'Leave empty for full payment',
              ),
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.green),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 40),

            // Save button
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
          // Handle bar
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
