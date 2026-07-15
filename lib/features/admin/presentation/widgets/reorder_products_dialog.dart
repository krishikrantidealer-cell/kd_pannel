import 'package:flutter/material.dart';
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
  late List<Map<String, dynamic>> _initialOrderedProducts;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isSaving = false;
  bool _isSearchFocused = false;
  String get _displayName {
    if (widget.contextName.contains('_split_')) {
      return widget.contextName.split('_split_')[1];
    }
    return widget.contextName;
  }

  @override
  void initState() {
    super.initState();
    _initializeProducts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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

  String _extractName(dynamic val) {
    if (val == null) return '';
    if (val is String) return val;
    if (val is Map) {
      if (val['name'] != null) return val['name'].toString();
      if (val['title'] != null) return val['title'].toString();
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
        final List<String> catIds = List<String>.from(
          (p['categoryIds'] as List?)?.map(_extractId) ?? [],
        );
        final catName = _extractName(p['category']);
        final List<String> catNamesList = catName.isNotEmpty
            ? catName.split(',').map((e) => e.trim().toLowerCase()).toList()
            : [];
        isMatch = catId == widget.contextId ||
            catIds.contains(widget.contextId) ||
            catNamesList.contains(widget.contextName.toLowerCase());
      } else if (widget.type == 'subcategory') {
        final subCatId = _extractId(p['subCategoryId'] ?? p['subCategory']);
        final List<String> subCatIds = List<String>.from(
          (p['subCategoryIds'] as List?)?.map(_extractId) ?? [],
        );
        
        String categoryName = '';
        String subCategoryName = widget.contextName;
        if (widget.contextName.contains('_split_')) {
          final parts = widget.contextName.split('_split_');
          categoryName = parts[0];
          subCategoryName = parts[1];
        }
        
        final subCatName = _extractName(p['subCategory']);
        final List<String> subNamesList = subCatName.isNotEmpty
            ? subCatName.split(',').map((e) => e.trim().toLowerCase()).toList()
            : [];
            
        final catName = _extractName(p['category']);
        final List<String> catNamesList = catName.isNotEmpty
            ? catName.split(',').map((e) => e.trim().toLowerCase()).toList()
            : [];
            
        final bool nameMatches = subNamesList.contains(subCategoryName.toLowerCase()) &&
            (categoryName.isEmpty || catNamesList.contains(categoryName.toLowerCase()));

        isMatch = subCatId == widget.contextId ||
            subCatIds.contains(widget.contextId) ||
            nameMatches;
      } else if (widget.type == 'featured') {
        isMatch = p['isFeatured'] as bool? ?? false;
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

      final orderA =
          int.tryParse(customOrdersA[safeKey]?.toString() ?? '') ?? 1000000;
      final orderB =
          int.tryParse(customOrdersB[safeKey]?.toString() ?? '') ?? 1000000;

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
    _initialOrderedProducts = List.from(filtered);
  }

  bool _hasUnsavedChanges() {
    if (_orderedProducts.length != _initialOrderedProducts.length) return true;
    for (int i = 0; i < _orderedProducts.length; i++) {
      final idA = _extractId(_orderedProducts[i]);
      final idB = _extractId(_initialOrderedProducts[i]);
      if (idA != idB) return true;
    }
    return false;
  }

  void _resetOrder() {
    setState(() {
      _orderedProducts = List.from(_initialOrderedProducts);
    });
  }

  void _sortAlphabetically() {
    setState(() {
      _orderedProducts.sort((a, b) {
        final nameA = (a['name'] ?? a['title'] ?? '').toString().toLowerCase();
        final nameB = (b['name'] ?? b['title'] ?? '').toString().toLowerCase();
        return nameA.compareTo(nameB);
      });
    });
  }

  void _reverseOrder() {
    setState(() {
      _orderedProducts = _orderedProducts.reversed.toList();
    });
  }

  void _moveItemToPosition(Map<String, dynamic> item, int targetIndexOneBased) {
    final displayedProducts = _getDisplayedProducts();
    final oldIndex = displayedProducts.indexOf(item);
    if (oldIndex == -1) return;

    int newIndex = (targetIndexOneBased - 1).clamp(0, displayedProducts.length - 1);
    if (oldIndex == newIndex) return;

    setState(() {
      displayedProducts.removeAt(oldIndex);
      displayedProducts.insert(newIndex, item);

      // Sync back to master list robustly
      final displayedSet = displayedProducts.toSet();
      final List<int> masterIndices = [];
      for (int i = 0; i < _orderedProducts.length; i++) {
        if (displayedSet.contains(_orderedProducts[i])) {
          masterIndices.add(i);
        }
      }
      for (int i = 0; i < masterIndices.length; i++) {
        _orderedProducts[masterIndices[i]] = displayedProducts[i];
      }
    });
  }

  void _moveToTop(Map<String, dynamic> item) {
    _moveItemToPosition(item, 1);
  }

  void _moveToBottom(Map<String, dynamic> item) {
    _moveItemToPosition(item, _orderedProducts.length);
  }

  Future<void> _promptMoveToPosition(Map<String, dynamic> item, int currentIndexOneBased) async {
    final totalCount = _orderedProducts.length;
    final TextEditingController controller = TextEditingController(text: currentIndexOneBased.toString());
    final formKey = GlobalKey<FormState>();

    final targetPosition = await showDialog<int>(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'Jump to Position',
            style: AppTheme.headingLG,
          ),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Enter a position between 1 and $totalCount:',
                  style: AppTheme.bodyMD,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: controller,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    hintText: 'Position (1-$totalCount)',
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppTheme.borderColor),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppTheme.primaryColor, width: 2),
                    ),
                  ),
                  style: AppTheme.bodyLG,
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Please enter a number';
                    }
                    final parsed = int.tryParse(val.trim());
                    if (parsed == null || parsed < 1 || parsed > totalCount) {
                      return 'Must be between 1 and $totalCount';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: AppTheme.labelLG.copyWith(color: AppTheme.textSecondary),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState?.validate() ?? false) {
                  final target = int.parse(controller.text.trim());
                  Navigator.pop(context, target);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              child: Text(
                'Move',
                style: AppTheme.button,
              ),
            ),
          ],
        );
      },
    );

    if (targetPosition != null) {
      _moveItemToPosition(item, targetPosition);
    }
  }

  Future<bool> _showDiscardConfirmation() async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Discard Unsaved Changes?',
          style: AppTheme.headingLG,
        ),
        content: Text(
          'You have rearranged some products. Closing now will revert the order to the last saved state.',
          style: AppTheme.bodyMD,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Keep Editing',
              style: AppTheme.labelLG.copyWith(color: AppTheme.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.error,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            child: Text(
              'Discard',
              style: AppTheme.button,
            ),
          ),
        ],
      ),
    ) ?? false;
  }

  Future<void> _handleClose() async {
    if (_hasUnsavedChanges()) {
      final confirm = await _showDiscardConfirmation();
      if (confirm && mounted) {
        Navigator.pop(context);
      }
    } else {
      Navigator.pop(context);
    }
  }

  Future<void> _saveOrder() async {
    setState(() => _isSaving = true);

    try {
      final productIds = _orderedProducts
          .map((p) => (p['_id'] ?? p['id'] ?? '').toString())
          .toList();
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

  List<Map<String, dynamic>> _getDisplayedProducts() {
    return _orderedProducts.where((p) {
      final title = (p['name'] ?? p['title'] ?? '').toString().toLowerCase();
      final brand = (p['vendor'] ?? p['brandName'] ?? '')
          .toString()
          .toLowerCase();
      final tech = (p['technicalName'] ?? '').toString().toLowerCase();
      final q = _searchQuery.toLowerCase();
      return title.contains(q) || brand.contains(q) || tech.contains(q);
    }).toList();
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
    Widget? action,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.06),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 40,
                color: AppTheme.primaryColor,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: AppTheme.headingMD,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: AppTheme.bodySM.copyWith(color: AppTheme.textSecondary),
              textAlign: TextAlign.center,
            ),
            if (action != null) ...[
              const SizedBox(height: 16),
              action,
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildToolbarButton({
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
    required String tooltip,
  }) {
    final isEnabled = onPressed != null;
    return Tooltip(
      message: tooltip,
      child: TextButton.icon(
        onPressed: onPressed,
        icon: Icon(
          icon,
          size: 14,
          color: isEnabled ? AppTheme.primaryColor : AppTheme.textSecondary.withOpacity(0.4),
        ),
        label: Text(
          label,
          style: AppTheme.labelSM.copyWith(
            color: isEnabled ? AppTheme.primaryColor : AppTheme.textSecondary.withOpacity(0.4),
          ),
        ),
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          backgroundColor: isEnabled ? AppTheme.primaryColor.withOpacity(0.06) : Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: isEnabled ? AppTheme.primaryColor.withOpacity(0.12) : AppTheme.borderColor.withOpacity(0.5),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProductCard(Map<String, dynamic> product, int index, int displayedIndex) {
    final String prodId = (product['_id'] ?? product['id'] ?? '').toString();
    final title = product['name'] ?? product['title'] ?? 'Unnamed Product';
    final subtitle = product['vendor'] ?? product['brandName'] ?? '';
    final hasImage = product['thumbnail'] != null && product['thumbnail'].toString().isNotEmpty;
    final rank = displayedIndex + 1;
    final sku = product['sku']?.toString() ?? '';
    final techName = product['technicalName']?.toString() ?? '';

    return Container(
      key: ValueKey(prodId),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderColor),
        boxShadow: AppTheme.cardShadow,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Rank Badge (interactive)
              _buildRankBadge(rank, product),
              const SizedBox(width: 12),

              // Image Thumbnail & Info
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          color: const Color(0xFFF3F4F6),
                          border: Border.all(color: AppTheme.lightBorderColor),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.03),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: hasImage
                              ? Image.network(
                                  product['thumbnail'],
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => const Icon(
                                    Icons.grass_rounded,
                                    size: 20,
                                    color: AppTheme.primaryColor,
                                  ),
                                )
                              : const Icon(
                                  Icons.grass_rounded,
                                  size: 20,
                                  color: AppTheme.primaryColor,
                                ),
                        ),
                      ),
                      const SizedBox(width: 12),

                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              title,
                              style: AppTheme.headingSM.copyWith(
                                color: AppTheme.textPrimary,
                                fontSize: 13.5,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (techName.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                techName,
                                style: AppTheme.bodySM.copyWith(
                                  color: AppTheme.textSecondary.withOpacity(0.85),
                                  fontStyle: FontStyle.italic,
                                  fontSize: 11,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryColor.withOpacity(0.06),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: AppTheme.primaryColor.withOpacity(0.12)),
                                  ),
                                  child: Text(
                                    subtitle.toString().isEmpty ? 'No Brand' : subtitle.toString(),
                                    style: AppTheme.labelSM.copyWith(
                                      color: AppTheme.primaryColor,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                if (sku.isNotEmpty) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF3F4F6),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(color: const Color(0xFFE5E7EB)),
                                    ),
                                    child: Text(
                                      'SKU: $sku',
                                      style: AppTheme.labelSM.copyWith(
                                        color: AppTheme.textSecondary,
                                        fontSize: 9,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Action buttons & drag handle
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildCardAction(
                    icon: Icons.keyboard_double_arrow_up_rounded,
                    tooltip: 'Move to Top',
                    onPressed: () => _moveToTop(product),
                  ),
                  _buildCardAction(
                    icon: Icons.keyboard_double_arrow_down_rounded,
                    tooltip: 'Move to Bottom',
                    onPressed: () => _moveToBottom(product),
                  ),
                  const SizedBox(width: 6),

                  ReorderableDragStartListener(
                    index: index,
                    child: const MouseRegion(
                      cursor: SystemMouseCursors.grab,
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 12,
                        ),
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
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRankBadge(int rank, Map<String, dynamic> product) {
    Color bgColor;
    Color textColor;
    BorderSide borderSide;
    IconData? rankIcon;

    if (rank == 1) {
      bgColor = const Color(0xFFFEF9C3); // Bright Gold background
      textColor = const Color(0xFF854D0E); // Deep gold text
      borderSide = const BorderSide(color: Color(0xFFFDE047), width: 1.5);
      rankIcon = Icons.emoji_events_rounded; // Gold Trophy
    } else if (rank == 2) {
      bgColor = const Color(0xFFF1F5F9); // Silver-grey background
      textColor = const Color(0xFF475569); // Cool Slate text
      borderSide = const BorderSide(color: Color(0xFFCBD5E1), width: 1.5);
      rankIcon = Icons.military_tech_rounded; // Silver medal
    } else if (rank == 3) {
      bgColor = const Color(0xFFFAF7F2); // Warm copper/bronze background
      textColor = const Color(0xFF7C2D12); // Deep Rust/Bronze text
      borderSide = const BorderSide(color: Color(0xFFE8D8CD), width: 1.5);
      rankIcon = Icons.star_rounded; // Star icon
    } else {
      bgColor = const Color(0xFFF9FAFB);
      textColor = AppTheme.textSecondary;
      borderSide = const BorderSide(color: AppTheme.borderColor);
    }

    return Tooltip(
      message: 'Jump to a specific position',
      child: InkWell(
        onTap: () => _promptMoveToPosition(product, rank),
        child: Container(
          width: 52,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: bgColor,
            border: Border(
              right: borderSide,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (rankIcon != null) ...[
                Icon(
                  rankIcon,
                  size: 15,
                  color: textColor,
                ),
                const SizedBox(height: 2),
              ],
              Text(
                '#$rank',
                style: AppTheme.labelLG.copyWith(
                  color: textColor,
                  fontWeight: FontWeight.w900,
                  fontSize: rankIcon != null ? 11 : 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCardAction({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return Tooltip(
      message: tooltip,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.all(6.0),
              child: Icon(
                icon,
                size: 16,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final displayedProducts = _getDisplayedProducts();
    final hasFilter = _searchQuery.isNotEmpty;

    Color typeColor;
    IconData typeIcon;
    if (widget.type == 'collection') {
      typeColor = AppTheme.accentColor;
      typeIcon = Icons.collections_bookmark_rounded;
    } else if (widget.type == 'category') {
      typeColor = AppTheme.primaryColor;
      typeIcon = Icons.category_rounded;
    } else if (widget.type == 'featured') {
      typeColor = AppTheme.warning; // Gold/Amber
      typeIcon = Icons.star_rounded;
    } else {
      typeColor = AppTheme.info;
      typeIcon = Icons.layers_rounded;
    }

    return PopScope(
      canPop: !_hasUnsavedChanges() && !_isSaving,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        final confirm = await _showDiscardConfirmation();
        if (confirm && mounted) {
          Navigator.pop(context);
        }
      },
      child: SelectionContainer.disabled(
        child: Dialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: MediaQuery.of(context).size.width.clamp(320.0, 650.0),
            height: MediaQuery.of(context).size.height.clamp(400.0, 780.0),
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
                          Row(
                            children: [
                              Text(
                                'Arrange Products',
                                style: AppTheme.headingXL.copyWith(
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: typeColor.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: typeColor.withOpacity(0.15),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      typeIcon,
                                      size: 11,
                                      color: typeColor,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      widget.type.toUpperCase(),
                                      style: AppTheme.labelSM.copyWith(
                                        color: typeColor,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Sorting: $_displayName',
                            style: AppTheme.bodyMD.copyWith(
                              color: AppTheme.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: _handleClose,
                      icon: const Icon(Icons.close_rounded),
                      style: IconButton.styleFrom(
                        hoverColor: Colors.black.withOpacity(0.05),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Search input field
                Focus(
                  onFocusChange: (hasFocus) {
                    setState(() {
                      _isSearchFocused = hasFocus;
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    height: 44,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _isSearchFocused ? AppTheme.primaryColor : AppTheme.borderColor,
                        width: _isSearchFocused ? 1.8 : 1.0,
                      ),
                      boxShadow: _isSearchFocused
                          ? [
                              BoxShadow(
                                color: AppTheme.primaryColor.withOpacity(0.08),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                                spreadRadius: 1,
                              )
                            ]
                          : [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.02),
                                blurRadius: 4,
                                offset: const Offset(0, 1),
                              )
                            ],
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.search_rounded,
                          size: 20,
                          color: _isSearchFocused ? AppTheme.primaryColor : AppTheme.textSecondary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            onChanged: (val) => setState(() => _searchQuery = val),
                            decoration: const InputDecoration(
                              hintText: 'Search products by name or brand...',
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                            style: AppTheme.bodyMD,
                          ),
                        ),
                        if (_searchQuery.isNotEmpty)
                          IconButton(
                            onPressed: () => setState(() {
                              _searchController.clear();
                              _searchQuery = '';
                            }),
                            icon: const Icon(
                              Icons.cancel_rounded,
                              size: 18,
                              color: AppTheme.textSecondary,
                            ),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Quick-Sort Toolbar
                Container(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        hasFilter
                            ? 'Showing ${displayedProducts.length} of ${_orderedProducts.length}'
                            : '${_orderedProducts.length} products',
                        style: AppTheme.labelMD,
                      ),
                      Row(
                        children: [
                          _buildToolbarButton(
                            icon: Icons.restore_rounded,
                            label: 'Reset',
                            onPressed: _hasUnsavedChanges() ? _resetOrder : null,
                            tooltip: 'Reset to original order',
                          ),
                          const SizedBox(width: 8),
                          _buildToolbarButton(
                            icon: Icons.sort_by_alpha_rounded,
                            label: 'A-Z',
                            onPressed: _orderedProducts.isNotEmpty ? _sortAlphabetically : null,
                            tooltip: 'Sort alphabetically by name',
                          ),
                          const SizedBox(width: 8),
                          _buildToolbarButton(
                            icon: Icons.swap_vert_rounded,
                            label: 'Reverse',
                            onPressed: _orderedProducts.isNotEmpty ? _reverseOrder : null,
                            tooltip: 'Reverse current sequence',
                          ),
                        ],
                      )
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                // List of products (Reorderable)
                Expanded(
                  child: _orderedProducts.isEmpty
                      ? _buildEmptyState(
                          icon: Icons.inventory_2_outlined,
                          title: 'No products assigned',
                          subtitle: 'There are no products assigned to this ${widget.type} yet.',
                        )
                      : (displayedProducts.isEmpty
                          ? _buildEmptyState(
                              icon: Icons.search_off_rounded,
                              title: 'No matches found',
                              subtitle: 'We couldn\'t find any products matching "$_searchQuery".',
                              action: TextButton(
                                onPressed: () {
                                  setState(() {
                                    _searchController.clear();
                                    _searchQuery = '';
                                  });
                                },
                                child: Text(
                                  'Clear Search',
                                  style: AppTheme.labelLG.copyWith(color: AppTheme.primaryColor),
                                ),
                              ),
                            )
                          : ReorderableListView.builder(
                              itemCount: displayedProducts.length,
                              buildDefaultDragHandles: false,
                              proxyDecorator: (child, index, animation) {
                                return AnimatedBuilder(
                                  animation: animation,
                                  builder: (context, child) {
                                    return Transform.scale(
                                      scale: 1.0 + (animation.value * 0.02),
                                      child: Material(
                                        elevation: animation.value * 12,
                                        borderRadius: BorderRadius.circular(16),
                                        color: Colors.transparent,
                                        shadowColor: AppTheme.primaryColor.withOpacity(0.18),
                                        child: child,
                                      ),
                                    );
                                  },
                                  child: child,
                                );
                              },
                              onReorder: (oldIndex, newIndex) {
                                setState(() {
                                  if (newIndex > oldIndex) newIndex -= 1;

                                  // Remove from displayed list and insert at new position
                                  final item = displayedProducts.removeAt(oldIndex);
                                  displayedProducts.insert(newIndex, item);

                                  // Sync back changes to master ordered list robustly
                                  final displayedSet = displayedProducts.toSet();
                                  final List<int> masterIndices = [];
                                  for (int i = 0; i < _orderedProducts.length; i++) {
                                    if (displayedSet.contains(_orderedProducts[i])) {
                                      masterIndices.add(i);
                                    }
                                  }

                                  for (int i = 0; i < masterIndices.length; i++) {
                                    _orderedProducts[masterIndices[i]] = displayedProducts[i];
                                  }
                                });
                              },
                              itemBuilder: (context, index) {
                                final product = displayedProducts[index];
                                return _buildProductCard(product, index, index);
                              },
                            )),
                ),
                const SizedBox(height: 16),

                // Dialog Footer buttons
                Row(
                  children: [
                    // Change status indicator
                    if (_hasUnsavedChanges())
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppTheme.warning.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppTheme.warning.withOpacity(0.2)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.pending_actions_rounded,
                              size: 12,
                              color: AppTheme.warning,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Unsaved modifications',
                              style: AppTheme.labelSM.copyWith(
                                color: AppTheme.warning,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    const Spacer(),
                    TextButton(
                      onPressed: _isSaving ? null : _handleClose,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text(
                        'Cancel',
                        style: AppTheme.labelLG.copyWith(
                          color: AppTheme.textSecondary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: _isSaving || !_hasUnsavedChanges() || _orderedProducts.isEmpty
                          ? null
                          : _saveOrder,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: const Color(0xFFF3F4F6),
                        disabledForegroundColor: AppTheme.textSecondary.withOpacity(0.4),
                        elevation: _hasUnsavedChanges() && !_isSaving ? 2 : 0,
                        shadowColor: AppTheme.primaryColor.withOpacity(0.25),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                valueColor: AlwaysStoppedAnimation(Colors.white),
                              ),
                            )
                          : Text(
                              'Save Layout',
                              style: AppTheme.button.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
