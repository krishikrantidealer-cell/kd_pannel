import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kd_pannel/app_theme.dart';
import 'package:kd_pannel/features/admin/presentation/widgets/product/product_form_helpers.dart';

class ProductTagsCard extends StatefulWidget {
  final List<String> tags;
  final TextEditingController tagController;
  final VoidCallback onTagsChanged;

  const ProductTagsCard({
    super.key,
    required this.tags,
    required this.tagController,
    required this.onTagsChanged,
  });

  @override
  State<ProductTagsCard> createState() => _ProductTagsCardState();
}

class _ProductTagsCardState extends State<ProductTagsCard> {
  void _addTag() {
    final val = widget.tagController.text.trim();
    if (val.isNotEmpty && !widget.tags.contains(val)) {
      setState(() {
        widget.tags.add(val);
        widget.tagController.clear();
      });
      widget.onTagsChanged();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ProductSectionCard(
      title: 'Tags & Keywords',
      icon: Icons.sell_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Add custom descriptive keywords to improve product searchability.',
            style: GoogleFonts.outfit(
              color: AppTheme.textSecondary,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryColor.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: TextField(
              controller: widget.tagController,
              decoration: InputDecoration(
                hintText: 'e.g. Organic, Summer, Fertilizer',
                hintStyle: GoogleFonts.outfit(
                  color: AppTheme.textSecondary.withValues(alpha: 0.6),
                  fontSize: 14,
                ),
                prefixIcon: const Icon(
                  Icons.tag_rounded,
                  color: AppTheme.primaryColor,
                  size: 20,
                ),
                suffixIcon: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: InkWell(
                    splashColor: Colors.transparent,
                    highlightColor: Colors.transparent,
                    onTap: _addTag,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppTheme.primaryColor, Color(0xFF2D6A4F)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primaryColor.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.add_circle_outline_rounded,
                            color: Colors.white,
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Add',
                            style: GoogleFonts.outfit(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppTheme.borderColor),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppTheme.borderColor),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: AppTheme.primaryColor,
                    width: 1.5,
                  ),
                ),
              ),
              onSubmitted: (_) => _addTag(),
            ),
          ),
          if (widget.tags.isNotEmpty) ...[
            const SizedBox(height: 20),
            Wrap(
              spacing: 8,
              runSpacing: 10,
              children: widget.tags.map((tag) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                      color: AppTheme.primaryColor.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.tag_rounded,
                        size: 14,
                        color: AppTheme.primaryColor,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        tag,
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                      const SizedBox(width: 6),
                      InkWell(
                        splashColor: Colors.transparent,
                        highlightColor: Colors.transparent,
                        onTap: () {
                          setState(() {
                            widget.tags.remove(tag);
                          });
                          widget.onTagsChanged();
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close_rounded,
                            size: 12,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class ProductCollectionsCard extends StatefulWidget {
  final List<dynamic> backendCollections;
  final List<String> assignedCollections;
  final Map<String, String> collectionIdToName;
  final VoidCallback onCollectionsChanged;

  const ProductCollectionsCard({
    super.key,
    required this.backendCollections,
    required this.assignedCollections,
    required this.collectionIdToName,
    required this.onCollectionsChanged,
  });

  @override
  State<ProductCollectionsCard> createState() => _ProductCollectionsCardState();
}

class _ProductCollectionsCardState extends State<ProductCollectionsCard> {
  String? _selectedCollection;
  String? _selectedSubCollection;

  @override
  Widget build(BuildContext context) {
    final List<String> collectionOptions = [];
    final Map<String, List<Map<String, String>>> subCollectionMap = {};

    for (var col in widget.backendCollections) {
      final colId = col['id']?.toString() ?? col['_id']?.toString() ?? '';
      final colName = col['name']?.toString() ?? '';
      if (colId.isNotEmpty && colName.isNotEmpty) {
        collectionOptions.add(colName);

        final List subs = col['subCollections'] ?? [];
        final List<Map<String, String>> subList = [];
        for (var sub in subs) {
          final subId = sub['id']?.toString() ?? sub['_id']?.toString() ?? '';
          final subName = sub['name']?.toString() ?? '';
          if (subId.isNotEmpty && subName.isNotEmpty) {
            subList.add({'id': subId, 'name': subName});
          }
        }
        subCollectionMap[colName] = subList;
      }
    }

    final currentSubOptions = _selectedCollection != null
        ? (subCollectionMap[_selectedCollection] ?? [])
        : <Map<String, String>>[];

    final List<String> subCollectionNames = currentSubOptions
        .map((e) => e['name']!)
        .toList();
    subCollectionNames.insert(0, 'All Sub-collections');

    return ProductSectionCard(
      title: 'Collections',
      icon: Icons.collections_bookmark_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.assignedCollections.isNotEmpty) ...[
            Wrap(
              spacing: 8,
              runSpacing: 10,
              children: widget.assignedCollections.map((col) {
                final displayName = widget.collectionIdToName[col] ?? col;
                return Container(
                  padding: const EdgeInsets.only(
                    left: 12,
                    right: 8,
                    top: 6,
                    bottom: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.02),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          displayName,
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: () {
                          setState(() {
                            widget.assignedCollections.remove(col);
                          });
                          widget.onCollectionsChanged();
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: const BoxDecoration(
                            color: Color(0xFFF1F5F9),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close_rounded,
                            size: 14,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
          ],
          Container(
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 5,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 16),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        padding: EdgeInsets.zero,
                        hint: Text(
                          'Select Collection',
                          style: GoogleFonts.outfit(
                            fontSize: 14,
                            color: const Color(0xFF94A3B8),
                          ),
                        ),
                        value: _selectedCollection,
                        icon: const Padding(
                          padding: EdgeInsets.only(right: 8),
                          child: Icon(
                            Icons.keyboard_arrow_down_rounded,
                            size: 18,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                        items: collectionOptions.map((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(
                              value,
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                              style: GoogleFonts.outfit(
                                fontSize: 14,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          setState(() {
                            _selectedCollection = val;
                            _selectedSubCollection = 'All Sub-collections';
                          });
                        },
                      ),
                    ),
                  ),
                ),
                if (_selectedCollection != null) ...[
                  Container(
                    width: 1,
                    height: 24,
                    color: const Color(0xFFE2E8F0),
                  ),
                  Expanded(
                    flex: 5,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 12),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          isExpanded: true,
                          padding: EdgeInsets.zero,
                          value: _selectedSubCollection,
                          icon: const Padding(
                            padding: EdgeInsets.only(right: 8),
                            child: Icon(
                              Icons.keyboard_arrow_down_rounded,
                              size: 18,
                              color: Color(0xFF94A3B8),
                            ),
                          ),
                          items: subCollectionNames.map((String value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(
                                value,
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                                style: GoogleFonts.outfit(
                                  fontSize: 14,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            setState(() {
                              _selectedSubCollection = val;
                            });
                          },
                        ),
                      ),
                    ),
                  ),
                ],
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: InkWell(
                    onTap: _selectedCollection == null
                        ? null
                        : () {
                            setState(() {
                              String idToAssign = '';
                              if (_selectedSubCollection !=
                                  'All Sub-collections') {
                                idToAssign = _selectedSubCollection!;
                              } else {
                                idToAssign = _selectedCollection!;
                              }
                              if (idToAssign.isNotEmpty &&
                                  !widget.assignedCollections.contains(idToAssign)) {
                                widget.assignedCollections.add(idToAssign);
                                _selectedCollection = null;
                                _selectedSubCollection = null;
                              }
                            });
                            widget.onCollectionsChanged();
                          },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: _selectedCollection == null
                            ? const Color(0xFFE2E8F0)
                            : AppTheme.primaryColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.add_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
