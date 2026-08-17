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
      case 'home_trust':
        return const Color(0xFF059669);
      case 'category_trust':
        return const Color(0xFF0284C7);
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
      case 'home_trust':
        return 'Home Trust';
      case 'category_trust':
        return 'Category Trust';
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
                          const SizedBox(width: 6),
                          _buildFilterChip('home_trust', 'Home Trust'),
                          const SizedBox(width: 6),
                          _buildFilterChip('category_trust', 'Category Trust'),
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
  late SearchController _productSearchController;

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
    _productSearchController = SearchController();
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
          // Update product search controller text if editing and it's a product redirect
          if (widget.existingBanner != null && _selectedRedirectType == 'product') {
            final targetId = _redirectTargetController.text;
            final product = _backendProducts.firstWhere(
              (p) => (p['_id'] ?? p['id']).toString() == targetId,
              orElse: () => {},
            );
            if (product.isNotEmpty) {
              _productSearchController.text = (product['title'] ?? product['name'] ?? '').toString();
            }
          }
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
    _productSearchController.dispose();
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
      case 'home_trust':
        return {
          'ratio': '3.3 : 1',
          'resolution': '1200 × 360 px',
          'description': 'Home Screen Trust Badges Footer Banner',
        };
      case 'category_trust':
        return {
          'ratio': '5 : 1',
          'resolution': '1200 × 240 px',
          'description': 'Category Screen Trust Badges Footer Banner',
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

  InputDecoration _buildInputDecoration({
    required String hintText,
    required IconData prefixIcon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: GoogleFonts.outfit(fontSize: 13, color: const Color(0xFF94A3B8)),
      prefixIcon: Icon(prefixIcon, size: 18, color: AppTheme.primaryColor),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppTheme.primaryColor, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFEF4444)),
      ),
    );
  }

  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: AppTheme.primaryColor),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.outfit(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF0F172A),
                ),
              ),
              if (subtitle != null)
                Text(
                  subtitle,
                  style: GoogleFonts.outfit(
                    fontSize: 11.5,
                    color: const Color(0xFF64748B),
                  ),
                ),
            ],
          ),
        ),
        if (trailing != null) trailing,
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existingBanner != null;
    final String? existingImageUrl = widget.existingBanner?['imageUrl'];
    final specs = _getSectionSpecs(_selectedType);

    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      elevation: 12,
      child: Container(
        width: 720,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.90,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // TOP HEADER BAR (Crisp White with subtle divider)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFECFDF5),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFA7F3D0)),
                        ),
                        child: const Icon(
                          Icons.photo_library_outlined,
                          color: Color(0xFF059669),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                isEditing ? 'Edit Banner Studio' : 'Upload Banner Studio',
                                style: GoogleFonts.outfit(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isEditing
                                      ? const Color(0xFFEFF6FF)
                                      : const Color(0xFFECFDF5),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: isEditing
                                        ? const Color(0xFFBFDBFE)
                                        : const Color(0xFFA7F3D0),
                                  ),
                                ),
                                child: Text(
                                  isEditing ? 'EDITING' : 'NEW BANNER',
                                  style: GoogleFonts.outfit(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: isEditing
                                        ? const Color(0xFF2563EB)
                                        : const Color(0xFF059669),
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Configure banner placement, specs & mobile preview',
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  InkWell(
                    onTap: () => Navigator.pop(context),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: const Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // SEGMENTED TAB SWITCHER
            Container(
              padding: const EdgeInsets.fromLTRB(24, 14, 24, 6),
              color: Colors.white,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => setState(() => _selectedTab = 0),
                        borderRadius: BorderRadius.circular(8),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(vertical: 9),
                          decoration: BoxDecoration(
                            color: _selectedTab == 0 ? Colors.white : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: _selectedTab == 0
                                ? [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.05),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.tune_rounded,
                                size: 16,
                                color: _selectedTab == 0
                                    ? AppTheme.primaryColor
                                    : const Color(0xFF64748B),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Banner Configuration',
                                style: GoogleFonts.outfit(
                                  fontSize: 13,
                                  fontWeight: _selectedTab == 0
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: _selectedTab == 0
                                      ? AppTheme.primaryColor
                                      : const Color(0xFF64748B),
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
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(vertical: 9),
                          decoration: BoxDecoration(
                            color: _selectedTab == 1 ? Colors.white : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: _selectedTab == 1
                                ? [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.05),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.phone_iphone_rounded,
                                size: 16,
                                color: _selectedTab == 1
                                    ? AppTheme.primaryColor
                                    : const Color(0xFF64748B),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Live Mobile App Preview',
                                style: GoogleFonts.outfit(
                                  fontSize: 13,
                                  fontWeight: _selectedTab == 1
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: _selectedTab == 1
                                      ? AppTheme.primaryColor
                                      : const Color(0xFF64748B),
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
            ),

            // SCROLLABLE FORM BODY
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_errorMsg != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF2F2),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFFECACA)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626), size: 18),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _errorMsg!,
                                  style: GoogleFonts.outfit(
                                    color: const Color(0xFF991B1B),
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],

                      // TAB 0: Configuration Form
                      if (_selectedTab == 0) ...[
                        // 1. SECTION CARD: ARTWORK DROPZONE
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildSectionHeader(
                                icon: Icons.image_outlined,
                                title: 'Banner Artwork *',
                                subtitle: 'Supports PNG, JPG, WebP',
                                trailing: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'Ratio: ${specs['ratio']}  •  ${specs['resolution']}',
                                    style: GoogleFonts.outfit(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF475569),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),

                              GestureDetector(
                                onTap: _pickImage,
                                child: Container(
                                  height: 160,
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: _pickedImageFile != null
                                          ? AppTheme.primaryColor
                                          : const Color(0xFFCBD5E1),
                                      width: _pickedImageFile != null ? 2 : 1,
                                    ),
                                  ),
                                  child: _pickedImageFile != null
                                      ? ClipRRect(
                                          borderRadius: BorderRadius.circular(11),
                                          child: Stack(
                                            children: [
                                              Positioned.fill(
                                                child: Image.memory(
                                                  _pickedImageFile!.bytes!,
                                                  fit: BoxFit.cover,
                                                ),
                                              ),
                                              Positioned(
                                                bottom: 0,
                                                left: 0,
                                                right: 0,
                                                child: Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                                  decoration: BoxDecoration(
                                                    gradient: LinearGradient(
                                                      begin: Alignment.bottomCenter,
                                                      end: Alignment.topCenter,
                                                      colors: [
                                                        Colors.black.withValues(alpha: 0.85),
                                                        Colors.black.withValues(alpha: 0.0),
                                                      ],
                                                    ),
                                                  ),
                                                  child: Row(
                                                    children: [
                                                      const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 16),
                                                      const SizedBox(width: 8),
                                                      Expanded(
                                                        child: Column(
                                                          crossAxisAlignment: CrossAxisAlignment.start,
                                                          mainAxisSize: MainAxisSize.min,
                                                          children: [
                                                            Text(
                                                              _pickedImageFile!.name,
                                                              maxLines: 1,
                                                              overflow: TextOverflow.ellipsis,
                                                              style: GoogleFonts.outfit(
                                                                color: Colors.white,
                                                                fontSize: 12,
                                                                fontWeight: FontWeight.w700,
                                                              ),
                                                            ),
                                                            Text(
                                                              _formatFileSize(_pickedImageFile!.size),
                                                              style: GoogleFonts.outfit(
                                                                color: const Color(0xFFE2E8F0),
                                                                fontSize: 11,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                      TextButton.icon(
                                                        onPressed: _pickImage,
                                                        icon: const Icon(Icons.swap_horiz_rounded, color: Colors.white, size: 15),
                                                        label: Text(
                                                          'Change',
                                                          style: GoogleFonts.outfit(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                                                        ),
                                                        style: TextButton.styleFrom(
                                                          backgroundColor: Colors.white.withValues(alpha: 0.2),
                                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                          minimumSize: Size.zero,
                                                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                        ),
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
                                              borderRadius: BorderRadius.circular(11),
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
                                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                                      decoration: BoxDecoration(
                                                        gradient: LinearGradient(
                                                          begin: Alignment.bottomCenter,
                                                          end: Alignment.topCenter,
                                                          colors: [
                                                            Colors.black.withValues(alpha: 0.85),
                                                            Colors.black.withValues(alpha: 0.0),
                                                          ],
                                                        ),
                                                      ),
                                                      child: Row(
                                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                        children: [
                                                          Row(
                                                            children: [
                                                              const Icon(Icons.cloud_done_rounded, color: Color(0xFF38BDF8), size: 16),
                                                              const SizedBox(width: 8),
                                                              Text(
                                                                'Active Cloud Artwork',
                                                                style: GoogleFonts.outfit(
                                                                  color: Colors.white,
                                                                  fontSize: 12,
                                                                  fontWeight: FontWeight.w600,
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                          TextButton.icon(
                                                            onPressed: _pickImage,
                                                            icon: const Icon(Icons.cloud_upload_outlined, color: Colors.white, size: 15),
                                                            label: Text(
                                                              'Replace Image',
                                                              style: GoogleFonts.outfit(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                                                            ),
                                                            style: TextButton.styleFrom(
                                                              backgroundColor: Colors.white.withValues(alpha: 0.2),
                                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                              minimumSize: Size.zero,
                                                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            )
                                          : Center(
                                              child: Column(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  Container(
                                                    padding: const EdgeInsets.all(12),
                                                    decoration: BoxDecoration(
                                                      color: AppTheme.primaryColor.withValues(alpha: 0.08),
                                                      shape: BoxShape.circle,
                                                    ),
                                                    child: const Icon(
                                                      Icons.cloud_upload_outlined,
                                                      size: 28,
                                                      color: AppTheme.primaryColor,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 8),
                                                  Text(
                                                    'Click to browse or drop banner artwork',
                                                    style: GoogleFonts.outfit(
                                                      fontWeight: FontWeight.w700,
                                                      fontSize: 13.5,
                                                      color: const Color(0xFF1E293B),
                                                    ),
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    'Optimal resolution for this section: ${specs['resolution']}',
                                                    style: GoogleFonts.outfit(
                                                      fontSize: 11.5,
                                                      color: const Color(0xFF64748B),
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

                        const SizedBox(height: 14),

                        // 2. SECTION CARD: PLACEMENT & TITLE
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildSectionHeader(
                                icon: Icons.space_dashboard_outlined,
                                title: 'Placement & Display Settings',
                                subtitle: 'Select where this banner appears in the mobile app',
                              ),
                              const SizedBox(height: 14),

                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    flex: 3,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Section Placement *', style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 12.5, color: const Color(0xFF334155))),
                                        const SizedBox(height: 5),
                                        DropdownButtonFormField<String>(
                                          isExpanded: true,
                                          initialValue: _selectedType,
                                          style: GoogleFonts.outfit(fontSize: 13, color: const Color(0xFF0F172A)),
                                          decoration: _buildInputDecoration(
                                            hintText: 'Select placement',
                                            prefixIcon: Icons.view_carousel_outlined,
                                          ),
                                          items: const [
                                            DropdownMenuItem(value: 'home', child: Text('Home Carousel (Hero Main)')),
                                            DropdownMenuItem(value: 'strip', child: Text('Header Strip Banner')),
                                            DropdownMenuItem(value: 'category', child: Text('Category Top Banner')),
                                            DropdownMenuItem(value: 'category_card', child: Text('Category Card Banner')),
                                            DropdownMenuItem(value: 'best_offers', child: Text('Best Offers Showcase')),
                                            DropdownMenuItem(value: 'home_trust', child: Text('Home Trust Badges Banner')),
                                            DropdownMenuItem(value: 'category_trust', child: Text('Category Trust Badges Banner')),
                                          ],
                                          onChanged: (val) {
                                            if (val != null) setState(() => _selectedType = val);
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    flex: 2,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Priority Order *', style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 12.5, color: const Color(0xFF334155))),
                                        const SizedBox(height: 5),
                                        TextFormField(
                                          controller: _priorityController,
                                          style: GoogleFonts.outfit(fontSize: 13, color: const Color(0xFF0F172A)),
                                          keyboardType: TextInputType.number,
                                          decoration: _buildInputDecoration(
                                            hintText: '0, 1, 2...',
                                            prefixIcon: Icons.sort_rounded,
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

                              const SizedBox(height: 12),

                              // Placement Preset Target
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Placement Preset / Scope', style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 12.5, color: const Color(0xFF334155))),
                                  const SizedBox(height: 5),
                                  DropdownButtonFormField<String>(
                                    isExpanded: true,
                                    decoration: _buildInputDecoration(
                                      hintText: '-- Select Target Placement Scope --',
                                      prefixIcon: Icons.category_outlined,
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
                                ],
                              ),

                              const SizedBox(height: 12),

                              // Banner Display Title
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Banner Display Title', style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 12.5, color: const Color(0xFF334155))),
                                  const SizedBox(height: 5),
                                  TextFormField(
                                    controller: _titleController,
                                    style: GoogleFonts.outfit(fontSize: 13, color: const Color(0xFF0F172A)),
                                    decoration: _buildInputDecoration(
                                      hintText: 'Enter descriptive title or pick from placement above...',
                                      prefixIcon: Icons.title_rounded,
                                    ),
                                    validator: (val) {
                                      if (val == null || val.trim().isEmpty) {
                                        return 'Banner title is required';
                                      }
                                      return null;
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 14),

                        // 3. SECTION CARD: REDIRECTION & ACTION
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildSectionHeader(
                                icon: Icons.touch_app_outlined,
                                title: 'Tap & Navigation Trigger',
                                subtitle: 'What occurs when the customer taps this banner',
                              ),
                              const SizedBox(height: 14),

                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Redirect Action', style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 12.5, color: const Color(0xFF334155))),
                                        const SizedBox(height: 5),
                                        DropdownButtonFormField<String>(
                                          isExpanded: true,
                                          initialValue: _selectedRedirectType,
                                          style: GoogleFonts.outfit(fontSize: 13, color: const Color(0xFF0F172A)),
                                          decoration: _buildInputDecoration(
                                            hintText: 'Select action',
                                            prefixIcon: Icons.navigation_outlined,
                                          ),
                                          items: const [
                                            DropdownMenuItem(value: 'none', child: Text('None (Static display only)')),
                                            DropdownMenuItem(value: 'category', child: Text('Category Page')),
                                            DropdownMenuItem(value: 'product', child: Text('Product Detail Page')),
                                            DropdownMenuItem(value: 'collection', child: Text('Collection Page')),
                                            DropdownMenuItem(value: 'external', child: Text('External Web Link (URL)')),
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
                                            _selectedRedirectType == 'external' ? 'URL Target Link *' : 'Target Slug / ID *',
                                            style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 12.5, color: const Color(0xFF334155)),
                                          ),
                                          const SizedBox(height: 5),
                                          TextFormField(
                                            controller: _redirectTargetController,
                                            style: GoogleFonts.outfit(fontSize: 13, color: const Color(0xFF0F172A)),
                                            decoration: _buildInputDecoration(
                                              hintText: _selectedRedirectType == 'external' ? 'https://example.com' : 'Enter target slug/ID...',
                                              prefixIcon: _selectedRedirectType == 'external' ? Icons.link_rounded : Icons.tag_rounded,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),

                              if (_isLoadingTargets) ...[
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    const SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryColor),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Loading backend options...',
                                      style: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF64748B)),
                                    ),
                                  ],
                                ),
                              ],

                              // Dynamic Category Chips Picker
                              if (_selectedRedirectType == 'category' && _backendCategories.isNotEmpty) ...[
                                const SizedBox(height: 12),
                                Text(
                                  'Quick Pick Category:',
                                  style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.primaryColor),
                                ),
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
                                          label: Text(name.toString(), style: GoogleFonts.outfit(fontSize: 11.5)),
                                          selected: isSelected,
                                          onSelected: (_) {
                                            setState(() {
                                              _redirectTargetController.text = slug.toString();
                                            });
                                          },
                                          selectedColor: AppTheme.primaryColor.withValues(alpha: 0.15),
                                          backgroundColor: const Color(0xFFF8FAFC),
                                          side: BorderSide(
                                            color: isSelected ? AppTheme.primaryColor : const Color(0xFFE2E8F0),
                                          ),
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ),
                              ],

                              // Dynamic Collection Chips Picker
                              if (_selectedRedirectType == 'collection' && _backendCollections.isNotEmpty) ...[
                                const SizedBox(height: 12),
                                Text(
                                  'Quick Pick Collection:',
                                  style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.primaryColor),
                                ),
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
                                          label: Text(name.toString(), style: GoogleFonts.outfit(fontSize: 11.5)),
                                          selected: isSelected,
                                          onSelected: (_) {
                                            setState(() {
                                              _redirectTargetController.text = slug.toString();
                                            });
                                          },
                                          selectedColor: AppTheme.primaryColor.withValues(alpha: 0.15),
                                          backgroundColor: const Color(0xFFF8FAFC),
                                          side: BorderSide(
                                            color: isSelected ? AppTheme.primaryColor : const Color(0xFFE2E8F0),
                                          ),
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ),
                              ],

                              // Dynamic Product Search Anchor Picker
                              if (_selectedRedirectType == 'product' && _backendProducts.isNotEmpty) ...[
                                const SizedBox(height: 12),
                                Text(
                                  'Search & Select Product:',
                                  style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.primaryColor),
                                ),
                                const SizedBox(height: 6),
                                SearchAnchor(
                                  searchController: _productSearchController,
                                  builder: (context, controller) {
                                    return TextFormField(
                                      controller: controller,
                                      readOnly: true,
                                      style: GoogleFonts.outfit(fontSize: 13, color: const Color(0xFF0F172A)),
                                      decoration: _buildInputDecoration(
                                        hintText: '-- Click to Search Product --',
                                        prefixIcon: Icons.inventory_2_outlined,
                                        suffixIcon: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            if (controller.text.isNotEmpty)
                                              IconButton(
                                                icon: const Icon(Icons.clear_rounded, size: 18),
                                                onPressed: () {
                                                  setState(() {
                                                    controller.clear();
                                                    _redirectTargetController.clear();
                                                  });
                                                },
                                              ),
                                            const Icon(Icons.arrow_drop_down_rounded, color: Color(0xFF64748B)),
                                            const SizedBox(width: 8),
                                          ],
                                        ),
                                      ),
                                      onTap: () => controller.openView(),
                                    );
                                  },
                                  suggestionsBuilder: (context, controller) {
                                    final query = controller.text.toLowerCase();
                                    final filtered = _backendProducts.where((p) {
                                      final name = (p['title'] ?? p['name'] ?? '').toString().toLowerCase();
                                      return name.contains(query);
                                    }).toList();

                                    if (filtered.isEmpty) {
                                      return [
                                        Padding(
                                          padding: const EdgeInsets.all(16.0),
                                          child: Center(
                                            child: Column(
                                              children: [
                                                const Icon(Icons.search_off_rounded, size: 36, color: Color(0xFF94A3B8)),
                                                const SizedBox(height: 6),
                                                Text('No products match "$query"', style: GoogleFonts.outfit(color: const Color(0xFF64748B), fontSize: 13)),
                                              ],
                                            ),
                                          ),
                                        )
                                      ];
                                    }

                                    return filtered.map((p) {
                                      final name = (p['title'] ?? p['name'] ?? '').toString();
                                      final id = (p['_id'] ?? p['id']).toString();
                                      final images = p['images'] as List?;
                                      final imageUrl = (images != null && images.isNotEmpty) ? images.first.toString() : null;

                                      return ListTile(
                                        leading: Container(
                                          width: 38,
                                          height: 38,
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF1F5F9),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: imageUrl != null
                                              ? ClipRRect(
                                                  borderRadius: BorderRadius.circular(6),
                                                  child: Image.network(
                                                    imageUrl,
                                                    fit: BoxFit.cover,
                                                    errorBuilder: (_, __, ___) => const Icon(Icons.image_not_supported_outlined, size: 18, color: Color(0xFF94A3B8)),
                                                  ),
                                                )
                                              : const Icon(Icons.inventory_2_outlined, size: 18, color: Color(0xFF94A3B8)),
                                        ),
                                        title: Text(name, style: GoogleFonts.outfit(fontSize: 13.5, fontWeight: FontWeight.w600)),
                                        subtitle: Text('ID: ${id.substring(0, id.length > 8 ? 8 : id.length)}...', style: GoogleFonts.outfit(fontSize: 11, color: const Color(0xFF94A3B8))),
                                        onTap: () {
                                          setState(() {
                                            _redirectTargetController.text = id;
                                            controller.closeView(name);
                                          });
                                        },
                                      );
                                    });
                                  },
                                ),
                              ],
                            ],
                          ),
                        ),

                        const SizedBox(height: 14),

                        // 4. SECTION CARD: ACTIVE STATUS
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: _isActive
                                      ? const Color(0xFFECFDF5)
                                      : const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  _isActive ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                                  size: 18,
                                  color: _isActive ? const Color(0xFF059669) : const Color(0xFF64748B),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Publish & Activate Banner',
                                      style: GoogleFonts.outfit(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13,
                                        color: const Color(0xFF0F172A),
                                      ),
                                    ),
                                    Text(
                                      'When enabled, this banner immediately appears on mobile user apps',
                                      style: GoogleFonts.outfit(fontSize: 11.5, color: const Color(0xFF64748B)),
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
                      ] else ...[
                        // TAB 1: Live Mobile Device Mockup Preview
                        Center(
                          child: Container(
                            width: 320,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F172A),
                              borderRadius: BorderRadius.circular(36),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.18),
                                  blurRadius: 24,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(26),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Top Notch & Status Bar Mockup
                                  Container(
                                    height: 28,
                                    padding: const EdgeInsets.symmetric(horizontal: 16),
                                    color: const Color(0xFF0F172A),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text('9:41', style: GoogleFonts.outfit(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                                        Container(
                                          width: 60,
                                          height: 8,
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF334155),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                        ),
                                        Row(
                                          children: const [
                                            Icon(Icons.signal_cellular_alt_rounded, color: Colors.white, size: 12),
                                            SizedBox(width: 4),
                                            Icon(Icons.wifi_rounded, color: Colors.white, size: 12),
                                            SizedBox(width: 4),
                                            Icon(Icons.battery_full_rounded, color: Colors.white, size: 12),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Mobile App Header Mockup
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                    color: AppTheme.primaryColor,
                                    child: Row(
                                      children: [
                                        const Icon(Icons.agriculture_rounded, color: Colors.white, size: 20),
                                        const SizedBox(width: 8),
                                        Text('Krishi Kranti', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13.5)),
                                        const Spacer(),
                                        const Icon(Icons.notifications_none_rounded, color: Colors.white, size: 18),
                                      ],
                                    ),
                                  ),

                                  // Live Banner Showcase
                                  Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              'Live Section Preview',
                                              style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 12, color: const Color(0xFF1E293B)),
                                            ),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: AppTheme.primaryColor.withValues(alpha: 0.12),
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                _selectedType.toUpperCase(),
                                                style: GoogleFonts.outfit(fontSize: 9, fontWeight: FontWeight.w700, color: AppTheme.primaryColor),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),

                                        // Realistic Banner Image Mockup
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(10),
                                          child: AspectRatio(
                                            aspectRatio: _selectedType == 'strip'
                                                ? 6 / 1
                                                : _selectedType == 'category_card'
                                                    ? 1.2 / 1
                                                    : _selectedType == 'home_trust'
                                                        ? 3.3 / 1
                                                        : _selectedType == 'category_trust'
                                                            ? 5 / 1
                                                            : 2.2 / 1,
                                            child: _pickedImageFile != null
                                                ? Image.memory(_pickedImageFile!.bytes!, fit: BoxFit.cover)
                                                : (existingImageUrl != null && existingImageUrl.isNotEmpty)
                                                    ? Image.network(existingImageUrl, fit: BoxFit.cover)
                                                    : Container(
                                                        color: const Color(0xFFE2E8F0),
                                                        child: const Center(
                                                          child: Icon(Icons.image_outlined, color: Color(0xFF94A3B8), size: 32),
                                                        ),
                                                      ),
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          _titleController.text.isNotEmpty ? _titleController.text : 'Banner Title Goes Here',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 12, color: const Color(0xFF0F172A)),
                                        ),
                                        Text(
                                          _selectedRedirectType == 'none'
                                              ? 'Static promotional banner'
                                              : 'Tapping redirects to ${_selectedRedirectType.toUpperCase()}',
                                          style: GoogleFonts.outfit(fontSize: 10.5, color: const Color(0xFF64748B)),
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
                    ],
                  ),
                ),
              ),
            ),

            // UPLOAD PROGRESS INDICATOR (if saving)
            if (_isSaving)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFA7F3D0)),
                ),
                child: Row(
                  children: [
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(color: Color(0xFF059669), strokeWidth: 2),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _uploadStepText,
                        style: GoogleFonts.outfit(fontSize: 12.5, fontWeight: FontWeight.w600, color: const Color(0xFF065F46)),
                      ),
                    ),
                  ],
                ),
              ),

            // DIALOG FOOTER BAR
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
                border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Changes publish instantly to live apps',
                    style: GoogleFonts.outfit(
                      fontSize: 11.5,
                      color: const Color(0xFF94A3B8),
                    ),
                  ),
                  Row(
                    children: [
                      OutlinedButton(
                        onPressed: _isSaving ? null : () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF64748B),
                          side: const BorderSide(color: Color(0xFFE2E8F0)),
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: Text('Cancel', style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w600)),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton.icon(
                        onPressed: _isSaving ? null : _submitForm,
                        icon: _isSaving
                            ? const SizedBox.shrink()
                            : const Icon(Icons.cloud_upload_outlined, size: 16),
                        label: Text(
                          isEditing ? 'Save Changes' : 'Upload Banner Now',
                          style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 13),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ],
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
