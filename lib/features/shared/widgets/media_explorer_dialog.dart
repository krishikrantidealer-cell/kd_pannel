import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:kd_pannel/app_theme.dart';
import 'package:kd_pannel/core/network/api_client.dart';

class MediaExplorerDialog extends StatefulWidget {
  final String conversationId;
  final String? initialMediaType; // 'Image', 'Document', 'Catalog', or null
  final VoidCallback? onMediaSent;

  const MediaExplorerDialog({
    super.key,
    required this.conversationId,
    this.initialMediaType,
    this.onMediaSent,
  });

  static Future<void> show(
    BuildContext context, {
    required String conversationId,
    String? initialMediaType,
    VoidCallback? onMediaSent,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => MediaExplorerDialog(
        conversationId: conversationId,
        initialMediaType: initialMediaType,
        onMediaSent: onMediaSent,
      ),
    );
  }

  @override
  State<MediaExplorerDialog> createState() => _MediaExplorerDialogState();
}

class _MediaExplorerDialogState extends State<MediaExplorerDialog> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _captionController = TextEditingController();
  final TextEditingController _urlController = TextEditingController();

  // Products Catalog State
  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _filteredProducts = [];
  bool _isLoadingProducts = true;

  // File Upload State
  PlatformFile? _selectedFile;
  bool _isImageUpload = true;
  bool _isUploadingAndSending = false;

  // Company Collateral Library Assets
  final List<Map<String, String>> _companyCollaterals = [
    {
      'title': '🌾 Krishi Kranti Product Catalogue 2026',
      'category': 'Catalogue',
      'type': 'Document',
      'icon': 'pdf',
      'url': 'https://storage.googleapis.com/krishi-assets/catalogs/krishi_product_catalog_2026.pdf',
      'description': 'Complete product brochure with NPK formulations, bio-fertilizers & seeds.',
    },
    {
      'title': '💳 Official UPI Payment QR Code',
      'category': 'Payment',
      'type': 'Image',
      'icon': 'qr',
      'url': 'https://storage.googleapis.com/krishi-assets/payments/krishi_upi_qr.png',
      'description': 'Direct bank payment QR for dealer & retail invoice clearance.',
    },
    {
      'title': '🧪 Organic Bio-Fertilizer Lab Analysis & NPK Cert',
      'category': 'Quality',
      'type': 'Document',
      'icon': 'pdf',
      'url': 'https://storage.googleapis.com/krishi-assets/certs/organic_lab_test_report.pdf',
      'description': 'Certified government lab test report for organic nitrogen & phosphorus.',
    },
    {
      'title': '🚚 Logistics & Bulk Freight Rate Card',
      'category': 'Logistics',
      'type': 'Document',
      'icon': 'pdf',
      'url': 'https://storage.googleapis.com/krishi-assets/docs/freight_rate_chart.pdf',
      'description': 'Doorstep transport and dispatch tariff across all districts.',
    },
    {
      'title': '🤝 Authorized Krishi Dealer Certificate Template',
      'category': 'Partnership',
      'type': 'Image',
      'icon': 'image',
      'url': 'https://storage.googleapis.com/krishi-assets/docs/dealer_auth_badge.png',
      'description': 'Official Krishi Kranti certified retailer badge and partner welcome note.',
    },
  ];

  @override
  void initState() {
    super.initState();
    int initialIndex = 0;
    if (widget.initialMediaType == 'Document') {
      initialIndex = 1;
      _isImageUpload = false;
    } else if (widget.initialMediaType == 'Image') {
      initialIndex = 1;
      _isImageUpload = true;
    } else if (widget.initialMediaType == 'Collateral') {
      initialIndex = 2;
    }

    _tabController = TabController(length: 4, vsync: this, initialIndex: initialIndex);
    _fetchProducts();

    _searchController.addListener(_filterProducts);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _captionController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _fetchProducts() async {
    setState(() => _isLoadingProducts = true);
    try {
      final res = await ApiClient().get('/products?limit=200');
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final List list = data is List
            ? data
            : (data['products'] ?? data['data'] ?? []);
        final parsed = list.map((p) => Map<String, dynamic>.from(p as Map)).toList();
        if (mounted) {
          setState(() {
            _products = parsed;
            _filteredProducts = parsed;
            _isLoadingProducts = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoadingProducts = false);
      }
    } catch (e) {
      debugPrint('[Media Explorer] Error fetching products: $e');
      if (mounted) setState(() => _isLoadingProducts = false);
    }
  }

  void _filterProducts() {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) {
      setState(() => _filteredProducts = _products);
    } else {
      setState(() {
        _filteredProducts = _products.where((p) {
          final name = (p['name'] ?? p['title'] ?? '').toString().toLowerCase();
          final brand = (p['brand'] ?? '').toString().toLowerCase();
          final category = (p['category'] ?? p['categoryName'] ?? '').toString().toLowerCase();
          return name.contains(query) || brand.contains(query) || category.contains(query);
        }).toList();
      });
    }
  }

  Future<void> _pickFile(bool isImage) async {
    setState(() {
      _isImageUpload = isImage;
    });

    final allowedExts = isImage
        ? ['jpg', 'jpeg', 'png', 'webp']
        : ['pdf', 'doc', 'docx', 'xls', 'xlsx', 'csv', 'png', 'jpg', 'jpeg'];

    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: allowedExts,
      withData: true,
    );

    if (result != null && result.files.isNotEmpty) {
      setState(() {
        _selectedFile = result.files.first;
      });
    }
  }

  Future<void> _uploadAndSendMedia({
    required String type,
    String? directUrl,
    String? customCaption,
  }) async {
    if (_isUploadingAndSending) return;
    setState(() => _isUploadingAndSending = true);

    try {
      String finalMediaUrl = '';

      if (directUrl != null && directUrl.isNotEmpty) {
        finalMediaUrl = directUrl;
      } else if (_selectedFile != null) {
        final bytes = _selectedFile!.bytes;
        if (bytes == null) throw Exception('Unable to read file bytes');

        final request = http.MultipartRequest(
          'POST',
          Uri.parse('${ApiClient().baseUrl}/conversations/media/upload'),
        );
        if (ApiClient().accessToken != null) {
          request.headers['Authorization'] = 'Bearer ${ApiClient().accessToken}';
        }
        request.files.add(
          http.MultipartFile.fromBytes(
            'file',
            bytes,
            filename: _selectedFile!.name,
          ),
        );

        final streamedRes = await request.send();
        final resBody = await streamedRes.stream.bytesToString();
        final decoded = jsonDecode(resBody);

        if (streamedRes.statusCode == 200 && decoded['success'] == true) {
          finalMediaUrl = decoded['data']?['mediaUrl'] ?? decoded['mediaUrl'] ?? '';
        } else {
          throw Exception(decoded['message'] ?? 'Failed to upload media');
        }
      }

      if (finalMediaUrl.isEmpty) {
        throw Exception('Please select a valid media file or enter a URL');
      }

      final captionText = customCaption ?? _captionController.text.trim();

      final res = await ApiClient().post('/messages/send', {
        'conversationId': widget.conversationId,
        'type': type,
        'content': captionText,
        'mediaUrl': finalMediaUrl,
      });

      if (res.statusCode == 200) {
        widget.onMediaSent?.call();
        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  Text('Media sent to WhatsApp successfully!', style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
                ],
              ),
              backgroundColor: const Color(0xFF008069),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
      } else {
        final body = jsonDecode(res.body);
        throw Exception(body['message'] ?? 'Failed to send WhatsApp media message');
      }
    } catch (e) {
      setState(() => _isUploadingAndSending = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString().replaceAll("Exception: ", "")}'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  void _sendProductCard(Map<String, dynamic> product) {
    final name = (product['name'] ?? product['title'] ?? 'Product').toString();
    final price = product['sellingPrice'] ?? product['price'] ?? product['mrp'] ?? '0';
    final mrp = product['mrp'] ?? product['price'];
    final description = (product['description'] ?? product['shortDescription'] ?? '').toString();
    
    // Extract main image
    String imageUrl = '';
    if (product['images'] is List && (product['images'] as List).isNotEmpty) {
      final img = (product['images'] as List).first;
      imageUrl = img is Map ? (img['url'] ?? img['imageUrl'] ?? '') : img.toString();
    } else if (product['imageUrl'] != null) {
      imageUrl = product['imageUrl'].toString();
    }

    // Compose a rich WhatsApp product caption
    final buffer = StringBuffer();
    buffer.writeln('🌱 *$name*');
    buffer.writeln('💰 *Special Price:* ₹$price ${mrp != null && mrp != price ? "(MRP: ~₹$mrp~)" : ""}');
    if (description.isNotEmpty) {
      final cleanDesc = description.replaceAll(RegExp(r'<[^>]*>'), '').trim();
      if (cleanDesc.length > 120) {
        buffer.writeln('📝 ${cleanDesc.substring(0, 120)}...');
      } else {
        buffer.writeln('📝 $cleanDesc');
      }
    }
    buffer.writeln('\n📦 *Krishi Kranti Quality Guaranteed*');
    buffer.writeln('Reply directly to place an order or book quantity!');

    if (imageUrl.isNotEmpty) {
      _uploadAndSendMedia(
        type: 'Image',
        directUrl: imageUrl,
        customCaption: buffer.toString(),
      );
    } else {
      // Send as text product card if no image
      ApiClient().post('/messages/send', {
        'conversationId': widget.conversationId,
        'type': 'Text',
        'content': buffer.toString(),
      }).then((res) {
        if (res.statusCode == 200) {
          widget.onMediaSent?.call();
          if (mounted) {
            Navigator.of(context).pop();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Product details shared successfully!'), backgroundColor: Color(0xFF008069)),
            );
          }
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        width: 720,
        height: 650,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            // Top Bar: Interakt / WhatsApp Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              color: const Color(0xFF008069),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.folder_shared_rounded, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Media & Product Explorer',
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'Select products, files, or company assets to attach to WhatsApp',
                          style: GoogleFonts.outfit(
                            fontSize: 11.5,
                            color: Colors.white.withValues(alpha: 0.85),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
                    style: IconButton.styleFrom(backgroundColor: Colors.white12),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Tab Bar Navigation
            Container(
              color: const Color(0xFFF0F2F5),
              child: TabBar(
                controller: _tabController,
                indicatorColor: const Color(0xFF008069),
                indicatorWeight: 3,
                labelColor: const Color(0xFF008069),
                unselectedLabelColor: const Color(0xFF64748B),
                labelStyle: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13),
                unselectedLabelStyle: GoogleFonts.outfit(fontWeight: FontWeight.w500, fontSize: 13),
                tabs: const [
                  Tab(icon: Icon(Icons.storefront_rounded, size: 18), text: 'Products Catalog'),
                  Tab(icon: Icon(Icons.upload_file_rounded, size: 18), text: 'Upload Device File'),
                  Tab(icon: Icon(Icons.collections_bookmark_rounded, size: 18), text: 'Company Collateral'),
                  Tab(icon: Icon(Icons.link_rounded, size: 18), text: 'Public Link / URL'),
                ],
              ),
            ),

            // Tab Views Content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Tab 1: Product Catalog Explorer (Interakt Style)
                  _buildProductCatalogTab(),

                  // Tab 2: Native Device File Upload & WhatsApp Preview
                  _buildFileUploadTab(),

                  // Tab 3: Pre-saved Company Collateral Library
                  _buildCompanyCollateralTab(),

                  // Tab 4: Direct Public URL Link
                  _buildDirectUrlTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductCatalogTab() {
    return Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _searchController,
            style: GoogleFonts.outfit(fontSize: 13.5),
            decoration: InputDecoration(
              hintText: 'Search products by title, category, or brand...',
              hintStyle: GoogleFonts.outfit(fontSize: 13, color: Colors.grey[500]),
              prefixIcon: const Icon(Icons.search_rounded, size: 20, color: Color(0xFF008069)),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () => _searchController.clear(),
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
            ),
          ),
        ),

        // Product Cards Grid
        Expanded(
          child: _isLoadingProducts
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF008069)))
              : _filteredProducts.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.inventory_2_outlined, size: 48, color: Colors.grey[400]),
                          const SizedBox(height: 12),
                          Text(
                            'No products found matching your search',
                            style: GoogleFonts.outfit(fontSize: 14, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 2.8,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                      ),
                      itemCount: _filteredProducts.length,
                      itemBuilder: (context, index) {
                        final product = _filteredProducts[index];
                        final name = (product['name'] ?? product['title'] ?? 'Product').toString();
                        final price = product['sellingPrice'] ?? product['price'] ?? product['mrp'] ?? '0';
                        final category = (product['category'] ?? product['categoryName'] ?? 'Agri').toString();

                        String imageUrl = '';
                        if (product['images'] is List && (product['images'] as List).isNotEmpty) {
                          final img = (product['images'] as List).first;
                          imageUrl = img is Map ? (img['url'] ?? img['imageUrl'] ?? '') : img.toString();
                        } else if (product['imageUrl'] != null) {
                          imageUrl = product['imageUrl'].toString();
                        }

                        return Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.03),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  width: 56,
                                  height: 56,
                                  color: const Color(0xFFF1F5F9),
                                  child: imageUrl.isNotEmpty
                                      ? Image.network(
                                          imageUrl,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) => const Icon(Icons.grass_rounded, color: Color(0xFF008069)),
                                        )
                                      : const Icon(Icons.grass_rounded, color: Color(0xFF008069)),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      name,
                                      style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13, color: const Color(0xFF1E293B)),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      category,
                                      style: GoogleFonts.outfit(fontSize: 10.5, color: const Color(0xFF64748B)),
                                      maxLines: 1,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '₹$price',
                                      style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 13, color: const Color(0xFF008069)),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 6),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF008069),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  elevation: 0,
                                ),
                                onPressed: _isUploadingAndSending ? null : () => _sendProductCard(product),
                                child: Text('Attach', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 11.5)),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildFileUploadTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.image_outlined, size: 18),
                  label: Text('Select Photos & Images', style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    foregroundColor: const Color(0xFF0284C7),
                    side: const BorderSide(color: Color(0xFF0284C7), width: 1.2),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => _pickFile(true),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.description_outlined, size: 18),
                  label: Text('Select PDF / Document', style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    foregroundColor: const Color(0xFF6366F1),
                    side: const BorderSide(color: Color(0xFF6366F1), width: 1.2),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => _pickFile(false),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // File Preview Area
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _selectedFile != null ? const Color(0xFF008069).withValues(alpha: 0.04) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _selectedFile != null ? const Color(0xFF008069) : const Color(0xFFCBD5E1),
                width: 1.2,
              ),
            ),
            child: _selectedFile == null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.cloud_upload_outlined, size: 48, color: Color(0xFF94A3B8)),
                        const SizedBox(height: 10),
                        Text(
                          'No file selected yet',
                          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14, color: const Color(0xFF475569)),
                        ),
                        Text(
                          'Click one of the buttons above to browse your device files (Images, PDFs, Excel sheets)',
                          style: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF94A3B8)),
                        ),
                      ],
                    ),
                  )
                : Row(
                    children: [
                      if (_isImageUpload && _selectedFile!.bytes != null)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.memory(
                            _selectedFile!.bytes!,
                            width: 80,
                            height: 80,
                            fit: BoxFit.cover,
                          ),
                        )
                      else
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: const Color(0xFFEEF2FF),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.picture_as_pdf_rounded, color: Color(0xFF6366F1), size: 36),
                        ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _selectedFile!.name,
                              style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14, color: const Color(0xFF1E293B)),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${(_selectedFile!.size / 1024).toStringAsFixed(1)} KB • Ready for WhatsApp Cloud dispatch',
                              style: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                        onPressed: () => setState(() => _selectedFile = null),
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: 18),

          // Caption Bar
          TextField(
            controller: _captionController,
            decoration: InputDecoration(
              labelText: 'Message Caption (Optional)',
              hintText: 'e.g. Please review this catalog and pricing sheet...',
              prefixIcon: const Icon(Icons.edit_note_rounded, color: Color(0xFF008069)),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              isDense: true,
            ),
            style: GoogleFonts.outfit(fontSize: 13.5),
          ),
          const SizedBox(height: 20),

          // Send Action
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              icon: _isUploadingAndSending
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.send_rounded, size: 16),
              label: Text(
                _isUploadingAndSending ? 'Uploading & Dispatching...' : 'Send to Customer',
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13.5),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF008069),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: (_selectedFile == null || _isUploadingAndSending)
                  ? null
                  : () => _uploadAndSendMedia(type: _isImageUpload ? 'Image' : 'Document'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompanyCollateralTab() {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _companyCollaterals.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final item = _companyCollaterals[index];
        final isImage = item['type'] == 'Image';

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isImage ? const Color(0xFFE0F2FE) : const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isImage ? Icons.image_rounded : Icons.description_rounded,
                  color: isImage ? const Color(0xFF0284C7) : const Color(0xFF6366F1),
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item['title']!,
                      style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13.5, color: const Color(0xFF1E293B)),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item['description']!,
                      style: GoogleFonts.outfit(fontSize: 11.5, color: const Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                icon: const Icon(Icons.send_rounded, size: 14),
                label: Text('Send', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 12)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF008069),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: _isUploadingAndSending
                    ? null
                    : () {
                        _uploadAndSendMedia(
                          type: item['type']!,
                          directUrl: item['url']!,
                          customCaption: '${item['title']}\n${item['description']}',
                        );
                      },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDirectUrlTab() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Attach via Public Media Link',
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14, color: const Color(0xFF1E293B)),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _urlController,
            decoration: InputDecoration(
              labelText: 'Direct Image or Document URL',
              hintText: 'https://example.com/assets/catalogue.pdf',
              prefixIcon: const Icon(Icons.link_rounded, color: Color(0xFF008069)),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              isDense: true,
            ),
            style: GoogleFonts.outfit(fontSize: 13.5),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _captionController,
            decoration: InputDecoration(
              labelText: 'Caption (Optional)',
              hintText: 'e.g. Please check this document.',
              prefixIcon: const Icon(Icons.edit_note_rounded, color: Color(0xFF008069)),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              isDense: true,
            ),
            style: GoogleFonts.outfit(fontSize: 13.5),
          ),
          const SizedBox(height: 20),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.send_rounded, size: 16),
              label: Text('Send Link', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13.5)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF008069),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: _isUploadingAndSending
                  ? null
                  : () {
                      final url = _urlController.text.trim();
                      if (url.isEmpty) return;
                      final isImage = url.toLowerCase().contains('.png') ||
                          url.toLowerCase().contains('.jpg') ||
                          url.toLowerCase().contains('.jpeg') ||
                          url.toLowerCase().contains('.webp');
                      _uploadAndSendMedia(
                        type: isImage ? 'Image' : 'Document',
                        directUrl: url,
                      );
                    },
            ),
          ),
        ],
      ),
    );
  }
}
