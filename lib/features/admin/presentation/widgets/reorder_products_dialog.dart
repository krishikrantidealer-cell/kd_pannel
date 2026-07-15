import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kd_pannel/app_theme.dart';
import 'package:kd_pannel/core/network/api_client.dart';

class ReorderProductsDialog extends StatefulWidget {
  final String contextId;
  final String contextName;
  final String type; // 'collection', 'category', 'subcategory'
  final List<Map<String, dynamic>> products;
  final VoidCallback onSaveComplete;

  const ReorderProductsDialog({
    super.key,
    required this.contextId,
    required this.contextName,
    required this.type,
    required this.products,
    required this.onSaveComplete,
  });

  @override
  State<ReorderProductsDialog> createState() => _ReorderProductsDialogState();
}

class _ReorderProductsDialogState extends State<ReorderProductsDialog> {
  late List<Map<String, dynamic>> _orderedProducts;
  String _searchQuery = '';
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _initializeProducts();
  }

  String _extractId(dynamic val) {
    if (val == null) return '';
    if (val is String) return val;
    if (val is Map) {
      if (val['_id'] != null) return val['_id'].toString();
      if (val['id'] != null) return val['id'].toString();
      if (val['\$oid'] != null) return val['\$oid'].toString();
    }
    return val.toString();
  }

  void _initializeProducts() {
    // 1. Filter and deduplicate products belonging to this context
    final List<Map<String, dynamic>> filtered = [];
    final Set<String> seenIds = {};

    for (final p in widget.products) {
      bool isMatch = false;
      if (widget.type == 'collection') {
        final collections = List<String>.from(p['assignedCollections'] ?? []);
        isMatch = collections.contains(widget.contextName);
      } else if (widget.type == 'category') {
        final catId = _extractId(p['categoryId'] ?? p['category']);
        final List<String> catIds = List<String>.from((p['categoryIds'] as List?)?.map(_extractId) ?? []);
        isMatch = catId == widget.contextId || catIds.contains(widget.contextId);
      } else if (widget.type == 'subcategory') {
        final subCatId = _extractId(p['subCategoryId'] ?? p['subCategory']);
        final List<String> subCatIds = List<String>.from((p['subCategoryIds'] as List?)?.map(_extractId) ?? []);
        isMatch = subCatId == widget.contextId || subCatIds.contains(widget.contextId);
      }

      if (isMatch) {
        final id = _extractId(p);
        if (id.isNotEmpty && !seenIds.contains(id)) {
          seenIds.add(id);
          filtered.add(p);
        }
      }
    }

    // 2. Sort them by customOrders for this context
    final String safeKey = widget.contextId.replaceAll('.', '_dot_');
    filtered.sort((a, b) {
      final customOrdersA = a['customOrders'] as Map? ?? {};
      final customOrdersB = b['customOrders'] as Map? ?? {};

      final orderA = int.tryParse(customOrdersA[safeKey]?.toString() ?? '') ?? 1000000;
      final orderB = int.tryParse(customOrdersB[safeKey]?.toString() ?? '') ?? 1000000;

      if (orderA != orderB) {
        return orderA.compareTo(orderB);
      }

      final gOrderA = int.tryParse(a['order']?.toString() ?? '') ?? 0;
      final gOrderB = int.tryParse(b['order']?.toString() ?? '') ?? 0;
      if (gOrderA != gOrderB) {
        return gOrderA.compareTo(gOrderB);
      }

      final idA = (a['_id'] ?? a['id'] ?? '').toString();
      final idB = (b['_id'] ?? b['id'] ?? '').toString();
      return idA.compareTo(idB);
    });

    _orderedProducts = filtered;
  }

  Future<void> _saveOrder() async {
    setState(() => _isSaving = true);

    try {
      final productIds = _orderedProducts.map((p) => (p['_id'] ?? p['id'] ?? '').toString()).toList();
      final res = await ApiClient().post('/products/reorder', {
        'contextId': widget.contextId,
        'productIds': productIds,
      });

      if (res.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Layout saved successfully!'),
              backgroundColor: AppTheme.success,
            ),
          );
          Navigator.pop(context);
        }
        widget.onSaveComplete();
      } else {
        throw Exception('Server responded with ${res.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save layout: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Apply search filter locally while maintaining overall order
    final displayedProducts = _orderedProducts.where((p) {
      final title = (p['name'] ?? p['title'] ?? '').toString().toLowerCase();
      final brand = (p['vendor'] ?? p['brandName'] ?? '').toString().toLowerCase();
      final tech = (p['technicalName'] ?? '').toString().toLowerCase();
      final q = _searchQuery.toLowerCase();
      return title.contains(q) || brand.contains(q) || tech.contains(q);
    }).toList();

    return SelectionContainer.disabled(
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: 600,
          height: 650,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Arrange Products',
                          style: GoogleFonts.outfit(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Sorting: ${widget.contextName} (${widget.type})',
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            color: AppTheme.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 16),
  
              // Search input field
              Container(
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.borderColor),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.search_rounded, size: 18, color: AppTheme.textSecondary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        onChanged: (val) => setState(() => _searchQuery = val),
                        decoration: const InputDecoration(
                          hintText: 'Search products within this list...',
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                        style: GoogleFonts.outfit(fontSize: 13, color: AppTheme.textPrimary),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
  
              // List of products (Reorderable)
              Expanded(
                child: displayedProducts.isEmpty
                    ? Center(
                        child: Text(
                          _orderedProducts.isEmpty
                              ? 'No products assigned to this context yet.'
                              : 'No matching products found.',
                          style: GoogleFonts.outfit(
                            fontSize: 14,
                            color: AppTheme.textSecondary,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      )
                    : ReorderableListView.builder(
                        itemCount: displayedProducts.length,
                        buildDefaultDragHandles: false,
                        onReorder: (oldIndex, newIndex) {
                          setState(() {
                            if (newIndex > oldIndex) newIndex -= 1;
                            final item = displayedProducts.removeAt(oldIndex);
                            displayedProducts.insert(newIndex, item);
  
                            // Sync back changes to master ordered list to handle filtering
                            final masterOldIndex = _orderedProducts.indexOf(item);
                            _orderedProducts.removeAt(masterOldIndex);
                            // Determine insertion point in master list
                            if (newIndex >= displayedProducts.length - 1) {
                              _orderedProducts.add(item);
                            } else {
                              final neighbor = displayedProducts[newIndex + (newIndex > 0 ? 0 : 0)];
                              final masterNewIndex = _orderedProducts.indexOf(neighbor);
                              _orderedProducts.insert(masterNewIndex, item);
                            }
                          });
                        },
                        itemBuilder: (context, index) {
                          final product = displayedProducts[index];
                          final String prodId = (product['_id'] ?? product['id'] ?? '').toString();
                          final title = product['name'] ?? product['title'] ?? 'Unnamed Product';
                          final subtitle = product['vendor'] ?? product['brandName'] ?? '';
                          final hasImage = product['thumbnail'] != null && product['thumbnail'].toString().isNotEmpty;
  
                          return Container(
                            key: ValueKey(prodId),
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppTheme.borderColor),
                            ),
                            child: Row(
                              children: [
                                // Image Thumbnail
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(6),
                                    color: const Color(0xFFF3F4F6),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(6),
                                    child: hasImage
                                        ? Image.network(
                                            product['thumbnail'],
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) => const Icon(
                                              Icons.grass_rounded,
                                              size: 16,
                                              color: AppTheme.primaryColor,
                                            ),
                                          )
                                        : const Icon(
                                            Icons.grass_rounded,
                                            size: 16,
                                            color: AppTheme.primaryColor,
                                          ),
                                  ),
                                ),
                                const SizedBox(width: 12),
  
                                // Product info
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        title,
                                        style: GoogleFonts.outfit(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: AppTheme.textPrimary,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      if (subtitle.isNotEmpty)
                                        Text(
                                          subtitle,
                                          style: GoogleFonts.outfit(
                                            fontSize: 11,
                                            color: AppTheme.textSecondary,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                    ],
                                  ),
                                ),
  
                                // Drag handle (Instant drag listener)
                                ReorderableDragStartListener(
                                  index: index,
                                  child: const MouseRegion(
                                    cursor: SystemMouseCursors.grab,
                                    child: Padding(
                                      padding: EdgeInsets.symmetric(horizontal: 8.0),
                                      child: Icon(
                                        Icons.drag_indicator_rounded,
                                        color: AppTheme.textSecondary,
                                        size: 20,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
              const SizedBox(height: 16),
  
              // Dialog Footer buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isSaving ? null : () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    child: Text(
                      'Cancel',
                      style: GoogleFonts.outfit(color: AppTheme.textSecondary, fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _isSaving || _orderedProducts.isEmpty ? null : _saveOrder,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.white)),
                          )
                        : Text(
                            'Save Layout',
                            style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                          ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
