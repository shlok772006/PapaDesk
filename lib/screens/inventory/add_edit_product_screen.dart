import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/product.dart';
import '../../providers/product_providers.dart';
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
  late TextEditingController _purchasePriceController;
  late TextEditingController _minStockController;
  late TextEditingController _initialStockController;
  late TextEditingController _customCategoryController;
  
  bool _saving = false;
  String? _imageBase64;
  String? _selectedCategory;
  bool _showCustomCategoryInput = false;

  bool get isEdit => widget.product != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.product?.name ?? '');
    _purchasePriceController =
        TextEditingController(text: widget.product?.purchasePrice.toStringAsFixed(0) ?? '');
    _minStockController =
        TextEditingController(text: widget.product?.minStock.toString() ?? '5');
    _initialStockController =
        TextEditingController(text: widget.product?.currentStock.toString() ?? '0');
    _customCategoryController = TextEditingController();
    _imageBase64 = widget.product?.imageBase64;
    
    final category = widget.product?.category ?? '';
    if (category.isNotEmpty) {
      _selectedCategory = category;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _purchasePriceController.dispose();
    _minStockController.dispose();
    _initialStockController.dispose();
    _customCategoryController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    final name = _nameController.text.trim();
    final category = _showCustomCategoryInput
        ? _customCategoryController.text.trim()
        : (_selectedCategory ?? '');
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
    final categoriesList = ref.watch(categoriesProvider);
    final dropdownItems = <String>[...categoriesList];
    if (_selectedCategory != null && _selectedCategory != 'custom' && !dropdownItems.contains(_selectedCategory)) {
      dropdownItems.add(_selectedCategory!);
    }

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

            // Category field (Dropdown + Custom Input)
            DropdownButtonFormField<String>(
              // ignore: deprecated_member_use
              value: _selectedCategory,
              decoration: InputDecoration(
                labelText: 'Category',
                prefixIcon: const Icon(Icons.category),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              hint: const Text('Select category'),
              items: [
                ...dropdownItems.map((cat) => DropdownMenuItem(
                      value: cat,
                      child: Text(cat),
                    )),
                const DropdownMenuItem(
                  value: 'custom',
                  child: Text('+ Add New Category', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
                ),
              ],
              onChanged: (val) {
                setState(() {
                  _selectedCategory = val;
                  _showCustomCategoryInput = val == 'custom';
                });
              },
            ),
            if (_showCustomCategoryInput) ...[
              const SizedBox(height: 16),
              TextFormField(
                controller: _customCategoryController,
                decoration: InputDecoration(
                  labelText: 'New Category Name *',
                  hintText: 'Enter new category name',
                  prefixIcon: const Icon(Icons.edit_note),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                style: const TextStyle(fontSize: 18),
                textCapitalization: TextCapitalization.words,
                validator: (value) {
                  if (_showCustomCategoryInput && (value == null || value.trim().isEmpty)) {
                    return 'Please enter category name';
                  }
                  return null;
                },
              ),
            ],
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
                if (value == null || value.trim().isEmpty) {
                  return 'Enter a price';
                }
                final val = double.tryParse(value);
                if (val == null || val < 0) {
                  return 'Enter a valid price (₹0 or more)';
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
                    validator: (value) {
                      if (value != null && value.trim().isNotEmpty) {
                        final val = int.tryParse(value);
                        if (val == null || val < 0) {
                          return 'Enter 0 or more';
                        }
                      }
                      return null;
                    },
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
                    validator: (value) {
                      if (!isEdit) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Enter stock';
                        }
                        final val = int.tryParse(value);
                        if (val == null || val < 0) {
                          return 'Enter 0 or more';
                        }
                      }
                      return null;
                    },
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
