import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'package:kd_pannel/app_theme.dart';
import 'package:kd_pannel/core/responsive/responsive.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kd_pannel/features/shared/widgets/main_layout.dart';
import 'create_product_page.dart';

class ProductsPage extends StatefulWidget {
  const ProductsPage({super.key});

  @override
  State<ProductsPage> createState() => _ProductsPageState();
}

class _ProductsPageState extends State<ProductsPage> {
  final ScrollController _scrollController = ScrollController();
  String _searchQuery = '';
  String _selectedCategory = 'All Categories';
  String _selectedSubCategory = 'All Sub-categories';
  String _selectedAvailability = 'All Availability';

  final List<String> _categories = [
    'All Categories',
    'Irrigation',
    'Seeds',
    'Machinery',
    'Fertilizers',
  ];

  final List<String> _availabilityOptions = [
    'All Availability',
    'In Stock',
    'Not in Stock',
  ];

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  final List<Map<String, dynamic>> _products = [
    {
      'sku': 'PROD-IRR-001',
      'name': 'Drip Irrigation Kit',
      'category': 'Irrigation',
      'subCategory': 'Drip',
      'vendor': 'Jain Irrigation',
      'price': '₹2,400',
      'inStock': true,
      'variants': [
        {
          'price': '2400',
          'compareAtPrice': '2800',
          'packSize': '50m',
          'baseQuantity': '1',
        },
        {
          'price': '4500',
          'compareAtPrice': '5200',
          'packSize': '100m',
          'baseQuantity': '1',
        },
      ],
    },
    {
      'sku': 'PROD-SEE-002',
      'name': 'Hybrid Seed Pack',
      'category': 'Seeds',
      'subCategory': 'Vegetable',
      'vendor': 'Mahyco',
      'price': '₹650',
      'inStock': true,
      'variants': [
        {
          'price': '650',
          'compareAtPrice': '750',
          'packSize': '100g',
          'baseQuantity': '1',
        },
        {
          'price': '1200',
          'compareAtPrice': '1400',
          'packSize': '250g',
          'baseQuantity': '1',
        },
        {
          'price': '2200',
          'compareAtPrice': '2500',
          'packSize': '500g',
          'baseQuantity': '1',
        },
      ],
    },
    {
      'sku': 'PROD-MAC-003',
      'name': 'Water Pump 5HP',
      'category': 'Machinery',
      'subCategory': 'Pumps',
      'vendor': 'Kirloskar',
      'price': '₹11,500',
      'inStock': true,
      'variants': [
        {
          'price': '11500',
          'compareAtPrice': '13000',
          'packSize': '1 Unit',
          'baseQuantity': '1',
        },
      ],
    },
    {
      'sku': 'PROD-FER-004',
      'name': 'Fertilizer Blend X',
      'category': 'Fertilizers',
      'subCategory': 'Organic',
      'vendor': 'IFFCO',
      'price': '₹980',
      'inStock': false,
      'variants': [
        {
          'price': '980',
          'compareAtPrice': '1100',
          'packSize': '10kg',
          'baseQuantity': '1',
        },
        {
          'price': '1800',
          'compareAtPrice': '2000',
          'packSize': '20kg',
          'baseQuantity': '1',
        },
      ],
    },
    {
      'sku': 'PROD-IRR-005',
      'name': 'Micro Sprinkler Set',
      'category': 'Irrigation',
      'subCategory': 'Sprinkler',
      'vendor': 'Netafim',
      'price': '₹3,200',
      'inStock': true,
      'variants': [
        {
          'price': '3200',
          'compareAtPrice': '3600',
          'packSize': '1 Unit',
          'baseQuantity': '1',
        },
      ],
    },
  ];

  List<String> get _subCategories {
    switch (_selectedCategory) {
      case 'Irrigation':
        return ['All Sub-categories', 'Drip', 'Sprinkler'];
      case 'Seeds':
        return ['All Sub-categories', 'Vegetable', 'Grain'];
      case 'Machinery':
        return ['All Sub-categories', 'Pumps', 'Tillers'];
      case 'Fertilizers':
        return ['All Sub-categories', 'Organic', 'NPK'];
      default:
        return ['All Sub-categories'];
    }
  }

  void _onCategoryChanged(String newCat) {
    setState(() {
      _selectedCategory = newCat;
      _selectedSubCategory = 'All Sub-categories';
    });
  }

  List<Map<String, dynamic>> get _filteredProducts {
    return _products.where((prod) {
      final matchesSearch =
          prod['name'].toString().toLowerCase().contains(
            _searchQuery.toLowerCase(),
          ) ||
          (prod['sku'] ?? '').toString().toLowerCase().contains(
            _searchQuery.toLowerCase(),
          );
      final matchesCategory =
          _selectedCategory == 'All Categories' ||
          prod['category'] == _selectedCategory;
      final matchesSubCategory =
          _selectedSubCategory == 'All Sub-categories' ||
          prod['subCategory'] == _selectedSubCategory;
      final matchesAvailability =
          _selectedAvailability == 'All Availability' ||
          (prod['inStock'] as bool) == (_selectedAvailability == 'In Stock');

      return matchesSearch &&
          matchesCategory &&
          matchesSubCategory &&
          matchesAvailability;
    }).toList();
  }

  void _startAddProduct() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MainLayout(
          child: CreateProductPage(
            onSave: (newProduct) {
              setState(() {
                _products.insert(0, newProduct);
              });
            },
          ),
        ),
      ),
    );
  }

  void _startEditProduct(Map<String, dynamic> product) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MainLayout(
          child: CreateProductPage(
            initialData: product,
            onSave: (updatedProduct) {
              setState(() {
                final index = _products.indexOf(product);
                if (index != -1) {
                  _products[index] = updatedProduct;
                }
              });
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isMobile = Responsive.isMobile(context);

    return SingleChildScrollView(
      controller: _scrollController,
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      padding: AppTheme.getResponsivePadding(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Product Catalogue',
                    style: GoogleFonts.outfit(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'View and manage agricultural products, categories and sub-categories',
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: _startAddProduct,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Add Product'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: AppTheme.spacingLarge),

          // Search & Filter Row
          _buildFiltersRow(isMobile),
          SizedBox(height: AppTheme.spacingMedium),

          // Table
          _buildProductsTable(isMobile),
        ],
      ),
    );
  }

  Widget _buildFiltersRow(bool isMobile) {
    final Widget searchField = Container(
      height: 38,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: TextField(
        onChanged: (val) => setState(() => _searchQuery = val),
        textAlignVertical: TextAlignVertical.center,
        style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary),
        decoration: const InputDecoration(
          hintText: 'Search SKU or name...',
          hintStyle: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
          prefixIcon: Icon(
            Icons.search,
            size: 18,
            color: AppTheme.textSecondary,
          ),
          border: InputBorder.none,
          isDense: true,
          contentPadding: EdgeInsets.zero,
        ),
      ),
    );

    if (isMobile) {
      return Column(
        children: [
          searchField,
          const SizedBox(height: 10),
          _buildDropdown(
            _categories,
            _selectedCategory,
            (val) => _onCategoryChanged(val!),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildDropdown(
                  _subCategories,
                  _selectedSubCategory,
                  (val) => setState(() => _selectedSubCategory = val!),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildDropdown(
                  _availabilityOptions,
                  _selectedAvailability,
                  (val) => setState(() => _selectedAvailability = val!),
                ),
              ),
            ],
          ),
        ],
      );
    }

    return Row(
      children: [
        SizedBox(width: 260, child: searchField),
        const SizedBox(width: 12),
        _buildDropdown(
          _categories,
          _selectedCategory,
          (val) => _onCategoryChanged(val!),
          width: 160,
        ),
        const SizedBox(width: 12),
        _buildDropdown(
          _subCategories,
          _selectedSubCategory,
          (val) => setState(() => _selectedSubCategory = val!),
          width: 160,
        ),
        const SizedBox(width: 12),
        _buildDropdown(
          _availabilityOptions,
          _selectedAvailability,
          (val) => setState(() => _selectedAvailability = val!),
          width: 160,
        ),
      ],
    );
  }

  Widget _buildDropdown(
    List<String> options,
    String currentValue,
    ValueChanged<String?> onChanged, {
    double? width,
  }) {
    final safeValue = options.contains(currentValue)
        ? currentValue
        : options.first;

    return Container(
      height: 38,
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: safeValue,
          onChanged: onChanged,
          icon: const Icon(
            Icons.keyboard_arrow_down,
            size: 16,
            color: AppTheme.textSecondary,
          ),
          items: options
              .map<DropdownMenuItem<String>>(
                (val) => DropdownMenuItem<String>(
                  value: val,
                  child: Text(
                    val,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppTheme.textBody,
                    ),
                  ),
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  Widget _buildProductsTable(bool isMobile) {
    final filtered = _filteredProducts;

    final header = Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      color: const Color(0xFFF9FAFB),
      child: Row(
        children: const [
          SizedBox(width: 250, child: _TableHeaderText('PRODUCT DETAIL')),
          SizedBox(width: 150, child: _TableHeaderText('CATEGORY')),
          SizedBox(width: 100, child: _TableHeaderText('VARIANTS')),
          SizedBox(width: 100, child: _TableHeaderText('UNIT PRICE')),
          SizedBox(width: 120, child: _TableHeaderText('AVAILABILITY')),
          SizedBox(width: 80),
        ],
      ),
    );

    Widget tableBody;
    if (filtered.isEmpty) {
      tableBody = Container(
        padding: const EdgeInsets.all(40),
        child: const Center(
          child: Text(
            'No products match your filters',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
          ),
        ),
      );
    } else {
      tableBody = Column(
        children: filtered.asMap().entries.map((entry) {
          final isEven = entry.key % 2 == 0;
          final prod = entry.value;
          final variantsList = prod['variants'] as List?;
          final int variantCount = variantsList?.length ?? 1;

          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: isEven ? Colors.white : const Color(0xFFF9FAFB),
              border: const Border(
                bottom: BorderSide(color: AppTheme.lightBorderColor),
              ),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 250,
                  child: Row(
                    children: [
                      _buildProductThumbnail(prod),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              prod['name'] as String,
                              style: GoogleFonts.outfit(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${prod['sku'] ?? 'N/A'}${prod['vendor'] != null && (prod['vendor'] as String).isNotEmpty ? '  •  ${prod['vendor']}' : ''}',
                              style: GoogleFonts.outfit(
                                fontSize: 11,
                                color: AppTheme.textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: 150,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        prod['category'] as String,
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          prod['subCategory'] as String,
                          style: GoogleFonts.outfit(
                            fontSize: 10,
                            color: AppTheme.primaryColor,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: 100,
                  child: Text(
                    '$variantCount Variant${variantCount > 1 ? 's' : ''}',
                    style: GoogleFonts.outfit(
                      fontSize: 12.5,
                      color: AppTheme.textBody,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                SizedBox(
                  width: 100,
                  child: Text(
                    prod['price'] as String,
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                SizedBox(
                  width: 120,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: _buildAvailabilityBadge(prod),
                  ),
                ),
                SizedBox(
                  width: 80,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: _buildRowActionButtons(prod),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      );
    }

    final tableWidget = Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
        border: Border.all(color: AppTheme.borderColor),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        children: [
          header,
          const Divider(height: 1, color: AppTheme.lightBorderColor),
          tableBody,
        ],
      ),
    );

    if (!isMobile) return tableWidget;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(width: 800, child: tableWidget),
    );
  }

  Widget _buildAvailabilityBadge(Map<String, dynamic> prod) {
    final bool inStock = prod['inStock'] as bool;
    final Color color = inStock ? AppTheme.success : AppTheme.error;
    final String label = inStock ? 'In Stock' : 'Out of Stock';

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => setState(() => prod['inStock'] = !inStock),
        child: Tooltip(
          message: 'Click to toggle availability',
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: color.withValues(alpha: 0.25)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: GoogleFonts.outfit(
                    color: color,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Map<String, dynamic> _getCategoryStyle(String category) {
    switch (category) {
      case 'Irrigation':
        return {
          'icon': Icons.water_drop_outlined,
          'color': Colors.blue.shade600,
          'bg': Colors.blue.shade50,
        };
      case 'Seeds':
        return {
          'icon': Icons.spa_outlined,
          'color': Colors.green.shade600,
          'bg': Colors.green.shade50,
        };
      case 'Machinery':
        return {
          'icon': Icons.agriculture_outlined,
          'color': Colors.orange.shade700,
          'bg': Colors.orange.shade50,
        };
      case 'Fertilizers':
        return {
          'icon': Icons.layers_outlined,
          'color': Colors.purple.shade600,
          'bg': Colors.purple.shade50,
        };
      default:
        return {
          'icon': Icons.category_outlined,
          'color': Colors.teal.shade600,
          'bg': Colors.teal.shade50,
        };
    }
  }

  Widget _buildProductThumbnail(Map<String, dynamic> prod) {
    return RepaintBoundary(child: _buildThumbnailContent(prod));
  }

  Widget _buildThumbnailContent(Map<String, dynamic> prod) {
    final style = _getCategoryStyle(prod['category'] ?? '');

    // Check if there are Uint8List images
    if (prod['images'] != null && (prod['images'] as List).isNotEmpty) {
      final img = (prod['images'] as List).first;
      if (img is Uint8List) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.memory(
            img,
            width: 36,
            height: 36,
            fit: BoxFit.cover,
            cacheWidth: 72,
            cacheHeight: 72,
          ),
        );
      }
    }

    // Check if there's a variant image or asset image
    if (prod['image'] != null) {
      final img = prod['image'];
      if (img is Uint8List) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.memory(
            img,
            width: 36,
            height: 36,
            fit: BoxFit.cover,
            cacheWidth: 72,
            cacheHeight: 72,
          ),
        );
      }
    }

    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: style['bg'] as Color,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: (style['color'] as Color).withValues(alpha: 0.15),
          width: 1,
        ),
      ),
      child: Icon(
        style['icon'] as IconData,
        size: 18,
        color: style['color'] as Color,
      ),
    );
  }

  Widget _buildRowActionButtons(Map<String, dynamic> prod) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        _buildActionTile(
          icon: Icons.edit_outlined,
          tooltip: 'Edit Product',
          color: AppTheme.primaryColor,
          bgColor: AppTheme.primaryColor.withValues(alpha: 0.06),
          onTap: () => _startEditProduct(prod),
        ),
        const SizedBox(width: 8),
        _buildActionTile(
          icon: Icons.delete_outline_rounded,
          tooltip: 'Delete Product',
          color: AppTheme.error,
          bgColor: AppTheme.error.withValues(alpha: 0.06),
          onTap: () => _showDeleteConfirmation(prod),
        ),
      ],
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String tooltip,
    required Color color,
    required Color bgColor,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      textStyle: GoogleFonts.outfit(fontSize: 11, color: Colors.white),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          hoverColor: color.withValues(alpha: 0.12),
          highlightColor: color.withValues(alpha: 0.2),
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: color.withValues(alpha: 0.15),
                width: 1,
              ),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
        ),
      ),
    );
  }

  void _showDeleteConfirmation(Map<String, dynamic> prod) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.error.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.warning_amber_rounded,
                color: AppTheme.error,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Delete Product',
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to delete "${prod['name']}"? This action cannot be undone.',
          style: GoogleFonts.outfit(
            fontSize: 14,
            color: AppTheme.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.outfit(
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _products.remove(prod);
              });
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: AppTheme.error,
                  behavior: SnackBarBehavior.floating,
                  content: Text(
                    'Product deleted successfully',
                    style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                  ),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.error,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              'Delete',
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TableHeaderText extends StatelessWidget {
  final String text;
  const _TableHeaderText(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: GoogleFonts.outfit(
        fontSize: 11,
        fontWeight: FontWeight.bold,
        color: AppTheme.textSecondary,
      ),
    );
  }
}
