import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kd_pannel/app_theme.dart';
import 'package:kd_pannel/core/network/api_client.dart';
import 'package:kd_pannel/core/responsive/responsive.dart';
import 'package:kd_pannel/features/shared/widgets/main_layout.dart';
import 'package:kd_pannel/features/admin/presentation/pages/create_product_page.dart';
import 'package:animations/animations.dart';
import '../bloc/products_bloc.dart';
import '../bloc/products_event.dart';
import 'package:shimmer/shimmer.dart';

class ProductsTabView extends StatefulWidget {
  final List<Map<String, dynamic>> products;
  final List<dynamic> backendCategories;
  final bool isLoadingProducts;
  final VoidCallback onRefresh;

  const ProductsTabView({
    super.key,
    required this.products,
    required this.backendCategories,
    required this.isLoadingProducts,
    required this.onRefresh,
  });

  @override
  State<ProductsTabView> createState() => _ProductsTabViewState();
}

class _ProductsTabViewState extends State<ProductsTabView> {
  String _searchQuery = '';
  String _selectedCategory = 'All Categories';
  String _selectedSubCategory = 'All Sub-categories';
  String _selectedAvailability = 'All Availability';
  int _currentPage = 1;
  int _rowsPerPage = 10;

  // Filter cache
  List<Map<String, dynamic>> _cachedFilteredProducts = [];
  String _lastSearchQuery = '';
  String _lastCategory = '';
  String _lastSubCategory = '';
  String _lastAvailability = '';
  List<Map<String, dynamic>>? _lastProducts;

  final List<String> _availabilityOptions = [
    'All Availability',
    'In Stock',
    'Not in Stock',
  ];

  List<String> get _categoryOptions {
    final List<String> list = ['All Categories'];
    for (var cat in widget.backendCategories) {
      final name = cat['name']?.toString();
      if (name != null && name.isNotEmpty && !list.contains(name)) {
        list.add(name);
      }
    }
    return list;
  }

  List<String> get _subCategories {
    final List<String> list = ['All Sub-categories'];
    if (widget.backendCategories.isNotEmpty &&
        _selectedCategory != 'All Categories') {
      final matchingCat = widget.backendCategories.firstWhere(
        (c) =>
            c['name'].toString().toLowerCase() ==
            _selectedCategory.toLowerCase(),
        orElse: () => null,
      );
      if (matchingCat != null) {
        final List subs = matchingCat['subCategories'] ?? [];
        for (var sub in subs) {
          final sName = sub['name']?.toString();
          if (sName != null && sName.isNotEmpty && !list.contains(sName)) {
            list.add(sName);
          }
        }
      }
    }
    return list;
  }

  void _onCategoryChanged(String newCat) {
    setState(() {
      _selectedCategory = newCat;
      _selectedSubCategory = 'All Sub-categories';
      _currentPage = 1;
    });
  }

  List<Map<String, dynamic>> get _filteredProducts {
    if (_lastProducts == widget.products &&
        _lastSearchQuery == _searchQuery &&
        _lastCategory == _selectedCategory &&
        _lastSubCategory == _selectedSubCategory &&
        _lastAvailability == _selectedAvailability) {
      return _cachedFilteredProducts;
    }

    _lastProducts = widget.products;
    _lastSearchQuery = _searchQuery;
    _lastCategory = _selectedCategory;
    _lastSubCategory = _selectedSubCategory;
    _lastAvailability = _selectedAvailability;

    _cachedFilteredProducts = widget.products.where((prod) {
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

    return _cachedFilteredProducts;
  }

  void _startEditProduct(Map<String, dynamic> product) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => MainLayout(
          child: CreateProductPage(
            initialData: product,
            preloadedCategories: widget.backendCategories,
            onSave: (updated) {
              widget.onRefresh();
            },
          ),
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return SharedAxisTransition(
            animation: animation,
            secondaryAnimation: secondaryAnimation,
            transitionType: SharedAxisTransitionType.scaled,
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 300),
        reverseTransitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isMobile = Responsive.isMobile(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFiltersRow(isMobile),
        SizedBox(height: AppTheme.spacingMedium),
        SelectionArea(child: _buildProductsTable(isMobile)),
      ],
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
        onChanged: (val) => setState(() {
          _searchQuery = val;
          _currentPage = 1;
        }),
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
            _categoryOptions,
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
                  (val) => setState(() {
                    _selectedSubCategory = val!;
                    _currentPage = 1;
                  }),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildDropdown(
                  _availabilityOptions,
                  _selectedAvailability,
                  (val) => setState(() {
                    _selectedAvailability = val!;
                    _currentPage = 1;
                  }),
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
          _categoryOptions,
          _selectedCategory,
          (val) => _onCategoryChanged(val!),
          width: 160,
        ),
        const SizedBox(width: 12),
        _buildDropdown(
          _subCategories,
          _selectedSubCategory,
          (val) => setState(() {
            _selectedSubCategory = val!;
            _currentPage = 1;
          }),
          width: 160,
        ),
        const SizedBox(width: 12),
        _buildDropdown(
          _availabilityOptions,
          _selectedAvailability,
          (val) => setState(() {
            _selectedAvailability = val!;
            _currentPage = 1;
          }),
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

    final int startIndex = (_currentPage - 1) * _rowsPerPage;
    if (startIndex >= filtered.length && _currentPage > 1) {
      _currentPage = ((filtered.length - 1) / _rowsPerPage).floor() + 1;
      if (_currentPage < 1) _currentPage = 1;
    }

    final int adjustedStartIndex = (_currentPage - 1) * _rowsPerPage;
    final int adjustedEndIndex = adjustedStartIndex + _rowsPerPage;
    final paginatedProducts = filtered.isEmpty
        ? <Map<String, dynamic>>[]
        : filtered.sublist(
            adjustedStartIndex,
            adjustedEndIndex > filtered.length
                ? filtered.length
                : adjustedEndIndex,
          );

    final header = Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      color: const Color(0xFFF9FAFB),
      child: Row(
        children: const [
          Expanded(flex: 8, child: _TableHeaderText('PRODUCT TITLE')),
          Expanded(flex: 4, child: _TableHeaderText('CATEGORY')),
          Expanded(flex: 2, child: _TableHeaderText('VARIANTS')),
          Expanded(flex: 3, child: _TableHeaderText('UNIT PRICE')),
          Expanded(flex: 4, child: _TableHeaderText('AVAILABILITY')),
          SizedBox(width: 80),
        ],
      ),
    );

    Widget tableBody;
    if (widget.isLoadingProducts) {
      tableBody = Column(
        children: const [
          _TableSkeletonRow(),
          _TableSkeletonRow(),
          _TableSkeletonRow(),
          _TableSkeletonRow(),
          _TableSkeletonRow(),
        ],
      );
    } else if (filtered.isEmpty) {
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
        children: paginatedProducts.asMap().entries.map((entry) {
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
                Expanded(
                  flex: 8,
                  child: Row(
                    children: [
                      _buildProductThumbnail(prod),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
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
                Expanded(
                  flex: 4,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        prod['category'] as String,
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
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
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    '$variantCount Variant${variantCount > 1 ? 's' : ''}',
                    style: GoogleFonts.outfit(
                      fontSize: 12.5,
                      color: AppTheme.textBody,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    prod['price'] as String,
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Expanded(
                  flex: 4,
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
          SelectionContainer.disabled(
            child: _buildProductsTableFooter(filtered.length),
          ),
        ],
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final double tableWidth = constraints.maxWidth > 850
            ? constraints.maxWidth
            : 850;
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(width: tableWidth, child: tableWidget),
        );
      },
    );
  }

  Widget _buildProductsTableFooter(int totalEntries) {
    final int startEntry = totalEntries == 0
        ? 0
        : (_currentPage - 1) * _rowsPerPage + 1;
    final int endEntry = (_currentPage * _rowsPerPage) > totalEntries
        ? totalEntries
        : (_currentPage * _rowsPerPage);

    final int totalPages = (totalEntries / _rowsPerPage).ceil();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(12)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Showing $startEntry to $endEntry of $totalEntries entries',
            style: GoogleFonts.outfit(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppTheme.textSecondary,
            ),
          ),
          if (totalPages > 1)
            Row(
              children: [
                _buildPageNavButton(
                  icon: Icons.chevron_left_rounded,
                  onTap: _currentPage > 1
                      ? () => setState(() => _currentPage--)
                      : null,
                ),
                const SizedBox(width: 8),
                ..._buildPageNumbers(totalPages),
                const SizedBox(width: 8),
                _buildPageNavButton(
                  icon: Icons.chevron_right_rounded,
                  onTap: _currentPage < totalPages
                      ? () => setState(() => _currentPage++)
                      : null,
                ),
              ],
            ),
        ],
      ),
    );
  }

  List<Widget> _buildPageNumbers(int totalPages) {
    final List<Widget> pages = [];
    for (int i = 1; i <= totalPages; i++) {
      if (totalPages > 7) {
        if (i == 1 ||
            i == totalPages ||
            (i >= _currentPage - 1 && i <= _currentPage + 1)) {
          pages.add(_buildPageNumberBtn(i));
        } else if (i == 2 || i == totalPages - 1) {
          // Only add ellipsis if we haven't just added one
          if (pages.isNotEmpty && pages.last.key != const ValueKey('ellipsis')) {
            pages.add(
              Padding(
                key: const ValueKey('ellipsis'),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text('...', style: GoogleFonts.outfit(color: AppTheme.textSecondary)),
              ),
            );
          }
        }
      } else {
        pages.add(_buildPageNumberBtn(i));
      }
    }
    return pages;
  }

  Widget _buildPageNumberBtn(int page) {
    final bool isActive = page == _currentPage;
    return Padding(
      key: ValueKey('page_$page'),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: InkWell(
        onTap: () => setState(() => _currentPage = page),
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isActive ? AppTheme.primaryColor : Colors.white,
            border: Border.all(
              color: isActive ? AppTheme.primaryColor : AppTheme.borderColor,
            ),
            borderRadius: BorderRadius.circular(8),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: AppTheme.primaryColor.withValues(alpha: 0.2),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    )
                  ]
                : [],
          ),
          child: Text(
            '$page',
            style: GoogleFonts.outfit(
              fontSize: 13,
              fontWeight: isActive ? FontWeight.bold : FontWeight.w600,
              color: isActive ? Colors.white : AppTheme.textPrimary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPageNavButton({required IconData icon, required VoidCallback? onTap}) {
    final bool disabled = onTap == null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: disabled ? const Color(0xFFF9FAFB) : Colors.white,
          border: Border.all(
            color: disabled ? const Color(0xFFE5E7EB) : AppTheme.borderColor,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          size: 20,
          color: disabled ? AppTheme.textSecondary.withValues(alpha: 0.4) : AppTheme.textPrimary,
        ),
      ),
    );
  }


  Widget _buildAvailabilityBadge(Map<String, dynamic> prod) {
    final bool inStock = prod['inStock'] ?? false;
    final color = inStock ? AppTheme.success : AppTheme.error;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            inStock ? 'In Stock' : 'Out of Stock',
            style: GoogleFonts.outfit(
              fontSize: 11.5,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductThumbnail(Map<String, dynamic> prod) {
    final Uint8List? thumbnailBytes = prod['thumbnailBytes'] as Uint8List?;
    if (thumbnailBytes != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.memory(
          thumbnailBytes,
          width: 36,
          height: 36,
          fit: BoxFit.cover,
        ),
      );
    }

    final String? thumbnail = prod['thumbnail'];
    if (thumbnail != null && thumbnail.isNotEmpty) {
      if (thumbnail.startsWith('data:image')) {
        try {
          final base64Str = thumbnail.split(',').last;
          final bytes = base64Decode(base64Str);
          // Cache the decoded bytes so we don't decode again
          prod['thumbnailBytes'] = bytes;
          return ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.memory(
              bytes,
              width: 36,
              height: 36,
              fit: BoxFit.cover,
            ),
          );
        } catch (_) {}
      } else {
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(
            thumbnail,
            width: 36,
            height: 36,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.image_not_supported_outlined,
                  size: 16,
                  color: AppTheme.textSecondary,
                ),
              );
            },
          ),
        );
      }
    }
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppTheme.primaryColor.withValues(alpha: 0.15),
        ),
      ),
      child: Center(
        child: Text(
          (prod['name'] as String).isNotEmpty
              ? (prod['name'] as String)[0].toUpperCase()
              : 'P',
          style: GoogleFonts.outfit(
            fontSize: 14,
            color: AppTheme.primaryColor,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildRowActionButtons(Map<String, dynamic> prod) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _CircleActionButton(
          icon: Icons.edit_outlined,
          tooltip: 'Edit Product',
          onTap: () => _startEditProduct(prod),
        ),
        const SizedBox(width: 8),
        _CircleActionButton(
          icon: Icons.delete_outline_rounded,
          tooltip: 'Delete Product',
          color: AppTheme.error,
          onTap: () => _showDeleteConfirmation(prod),
        ),
      ],
    );
  }

  void _showDeleteConfirmation(Map<String, dynamic> prod) {
    showDialog(
      context: context,
      builder: (BuildContext ctx) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
          backgroundColor: Colors.transparent,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.error.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.warning_amber_rounded,
                    color: AppTheme.error,
                    size: 28,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Delete Product',
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Are you sure you want to delete "${prod['name']}"? This action cannot be undone.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    fontSize: 13.5,
                    color: AppTheme.textSecondary,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppTheme.borderColor),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          'Cancel',
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            color: AppTheme.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          context.read<ProductsBloc>().add(
                            DeleteProductEvent(prod['id'].toString()),
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Product deleted successfully'),
                              backgroundColor: AppTheme.success,
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.error,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          'Delete',
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
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
        letterSpacing: 0.8,
      ),
    );
  }
}

class _CircleActionButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final Color color;

  const _CircleActionButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.color = AppTheme.textSecondary,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppTheme.borderColor),
          ),
          child: Icon(icon, size: 16, color: color),
        ),
      ),
    );
  }
}

class _TableSkeletonRow extends StatelessWidget {
  const _TableSkeletonRow();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: AppTheme.lightBorderColor),
        ),
      ),
      child: Shimmer.fromColors(
        baseColor: Colors.grey.shade200,
        highlightColor: Colors.grey.shade100,
        child: Row(
          children: [
            Expanded(
              flex: 8,
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          height: 12,
                          width: 140,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          height: 10,
                          width: 80,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 4,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  height: 12,
                  width: 90,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  height: 12,
                  width: 40,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
            Expanded(
              flex: 3,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  height: 12,
                  width: 60,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
            Expanded(
              flex: 4,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  height: 20,
                  width: 75,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
            const SizedBox(
              width: 80,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  CircleAvatar(
                    radius: 12,
                    backgroundColor: Colors.white,
                  ),
                  SizedBox(width: 8),
                  CircleAvatar(
                    radius: 12,
                    backgroundColor: Colors.white,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
