import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kd_pannel/app_theme.dart';

class ProductDetailsDialog extends StatefulWidget {
  final Map<String, dynamic> product;

  const ProductDetailsDialog({
    super.key,
    required this.product,
  });

  @override
  State<ProductDetailsDialog> createState() => _ProductDetailsDialogState();
}

class _ProductDetailsDialogState extends State<ProductDetailsDialog> {
  int _selectedImageIndex = 0;

  List<String> get _allImages {
    final List<String> images = [];
    final p = widget.product;

    if (p['images'] is List) {
      for (var img in p['images']) {
        if (img != null && img.toString().isNotEmpty) {
          images.add(img.toString());
        }
      }
    }

    if (images.isEmpty && p['thumbnail'] != null && p['thumbnail'].toString().isNotEmpty) {
      images.add(p['thumbnail'].toString());
    }

    return images;
  }

  void _copyToClipboard(String text, String message) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w500),
        ),
        backgroundColor: AppTheme.primaryColor,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  String _cleanHtml(String htmlString) {
    if (htmlString.isEmpty) return '';
    // Strip common html tags
    final exp = RegExp(r'<[^>]*>', multiLine: true, caseSensitive: false);
    String clean = htmlString.replaceAll(exp, ' ').replaceAll('&nbsp;', ' ').trim();
    // Replace multiple whitespaces with single space
    clean = clean.replaceAll(RegExp(r'\s+'), ' ');
    return clean;
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    final String name = (p['name'] ?? 'Product Details').toString();
    final String sku = (p['sku'] ?? 'N/A').toString();
    final String vendor = (p['vendor'] ?? '').toString();
    final String category = (p['category'] ?? '').toString();
    final String subCategory = (p['subCategory'] ?? '').toString();
    final bool inStock = p['inStock'] ?? (p['availabilityStatus'] != 'Out of Stock');
    final bool isFeatured = p['isFeatured'] ?? false;
    final List<String> images = _allImages;
    final List variants = (p['variants'] as List?) ?? [];
    final List<String> tags = List<String>.from(p['tags'] ?? []);
    final Map<String, dynamic> dosage = (p['dosage'] as Map?) != null
        ? Map<String, dynamic>.from(p['dosage'])
        : {};
    final String perLiter = dosage['perLiter']?.toString() ?? '';
    final String perAcre = dosage['perAcre']?.toString() ?? '';
    final String dosageMethod = dosage['method']?.toString() ?? '';
    final String rawDescription = p['description']?.toString() ?? '';
    final String cleanDescription = _cleanHtml(rawDescription);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 10,
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        width: 800,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        child: Column(
          children: [
            // 1. Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppTheme.lightBorderColor)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                name,
                                style: GoogleFonts.outfit(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.textPrimary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 10),
                            // In Stock Badge
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: (inStock ? AppTheme.success : AppTheme.error).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: (inStock ? AppTheme.success : AppTheme.error).withValues(alpha: 0.3),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      color: inStock ? AppTheme.success : AppTheme.error,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    inStock ? 'In Stock' : 'Out of Stock',
                                    style: GoogleFonts.outfit(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: inStock ? AppTheme.success : AppTheme.error,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (isFeatured) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppTheme.warning.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: AppTheme.warning.withValues(alpha: 0.3),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.star_rounded, size: 12, color: AppTheme.warning),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Featured',
                                      style: GoogleFonts.outfit(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.warning,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            if (vendor.isNotEmpty) ...[
                              Text(
                                vendor,
                                style: GoogleFonts.outfit(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.primaryColor,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Text('•', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                              const SizedBox(width: 8),
                            ],
                            Text(
                              'SKU: $sku',
                              style: GoogleFonts.outfit(
                                fontSize: 12,
                                color: AppTheme.textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(width: 4),
                            InkWell(
                              onTap: () => _copyToClipboard(sku, 'SKU copied to clipboard'),
                              borderRadius: BorderRadius.circular(4),
                              child: const Padding(
                                padding: EdgeInsets.all(2),
                                child: Icon(Icons.copy_rounded, size: 13, color: AppTheme.textSecondary),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded, size: 20, color: AppTheme.textSecondary),
                    splashRadius: 20,
                  ),
                ],
              ),
            ),

            // 2. Scrollable Body
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top Row: Image preview & Quick Details
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Left: Image View
                        Container(
                          width: 220,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF9FAFB),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppTheme.borderColor),
                          ),
                          child: Column(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: SizedBox(
                                  height: 180,
                                  width: double.infinity,
                                  child: _buildMainImage(images),
                                ),
                              ),
                              if (images.length > 1) ...[
                                const SizedBox(height: 10),
                                SizedBox(
                                  height: 44,
                                  child: ListView.separated(
                                    scrollDirection: Axis.horizontal,
                                    itemCount: images.length,
                                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                                    itemBuilder: (ctx, i) {
                                      final isSelected = i == _selectedImageIndex;
                                      return InkWell(
                                        onTap: () => setState(() => _selectedImageIndex = i),
                                        borderRadius: BorderRadius.circular(6),
                                        child: Container(
                                          width: 44,
                                          height: 44,
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(
                                              color: isSelected ? AppTheme.primaryColor : AppTheme.borderColor,
                                              width: isSelected ? 2 : 1,
                                            ),
                                          ),
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(5),
                                            child: _buildThumbnailItem(images[i]),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 20),

                        // Right: Key Info Cards
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Categories & Sub-category Tags
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  if (category.isNotEmpty && category != 'N/A')
                                    _buildInfoChip(
                                      icon: Icons.category_outlined,
                                      label: category,
                                      color: AppTheme.primaryColor,
                                    ),
                                  if (subCategory.isNotEmpty && subCategory != 'N/A')
                                    _buildInfoChip(
                                      icon: Icons.subdirectory_arrow_right_rounded,
                                      label: subCategory,
                                      color: const Color(0xFF0284C7),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 16),

                              // Dosage & Application Grid
                              Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF9FAFB),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppTheme.borderColor),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Application & Dosage',
                                      style: GoogleFonts.outfit(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: _buildDetailField(
                                            'Per Liter',
                                            perLiter.isNotEmpty ? perLiter : 'Not specified',
                                          ),
                                        ),
                                        Expanded(
                                          child: _buildDetailField(
                                            'Per Acre',
                                            perAcre.isNotEmpty ? perAcre : 'Not specified',
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    _buildDetailField(
                                      'Application Method',
                                      dosageMethod.isNotEmpty ? dosageMethod : 'Standard application',
                                    ),
                                  ],
                                ),
                              ),

                              if (tags.isNotEmpty) ...[
                                const SizedBox(height: 14),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: tags.map((t) {
                                    return Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade100,
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: Colors.grey.shade300),
                                      ),
                                      child: Text(
                                        '#$t',
                                        style: GoogleFonts.outfit(
                                          fontSize: 11,
                                          color: AppTheme.textSecondary,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Section 2: Variants & Pricing Breakdown
                    Text(
                      'Variants & Price Breakdown',
                      style: GoogleFonts.outfit(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 10),

                    if (variants.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF9FAFB),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.borderColor),
                        ),
                        child: Text(
                          'No variant details available for this product.',
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      )
                    else
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.borderColor),
                        ),
                        child: Column(
                          children: [
                            // Variants Table Header
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              decoration: const BoxDecoration(
                                color: Color(0xFFF9FAFB),
                                borderRadius: BorderRadius.vertical(top: Radius.circular(11)),
                              ),
                              child: Row(
                                children: [
                                  Expanded(flex: 3, child: _tableHeader('PACK SIZE / VARIANT')),
                                  Expanded(flex: 2, child: _tableHeader('MRP (₹)')),
                                  Expanded(flex: 2, child: _tableHeader('DEALER PRICE (₹)')),
                                  Expanded(flex: 2, child: _tableHeader('FARMER PRICE (₹)')),
                                  Expanded(flex: 3, child: _tableHeader('EST. MARGIN')),
                                ],
                              ),
                            ),
                            const Divider(height: 1, color: AppTheme.lightBorderColor),

                            // Variants Rows
                            ...variants.asMap().entries.map((entry) {
                              final v = entry.value as Map;
                              final isLast = entry.key == variants.length - 1;
                              final String packSize = (v['size'] ?? v['packSize'] ?? 'Default').toString();
                              final double dealerPrice = double.tryParse(v['price']?.toString() ?? '0') ?? 0.0;
                              final double mrp = double.tryParse(v['compareAtPrice']?.toString() ?? '0') ?? 0.0;
                              final dynamic fpRaw = v['farmerPrice'] ?? v['farmer_price'];
                              final double farmerPrice = fpRaw != null ? (double.tryParse(fpRaw.toString()) ?? 0.0) : 0.0;
                              final double marginAmt = (farmerPrice > 0 && dealerPrice > 0) ? (farmerPrice - dealerPrice) : 0.0;
                              final double marginPct = (farmerPrice > 0 && marginAmt > 0) ? (marginAmt / farmerPrice) * 100 : 0.0;

                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                decoration: BoxDecoration(
                                  color: entry.key % 2 == 0 ? Colors.white : const Color(0xFFFAFAFA),
                                  border: isLast ? null : const Border(bottom: BorderSide(color: AppTheme.lightBorderColor)),
                                  borderRadius: isLast ? const BorderRadius.vertical(bottom: Radius.circular(11)) : null,
                                ),
                                child: Row(
                                  children: [
                                    // Pack Size
                                    Expanded(
                                      flex: 3,
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            packSize,
                                            style: GoogleFonts.outfit(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w700,
                                              color: AppTheme.textPrimary,
                                            ),
                                          ),
                                          if (v['sku'] != null && v['sku'].toString().isNotEmpty)
                                            Text(
                                              'SKU: ${v['sku']}',
                                              style: GoogleFonts.outfit(
                                                fontSize: 10.5,
                                                color: AppTheme.textSecondary,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    // MRP
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        mrp > 0 ? '₹${mrp % 1 == 0 ? mrp.toInt() : mrp.toStringAsFixed(2)}' : '—',
                                        style: GoogleFonts.outfit(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w500,
                                          color: AppTheme.textSecondary,
                                          decoration: mrp > dealerPrice ? TextDecoration.lineThrough : null,
                                        ),
                                      ),
                                    ),
                                    // Dealer Price
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        '₹${dealerPrice % 1 == 0 ? dealerPrice.toInt() : dealerPrice.toStringAsFixed(2)}',
                                        style: GoogleFonts.outfit(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.primaryColor,
                                        ),
                                      ),
                                    ),
                                    // Farmer Price
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        farmerPrice > 0 ? '₹${farmerPrice % 1 == 0 ? farmerPrice.toInt() : farmerPrice.toStringAsFixed(2)}' : '—',
                                        style: GoogleFonts.outfit(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: const Color(0xFF059669),
                                        ),
                                      ),
                                    ),
                                    // Margin
                                    Expanded(
                                      flex: 3,
                                      child: marginAmt > 0
                                          ? Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFECFDF5),
                                                borderRadius: BorderRadius.circular(6),
                                                border: Border.all(color: const Color(0xFFA7F3D0)),
                                              ),
                                              child: Text(
                                                '₹${marginAmt.toStringAsFixed(0)} (${marginPct.toStringAsFixed(1)}%)',
                                                style: GoogleFonts.outfit(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                  color: const Color(0xFF059669),
                                                ),
                                              ),
                                            )
                                          : Text(
                                              '—',
                                              style: GoogleFonts.outfit(
                                                fontSize: 12.5,
                                                color: AppTheme.textSecondary,
                                              ),
                                            ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ],
                        ),
                      ),

                    // Section 3: Description (if any)
                    if (cleanDescription.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      Text(
                        'Product Overview',
                        style: GoogleFonts.outfit(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF9FAFB),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.borderColor),
                        ),
                        child: Text(
                          cleanDescription,
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            color: AppTheme.textBody,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // 3. Footer
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: AppTheme.lightBorderColor)),
                color: Color(0xFFF9FAFB),
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  OutlinedButton.icon(
                    onPressed: () {
                      final summary = StringBuffer();
                      summary.writeln('Product: $name');
                      if (vendor.isNotEmpty) summary.writeln('Brand: $vendor');
                      summary.writeln('SKU: $sku');
                      if (category.isNotEmpty) summary.writeln('Category: $category');
                      if (variants.isNotEmpty) {
                        summary.writeln('Pricing & Variants:');
                        for (var v in variants) {
                          final pack = v['size'] ?? v['packSize'] ?? 'Standard';
                          final dp = v['price'] ?? 0;
                          final fp = v['farmerPrice'] ?? v['farmer_price'] ?? '—';
                          summary.writeln('• $pack: Dealer ₹$dp | Farmer ₹$fp');
                        }
                      }
                      _copyToClipboard(summary.toString(), 'Product summary copied to clipboard');
                    },
                    icon: const Icon(Icons.copy_all_rounded, size: 16),
                    label: Text(
                      'Copy Summary',
                      style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.textPrimary,
                      side: const BorderSide(color: AppTheme.borderColor),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    ),
                    child: Text(
                      'Close',
                      style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainImage(List<String> images) {
    if (images.isEmpty) {
      return Container(
        color: AppTheme.primaryColor.withValues(alpha: 0.05),
        child: const Center(
          child: Icon(
            Icons.image_not_supported_outlined,
            size: 40,
            color: AppTheme.textSecondary,
          ),
        ),
      );
    }

    final currentImg = (_selectedImageIndex < images.length)
        ? images[_selectedImageIndex]
        : images.first;

    if (currentImg.startsWith('data:image')) {
      try {
        final base64Str = currentImg.split(',').last;
        final bytes = base64Decode(base64Str);
        return Image.memory(bytes, fit: BoxFit.cover);
      } catch (_) {}
    }

    return Image.network(
      currentImg,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Container(
        color: AppTheme.primaryColor.withValues(alpha: 0.05),
        child: const Center(
          child: Icon(Icons.broken_image_outlined, size: 36, color: AppTheme.textSecondary),
        ),
      ),
    );
  }

  Widget _buildThumbnailItem(String imgUrl) {
    if (imgUrl.startsWith('data:image')) {
      try {
        final base64Str = imgUrl.split(',').last;
        final bytes = base64Decode(base64Str);
        return Image.memory(bytes, fit: BoxFit.cover);
      } catch (_) {}
    }

    return Image.network(
      imgUrl,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => const Center(
        child: Icon(Icons.image_outlined, size: 18, color: AppTheme.textSecondary),
      ),
    );
  }

  Widget _buildInfoChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
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

  Widget _buildDetailField(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 11,
            color: AppTheme.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: GoogleFonts.outfit(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _tableHeader(String text) {
    return Text(
      text,
      style: GoogleFonts.outfit(
        fontSize: 11,
        fontWeight: FontWeight.bold,
        color: AppTheme.textSecondary,
        letterSpacing: 0.5,
      ),
    );
  }
}
