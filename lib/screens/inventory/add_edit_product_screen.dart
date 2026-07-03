import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/product.dart';
import '../../providers/repository_providers.dart';
import '../../utils/image_picker_helper.dart';
import '../../widgets/product_image_widget.dart';

class AddEditProductScreen extends ConsumerStatefulWidget {
  final Product? product;

  const AddEditProductScreen({super.key, this.product});

  @override
  ConsumerState<AddEditProductScreen> createState() => _AddEditProductScreenState();
}

class _AddEditProductScreenState extends ConsumerState<AddEditProductScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _categoryController;
  late TextEditingController _purchasePriceController;
  late TextEditingController _minStockController;
  late TextEditingController _initialStockController;
  bool _saving = false;
  String? _imageBase64;

  bool get isEdit => widget.product != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.product?.name ?? '');
    _categoryController = TextEditingController(text: widget.product?.category ?? '');
    _purchasePriceController =
        TextEditingController(text: widget.product?.purchasePrice.toStringAsFixed(0) ?? '');
    _minStockController =
        TextEditingController(text: widget.product?.minStock.toString() ?? '5');
    _initialStockController =
        TextEditingController(text: widget.product?.currentStock.toString() ?? '0');
    _imageBase64 = widget.product?.imageBase64;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _categoryController.dispose();
    _purchasePriceController.dispose();
    _minStockController.dispose();
    _initialStockController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    final name = _nameController.text.trim();
    final category = _categoryController.text.trim();
    final purchasePrice = double.tryParse(_purchasePriceController.text) ?? 0.0;
    const sellingPrice = 0.0;
    final minStock = int.tryParse(_minStockController.text) ?? 5;
    final initialStock = int.tryParse(_initialStockController.text) ?? 0;

    final repo = ref.read(productRepositoryProvider);

    try {
      if (isEdit) {
        await repo.updateProduct(
          widget.product!.id,
          {
            'name': name,
            'category': category,
            'purchasePrice': purchasePrice,
            'sellingPrice': sellingPrice,
            'minStock': minStock,
            'imageBase64': _imageBase64,
          },
        );
      } else {
        final newProduct = Product(
          id: '',
          name: name,
          category: category,
          purchasePrice: purchasePrice,
          sellingPrice: sellingPrice,
          minStock: minStock,
          currentStock: initialStock,
          imageBase64: _imageBase64,
        );
        await repo.addProduct(newProduct);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isEdit ? 'Product updated ✓' : 'Product added ✓'),
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
    return Scaffold(
      appBar: AppBar(
        title: Text(
          isEdit ? 'Edit Product' : 'Add Product',
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            // Circular Image Picker at the top
            Center(
              child: GestureDetector(
                onTap: () async {
                  final base64 = await pickImageAsBase64();
                  if (base64 != null) {
                    setState(() => _imageBase64 = base64);
                  }
                },
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 56,
                      backgroundColor: Colors.grey[200],
                      child: _imageBase64 == null
                          ? Icon(Icons.shopping_bag_outlined, size: 48, color: Colors.grey[500])
                          : ClipRRect(
                              borderRadius: BorderRadius.circular(56),
                              child: buildProductImage(_imageBase64, size: 112),
                            ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: CircleAvatar(
                        radius: 18,
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        child: const Icon(Icons.camera_alt, size: 18, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Name field
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Product Name *',
                hintText: 'Enter name',
                prefixIcon: const Icon(Icons.shopping_bag),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              style: const TextStyle(fontSize: 18),
              textCapitalization: TextCapitalization.words,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter product name';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),

            // Category field
            TextFormField(
              controller: _categoryController,
              decoration: InputDecoration(
                labelText: 'Category',
                hintText: 'Enter category (e.g., Chargers, Remotes)',
                prefixIcon: const Icon(Icons.category),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              style: const TextStyle(fontSize: 18),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 20),

            // Purchase Price field (Full width)
            TextFormField(
              controller: _purchasePriceController,
              decoration: InputDecoration(
                labelText: 'Purchase Price *',
                prefixText: '₹ ',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.currency_rupee),
              ),
              style: const TextStyle(fontSize: 18),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: (value) {
                if (value == null || double.tryParse(value) == null) {
                  return 'Enter a price';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),

            // Stock Row
            Row(
              children: [
                // Min Stock
                Expanded(
                  child: TextFormField(
                    controller: _minStockController,
                    decoration: InputDecoration(
                      labelText: 'Min Stock Warning',
                      suffixText: 'pcs',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    style: const TextStyle(fontSize: 18),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 16),
                // Initial Stock (Create-only)
                Expanded(
                  child: TextFormField(
                    controller: _initialStockController,
                    enabled: !isEdit,
                    decoration: InputDecoration(
                      labelText: isEdit ? 'Stock (Read Only)' : 'Initial Stock',
                      suffixText: 'pcs',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      helperText: isEdit ? 'Changed via Sales/Purchases' : null,
                    ),
                    style: const TextStyle(fontSize: 18),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 40),

            // Save button
            SizedBox(
              height: 56,
              child: FilledButton.icon(
                onPressed: _saving ? null : _save,
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
                  _saving ? 'Saving...' : 'Save Product',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
