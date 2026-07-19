import 'package:flutter/material.dart';
import '../data/database_helper.dart';
import '../models/product.dart';

/// Screen for adding a new product or editing an existing one.
/// Supports full product fields: name, Malayalam name, category, brand,
/// price, GST%, unit, stock, barcode, and aliases.
class AddEditProductScreen extends StatefulWidget {
  const AddEditProductScreen({this.product, super.key});

  /// If null, we are adding a new product. If provided, we are editing.
  final Product? product;

  bool get isEditing => product != null;

  @override
  State<AddEditProductScreen> createState() => _AddEditProductScreenState();
}

class _AddEditProductScreenState extends State<AddEditProductScreen> {
  final _formKey = GlobalKey<FormState>();
  final _db = DatabaseHelper.instance;

  late final TextEditingController _nameController;
  late final TextEditingController _malayalamNameController;
  late final TextEditingController _categoryController;
  late final TextEditingController _brandController;
  late final TextEditingController _priceController;
  late final TextEditingController _gstController;
  late final TextEditingController _unitController;
  late final TextEditingController _stockController;
  late final TextEditingController _barcodeController;
  late final TextEditingController _aliasController;
  late List<String> _aliases;

  bool _isSaving = false;

  // Common categories for quick selection
  static const _commonCategories = [
    'Dairy',
    'Bakery',
    'Biscuits',
    'Snacks',
    'Beverages',
    'Personal Care',
    'Staples',
    'Instant',
    'Household',
    'Frozen',
    'Fruits & Vegetables',
    'Spices',
    'Pulses',
    'Oil & Ghee',
    'Cleaning',
  ];

  // Common units
  static const _commonUnits = [
    'pcs', 'kg', 'g', '500g', '250g', '100g',
    'L', '500ml', '250ml', '200ml', '100ml',
    'sachet', 'packet', 'bottle', 'box', 'dozen',
  ];

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    _nameController = TextEditingController(text: p?.name ?? '');
    _malayalamNameController = TextEditingController(text: p?.malayalamName ?? '');
    _categoryController = TextEditingController(text: p?.category ?? '');
    _brandController = TextEditingController(text: p?.brand ?? '');
    _priceController = TextEditingController(
      text: p != null ? p.price.toStringAsFixed(p.price == p.price.roundToDouble() ? 0 : 2) : '',
    );
    _gstController = TextEditingController(
      text: p != null ? p.gstPercentage.toStringAsFixed(0) : '0',
    );
    _unitController = TextEditingController(text: p?.unit ?? '');
    _stockController = TextEditingController(text: p?.stockQuantity.toString() ?? '0');
    _barcodeController = TextEditingController(text: p?.barcode ?? '');
    _aliasController = TextEditingController();
    _aliases = List<String>.from(p?.aliases ?? []);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _malayalamNameController.dispose();
    _categoryController.dispose();
    _brandController.dispose();
    _priceController.dispose();
    _gstController.dispose();
    _unitController.dispose();
    _stockController.dispose();
    _barcodeController.dispose();
    _aliasController.dispose();
    super.dispose();
  }

  void _addAlias() {
    final alias = _aliasController.text.trim();
    if (alias.isNotEmpty && !_aliases.contains(alias)) {
      setState(() {
        _aliases.add(alias);
        _aliasController.clear();
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    // Auto-generate aliases from name, Malayalam name, and brand
    final autoAliases = <String>{};
    final name = _nameController.text.trim();
    final malName = _malayalamNameController.text.trim();
    final brand = _brandController.text.trim();

    autoAliases.add(name.toLowerCase());
    if (malName.isNotEmpty) autoAliases.add(malName);
    if (brand.isNotEmpty) {
      autoAliases.add(brand.toLowerCase());
      autoAliases.add('${brand.toLowerCase()} ${name.toLowerCase()}');
    }
    // Add user-defined aliases
    autoAliases.addAll(_aliases.map((a) => a.toLowerCase()));

    final product = Product(
      id: widget.product?.id,
      name: name,
      malayalamName: malName,
      category: _categoryController.text.trim().isEmpty ? null : _categoryController.text.trim(),
      brand: brand.isEmpty ? null : brand,
      price: double.tryParse(_priceController.text) ?? 0,
      gstPercentage: double.tryParse(_gstController.text) ?? 0,
      unit: _unitController.text.trim().isEmpty ? null : _unitController.text.trim(),
      stockQuantity: int.tryParse(_stockController.text) ?? 0,
      barcode: _barcodeController.text.trim().isEmpty ? null : _barcodeController.text.trim(),
      aliases: autoAliases.toList(),
    );

    try {
      if (widget.isEditing) {
        await _db.updateProduct(product);
      } else {
        await _db.insertProduct(product);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.isEditing ? '${product.name} updated' : '${product.name} added'),
          backgroundColor: Theme.of(context).colorScheme.primary,
        ),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      setState(() => _isSaving = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Edit Product' : 'Add Product'),
        actions: [
          TextButton.icon(
            onPressed: _isSaving ? null : _save,
            icon: _isSaving
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: colors.primary),
                  )
                : const Icon(Icons.check),
            label: Text(widget.isEditing ? 'Save' : 'Add'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // ─── Section: Basic Info ───
            _SectionHeader(title: 'Basic Information', icon: Icons.info_outline),
            const SizedBox(height: 12),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Product Name *',
                hintText: 'e.g. Milk, Bread, Soap',
                prefixIcon: Icon(Icons.inventory_2_outlined),
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.words,
              validator: (v) => v == null || v.trim().isEmpty ? 'Name is required' : null,
              autofocus: !widget.isEditing,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _malayalamNameController,
              decoration: const InputDecoration(
                labelText: 'Malayalam Name',
                hintText: 'e.g. പാൽ, ബ്രെഡ്',
                prefixIcon: Icon(Icons.translate),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _categoryController,
                    decoration: InputDecoration(
                      labelText: 'Category',
                      hintText: 'e.g. Dairy',
                      prefixIcon: const Icon(Icons.category_outlined),
                      border: const OutlineInputBorder(),
                      suffixIcon: PopupMenuButton<String>(
                        icon: const Icon(Icons.arrow_drop_down),
                        onSelected: (value) => _categoryController.text = value,
                        itemBuilder: (_) => _commonCategories
                            .map((c) => PopupMenuItem(value: c, child: Text(c)))
                            .toList(),
                      ),
                    ),
                    textCapitalization: TextCapitalization.words,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _brandController,
                    decoration: const InputDecoration(
                      labelText: 'Brand',
                      hintText: 'e.g. Amul',
                      prefixIcon: Icon(Icons.business_outlined),
                      border: OutlineInputBorder(),
                    ),
                    textCapitalization: TextCapitalization.words,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 28),

            // ─── Section: Pricing ───
            _SectionHeader(title: 'Pricing', icon: Icons.currency_rupee),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _priceController,
                    decoration: const InputDecoration(
                      labelText: 'Price *',
                      prefixText: '₹ ',
                      prefixIcon: Icon(Icons.payments_outlined),
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Price is required';
                      final price = double.tryParse(v);
                      if (price == null || price < 0) return 'Invalid price';
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _gstController,
                    decoration: const InputDecoration(
                      labelText: 'GST %',
                      suffixText: '%',
                      prefixIcon: Icon(Icons.receipt_outlined),
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 28),

            // ─── Section: Inventory ───
            _SectionHeader(title: 'Inventory', icon: Icons.warehouse_outlined),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _stockController,
                    decoration: const InputDecoration(
                      labelText: 'Stock Quantity',
                      prefixIcon: Icon(Icons.inventory_outlined),
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _unitController,
                    decoration: InputDecoration(
                      labelText: 'Unit',
                      hintText: 'e.g. kg, pcs',
                      prefixIcon: const Icon(Icons.straighten),
                      border: const OutlineInputBorder(),
                      suffixIcon: PopupMenuButton<String>(
                        icon: const Icon(Icons.arrow_drop_down),
                        onSelected: (value) => _unitController.text = value,
                        itemBuilder: (_) => _commonUnits
                            .map((u) => PopupMenuItem(value: u, child: Text(u)))
                            .toList(),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _barcodeController,
              decoration: const InputDecoration(
                labelText: 'Barcode (optional)',
                prefixIcon: Icon(Icons.qr_code),
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),

            const SizedBox(height: 28),

            // ─── Section: Voice Aliases ───
            _SectionHeader(
              title: 'Voice Aliases',
              icon: Icons.mic_outlined,
              subtitle: 'Add alternative names so voice billing can match this product',
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _aliasController,
                    decoration: const InputDecoration(
                      hintText: 'Add an alias (e.g. "paal", "doodh")',
                      prefixIcon: Icon(Icons.add),
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _addAlias(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: _addAlias,
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_aliases.isNotEmpty)
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: _aliases.map((alias) {
                  return Chip(
                    label: Text(alias, style: const TextStyle(fontSize: 13)),
                    deleteIcon: const Icon(Icons.close, size: 16),
                    onDeleted: () => setState(() => _aliases.remove(alias)),
                    visualDensity: VisualDensity.compact,
                    backgroundColor: colors.surfaceContainerHighest,
                  );
                }).toList(),
              )
            else
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Aliases will be auto-generated from the product name, Malayalam name, and brand.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),

            const SizedBox(height: 32),

            // ─── Save button ───
            FilledButton.icon(
              onPressed: _isSaving ? null : _save,
              icon: _isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Icon(widget.isEditing ? Icons.save : Icons.add),
              label: Text(widget.isEditing ? 'Save Changes' : 'Add Product'),
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.icon,
    this.subtitle,
  });

  final String title;
  final IconData icon;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 20, color: colors.primary),
            const SizedBox(width: 8),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: colors.primary,
              ),
            ),
          ],
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 2),
          Padding(
            padding: const EdgeInsets.only(left: 28),
            child: Text(
              subtitle!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
