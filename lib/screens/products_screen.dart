import 'package:flutter/material.dart';
import '../data/database_helper.dart';
import '../models/product.dart';
import 'add_edit_product_screen.dart';

/// Full-featured product management screen with search, categories,
/// stock indicators, and swipe-to-delete.
class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  final _db = DatabaseHelper.instance;
  List<Product> _allProducts = [];
  List<Product> _filteredProducts = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String? _selectedCategory;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    setState(() => _isLoading = true);
    final products = await _db.getAllProducts();
    setState(() {
      _allProducts = products;
      _applyFilters();
      _isLoading = false;
    });
  }

  void _applyFilters() {
    var filtered = _allProducts;

    // Category filter
    if (_selectedCategory != null) {
      filtered = filtered.where((p) => p.category == _selectedCategory).toList();
    }

    // Search filter
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((p) {
        return p.name.toLowerCase().contains(query) ||
            p.malayalamName.toLowerCase().contains(query) ||
            (p.brand?.toLowerCase().contains(query) ?? false) ||
            p.aliases.any((a) => a.toLowerCase().contains(query));
      }).toList();
    }

    _filteredProducts = filtered;
  }

  List<String> get _categories {
    final cats = _allProducts
        .map((p) => p.category)
        .where((c) => c != null && c.isNotEmpty)
        .cast<String>()
        .toSet()
        .toList()
      ..sort();
    return cats;
  }

  Future<void> _deleteProduct(Product product) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Product'),
        content: Text('Are you sure you want to delete "${product.name}"?\n\nThis action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && product.id != null) {
      await _db.deleteProduct(product.id!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${product.name} deleted')),
        );
      }
      _loadProducts();
    }
  }

  Future<void> _navigateToAddProduct() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const AddEditProductScreen()),
    );
    if (result == true) _loadProducts();
  }

  Future<void> _navigateToEditProduct(Product product) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => AddEditProductScreen(product: product)),
    );
    if (result == true) _loadProducts();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final lowStockCount = _allProducts.where((p) => p.stockQuantity <= 5).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Products'),
        actions: [
          if (lowStockCount > 0)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Chip(
                avatar: Icon(Icons.warning_amber_rounded, color: colors.error, size: 18),
                label: Text('$lowStockCount low stock',
                    style: TextStyle(color: colors.error, fontSize: 12)),
                backgroundColor: colors.errorContainer.withOpacity(0.5),
                side: BorderSide.none,
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('addProductFab'),
        onPressed: _navigateToAddProduct,
        icon: const Icon(Icons.add),
        label: const Text('Add Product'),
      ),
      body: Column(
        children: [
          // ─── Search bar ───
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search products...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                            _applyFilters();
                          });
                        },
                      )
                    : null,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                filled: true,
                fillColor: colors.surfaceContainerHighest.withOpacity(0.3),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                  _applyFilters();
                });
              },
            ),
          ),

          // ─── Category chips ───
          if (_categories.isNotEmpty)
            SizedBox(
              height: 48,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: FilterChip(
                      label: const Text('All'),
                      selected: _selectedCategory == null,
                      onSelected: (_) => setState(() {
                        _selectedCategory = null;
                        _applyFilters();
                      }),
                    ),
                  ),
                  for (final cat in _categories)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: FilterChip(
                        label: Text(cat),
                        selected: _selectedCategory == cat,
                        onSelected: (_) => setState(() {
                          _selectedCategory = _selectedCategory == cat ? null : cat;
                          _applyFilters();
                        }),
                      ),
                    ),
                ],
              ),
            ),

          const SizedBox(height: 4),

          // ─── Summary bar ───
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text(
                  '${_filteredProducts.length} product${_filteredProducts.length == 1 ? '' : 's'}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const Spacer(),
                if (_selectedCategory != null)
                  TextButton.icon(
                    onPressed: () => setState(() {
                      _selectedCategory = null;
                      _applyFilters();
                    }),
                    icon: const Icon(Icons.clear, size: 16),
                    label: const Text('Clear filter'),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
              ],
            ),
          ),

          // ─── Product list ───
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredProducts.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.inventory_2_outlined, size: 64, color: colors.outline),
                            const SizedBox(height: 16),
                            Text(
                              _searchQuery.isNotEmpty
                                  ? 'No products match "$_searchQuery"'
                                  : 'No products yet',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            const Text('Tap + to add your first product'),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.only(bottom: 88),
                        itemCount: _filteredProducts.length,
                        itemBuilder: (context, index) {
                          final product = _filteredProducts[index];
                          return _ProductTile(
                            product: product,
                            onTap: () => _navigateToEditProduct(product),
                            onDelete: () => _deleteProduct(product),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

class _ProductTile extends StatelessWidget {
  const _ProductTile({
    required this.product,
    required this.onTap,
    required this.onDelete,
  });

  final Product product;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isLowStock = product.stockQuantity <= 5;
    final isOutOfStock = product.stockQuantity <= 0;

    return Dismissible(
      key: Key('product_${product.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        color: colors.error,
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      confirmDismiss: (_) async {
        onDelete();
        return false; // We handle deletion ourselves with a dialog
      },
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: CircleAvatar(
          backgroundColor: isOutOfStock
              ? colors.errorContainer
              : isLowStock
                  ? Colors.orange.withOpacity(0.15)
                  : colors.primaryContainer,
          child: Text(
            product.name[0].toUpperCase(),
            style: TextStyle(
              color: isOutOfStock
                  ? colors.onErrorContainer
                  : isLowStock
                      ? Colors.orange.shade800
                      : colors.onPrimaryContainer,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                product.name,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            Text(
              '₹${product.price.toStringAsFixed(product.price == product.price.roundToDouble() ? 0 : 2)}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: colors.primary,
                fontSize: 15,
              ),
            ),
          ],
        ),
        subtitle: Row(
          children: [
            if (product.malayalamName.isNotEmpty) ...[
              Text(product.malayalamName, style: const TextStyle(fontSize: 12)),
              const SizedBox(width: 8),
            ],
            if (product.category != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: colors.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  product.category!,
                  style: TextStyle(fontSize: 10, color: colors.onSurfaceVariant),
                ),
              ),
              const SizedBox(width: 8),
            ],
            const Spacer(),
            // Stock indicator
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isOutOfStock
                    ? colors.errorContainer
                    : isLowStock
                        ? Colors.orange.withOpacity(0.15)
                        : Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isOutOfStock
                        ? Icons.error_outline
                        : isLowStock
                            ? Icons.warning_amber_rounded
                            : Icons.check_circle_outline,
                    size: 12,
                    color: isOutOfStock
                        ? colors.error
                        : isLowStock
                            ? Colors.orange.shade700
                            : Colors.green.shade700,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    isOutOfStock
                        ? 'Out of stock'
                        : '${product.stockQuantity} ${product.unit ?? 'pcs'}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: isOutOfStock
                          ? colors.error
                          : isLowStock
                              ? Colors.orange.shade700
                              : Colors.green.shade700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        onTap: onTap,
      ),
    );
  }
}
