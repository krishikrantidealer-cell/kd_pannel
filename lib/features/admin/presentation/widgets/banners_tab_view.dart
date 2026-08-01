import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:file_picker/file_picker.dart' as fp;
import 'package:kd_pannel/app_theme.dart';
import 'package:kd_pannel/core/network/api_client.dart';
import 'package:kd_pannel/core/responsive/responsive.dart';

class BannersTabView extends StatefulWidget {
  final VoidCallback? onRefresh;

  const BannersTabView({
    super.key,
    this.onRefresh,
  });

  @override
  State<BannersTabView> createState() => _BannersTabViewState();
}

class _BannersTabViewState extends State<BannersTabView> {
  List<Map<String, dynamic>> _banners = [];
  bool _isLoading = true;
  String? _errorMessage;
  String _selectedTypeFilter = 'all';
  String _searchQuery = '';
  bool _isGridView = false; // Default to sleek, compact list view

  @override
  void initState() {
    super.initState();
    _fetchBanners();
  }

  Future<void> _fetchBanners() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await ApiClient().get('/banners');
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded['success'] == true && decoded['banners'] is List) {
          setState(() {
            _banners = List<Map<String, dynamic>>.from(decoded['banners']);
            _isLoading = false;
          });
          return;
        }
      }
      setState(() {
        _errorMessage = 'Failed to load banners (${response.statusCode})';
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error loading banners: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _toggleBannerActive(Map<String, dynamic> banner) async {
    final String id = banner['_id'] ?? banner['id'] ?? '';
    if (id.isEmpty) return;

    final bool currentActive = banner['isActive'] == true;
    setState(() {
      banner['isActive'] = !currentActive;
    });

    try {
      final response = await ApiClient().patch('/banners/$id/toggle');
      if (response.statusCode != 200) {
        setState(() {
          banner['isActive'] = currentActive;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to update banner status')),
          );
        }
      }
    } catch (e) {
      setState(() {
        banner['isActive'] = currentActive;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating banner: $e')),
        );
      }
    }
  }

  Future<void> _deleteBanner(Map<String, dynamic> banner) async {
    final String id = banner['_id'] ?? banner['id'] ?? '';
    final String title = banner['title'] ?? 'this banner';
    if (id.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Delete Banner',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Are you sure you want to delete "$title"? This action cannot be undone.',
          style: GoogleFonts.outfit(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: GoogleFonts.outfit(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text('Delete', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final response = await ApiClient().delete('/banners/$id');
      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Banner deleted successfully')),
          );
        }
        _fetchBanners();
        widget.onRefresh?.call();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete banner (${response.statusCode})')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting banner: $e')),
        );
      }
    }
  }

  void _openBannerFormModal([Map<String, dynamic>? existingBanner]) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _BannerFormDialog(
        existingBanner: existingBanner,
        onSaved: () {
          _fetchBanners();
          widget.onRefresh?.call();
        },
      ),
    );
  }

  void _showImagePreview(String imageUrl, String title) {
    if (imageUrl.isEmpty) return;
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        clipBehavior: Clip.antiAlias,
        child: Container(
          width: 700,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.8,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        title.isNotEmpty ? title : 'Banner Preview',
                        style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: Color(0xFFE5E7EB)),
              Flexible(
                child: SingleChildScrollView(
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Padding(
                      padding: EdgeInsets.all(40),
                      child: Icon(Icons.broken_image_rounded, size: 48, color: Colors.grey),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Map<String, dynamic>> get _filteredBanners {
    return _banners.where((banner) {
      final type = (banner['type'] ?? 'home').toString();
      final title = (banner['title'] ?? '').toString().toLowerCase();

      if (_selectedTypeFilter != 'all' && type != _selectedTypeFilter) {
        return false;
      }
      if (_searchQuery.isNotEmpty && !title.contains(_searchQuery.toLowerCase())) {
        return false;
      }
      return true;
    }).toList();
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'home':
        return const Color(0xFF10B981);
      case 'strip':
        return const Color(0xFFEC4899);
      case 'category':
        return const Color(0xFF3B82F6);
      case 'category_card':
        return const Color(0xFF8B5CF6);
      case 'best_offers':
        return const Color(0xFFF59E0B);
      default:
        return const Color(0xFF6B7280);
    }
  }

  String _getTypeLabel(String type) {
    switch (type) {
      case 'home':
        return 'Home Carousel';
      case 'strip':
        return 'Header Strip';
      case 'category':
        return 'Category Top';
      case 'category_card':
        return 'Category Card';
      case 'best_offers':
        return 'Best Offers';
      default:
        return type.toUpperCase();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isMobile = Responsive.isMobile(context);
    final int totalCount = _banners.length;
    final int activeCount = _banners.where((b) => b['isActive'] == true).length;
    final filtered = _filteredBanners;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Top Header Summary & Control Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.borderColor),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Row 1: Title, Quick Stats, View Mode & Add Button
              Row(
                children: [
                  // Title & Stats
                  Expanded(
                    child: Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        Text(
                          'Banner Management',
                          style: GoogleFonts.outfit(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        _buildBadgeChip(
                          label: '$totalCount Total',
                          color: AppTheme.primaryColor,
                          icon: Icons.photo_library_outlined,
                        ),
                        _buildBadgeChip(
                          label: '$activeCount Active',
                          color: const Color(0xFF10B981),
                          icon: Icons.check_circle_outline_rounded,
                        ),
                      ],
                    ),
                  ),

                  // View Toggle & Add Button
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // View Mode Toggle (List vs Grid)
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            InkWell(
                              onTap: () => setState(() => _isGridView = false),
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                decoration: BoxDecoration(
                                  color: !_isGridView ? Colors.white : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                  boxShadow: !_isGridView
                                      ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)]
                                      : null,
                                ),
                                child: Icon(
                                  Icons.format_list_bulleted_rounded,
                                  size: 18,
                                  color: !_isGridView ? AppTheme.primaryColor : Colors.grey.shade600,
                                ),
                              ),
                            ),
                            InkWell(
                              onTap: () => setState(() => _isGridView = true),
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                decoration: BoxDecoration(
                                  color: _isGridView ? Colors.white : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                  boxShadow: _isGridView
                                      ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)]
                                      : null,
                                ),
                                child: Icon(
                                  Icons.grid_view_rounded,
                                  size: 18,
                                  color: _isGridView ? AppTheme.primaryColor : Colors.grey.shade600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Add Banner Button
                      ElevatedButton.icon(
                        onPressed: () => _openBannerFormModal(),
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: Text(
                          isMobile ? 'Add' : 'Upload Banner',
                          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Row 2: Search Bar & Section Filter Chips
              Row(
                children: [
                  Expanded(
                    flex: isMobile ? 1 : 0,
                    child: SizedBox(
                      width: isMobile ? double.infinity : 240,
                      height: 36,
                      child: TextField(
                        onChanged: (val) => setState(() => _searchQuery = val),
                        style: GoogleFonts.outfit(fontSize: 13),
                        decoration: InputDecoration(
                          hintText: 'Search banners...',
                          hintStyle: GoogleFonts.outfit(color: AppTheme.textSecondary, fontSize: 13),
                          prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.textSecondary, size: 18),
                          filled: true,
                          fillColor: const Color(0xFFF9FAFB),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.grey.shade200),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Horizontal Category Chips
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildFilterChip('all', 'All'),
                          const SizedBox(width: 6),
                          _buildFilterChip('home', 'Home Carousel'),
                          const SizedBox(width: 6),
                          _buildFilterChip('strip', 'Header Strip'),
                          const SizedBox(width: 6),
                          _buildFilterChip('category', 'Category Top'),
                          const SizedBox(width: 6),
                          _buildFilterChip('category_card', 'Category Card'),
                          const SizedBox(width: 6),
                          _buildFilterChip('best_offers', 'Best Offers'),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Main List Content
        if (_isLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(
              child: CircularProgressIndicator(color: AppTheme.primaryColor),
            ),
          )
        else if (_errorMessage != null)
          Container(
            padding: const EdgeInsets.all(20),
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red.shade200),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline_rounded, color: Colors.red),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _errorMessage!,
                    style: GoogleFonts.outfit(color: Colors.red.shade800),
                  ),
                ),
                TextButton(
                  onPressed: _fetchBanners,
                  child: Text('Retry', style: GoogleFonts.outfit(color: Colors.red.shade900, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          )
        else if (filtered.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 20),
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.borderColor),
            ),
            child: Column(
              children: [
                Icon(Icons.collections_outlined, size: 52, color: Colors.grey.shade400),
                const SizedBox(height: 12),
                Text(
                  'No Banners Found',
                  style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                ),
                const SizedBox(height: 4),
                Text(
                  'Upload banners to feature them on the mobile application',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(fontSize: 13, color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => _openBannerFormModal(),
                  icon: const Icon(Icons.add_rounded, size: 16),
                  label: Text('Upload Banner', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
          )
        else if (!_isGridView)
          // Sleek Compact List View (Default)
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: filtered.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final banner = filtered[index];
              return _buildCompactBannerRow(banner);
            },
          )
        else
          // Compact Grid View Option
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: isMobile ? 1 : 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              mainAxisExtent: 210, // Compact grid height
            ),
            itemCount: filtered.length,
            itemBuilder: (context, index) {
              final banner = filtered[index];
              return _buildCompactGridCard(banner);
            },
          ),
      ],
    );
  }

  Widget _buildBadgeChip({
    required String label,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String type, String label) {
    final bool isSelected = _selectedTypeFilter == type;
    final Color color = type == 'all' ? AppTheme.primaryColor : _getTypeColor(type);

    return InkWell(
      onTap: () => setState(() => _selectedTypeFilter = type),
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? color : Colors.grey.shade200,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }

  // --- Compact List View Row ---
  Widget _buildCompactBannerRow(Map<String, dynamic> banner) {
    final String imageUrl = banner['imageUrl'] ?? '';
    final String title = banner['title'] ?? 'Untitled Banner';
    final String type = banner['type'] ?? 'home';
    final bool isActive = banner['isActive'] == true;
    final int priority = (banner['priority'] as num?)?.toInt() ?? 0;
    final String redirectType = banner['redirectType'] ?? 'none';
    final String? redirectTarget = banner['redirectTarget'];
    final Color typeColor = _getTypeColor(type);
    final String typeLabel = _getTypeLabel(type);

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.015),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          // 1. Thumbnail Image Preview (Clickable)
          GestureDetector(
            onTap: () => _showImagePreview(imageUrl, title),
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: 96,
                    height: 54,
                    child: imageUrl.isNotEmpty
                        ? Image.network(
                            imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: Colors.grey.shade100,
                              child: const Icon(Icons.broken_image_rounded, size: 24, color: Colors.grey),
                            ),
                          )
                        : Container(
                            color: Colors.grey.shade100,
                            child: const Icon(Icons.image_rounded, size: 24, color: Colors.grey),
                          ),
                  ),
                ),
                Positioned(
                  bottom: 2,
                  right: 2,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Icon(Icons.zoom_in_rounded, color: Colors.white, size: 12),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),

          // 2. Banner Details & Badges
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    // Title
                    Expanded(
                      child: Text(
                        title.isNotEmpty ? title : 'Untitled Banner',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Section Type Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: typeColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        typeLabel,
                        style: GoogleFonts.outfit(
                          color: typeColor,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),

                    // Priority Chip
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'P: $priority',
                        style: GoogleFonts.outfit(
                          color: Colors.grey.shade700,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),

                // Redirect Target info tag
                Row(
                  children: [
                    Icon(
                      redirectType == 'none' ? Icons.link_off_rounded : Icons.link_rounded,
                      size: 13,
                      color: AppTheme.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      redirectType == 'none'
                          ? 'No Redirect'
                          : '${redirectType.toUpperCase()}: ${redirectTarget ?? ''}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(width: 12),

          // 3. Actions: Active Switch & Edit / Delete Buttons
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Active Toggle Switch
              Tooltip(
                message: isActive ? 'Banner Active' : 'Banner Inactive',
                child: Transform.scale(
                  scale: 0.75,
                  child: Switch(
                    value: isActive,
                    activeTrackColor: AppTheme.primaryColor.withValues(alpha: 0.5),
                    activeThumbColor: AppTheme.primaryColor,
                    onChanged: (_) => _toggleBannerActive(banner),
                  ),
                ),
              ),
              const SizedBox(width: 4),

              // Edit Button
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 18),
                color: AppTheme.primaryColor,
                tooltip: 'Edit Banner',
                visualDensity: VisualDensity.compact,
                onPressed: () => _openBannerFormModal(banner),
              ),

              // Delete Button
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, size: 18),
                color: Colors.red.shade400,
                tooltip: 'Delete Banner',
                visualDensity: VisualDensity.compact,
                onPressed: () => _deleteBanner(banner),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- Compact Grid View Card ---
  Widget _buildCompactGridCard(Map<String, dynamic> banner) {
    final String imageUrl = banner['imageUrl'] ?? '';
    final String title = banner['title'] ?? 'Untitled Banner';
    final String type = banner['type'] ?? 'home';
    final bool isActive = banner['isActive'] == true;
    final int priority = (banner['priority'] as num?)?.toInt() ?? 0;
    final String redirectType = banner['redirectType'] ?? 'none';
    final String? redirectTarget = banner['redirectTarget'];
    final Color typeColor = _getTypeColor(type);
    final String typeLabel = _getTypeLabel(type);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner Image Header (height 110px)
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
                child: SizedBox(
                  height: 110,
                  width: double.infinity,
                  child: imageUrl.isNotEmpty
                      ? Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: Colors.grey.shade100,
                            child: const Center(
                              child: Icon(Icons.broken_image_rounded, color: Colors.grey, size: 30),
                            ),
                          ),
                        )
                      : Container(
                          color: Colors.grey.shade100,
                          child: const Center(
                            child: Icon(Icons.image_rounded, color: Colors.grey, size: 30),
                          ),
                        ),
                ),
              ),
              Positioned(
                top: 8,
                left: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: typeColor.withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    typeLabel,
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.65),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'P: $priority',
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Details Section
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title.isNotEmpty ? title : 'Untitled Banner',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ),
                      Transform.scale(
                        scale: 0.7,
                        child: Switch(
                          value: isActive,
                          activeThumbColor: AppTheme.primaryColor,
                          onChanged: (_) => _toggleBannerActive(banner),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    redirectType == 'none'
                        ? 'No Redirect'
                        : '${redirectType.toUpperCase()}: ${redirectTarget ?? ''}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const Spacer(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      InkWell(
                        onTap: () => _openBannerFormModal(banner),
                        borderRadius: BorderRadius.circular(6),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                          child: Row(
                            children: [
                              const Icon(Icons.edit_rounded, size: 14, color: AppTheme.primaryColor),
                              const SizedBox(width: 2),
                              Text('Edit', style: GoogleFonts.outfit(fontSize: 11, color: AppTheme.primaryColor, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: () => _deleteBanner(banner),
                        borderRadius: BorderRadius.circular(6),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                          child: Row(
                            children: [
                              Icon(Icons.delete_outline_rounded, size: 14, color: Colors.red.shade400),
                              const SizedBox(width: 2),
                              Text('Delete', style: GoogleFonts.outfit(fontSize: 11, color: Colors.red.shade400, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BannerFormDialog extends StatefulWidget {
  final Map<String, dynamic>? existingBanner;
  final VoidCallback onSaved;

  const _BannerFormDialog({
    this.existingBanner,
    required this.onSaved,
  });

  @override
  State<_BannerFormDialog> createState() => _BannerFormDialogState();
}

class _BannerFormDialogState extends State<_BannerFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _priorityController;
  late TextEditingController _redirectTargetController;

  int _selectedTab = 0; // 0 = Form Setup, 1 = Live Mobile Preview
  String _selectedType = 'home';
  String _selectedRedirectType = 'none';
  bool _isActive = true;
  fp.PlatformFile? _pickedImageFile;
  bool _isSaving = false;
  String? _errorMsg;
  String _uploadStepText = '';

  // Dynamic Backend Targets
  List<Map<String, dynamic>> _backendCategories = [];
  List<Map<String, dynamic>> _backendProducts = [];
  List<Map<String, dynamic>> _backendCollections = [];
  bool _isLoadingTargets = false;

  @override
  void initState() {
    super.initState();
    final b = widget.existingBanner;
    _titleController = TextEditingController(text: b?['title'] ?? '');
    _priorityController = TextEditingController(text: (b?['priority'] ?? 0).toString());
    _redirectTargetController = TextEditingController(text: b?['redirectTarget'] ?? '');
    _selectedType = b?['type'] ?? 'home';
    _selectedRedirectType = b?['redirectType'] ?? 'none';
    _isActive = b?['isActive'] ?? true;
    _fetchBackendTargets();
  }

  Future<void> _fetchBackendTargets() async {
    if (!mounted) return;
    setState(() => _isLoadingTargets = true);

    try {
      final results = await Future.wait([
        ApiClient().get('/products/categories').catchError((_) => http.Response('[]', 200)),
        ApiClient().get('/products?limit=500').catchError((_) => http.Response('[]', 200)),
        ApiClient().get('/collections?all=true').catchError((_) => http.Response('[]', 200)),
      ]);

      // 1. Categories
      if (results[0].statusCode == 200) {
        final decoded = jsonDecode(results[0].body);
        final raw = decoded is List ? decoded : (decoded['categories'] ?? decoded['data'] ?? []);
        if (raw is List) {
          _backendCategories = List<Map<String, dynamic>>.from(raw);
        }
      }

      // 2. Products
      if (results[1].statusCode == 200) {
        final decoded = jsonDecode(results[1].body);
        final raw = decoded is List ? decoded : (decoded['products'] ?? decoded['data'] ?? []);
        if (raw is List) {
          _backendProducts = List<Map<String, dynamic>>.from(raw);
        }
      }

      // 3. Collections
      if (results[2].statusCode == 200) {
        final decoded = jsonDecode(results[2].body);
        final raw = decoded is List ? decoded : (decoded['collections'] ?? decoded['data'] ?? []);
        if (raw is List) {
          _backendCollections = List<Map<String, dynamic>>.from(raw);
        }
      }
    } catch (e) {
      debugPrint('Error loading backend target options: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoadingTargets = false);
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _priorityController.dispose();
    _redirectTargetController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final result = await fp.FilePicker.pickFiles(
        type: fp.FileType.image,
        withData: true,
      );
      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _pickedImageFile = result.files.first;
          _errorMsg = null;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick image: $e')),
        );
      }
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  Map<String, String> _getSectionSpecs(String type) {
    switch (type) {
      case 'home':
        return {
          'ratio': '2.35 : 1',
          'resolution': '1200 × 510 px',
          'description': 'Main Hero Carousel on App Home',
        };
      case 'strip':
        return {
          'ratio': '8 : 1',
          'resolution': '1200 × 150 px',
          'description': 'Header Strip Announcement Banner',
        };
      case 'category':
        return {
          'ratio': '3 : 1',
          'resolution': '1200 × 400 px',
          'description': 'Category Top Banner',
        };
      case 'category_card':
        return {
          'ratio': '1 : 1',
          'resolution': '600 × 600 px',
          'description': 'Grid Category Promotion Card',
        };
      case 'best_offers':
        return {
          'ratio': '16 : 9',
          'resolution': '800 × 450 px',
          'description': 'Best Offers Showcase Section',
        };
      default:
        return {
          'ratio': '16 : 9',
          'resolution': '800 × 450 px',
          'description': 'Standard App Banner',
        };
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    final isEditing = widget.existingBanner != null;

    if (!isEditing && _pickedImageFile == null) {
      setState(() {
        _errorMsg = 'Please select a banner artwork to upload';
      });
      return;
    }

    if (_selectedRedirectType == 'external') {
      final target = _redirectTargetController.text.trim();
      if (target.isNotEmpty && !target.startsWith('http://') && !target.startsWith('https://')) {
        _redirectTargetController.text = 'https://$target';
      }
    }

    setState(() {
      _isSaving = true;
      _errorMsg = null;
      _uploadStepText = 'Validating banner payload...';
    });

    try {
      await Future.delayed(const Duration(milliseconds: 300));
      if (mounted) {
        setState(() {
          _uploadStepText = 'Uploading artwork to cloud server...';
        });
      }

      final fields = <String, String>{
        'title': _titleController.text.trim(),
        'priority': _priorityController.text.trim(),
        'type': _selectedType,
        'redirectType': _selectedRedirectType,
        'redirectTarget': _redirectTargetController.text.trim(),
        'isActive': _isActive.toString(),
      };

      final bannerId = widget.existingBanner?['_id'] ?? widget.existingBanner?['id'];
      final endpoint = isEditing ? '/banners/$bannerId' : '/banners';
      final method = isEditing ? 'PUT' : 'POST';

      final response = await ApiClient().multipartRequest(
        method: method,
        endpoint: endpoint,
        fields: fields,
        filesBuilder: () {
          if (_pickedImageFile != null && _pickedImageFile!.bytes != null) {
            final ext = _pickedImageFile!.name.split('.').last.toLowerCase();
            return [
              http.MultipartFile.fromBytes(
                'image',
                _pickedImageFile!.bytes!,
                filename: _pickedImageFile!.name,
                contentType: MediaType('image', ext == 'jpg' ? 'jpeg' : ext),
              ),
            ];
          }
          return [];
        },
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (mounted) {
          Navigator.pop(context);
          widget.onSaved();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(isEditing ? 'Banner updated successfully' : 'Banner uploaded successfully'),
            ),
          );
        }
      } else {
        final err = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _errorMsg = err['message'] ?? 'Server error (${response.statusCode})';
            _isSaving = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMsg = 'Error saving banner: $e';
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existingBanner != null;
    final String? existingImageUrl = widget.existingBanner?['imageUrl'];
    final specs = _getSectionSpecs(_selectedType);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      elevation: 8,
      child: Container(
        width: 680,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.88,
        ),
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top Header & Studio Title
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [AppTheme.primaryColor, Color(0xFF059669)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.primaryColor.withValues(alpha: 0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 22),
                        ),
                        const SizedBox(width: 14),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isEditing ? 'Edit Banner Studio' : 'Upload Banner Studio',
                              style: GoogleFonts.outfit(
                                fontSize: 19,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            Text(
                              'Configure banner placement, specs & mobile preview',
                              style: GoogleFonts.outfit(fontSize: 12, color: AppTheme.textSecondary),
                            ),
                          ],
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 22),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),

                const SizedBox(height: 18),

                // Dual Mode Switcher Bar (Configuration vs Live App Preview)
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () => setState(() => _selectedTab = 0),
                          borderRadius: BorderRadius.circular(8),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.symmetric(vertical: 9),
                            decoration: BoxDecoration(
                              color: _selectedTab == 0 ? Colors.white : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: _selectedTab == 0
                                  ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)]
                                  : null,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.tune_rounded,
                                  size: 16,
                                  color: _selectedTab == 0 ? AppTheme.primaryColor : Colors.grey.shade600,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Banner Configuration',
                                  style: GoogleFonts.outfit(
                                    fontSize: 13,
                                    fontWeight: _selectedTab == 0 ? FontWeight.bold : FontWeight.w500,
                                    color: _selectedTab == 0 ? AppTheme.primaryColor : Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: InkWell(
                          onTap: () => setState(() => _selectedTab = 1),
                          borderRadius: BorderRadius.circular(8),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.symmetric(vertical: 9),
                            decoration: BoxDecoration(
                              color: _selectedTab == 1 ? Colors.white : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: _selectedTab == 1
                                  ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)]
                                  : null,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.phone_iphone_rounded,
                                  size: 16,
                                  color: _selectedTab == 1 ? AppTheme.primaryColor : Colors.grey.shade600,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Live Mobile App Preview',
                                  style: GoogleFonts.outfit(
                                    fontSize: 13,
                                    fontWeight: _selectedTab == 1 ? FontWeight.bold : FontWeight.w500,
                                    color: _selectedTab == 1 ? AppTheme.primaryColor : Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 18),

                if (_errorMsg != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline_rounded, color: Colors.red, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(_errorMsg!, style: GoogleFonts.outfit(color: Colors.red.shade800, fontSize: 13)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                // TAB 0: Configuration Form
                if (_selectedTab == 0) ...[
                  // 1. Placement Selector & Guidelines Box
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Section Placement *', style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 13)),
                            const SizedBox(height: 6),
                            DropdownButtonFormField<String>(
                              isExpanded: true,
                              initialValue: _selectedType,
                              style: GoogleFonts.outfit(fontSize: 13, color: AppTheme.textPrimary),
                              decoration: InputDecoration(
                                prefixIcon: const Icon(Icons.space_dashboard_outlined, size: 18, color: AppTheme.primaryColor),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              ),
                              items: const [
                                DropdownMenuItem(value: 'home', child: Text('Home Carousel (Hero)')),
                                DropdownMenuItem(value: 'strip', child: Text('Header Strip Banner')),
                                DropdownMenuItem(value: 'category', child: Text('Category Top Banner')),
                                DropdownMenuItem(value: 'category_card', child: Text('Category Card Banner')),
                                DropdownMenuItem(value: 'best_offers', child: Text('Best Offers Showcase')),
                              ],
                              onChanged: (val) {
                                if (val != null) setState(() => _selectedType = val);
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Live Spec Guide Card
                      Expanded(
                        flex: 2,
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF9FAFB),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.aspect_ratio_rounded, size: 14, color: AppTheme.primaryColor),
                                  const SizedBox(width: 4),
                                  Text('Recommended Specs', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text('Ratio: ${specs['ratio']}', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                              Text('Res: ${specs['resolution']}', style: GoogleFonts.outfit(fontSize: 11, color: AppTheme.textSecondary)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),


                  const SizedBox(height: 16),


                  // 2. Image Upload Dropzone Card
                  Text('Banner Artwork *', style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: _pickImage,
                    child: Container(
                      height: 150,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: _pickedImageFile != null ? AppTheme.primaryColor : AppTheme.borderColor,
                          width: _pickedImageFile != null ? 2 : 1,
                        ),
                      ),
                      child: _pickedImageFile != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Stack(
                                children: [
                                  Positioned.fill(
                                    child: Image.memory(_pickedImageFile!.bytes!, fit: BoxFit.cover),
                                  ),
                                  Positioned(
                                    bottom: 0,
                                    left: 0,
                                    right: 0,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      color: Colors.black.withValues(alpha: 0.75),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.image_rounded, color: Colors.white, size: 16),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  _pickedImageFile!.name,
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: GoogleFonts.outfit(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                                ),
                                                Text(
                                                  _formatFileSize(_pickedImageFile!.size),
                                                  style: GoogleFonts.outfit(color: Colors.grey.shade300, fontSize: 11),
                                                ),
                                              ],
                                            ),
                                          ),
                                          TextButton.icon(
                                            onPressed: _pickImage,
                                            icon: const Icon(Icons.swap_horiz_rounded, color: Colors.white, size: 16),
                                            label: Text('Change', style: GoogleFonts.outfit(color: Colors.white, fontSize: 12)),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : (existingImageUrl != null && existingImageUrl.isNotEmpty)
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Stack(
                                    children: [
                                      Positioned.fill(
                                        child: Image.network(existingImageUrl, fit: BoxFit.cover),
                                      ),
                                      Positioned(
                                        bottom: 0,
                                        left: 0,
                                        right: 0,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                          color: Colors.black.withValues(alpha: 0.7),
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text('Current Active Image', style: GoogleFonts.outfit(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                                              TextButton.icon(
                                                onPressed: _pickImage,
                                                icon: const Icon(Icons.cloud_upload_outlined, color: Colors.white, size: 16),
                                                label: Text('Replace Image', style: GoogleFonts.outfit(color: Colors.white, fontSize: 12)),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: AppTheme.primaryColor.withValues(alpha: 0.1),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.cloud_upload_rounded, size: 32, color: AppTheme.primaryColor),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Click to upload banner artwork',
                                      style: GoogleFonts.outfit(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        color: AppTheme.primaryColor,
                                      ),
                                    ),
                                    Text(
                                      'Supports PNG, JPG, WebP (Ideal resolution: ${specs['resolution']})',
                                      style: GoogleFonts.outfit(fontSize: 12, color: AppTheme.textSecondary),
                                    ),
                                  ],
                                ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 3. Section Placement & Target Dropdown
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Section Placement & Target *', style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 13)),
                      const SizedBox(height: 4),
                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        decoration: InputDecoration(
                          hintText: '-- Select Target Placement Section --',
                          prefixIcon: const Icon(Icons.stars_rounded, size: 18, color: AppTheme.primaryColor),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        items: () {
                          final List<DropdownMenuItem<String>> items = [];
                          if (_selectedType == 'strip') {
                            items.add(const DropdownMenuItem(value: 'dealer_first_choice', child: Text('Dealer First Choice (Home Section Strip)')));
                            items.add(const DropdownMenuItem(value: 'categories', child: Text('Categories Section (Header Strip)')));
                            items.add(const DropdownMenuItem(value: 'featured', child: Text('Featured Products Section (Header Strip)')));
                            items.add(const DropdownMenuItem(value: 'shop_by_crop', child: Text('Shop By Crop Section (Header Strip)')));
                            for (final cat in _backendCategories) {
                              final name = (cat['name'] ?? cat['title'] ?? '').toString();
                              final bannerTitle = (cat['bannerTitle'] ?? '').toString().trim();
                              final displayLabel = bannerTitle.isNotEmpty ? bannerTitle : name;
                              final id = (cat['_id'] ?? cat['id'] ?? name).toString();
                              if (name.isNotEmpty) {
                                items.add(DropdownMenuItem(value: 'cat_$id', child: Text('Category Strip: $displayLabel')));
                              }
                            }
                            for (final col in _backendCollections) {
                              final name = (col['name'] ?? col['title'] ?? '').toString();
                              final bannerTitle = (col['bannerTitle'] ?? '').toString().trim();
                              final displayLabel = bannerTitle.isNotEmpty ? bannerTitle : name;
                              final id = (col['_id'] ?? col['id'] ?? name).toString();
                              if (name.isNotEmpty) {
                                items.add(DropdownMenuItem(value: 'col_$id', child: Text('Collection Strip: $displayLabel')));
                              }
                            }
                          } else if (_selectedType == 'category' || _selectedType == 'category_card') {
                            for (final cat in _backendCategories) {
                              final name = (cat['name'] ?? cat['title'] ?? '').toString();
                              final bannerTitle = (cat['bannerTitle'] ?? '').toString().trim();
                              final displayLabel = bannerTitle.isNotEmpty ? bannerTitle : name;
                              final id = (cat['_id'] ?? cat['id'] ?? name).toString();
                              if (name.isNotEmpty) {
                                items.add(DropdownMenuItem(value: 'cat_$id', child: Text('Category: $displayLabel')));
                              }
                            }
                          } else if (_selectedType == 'best_offers') {
                            items.add(const DropdownMenuItem(value: 'best_offers_main', child: Text('Best Offers Showcase')));
                            for (final col in _backendCollections) {
                              final name = (col['name'] ?? col['title'] ?? '').toString();
                              final bannerTitle = (col['bannerTitle'] ?? '').toString().trim();
                              final displayLabel = bannerTitle.isNotEmpty ? bannerTitle : name;
                              final id = (col['_id'] ?? col['id'] ?? name).toString();
                              if (name.isNotEmpty) {
                                items.add(DropdownMenuItem(value: 'col_$id', child: Text('Collection Offer: $displayLabel')));
                              }
                            }
                          } else {
                            items.add(const DropdownMenuItem(value: 'home_hero_main', child: Text('Home Hero Carousel Main Banner')));
                            for (final col in _backendCollections) {
                              final name = (col['name'] ?? col['title'] ?? '').toString();
                              final bannerTitle = (col['bannerTitle'] ?? '').toString().trim();
                              final displayLabel = bannerTitle.isNotEmpty ? bannerTitle : name;
                              final id = (col['_id'] ?? col['id'] ?? name).toString();
                              if (name.isNotEmpty) {
                                items.add(DropdownMenuItem(value: 'col_$id', child: Text('Collection Banner: $displayLabel')));
                              }
                            }
                          }
                          return items;
                        }(),
                        onChanged: (val) {
                          if (val == null) return;
                          setState(() {
                            if (val == 'dealer_first_choice') {
                              _titleController.text = 'Dealer First Choice';
                              _redirectTargetController.text = 'dealer_first_choice';
                              _selectedRedirectType = 'none';
                            } else if (val == 'categories') {
                              _titleController.text = 'Categories Section';
                              _redirectTargetController.text = 'categories';
                              _selectedRedirectType = 'none';
                            } else if (val == 'featured') {
                              _titleController.text = 'Featured Products Section';
                              _redirectTargetController.text = 'featured';
                              _selectedRedirectType = 'none';
                            } else if (val == 'shop_by_crop') {
                              _titleController.text = 'Shop By Crop Section';
                              _redirectTargetController.text = 'shop_by_crop';
                              _selectedRedirectType = 'none';
                            } else if (val.startsWith('cat_')) {
                              final id = val.replaceFirst('cat_', '');
                              final cat = _backendCategories.firstWhere(
                                (c) => (c['_id'] ?? c['id']).toString() == id || c['name'] == id,
                                orElse: () => {},
                              );
                              final bannerTitle = (cat['bannerTitle'] ?? '').toString().trim();
                              final name = bannerTitle.isNotEmpty ? bannerTitle : (cat['name'] ?? cat['title'] ?? 'Category').toString();
                              _titleController.text = name;
                              _redirectTargetController.text = (cat['slug'] ?? (cat['name'] ?? '')).toString();
                              _selectedRedirectType = 'category';
                            } else if (val.startsWith('col_')) {
                              final id = val.replaceFirst('col_', '');
                              final col = _backendCollections.firstWhere(
                                (c) => (c['_id'] ?? c['id']).toString() == id || c['name'] == id,
                                orElse: () => {},
                              );
                              final bannerTitle = (col['bannerTitle'] ?? '').toString().trim();
                              final name = bannerTitle.isNotEmpty ? bannerTitle : (col['name'] ?? col['title'] ?? 'Collection').toString();
                              _titleController.text = name;
                              _redirectTargetController.text = (col['slug'] ?? (col['name'] ?? '')).toString();
                              _selectedRedirectType = 'collection';
                            } else if (val == 'best_offers_main') {
                              _titleController.text = 'Best Offers Showcase';
                              _redirectTargetController.text = 'best_offers';
                              _selectedRedirectType = 'none';
                            } else if (val == 'home_hero_main') {
                              _titleController.text = 'Home Hero Banner';
                              _redirectTargetController.text = '';
                              _selectedRedirectType = 'none';
                            }
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Banner Display Title', style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 13)),
                                const SizedBox(height: 4),
                                TextFormField(
                                  controller: _titleController,
                                  style: GoogleFonts.outfit(fontSize: 13),
                                  decoration: InputDecoration(
                                    hintText: 'Auto-filled from placement dropdown...',
                                    prefixIcon: const Icon(Icons.title_rounded, size: 18, color: AppTheme.primaryColor),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 1,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Priority Order', style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 13)),
                                const SizedBox(height: 4),
                                TextFormField(
                                  controller: _priorityController,
                                  style: GoogleFonts.outfit(fontSize: 13),
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    hintText: '0, 1, 2...',
                                    prefixIcon: const Icon(Icons.sort_rounded, size: 18, color: AppTheme.primaryColor),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                  validator: (val) {
                                    if (val == null || val.trim().isEmpty) return 'Required';
                                    if (int.tryParse(val.trim()) == null) return 'Number';
                                    return null;
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // 4. Redirect Action & Dynamic Backend Target Picker
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Redirect Action', style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 13)),
                                const SizedBox(height: 4),
                                DropdownButtonFormField<String>(
                                  isExpanded: true,
                                  initialValue: _selectedRedirectType,
                                  style: GoogleFonts.outfit(fontSize: 13, color: AppTheme.textPrimary),
                                  decoration: InputDecoration(
                                    prefixIcon: const Icon(Icons.touch_app_rounded, size: 18, color: AppTheme.primaryColor),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                  ),
                                  items: const [
                                    DropdownMenuItem(value: 'none', child: Text('None (Static display)')),
                                    DropdownMenuItem(value: 'category', child: Text('Category Page')),
                                    DropdownMenuItem(value: 'product', child: Text('Product Detail Page')),
                                    DropdownMenuItem(value: 'collection', child: Text('Collection Page')),
                                    DropdownMenuItem(value: 'external', child: Text('External Web Link')),
                                  ],
                                  onChanged: (val) {
                                    if (val != null) {
                                      setState(() {
                                        _selectedRedirectType = val;
                                        if (val == 'none') _redirectTargetController.clear();
                                      });
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),
                          if (_selectedRedirectType != 'none') ...[
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _selectedRedirectType == 'external' ? 'URL Target Link' : 'Target Slug or ID',
                                    style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 13),
                                  ),
                                  const SizedBox(height: 4),
                                  TextFormField(
                                    controller: _redirectTargetController,
                                    style: GoogleFonts.outfit(fontSize: 13),
                                    decoration: InputDecoration(
                                      hintText: _selectedRedirectType == 'external' ? 'https://example.com' : 'Target Slug or ID...',
                                      prefixIcon: const Icon(Icons.link_rounded, size: 18, color: AppTheme.primaryColor),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),

                      // DYNAMIC BACKEND TARGET PICKERS
                      if (_selectedRedirectType != 'none' && _selectedRedirectType != 'external') ...[
                        const SizedBox(height: 10),
                        if (_isLoadingTargets)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              children: [
                                SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
                                SizedBox(width: 8),
                                Text('Loading backend options...', style: TextStyle(fontSize: 12, color: Colors.grey)),
                              ],
                            ),
                          )
                        else if (_selectedRedirectType == 'category' && _backendCategories.isNotEmpty) ...[
                          Text('Select Backend Category:', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.primaryColor)),
                          const SizedBox(height: 6),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: _backendCategories.map((cat) {
                                final name = cat['name'] ?? cat['title'] ?? 'Category';
                                final slug = cat['slug'] ?? cat['_id'] ?? name;
                                final isSelected = _redirectTargetController.text == slug || _redirectTargetController.text == name;
                                return Padding(
                                  padding: const EdgeInsets.only(right: 6),
                                  child: FilterChip(
                                    label: Text(name, style: GoogleFonts.outfit(fontSize: 11)),
                                    selected: isSelected,
                                    onSelected: (_) {
                                      setState(() {
                                        _redirectTargetController.text = slug.toString();
                                      });
                                    },
                                    selectedColor: AppTheme.primaryColor.withValues(alpha: 0.2),
                                    backgroundColor: Colors.grey.shade100,
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ] else if (_selectedRedirectType == 'product' && _backendProducts.isNotEmpty) ...[
                          Text('Select Backend Product:', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.primaryColor)),
                          const SizedBox(height: 6),
                          DropdownButtonFormField<String>(
                            isExpanded: true,
                            style: GoogleFonts.outfit(fontSize: 13, color: AppTheme.textPrimary),
                            decoration: InputDecoration(
                              hintText: '-- Select Product from Backend --',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            ),
                            items: _backendProducts.map((prod) {
                              final name = prod['title'] ?? prod['name'] ?? 'Product';
                              final id = prod['_id'] ?? prod['id'] ?? '';
                              return DropdownMenuItem<String>(
                                value: id.toString(),
                                child: Text(
                                  '$name (ID: ${id.toString().substring(0, id.toString().length > 8 ? 8 : id.toString().length)})',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setState(() {
                                  _redirectTargetController.text = val;
                                });
                              }
                            },
                          ),
                        ] else if (_selectedRedirectType == 'collection' && _backendCollections.isNotEmpty) ...[
                          Text('Select Backend Collection:', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.primaryColor)),
                          const SizedBox(height: 6),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: _backendCollections.map((col) {
                                final name = col['title'] ?? col['name'] ?? 'Collection';
                                final slug = col['slug'] ?? col['_id'] ?? name;
                                final isSelected = _redirectTargetController.text == slug || _redirectTargetController.text == name;
                                return Padding(
                                  padding: const EdgeInsets.only(right: 6),
                                  child: FilterChip(
                                    label: Text(name, style: GoogleFonts.outfit(fontSize: 11)),
                                    selected: isSelected,
                                    onSelected: (_) {
                                      setState(() {
                                        _redirectTargetController.text = slug.toString();
                                      });
                                    },
                                    selectedColor: AppTheme.primaryColor.withValues(alpha: 0.2),
                                    backgroundColor: Colors.grey.shade100,
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ],
                      ],
                    ],
                  ),

                  const SizedBox(height: 16),

                  // 5. Active Status Switch Card (REPLACED SwitchListTile TO FIX FLUTTER ASSERTION ERROR)
                  InkWell(
                    onTap: () => setState(() => _isActive = !_isActive),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: _isActive
                            ? AppTheme.primaryColor.withValues(alpha: 0.05)
                            : const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _isActive
                              ? AppTheme.primaryColor.withValues(alpha: 0.3)
                              : AppTheme.borderColor,
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Publish & Activate Banner',
                                  style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textPrimary),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'When enabled, this banner immediately appears on mobile user apps',
                                  style: GoogleFonts.outfit(fontSize: 11, color: AppTheme.textSecondary),
                                ),
                              ],
                            ),
                          ),
                          Switch.adaptive(
                            value: _isActive,
                            activeThumbColor: AppTheme.primaryColor,
                            onChanged: (val) => setState(() => _isActive = val),
                          ),
                        ],
                      ),
                    ),
                  ),
                ] else ...[
                  // TAB 1: Live Mobile Device Mockup Preview
                  Center(
                    child: Container(
                      width: 290,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(32),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.25),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Phone Speaker & Notch Header
                            Container(
                              height: 24,
                              decoration: const BoxDecoration(
                                color: Colors.black,
                                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                              ),
                              child: Center(
                                child: Container(
                                  width: 60,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade800,
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                ),
                              ),
                            ),

                            // Mobile App Top Bar Mockup
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              color: AppTheme.primaryColor,
                              child: Row(
                                children: [
                                  const Icon(Icons.agriculture_rounded, color: Colors.white, size: 18),
                                  const SizedBox(width: 6),
                                  Text('Krishikranti', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                                  const Spacer(),
                                  const Icon(Icons.notifications_none_rounded, color: Colors.white, size: 16),
                                ],
                              ),
                            ),

                            // Live Banner Container Preview
                            Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Featured Preview',
                                        style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 12),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: AppTheme.primaryColor.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          _selectedType.toUpperCase(),
                                          style: GoogleFonts.outfit(fontSize: 9, fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),

                                  // Banner Image Mockup
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: AspectRatio(
                                      aspectRatio: _selectedType == 'strip'
                                          ? 6 / 1
                                          : _selectedType == 'category_card'
                                              ? 1.2 / 1
                                              : 2.2 / 1,
                                      child: _pickedImageFile != null
                                          ? Image.memory(_pickedImageFile!.bytes!, fit: BoxFit.cover)
                                          : (existingImageUrl != null && existingImageUrl.isNotEmpty)
                                              ? Image.network(existingImageUrl, fit: BoxFit.cover)
                                              : Container(
                                                  color: Colors.grey.shade300,
                                                  child: const Center(
                                                    child: Icon(Icons.image_outlined, color: Colors.grey, size: 32),
                                                  ),
                                                ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    _titleController.text.isNotEmpty ? _titleController.text : 'Your Banner Title',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 12),
                                  ),
                                  Text(
                                    _selectedRedirectType == 'none'
                                        ? 'Static banner (no redirect)'
                                        : 'Tap opens ${_selectedRedirectType.toUpperCase()} target',
                                    style: GoogleFonts.outfit(fontSize: 10, color: AppTheme.textSecondary),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 20),

                // Upload Progress State Indicator
                if (_isSaving) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(color: AppTheme.primaryColor, strokeWidth: 2),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _uploadStepText,
                              style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const LinearProgressIndicator(color: AppTheme.primaryColor, backgroundColor: Colors.white),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Action Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _isSaving ? null : () => Navigator.pop(context),
                      child: Text('Cancel', style: GoogleFonts.outfit(color: Colors.grey)),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: _isSaving ? null : _submitForm,
                      icon: _isSaving
                          ? const SizedBox.shrink()
                          : const Icon(Icons.cloud_upload_rounded, size: 18),
                      label: Text(
                        isEditing ? 'Save Changes' : 'Upload Banner Now',
                        style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
