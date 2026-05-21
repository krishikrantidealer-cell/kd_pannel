import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:google_fonts/google_fonts.dart';
import 'package:kd_pannel/app_theme.dart';
import 'package:kd_pannel/core/network/api_client.dart';
import 'package:kd_pannel/features/shared/widgets/stat_card_widget.dart';

class CategoriesTabView extends StatefulWidget {
  final List<dynamic> categories;
  final List<Map<String, dynamic>> products;
  final VoidCallback onRefresh;

  const CategoriesTabView({
    super.key,
    required this.categories,
    required this.products,
    required this.onRefresh,
  });

  @override
  State<CategoriesTabView> createState() => _CategoriesTabViewState();
}

class _CategoriesTabViewState extends State<CategoriesTabView> {
  String _categorySearchQuery = '';
  Map<String, int> _categoryProductCounts = {};
  Map<String, int> _subCategoryProductCounts =
      {}; // Key: "categoryName_subCategoryName"

  // Filter cache
  List<dynamic> _cachedFilteredCategories = [];
  String _lastSearchQuery = '';
  List<dynamic>? _lastCategories;

  @override
  void initState() {
    super.initState();
    _calculateProductCounts();
  }

  @override
  void didUpdateWidget(covariant CategoriesTabView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.products != widget.products) {
      _calculateProductCounts();
    }
  }

  void _calculateProductCounts() {
    final catCounts = <String, int>{};
    final subCatCounts = <String, int>{};

    for (final p in widget.products) {
      final cat = p['category']?.toString() ?? '';
      final sub = p['subCategory']?.toString() ?? '';

      catCounts[cat] = (catCounts[cat] ?? 0) + 1;
      final subKey = '${cat}_$sub';
      subCatCounts[subKey] = (subCatCounts[subKey] ?? 0) + 1;
    }

    _categoryProductCounts = catCounts;
    _subCategoryProductCounts = subCatCounts;
  }

  List<dynamic> get _filteredCategories {
    if (_lastCategories == widget.categories &&
        _lastSearchQuery == _categorySearchQuery) {
      return _cachedFilteredCategories;
    }
    _lastCategories = widget.categories;
    _lastSearchQuery = _categorySearchQuery;

    _cachedFilteredCategories = widget.categories.where((cat) {
      final name = cat['name']?.toString().toLowerCase() ?? '';
      return name.contains(_categorySearchQuery.toLowerCase());
    }).toList();

    return _cachedFilteredCategories;
  }

  int _getProductCountForCategory(String categoryName) {
    return _categoryProductCounts[categoryName] ?? 0;
  }

  int _getProductCountForSubCategory(
    String categoryName,
    String subCategoryName,
  ) {
    return _subCategoryProductCounts['${categoryName}_$subCategoryName'] ?? 0;
  }

  Future<void> _createCategory() async {
    final TextEditingController controller = TextEditingController();
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (ctx) {
        bool isLoading = false;
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Text(
                'Create Category',
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
              ),
              content: Form(
                key: formKey,
                child: TextFormField(
                  controller: controller,
                  decoration: const InputDecoration(
                    labelText: 'Category Name',
                    hintText: 'e.g. Fertilizers',
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Please enter category name';
                    }
                    return null;
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isLoading ? null : () => Navigator.pop(ctx),
                  child: Text(
                    'Cancel',
                    style: GoogleFonts.outfit(color: AppTheme.textSecondary),
                  ),
                ),
                ElevatedButton(
                  onPressed: isLoading
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;
                          setState(() {
                            isLoading = true;
                          });
                          try {
                            final response = await ApiClient().post(
                              '/products/categories',
                              {'name': controller.text.trim()},
                            );
                            if (response.statusCode == 201) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Category created successfully',
                                    ),
                                    backgroundColor: AppTheme.success,
                                  ),
                                );
                              }
                              widget.onRefresh();
                              Navigator.pop(ctx);
                            } else {
                              final err = jsonDecode(response.body);
                              throw Exception(
                                err['message'] ?? 'Failed to create category',
                              );
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Error: $e'),
                                  backgroundColor: AppTheme.error,
                                ),
                              );
                            }
                          } finally {
                            if (mounted) {
                              setState(() {
                                isLoading = false;
                              });
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                  ),
                  child: isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : Text(
                          'Create',
                          style: GoogleFonts.outfit(color: Colors.white),
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _editCategory(dynamic cat) async {
    final TextEditingController controller = TextEditingController(
      text: cat['name'],
    );
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (ctx) {
        bool isLoading = false;
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Text(
                'Rename Category',
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
              ),
              content: Form(
                key: formKey,
                child: TextFormField(
                  controller: controller,
                  decoration: const InputDecoration(labelText: 'Category Name'),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Please enter category name';
                    }
                    return null;
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isLoading ? null : () => Navigator.pop(ctx),
                  child: Text(
                    'Cancel',
                    style: GoogleFonts.outfit(color: AppTheme.textSecondary),
                  ),
                ),
                ElevatedButton(
                  onPressed: isLoading
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;
                          setState(() {
                            isLoading = true;
                          });
                          try {
                            final response = await ApiClient().put(
                              '/products/categories/${cat['_id']}',
                              {'name': controller.text.trim()},
                            );
                            if (response.statusCode == 200) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Category renamed successfully',
                                    ),
                                    backgroundColor: AppTheme.success,
                                  ),
                                );
                              }
                              widget.onRefresh();
                              Navigator.pop(ctx);
                            } else {
                              throw Exception('Failed to rename category');
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Error: $e'),
                                  backgroundColor: AppTheme.error,
                                ),
                              );
                            }
                          } finally {
                            if (mounted) {
                              setState(() {
                                isLoading = false;
                              });
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                  ),
                  child: isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : Text(
                          'Save',
                          style: GoogleFonts.outfit(color: Colors.white),
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _deleteCategory(dynamic cat) async {
    await showDialog(
      context: context,
      builder: (ctx) {
        bool isLoading = false;
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Text(
                'Delete Category',
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
              ),
              content: Text(
                'Are you sure you want to delete category "${cat['name']}"? All associated products will have their category removed. This action cannot be undone.',
                style: GoogleFonts.outfit(fontSize: 13.5, height: 1.5),
              ),
              actions: [
                TextButton(
                  onPressed: isLoading ? null : () => Navigator.pop(ctx),
                  child: Text(
                    'Cancel',
                    style: GoogleFonts.outfit(color: AppTheme.textSecondary),
                  ),
                ),
                ElevatedButton(
                  onPressed: isLoading
                      ? null
                      : () async {
                          setState(() {
                            isLoading = true;
                          });
                          try {
                            final response = await ApiClient().delete(
                              '/products/categories/${cat['_id']}',
                            );
                            if (response.statusCode == 200) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Category deleted successfully',
                                    ),
                                    backgroundColor: AppTheme.success,
                                  ),
                                );
                              }
                              widget.onRefresh();
                              Navigator.pop(ctx);
                            } else {
                              throw Exception('Failed to delete category');
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Error: $e'),
                                  backgroundColor: AppTheme.error,
                                ),
                              );
                            }
                          } finally {
                            if (mounted) {
                              setState(() {
                                isLoading = false;
                              });
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.error,
                  ),
                  child: isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : Text(
                          'Delete',
                          style: GoogleFonts.outfit(color: Colors.white),
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _addSubCategory(dynamic cat) async {
    final TextEditingController controller = TextEditingController();
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (ctx) {
        bool isLoading = false;
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Text(
                'Add Sub-category',
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
              ),
              content: Form(
                key: formKey,
                child: TextFormField(
                  controller: controller,
                  decoration: const InputDecoration(
                    labelText: 'Sub-category Name',
                    hintText: 'e.g. Organic, Chemical',
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Please enter sub-category name';
                    }
                    return null;
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isLoading ? null : () => Navigator.pop(ctx),
                  child: Text(
                    'Cancel',
                    style: GoogleFonts.outfit(color: AppTheme.textSecondary),
                  ),
                ),
                ElevatedButton(
                  onPressed: isLoading
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;
                          setState(() {
                            isLoading = true;
                          });
                          try {
                            final response = await ApiClient().post(
                              '/products/categories/${cat['_id']}/subcategories',
                              {'name': controller.text.trim()},
                            );
                            if (response.statusCode == 201) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Sub-category added successfully',
                                    ),
                                    backgroundColor: AppTheme.success,
                                  ),
                                );
                              }
                              widget.onRefresh();
                              Navigator.pop(ctx);
                            } else {
                              throw Exception('Failed to add sub-category');
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Error: $e'),
                                  backgroundColor: AppTheme.error,
                                ),
                              );
                            }
                          } finally {
                            if (mounted) {
                              setState(() {
                                isLoading = false;
                              });
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                  ),
                  child: isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : Text(
                          'Add',
                          style: GoogleFonts.outfit(color: Colors.white),
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _editSubCategory(dynamic cat, dynamic sub) async {
    final TextEditingController controller = TextEditingController(
      text: sub['name'],
    );
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (ctx) {
        bool isLoading = false;
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Text(
                'Rename Sub-category',
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
              ),
              content: Form(
                key: formKey,
                child: TextFormField(
                  controller: controller,
                  decoration: const InputDecoration(
                    labelText: 'Sub-category Name',
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Please enter sub-category name';
                    }
                    return null;
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isLoading ? null : () => Navigator.pop(ctx),
                  child: Text(
                    'Cancel',
                    style: GoogleFonts.outfit(color: AppTheme.textSecondary),
                  ),
                ),
                ElevatedButton(
                  onPressed: isLoading
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;
                          setState(() {
                            isLoading = true;
                          });
                          try {
                            final response = await ApiClient().put(
                              '/products/categories/${cat['_id']}/subcategories/${sub['_id']}',
                              {'name': controller.text.trim()},
                            );
                            if (response.statusCode == 200) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Sub-category renamed successfully',
                                    ),
                                    backgroundColor: AppTheme.success,
                                  ),
                                );
                              }
                              widget.onRefresh();
                              Navigator.pop(ctx);
                            } else {
                              throw Exception('Failed to rename sub-category');
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Error: $e'),
                                  backgroundColor: AppTheme.error,
                                ),
                              );
                            }
                          } finally {
                            if (mounted) {
                              setState(() {
                                isLoading = false;
                              });
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                  ),
                  child: isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : Text(
                          'Save',
                          style: GoogleFonts.outfit(color: Colors.white),
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _deleteSubCategory(dynamic cat, dynamic sub) async {
    await showDialog(
      context: context,
      builder: (ctx) {
        bool isLoading = false;
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Text(
                'Delete Sub-category',
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
              ),
              content: Text(
                'Are you sure you want to delete sub-category "${sub['name']}"? Associated products will have their sub-category reference cleared.',
                style: GoogleFonts.outfit(fontSize: 13.5, height: 1.5),
              ),
              actions: [
                TextButton(
                  onPressed: isLoading ? null : () => Navigator.pop(ctx),
                  child: Text(
                    'Cancel',
                    style: GoogleFonts.outfit(color: AppTheme.textSecondary),
                  ),
                ),
                ElevatedButton(
                  onPressed: isLoading
                      ? null
                      : () async {
                          setState(() {
                            isLoading = true;
                          });
                          try {
                            final response = await ApiClient().delete(
                              '/products/categories/${cat['_id']}/subcategories/${sub['_id']}',
                            );
                            if (response.statusCode == 200) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Sub-category deleted successfully',
                                    ),
                                    backgroundColor: AppTheme.success,
                                  ),
                                );
                              }
                              widget.onRefresh();
                              Navigator.pop(ctx);
                            } else {
                              throw Exception('Failed to delete sub-category');
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Error: $e'),
                                  backgroundColor: AppTheme.error,
                                ),
                              );
                            }
                          } finally {
                            if (mounted) {
                              setState(() {
                                isLoading = false;
                              });
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.error,
                  ),
                  child: isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : Text(
                          'Delete',
                          style: GoogleFonts.outfit(color: Colors.white),
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildQuickStats() {
    final totalCategories = widget.categories.length;

    int totalSubCategories = 0;
    for (final cat in widget.categories) {
      final List subs = cat['subCategories'] as List? ?? [];
      totalSubCategories += subs.length;
    }

    int categorizedProducts = 0;
    final Map<String, int> catCounts = {};
    for (final p in widget.products) {
      final cat = p['category']?.toString() ?? '';
      if (cat.isNotEmpty && cat != 'N/A') {
        categorizedProducts++;
        catCounts[cat] = (catCounts[cat] ?? 0) + 1;
      }
    }

    String topCategory = 'None';
    int maxCount = 0;
    catCounts.forEach((catName, count) {
      if (count > maxCount) {
        maxCount = count;
        topCategory = catName;
      }
    });

    final stats = [
      {
        'title': 'Total Categories',
        'value': '$totalCategories',
        'icon': Icons.category_rounded,
        'color': AppTheme.primaryColor,
      },
      {
        'title': 'Total Sub-categories',
        'value': '$totalSubCategories',
        'icon': Icons.schema_rounded,
        'color': const Color(0xFF3B82F6),
      },
      {
        'title': 'Categorized Products',
        'value': '$categorizedProducts',
        'icon': Icons.inventory_2_rounded,
        'color': AppTheme.success,
      },
      {
        'title': 'Top Category',
        'value': topCategory,
        'icon': Icons.emoji_events_rounded,
        'color': const Color(0xFFF59E0B),
      },
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        const double spacing = 16.0;
        final int columns = constraints.maxWidth >= 600 ? 4 : 2;
        final double cardWidth =
            (constraints.maxWidth - (spacing * (columns - 1))) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: stats.map((stat) {
            return StatCardWidget(
              width: cardWidth,
              isCompact: true,
              title: stat['title'] as String,
              value: stat['value'] as String,
              icon: stat['icon'] as IconData,
              color: stat['color'] as Color,
            );
          }).toList(),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isMobile = MediaQuery.of(context).size.width < 768;
    final filtered = _filteredCategories;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildQuickStats(),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              height: 38,
              width: isMobile ? 180 : 260,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.borderColor),
              ),
              child: TextField(
                onChanged: (val) => setState(() => _categorySearchQuery = val),
                textAlignVertical: TextAlignVertical.center,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppTheme.textPrimary,
                ),
                decoration: const InputDecoration(
                  hintText: 'Search category name...',
                  hintStyle: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 13,
                  ),
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
            ),
            ElevatedButton.icon(
              onPressed: _createCategory,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Add Category'),
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
        const SizedBox(height: 16),
        filtered.isEmpty
            ? Container(
                width: double.infinity,
                padding: const EdgeInsets.all(48),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.borderColor),
                ),
                child: const Center(
                  child: Text(
                    'No categories found',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                ),
              )
            : GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 400,
                  mainAxisExtent: 300,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                ),
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final cat = filtered[index];
                  final catName = cat['name'] ?? '';
                  final productCount = _getProductCountForCategory(catName);
                  final subs = cat['subCategories'] as List? ?? [];

                  return _AnimatedListItem(
                    index: index,
                    child: CategoryCardWidget(
                      category: cat,
                      productCount: productCount,
                      subCategories: subs,
                      onEditCategory: _editCategory,
                      onDeleteCategory: _deleteCategory,
                      onAddSubCategory: _addSubCategory,
                      onEditSubCategory: _editSubCategory,
                      onDeleteSubCategory: _deleteSubCategory,
                      getSubProductCount: _getProductCountForSubCategory,
                    ),
                  );
                },
              ),
      ],
    );
  }
}

class CategoryCardWidget extends StatefulWidget {
  final dynamic category;
  final int productCount;
  final List<dynamic> subCategories;
  final Function(dynamic) onEditCategory;
  final Function(dynamic) onDeleteCategory;
  final Function(dynamic) onAddSubCategory;
  final Function(dynamic, dynamic) onEditSubCategory;
  final Function(dynamic, dynamic) onDeleteSubCategory;
  final int Function(String, String) getSubProductCount;

  const CategoryCardWidget({
    super.key,
    required this.category,
    required this.productCount,
    required this.subCategories,
    required this.onEditCategory,
    required this.onDeleteCategory,
    required this.onAddSubCategory,
    required this.onEditSubCategory,
    required this.onDeleteSubCategory,
    required this.getSubProductCount,
  });

  @override
  State<CategoryCardWidget> createState() => _CategoryCardWidgetState();
}

class _CategoryCardWidgetState extends State<CategoryCardWidget> {
  final ScrollController _scrollController = ScrollController();
  bool _isHovered = false;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final catName = widget.category['name'] ?? '';

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _isHovered
                ? AppTheme.primaryColor.withValues(alpha: 0.4)
                : AppTheme.borderColor,
            width: _isHovered ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: _isHovered
                  ? AppTheme.primaryColor.withValues(alpha: 0.06)
                  : Colors.black.withValues(alpha: 0.02),
              blurRadius: _isHovered ? 16 : 10,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFAFBFD),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
                border: Border(bottom: BorderSide(color: AppTheme.borderColor)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.grid_view_rounded,
                      color: AppTheme.primaryColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          catName,
                          style: GoogleFonts.outfit(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${widget.productCount} Product${widget.productCount != 1 ? 's' : ''}',
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        color: AppTheme.textSecondary,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () => widget.onEditCategory(widget.category),
                      ),
                      const SizedBox(width: 12),
                      IconButton(
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                          size: 18,
                        ),
                        color: AppTheme.error,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () =>
                            widget.onDeleteCategory(widget.category),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: Scrollbar(
                controller: _scrollController,
                thumbVisibility: true,
                trackVisibility: false,
                thickness: 4,
                radius: const Radius.circular(10),
                child: SingleChildScrollView(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'SUB-CATEGORIES (${widget.subCategories.length})',
                        style: GoogleFonts.outfit(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textSecondary,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (widget.subCategories.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            'No sub-categories yet.',
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              color: AppTheme.textSecondary,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        )
                      else
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: widget.subCategories.map((sub) {
                            final subName = sub['name'] ?? '';
                            final subCount = widget.getSubProductCount(
                              catName,
                              subName,
                            );
                            return Container(
                              padding: const EdgeInsets.only(
                                left: 10,
                                right: 6,
                                top: 4,
                                bottom: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor.withValues(
                                  alpha: 0.04,
                                ),
                                borderRadius: BorderRadius.circular(30),
                                border: Border.all(
                                  color: AppTheme.primaryColor.withValues(
                                    alpha: 0.15,
                                  ),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  MouseRegion(
                                    cursor: SystemMouseCursors.click,
                                    child: InkWell(
                                      onTap: () => widget.onEditSubCategory(
                                        widget.category,
                                        sub,
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                      child: Text(
                                        subName,
                                        style: GoogleFonts.outfit(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: AppTheme.primaryColor,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 1.5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppTheme.primaryColor.withValues(
                                        alpha: 0.08,
                                      ),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      '$subCount',
                                      style: GoogleFonts.outfit(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.primaryColor,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  MouseRegion(
                                    cursor: SystemMouseCursors.click,
                                    child: GestureDetector(
                                      onTap: () => widget.onDeleteSubCategory(
                                        widget.category,
                                        sub,
                                      ),
                                      child: Container(
                                        padding: const EdgeInsets.all(2),
                                        decoration: BoxDecoration(
                                          color: AppTheme.primaryColor
                                              .withValues(alpha: 0.06),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          Icons.close_rounded,
                                          size: 11,
                                          color: AppTheme.primaryColor
                                              .withValues(alpha: 0.7),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: OutlinedButton.icon(
                onPressed: () => widget.onAddSubCategory(widget.category),
                icon: const Icon(Icons.add, size: 16),
                label: Text(
                  'Add Sub-category',
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 40),
                  foregroundColor: AppTheme.textSecondary,
                  side: BorderSide(color: AppTheme.borderColor),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
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

class _AnimatedListItem extends StatefulWidget {
  final int index;
  final Widget child;

  const _AnimatedListItem({required this.index, required this.child});

  @override
  State<_AnimatedListItem> createState() => _AnimatedListItemState();
}

class _AnimatedListItemState extends State<_AnimatedListItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    final delayIndex = widget.index.clamp(0, 8);
    Future.delayed(Duration(milliseconds: delayIndex * 40), () {
      if (mounted) {
        _controller.forward();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(position: _slideAnimation, child: widget.child),
    );
  }
}
