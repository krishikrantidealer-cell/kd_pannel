import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kd_pannel/app_theme.dart';
import 'package:kd_pannel/core/network/api_client.dart';
import 'package:kd_pannel/features/shared/widgets/main_layout.dart';
import 'package:kd_pannel/features/shared/widgets/stat_card_widget.dart';
import 'package:kd_pannel/features/admin/presentation/pages/create_collection_page.dart';

class CollectionsTabView extends StatefulWidget {
  // Each item: { id, name, slug, isActive, subCollections: [{id, parentId, name, slug, isActive}] }
  final List<Map<String, dynamic>> collections;
  final List<Map<String, dynamic>> products;
  final bool isLoadingCollections;
  final VoidCallback onRefresh;

  const CollectionsTabView({
    super.key,
    required this.collections,
    required this.products,
    required this.isLoadingCollections,
    required this.onRefresh,
  });

  @override
  State<CollectionsTabView> createState() => _CollectionsTabViewState();
}

class _CollectionsTabViewState extends State<CollectionsTabView> {
  String _searchQuery = '';
  final Set<String> _expandedIds = {};
  final Set<String> _deletingIds = {};

  // Filter cache
  List<Map<String, dynamic>> _cachedFilteredCollections = [];
  String _lastSearchQuery = '';
  List<Map<String, dynamic>>? _lastCollections;

  // Stats Cache
  int? _cachedTotalParent;
  int? _cachedTotalSub;
  int? _cachedActiveParent;
  int? _cachedLinkedProducts;
  List<Map<String, dynamic>>? _statsLastCollections;
  List<Map<String, dynamic>>? _statsLastProducts;

  void _recalcStats() {
    if (_statsLastCollections == widget.collections &&
        _statsLastProducts == widget.products &&
        _cachedTotalParent != null) {
      return;
    }
    _statsLastCollections = widget.collections;
    _statsLastProducts = widget.products;

    _cachedTotalParent = widget.collections.length;
    _cachedTotalSub = widget.collections.fold<int>(
      0,
      (sum, c) => sum + (c['subCollections'] as List? ?? []).length,
    );
    _cachedActiveParent = widget.collections
        .where((c) => c['isActive'] == true)
        .length;
    _cachedLinkedProducts = widget.products
        .where((p) => (p['assignedCollections'] as List? ?? []).isNotEmpty)
        .length;
  }

  List<Map<String, dynamic>> get _filteredCollections {
    if (_lastCollections == widget.collections &&
        _lastSearchQuery == _searchQuery) {
      return _cachedFilteredCollections;
    }
    _lastCollections = widget.collections;
    _lastSearchQuery = _searchQuery;

    if (_searchQuery.isEmpty) {
      _cachedFilteredCollections = widget.collections;
    } else {
      _cachedFilteredCollections = widget.collections.where((col) {
        final nameMatch = col['name'].toString().toLowerCase().contains(
          _searchQuery.toLowerCase(),
        );
        final subMatch = (col['subCollections'] as List? ?? []).any(
          (sub) => sub['name'].toString().toLowerCase().contains(
            _searchQuery.toLowerCase(),
          ),
        );
        return nameMatch || subMatch;
      }).toList();
    }
    return _cachedFilteredCollections;
  }

  void _startEditCollection(Map<String, dynamic> collection) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => MainLayout(
          child: CreateCollectionPage(
            initialData: collection,
            allProducts: widget.products,
            onSave: (updated) => widget.onRefresh(),
          ),
        ),
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
    );
  }

  Future<void> _deleteSubCollection(
    String parentId,
    Map<String, dynamic> sub,
  ) async {
    final String subId = (sub['id'] ?? sub['_id'] ?? '').toString();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => _ConfirmDeleteDialog(name: sub['name'] as String),
    );
    if (confirmed != true) return;
    setState(() {
      _deletingIds.add(subId);
    });
    try {
      final response = await ApiClient().delete(
        '/collections/$parentId/sub/$subId',
      );
      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Sub-collection deleted'),
              backgroundColor: AppTheme.success,
            ),
          );
        }
        widget.onRefresh();
      } else {
        String msg = 'Failed';
        try {
          final body = jsonDecode(response.body);
          if (body is Map && body['message'] != null) {
            msg = body['message'].toString();
          }
        } catch (_) {}
        throw Exception('$msg [Code: ${response.statusCode}]');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _deletingIds.remove(subId);
        });
      }
    }
  }

  Future<void> _deleteParentCollection(Map<String, dynamic> col) async {
    final String colId = (col['id'] ?? col['_id'] ?? '').toString();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => _ConfirmDeleteDialog(name: col['name'] as String),
    );
    if (confirmed != true) return;
    setState(() {
      _deletingIds.add(colId);
    });
    try {
      final response = await ApiClient().delete('/collections/$colId');
      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Collection deleted'),
              backgroundColor: AppTheme.success,
            ),
          );
        }
        widget.onRefresh();
      } else {
        String msg = 'Failed';
        try {
          final body = jsonDecode(response.body);
          if (body is Map && body['message'] != null) {
            msg = body['message'].toString();
          }
        } catch (_) {}
        throw Exception('$msg [Code: ${response.statusCode}]');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _deletingIds.remove(colId);
        });
      }
    }
  }

  Future<void> _toggleSubStatus(
    String parentId,
    Map<String, dynamic> sub,
  ) async {
    final String subId = (sub['id'] ?? sub['_id'] ?? '').toString();
    final bool newStatus = !(sub['isActive'] as bool? ?? true);
    try {
      final response = await ApiClient().put(
        '/collections/$parentId/sub/$subId',
        {'name': sub['name'], 'isActive': newStatus},
      );
      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Status set to ${newStatus ? 'Active' : 'Inactive'}',
              ),
              backgroundColor: AppTheme.success,
            ),
          );
        }
        widget.onRefresh();
      } else {
        String msg = 'Failed';
        try {
          final body = jsonDecode(response.body);
          if (body is Map && body['message'] != null) {
            msg = body['message'].toString();
          }
        } catch (_) {}
        throw Exception('$msg [Code: ${response.statusCode}]');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error),
        );
      }
    }
  }

  Widget _buildQuickStats() {
    _recalcStats();
    final totalParent = _cachedTotalParent!;
    final totalSub = _cachedTotalSub!;
    final activeParent = _cachedActiveParent!;
    final linkedProducts = _cachedLinkedProducts!;

    final stats = [
      {
        'title': 'Parent Collections',
        'value': '$totalParent',
        'icon': Icons.collections_bookmark_rounded,
        'color': AppTheme.primaryColor,
      },
      {
        'title': 'Sub-collections',
        'value': '$totalSub',
        'icon': Icons.collections_rounded,
        'color': const Color(0xFF3B82F6),
      },
      {
        'title': 'Active Parent',
        'value': '$activeParent',
        'icon': Icons.published_with_changes_rounded,
        'color': AppTheme.success,
      },
      {
        'title': 'Products Linked',
        'value': '$linkedProducts',
        'icon': Icons.link_rounded,
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
    final isMobile = MediaQuery.of(context).size.width < 768;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header & Search Actions Row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                'Collections Directory',
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Container(
              height: 36,
              width: isMobile ? 180 : 260,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.borderColor),
              ),
              child: TextField(
                onChanged: (val) => setState(() => _searchQuery = val),
                textAlignVertical: TextAlignVertical.center,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppTheme.textPrimary,
                ),
                decoration: const InputDecoration(
                  hintText: 'Search collections...',
                  hintStyle: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 13,
                  ),
                  prefixIcon: Icon(
                    Icons.search,
                    size: 16,
                    color: AppTheme.textSecondary,
                  ),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Quick Stats Cards
        _buildQuickStats(),
        const SizedBox(height: 20),

        // Body
        if (widget.isLoadingCollections)
          Column(
            children: const [_SkeletonRow(), _SkeletonRow(), _SkeletonRow()],
          )
        else if (_filteredCollections.isEmpty)
          Padding(
            padding: const EdgeInsets.all(40),
            child: Center(
              child: Text(
                'No collections found',
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  color: AppTheme.textSecondary,
                ),
              ),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _filteredCollections.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final col = _filteredCollections[index];
              final String colId = (col['id'] ?? col['_id'] ?? '').toString();
              final List<dynamic> subs = col['subCollections'] as List? ?? [];
              final bool isActive = col['isActive'] as bool? ?? true;

              return StatefulBuilder(
                builder: (context, setItemState) {
                  final bool isExpanded = _expandedIds.contains(colId);

                  return _AnimatedListItem(
                    key: ValueKey(colId),
                    index: index,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.borderColor),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.01),
                            blurRadius: 6,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Parent Row
                          InkWell(
                            onTap: () => setItemState(() {
                              if (isExpanded) {
                                _expandedIds.remove(colId);
                              } else {
                                _expandedIds.add(colId);
                              }
                            }),
                            borderRadius: BorderRadius.circular(12),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              child: Row(
                                children: [
                                  // Chevron Toggle
                                  AnimatedRotation(
                                    turns: isExpanded ? 0.25 : 0,
                                    duration: const Duration(milliseconds: 200),
                                    child: Icon(
                                      Icons.chevron_right_rounded,
                                      size: 20,
                                      color: subs.isEmpty
                                          ? AppTheme.textSecondary.withValues(
                                              alpha: 0.2,
                                            )
                                          : AppTheme.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  // Avatar & Name
                                  Expanded(
                                    flex: isMobile ? 1 : 5,
                                    child: Row(
                                      children: [
                                        _CollectionAvatar(
                                          name: col['name'] as String,
                                          isParent: true,
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                col['name'] as String,
                                                style: GoogleFonts.outfit(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w700,
                                                  color: AppTheme.textPrimary,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              if ((col['slug'] as String?)
                                                      ?.isNotEmpty ==
                                                  true)
                                                Container(
                                                  margin: const EdgeInsets.only(
                                                    top: 2,
                                                  ),
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 6,
                                                        vertical: 2,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: const Color(
                                                      0xFFF3F4F6,
                                                    ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          4,
                                                        ),
                                                  ),
                                                  child: Text(
                                                    '/${col['slug']}',
                                                    style: GoogleFonts.outfit(
                                                      fontSize: 10,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                      color: AppTheme
                                                          .textSecondary,
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (isMobile) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppTheme.primaryColor.withValues(
                                          alpha: 0.06,
                                        ),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        '${subs.length} Sub${subs.length != 1 ? 's' : ''}',
                                        style: GoogleFonts.outfit(
                                          fontSize: 11,
                                          color: AppTheme.primaryColor,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    _StatusBadge(isActive: isActive),
                                  ] else ...[
                                    // Sub-collection count pill
                                    Expanded(
                                      flex: 3,
                                      child: Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: AppTheme.primaryColor
                                                  .withValues(alpha: 0.06),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            child: Text(
                                              '${subs.length} Sub${subs.length != 1 ? 's' : ''}',
                                              style: GoogleFonts.outfit(
                                                fontSize: 11,
                                                color: AppTheme.primaryColor,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    // Status Pill
                                    Expanded(
                                      flex: 3,
                                      child: Row(
                                        children: [
                                          _StatusBadge(isActive: isActive),
                                        ],
                                      ),
                                    ),
                                  ],
                                  // Actions
                                  SizedBox(
                                    width: 72,
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        _CircleActionButton(
                                          icon: Icons.edit_outlined,
                                          tooltip: 'Edit Parent Collection',
                                          onTap: () =>
                                              _startEditCollection(col),
                                        ),
                                        const SizedBox(width: 8),
                                        _deletingIds.contains(colId)
                                            ? const SizedBox(
                                                width: 32,
                                                height: 32,
                                                child: Padding(
                                                  padding: EdgeInsets.all(8.0),
                                                  child: CircularProgressIndicator(
                                                    strokeWidth: 2,
                                                    valueColor:
                                                        AlwaysStoppedAnimation<
                                                          Color
                                                        >(AppTheme.error),
                                                  ),
                                                ),
                                              )
                                            : _CircleActionButton(
                                                icon: Icons
                                                    .delete_outline_rounded,
                                                tooltip: 'Delete Collection',
                                                color: AppTheme.error,
                                                onTap: () =>
                                                    _deleteParentCollection(
                                                      col,
                                                    ),
                                              ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // Expanded Sub-collections
                          AnimatedSize(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeOutCubic,
                            alignment: Alignment.topCenter,
                            child: !isExpanded
                                ? const SizedBox(
                                    width: double.infinity,
                                    height: 0,
                                  )
                                : Column(
                                    children: [
                                      const Divider(
                                        height: 1,
                                        color: AppTheme.lightBorderColor,
                                      ),
                                      Container(
                                        color: const Color(0xFFFAFBFD),
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 8,
                                        ),
                                        child: subs.isEmpty
                                            ? Padding(
                                                padding: const EdgeInsets.only(
                                                  left: 64,
                                                  right: 16,
                                                  top: 12,
                                                  bottom: 12,
                                                ),
                                                child: Text(
                                                  'No sub-collections yet. Add sub-collections via product edits.',
                                                  style: GoogleFonts.outfit(
                                                    fontSize: 12,
                                                    color:
                                                        AppTheme.textSecondary,
                                                    fontStyle: FontStyle.italic,
                                                  ),
                                                ),
                                              )
                                            : Column(
                                                children: subs.asMap().entries.map((
                                                  entry,
                                                ) {
                                                  final sub =
                                                      Map<String, dynamic>.from(
                                                        entry.value,
                                                      );
                                                  final String subId =
                                                      (sub['id'] ??
                                                              sub['_id'] ??
                                                              '')
                                                          .toString();
                                                  final bool subActive =
                                                      sub['isActive']
                                                          as bool? ??
                                                      true;
                                                  final bool isLast =
                                                      entry.key ==
                                                      subs.length - 1;

                                                  return Row(
                                                    children: [
                                                      const SizedBox(width: 24),
                                                      // Tree line connector
                                                      CustomPaint(
                                                        size: const Size(
                                                          20,
                                                          48,
                                                        ),
                                                        painter:
                                                            _TreeLinePainter(
                                                              isLast: isLast,
                                                            ),
                                                      ),
                                                      const SizedBox(width: 8),
                                                      Expanded(
                                                        child: Container(
                                                          padding:
                                                              const EdgeInsets.symmetric(
                                                                vertical: 8,
                                                                horizontal: 12,
                                                              ),
                                                          margin:
                                                              const EdgeInsets.only(
                                                                right: 16,
                                                                bottom: 4,
                                                              ),
                                                          decoration: BoxDecoration(
                                                            color: Colors.white,
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  8,
                                                                ),
                                                            border: Border.all(
                                                              color:
                                                                  const Color(
                                                                    0xFFEDF2F7,
                                                                  ),
                                                            ),
                                                          ),
                                                          child: Row(
                                                            children: [
                                                              _CollectionAvatar(
                                                                name:
                                                                    sub['name']
                                                                        as String,
                                                                isParent: false,
                                                              ),
                                                              const SizedBox(
                                                                width: 12,
                                                              ),
                                                              Expanded(
                                                                flex: isMobile
                                                                    ? 1
                                                                    : 5,
                                                                child: Column(
                                                                  crossAxisAlignment:
                                                                      CrossAxisAlignment
                                                                          .start,
                                                                  children: [
                                                                    Text(
                                                                      sub['name']
                                                                          as String,
                                                                      style: GoogleFonts.outfit(
                                                                        fontSize:
                                                                            13,
                                                                        fontWeight:
                                                                            FontWeight.w600,
                                                                        color: AppTheme
                                                                            .textPrimary,
                                                                      ),
                                                                      maxLines:
                                                                          1,
                                                                      overflow:
                                                                          TextOverflow
                                                                              .ellipsis,
                                                                    ),
                                                                    if ((sub['slug']
                                                                                as String?)
                                                                            ?.isNotEmpty ==
                                                                        true)
                                                                      Text(
                                                                        '/${sub['slug']}',
                                                                        style: GoogleFonts.outfit(
                                                                          fontSize:
                                                                              11,
                                                                          color:
                                                                              AppTheme.textSecondary,
                                                                        ),
                                                                      ),
                                                                  ],
                                                                ),
                                                              ),
                                                              if (isMobile) ...[
                                                                const SizedBox(
                                                                  width: 8,
                                                                ),
                                                                GestureDetector(
                                                                  onTap: () =>
                                                                      _toggleSubStatus(
                                                                        colId,
                                                                        sub,
                                                                      ),
                                                                  child: Tooltip(
                                                                    message:
                                                                        'Tap to toggle status',
                                                                    child: _StatusBadge(
                                                                      isActive:
                                                                          subActive,
                                                                    ),
                                                                  ),
                                                                ),
                                                              ] else ...[
                                                                const Expanded(
                                                                  flex: 3,
                                                                  child:
                                                                      SizedBox.shrink(),
                                                                ),
                                                                Expanded(
                                                                  flex: 3,
                                                                  child: Row(
                                                                    children: [
                                                                      GestureDetector(
                                                                        onTap: () => _toggleSubStatus(
                                                                          colId,
                                                                          sub,
                                                                        ),
                                                                        child: Tooltip(
                                                                          message:
                                                                              'Tap to toggle status',
                                                                          child: _StatusBadge(
                                                                            isActive:
                                                                                subActive,
                                                                          ),
                                                                        ),
                                                                      ),
                                                                    ],
                                                                  ),
                                                                ),
                                                              ],
                                                              SizedBox(
                                                                width: 80,
                                                                child: Row(
                                                                  mainAxisAlignment:
                                                                      MainAxisAlignment
                                                                          .end,
                                                                  children: [
                                                                    _CircleActionButton(
                                                                      icon: Icons
                                                                          .edit_outlined,
                                                                      tooltip:
                                                                          'Edit',
                                                                      onTap: () {
                                                                        final copy =
                                                                            Map<
                                                                              String,
                                                                              dynamic
                                                                            >.from(
                                                                              sub,
                                                                            );
                                                                        copy['parentId'] =
                                                                            colId;
                                                                        _startEditCollection(
                                                                          copy,
                                                                        );
                                                                      },
                                                                    ),
                                                                    const SizedBox(
                                                                      width: 8,
                                                                    ),
                                                                    _deletingIds.contains(
                                                                          subId,
                                                                        )
                                                                        ? const SizedBox(
                                                                            width:
                                                                                32,
                                                                            height:
                                                                                32,
                                                                            child: Padding(
                                                                              padding: EdgeInsets.all(
                                                                                8.0,
                                                                              ),
                                                                              child: CircularProgressIndicator(
                                                                                strokeWidth: 2,
                                                                                valueColor:
                                                                                    AlwaysStoppedAnimation<
                                                                                      Color
                                                                                    >(
                                                                                      AppTheme.error,
                                                                                    ),
                                                                              ),
                                                                            ),
                                                                          )
                                                                        : _CircleActionButton(
                                                                            icon:
                                                                                Icons.delete_outline_rounded,
                                                                            tooltip:
                                                                                'Delete',
                                                                            color:
                                                                                AppTheme.error,
                                                                            onTap: () => _deleteSubCollection(
                                                                              colId,
                                                                              sub,
                                                                            ),
                                                                          ),
                                                                  ],
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  );
                                                }).toList(),
                                              ),
                                      ),
                                    ],
                                  ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
      ],
    );
  }

  Widget _headerText(String text) {
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

class _TreeLinePainter extends CustomPainter {
  final bool isLast;
  _TreeLinePainter({required this.isLast});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFD1D5DB)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    // Draw vertical line
    canvas.drawLine(
      Offset(size.width / 2, 0),
      Offset(size.width / 2, isLast ? size.height / 2 : size.height),
      paint,
    );

    // Draw horizontal branch
    canvas.drawLine(
      Offset(size.width / 2, size.height / 2),
      Offset(size.width, size.height / 2),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─── Shared Widgets ────────────────────────────────────────────────────────────

class _CollectionAvatar extends StatelessWidget {
  final String name;
  final bool isParent;
  const _CollectionAvatar({required this.name, required this.isParent});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: isParent ? 36 : 30,
      height: isParent ? 36 : 30,
      decoration: BoxDecoration(
        color: isParent
            ? AppTheme.primaryColor.withValues(alpha: 0.1)
            : AppTheme.primaryColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(isParent ? 8 : 6),
        border: Border.all(
          color: AppTheme.primaryColor.withValues(alpha: isParent ? 0.2 : 0.1),
        ),
      ),
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : 'C',
          style: GoogleFonts.outfit(
            fontSize: isParent ? 14 : 12,
            color: AppTheme.primaryColor,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final bool isActive;
  const _StatusBadge({required this.isActive});

  @override
  Widget build(BuildContext context) {
    final color = isActive ? AppTheme.success : AppTheme.textSecondary;
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
          const SizedBox(width: 5),
          Text(
            isActive ? 'Active' : 'Inactive',
            style: GoogleFonts.outfit(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
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
          child: Icon(icon, size: 15, color: color),
        ),
      ),
    );
  }
}

class _ConfirmDeleteDialog extends StatelessWidget {
  final String name;
  const _ConfirmDeleteDialog({required this.name});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 0,
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 380),
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
              'Delete "$name"?',
              style: GoogleFonts.outfit(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'This action cannot be undone.',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 13,
                color: AppTheme.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
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
                    onPressed: () => Navigator.pop(context, true),
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
  }
}

class _SkeletonRow extends StatefulWidget {
  const _SkeletonRow();

  @override
  State<_SkeletonRow> createState() => _SkeletonRowState();
}

class _SkeletonRowState extends State<_SkeletonRow>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _anim = Tween<double>(
      begin: 0.4,
      end: 0.8,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Opacity(
        opacity: _anim.value,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(
              bottom: BorderSide(color: AppTheme.lightBorderColor),
            ),
          ),
          child: Row(
            children: [
              _box(20, 20, radius: 4),
              const SizedBox(width: 24),
              _box(36, 36, radius: 8),
              const SizedBox(width: 12),
              Expanded(child: _box(12, double.infinity, radius: 4)),
              const SizedBox(width: 16),
              _box(12, 70, radius: 10),
              const SizedBox(width: 16),
              _box(20, 60, radius: 10),
              const SizedBox(width: 16),
              _box(32, 32, radius: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _box(double h, double w, {double radius = 4}) {
    return Container(
      height: h,
      width: w == double.infinity ? null : w,
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

class _AnimatedListItem extends StatefulWidget {
  final int index;
  final Widget child;

  const _AnimatedListItem({
    super.key,
    required this.index,
    required this.child,
  });

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
