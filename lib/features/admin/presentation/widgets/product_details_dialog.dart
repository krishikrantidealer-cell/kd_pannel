import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kd_pannel/app_theme.dart';
import 'package:kd_pannel/core/auth/auth_service.dart';

class ProductDetailsDialog extends StatefulWidget {
  final Map<String, dynamic> product;

  const ProductDetailsDialog({
    super.key,
    required this.product,
  });

  @override
  State<ProductDetailsDialog> createState() => _ProductDetailsDialogState();
}

class _StructuredProductInfo {
  final String overview;
  final Map<String, String> composition;
  final List<String> benefits;
  final List<String> suitableCrops;
  final String modeOfAction;
  final List<Map<String, String>> faqs;

  const _StructuredProductInfo({
    this.overview = '',
    this.composition = const {},
    this.benefits = const [],
    this.suitableCrops = const [],
    this.modeOfAction = '',
    this.faqs = const [],
  });
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

  _StructuredProductInfo _parseDescription(String rawHtml) {
    if (rawHtml.isEmpty) return const _StructuredProductInfo();

    // Clean raw html
    String text = rawHtml
        .replaceAll(RegExp(r'&#47;'), '/')
        .replaceAll(RegExp(r'&amp;'), '&')
        .replaceAll(RegExp(r'&nbsp;'), ' ')
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'</p>', caseSensitive: false), '\n\n')
        .replaceAll(RegExp(r'<p>', caseSensitive: false), '')
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .trim();

    final lines = text.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();

    String currentSection = 'overview';
    final List<String> overviewLines = [];
    final Map<String, String> composition = {};
    final List<String> benefits = [];
    final List<String> crops = [];
    final List<String> modeOfActionLines = [];
    final List<Map<String, String>> faqs = [];
    String currentFaqQuestion = '';
    final List<String> currentFaqAnswer = [];

    void flushFaq() {
      if (currentFaqQuestion.isNotEmpty) {
        faqs.add({
          'q': currentFaqQuestion,
          'a': currentFaqAnswer.join(' ').trim(),
        });
        currentFaqQuestion = '';
        currentFaqAnswer.clear();
      }
    }

    for (var line in lines) {
      final lower = line.toLowerCase();

      // Check for section headers
      if (lower == 'product description') {
        flushFaq();
        currentSection = 'overview';
        continue;
      } else if (lower.contains('composition') || lower.contains('nutrient') || lower.contains('technical composition')) {
        flushFaq();
        currentSection = 'composition';
        continue;
      } else if (lower.contains('key benefits') || lower == 'benefits') {
        flushFaq();
        currentSection = 'benefits';
        continue;
      } else if (lower.contains('suitable crops') || lower.contains('target crops') || lower == 'crops') {
        flushFaq();
        currentSection = 'crops';
        continue;
      } else if (lower.contains('mode of action')) {
        flushFaq();
        currentSection = 'mode_of_action';
        continue;
      } else if (lower.contains('frequently asked questions') || lower == 'faqs' || lower == 'faq') {
        flushFaq();
        currentSection = 'faqs';
        continue;
      }

      // Process line based on current section
      switch (currentSection) {
        case 'overview':
          overviewLines.add(line);
          break;
        case 'composition':
          if (line.contains(':')) {
            final idx = line.indexOf(':');
            final k = line.substring(0, idx).trim();
            final v = line.substring(idx + 1).trim();
            if (k.isNotEmpty && v.isNotEmpty) {
              composition[k] = v;
            }
          } else {
            overviewLines.add(line);
          }
          break;
        case 'benefits':
          benefits.add(line.replaceAll(RegExp(r'^[•\-\*]\s*'), ''));
          break;
        case 'crops':
          if (!lower.startsWith('suitable for multiple') && !lower.startsWith('suitable crops')) {
            final cleanedLine = line.replaceAll(RegExp(r'^[•\-\*]\s*'), '');
            final splitItems = cleanedLine.split(RegExp(r'[,;•]'));
            for (var item in splitItems) {
              final trimmed = item.trim();
              if (trimmed.isNotEmpty) {
                if (trimmed.length < 50) {
                  crops.add(trimmed);
                } else {
                  overviewLines.add(trimmed);
                }
              }
            }
          }
          break;
        case 'mode_of_action':
          modeOfActionLines.add(line);
          break;
        case 'faqs':
          final isQuestion = RegExp(r'^\d+[\.\)]\s*').hasMatch(line) || lower.startsWith('q:') || lower.startsWith('question:');
          if (isQuestion) {
            flushFaq();
            currentFaqQuestion = line.replaceFirst(RegExp(r'^\d+[\.\)]\s*'), '').replaceFirst(RegExp(r'^[Qq](uestion)?:\s*'), '').trim();
          } else if (currentFaqQuestion.isNotEmpty) {
            currentFaqAnswer.add(line.replaceFirst(RegExp(r'^[Aa](nswer)?:\s*'), '').trim());
          } else {
            overviewLines.add(line);
          }
          break;
      }
    }
    flushFaq();

    return _StructuredProductInfo(
      overview: overviewLines.join('\n\n'),
      composition: composition,
      benefits: benefits,
      suitableCrops: crops,
      modeOfAction: modeOfActionLines.join('\n\n'),
      faqs: faqs,
    );
  }

  double? _parseRateValue(dynamic rawRate) {
    if (rawRate == null) return null;
    final str = rawRate.toString().trim();
    if (str.isEmpty) return null;
    final clean = str.split('/').first.replaceAll(RegExp(r'[^0-9.]'), '');
    return double.tryParse(clean);
  }

  String _extractRateUnit(dynamic rawRate, String fallbackUnit) {
    if (rawRate != null && rawRate.toString().contains('/')) {
      final unitPart = rawRate.toString().split('/').last.trim();
      if (unitPart.isNotEmpty) return unitPart;
    }
    return fallbackUnit.isNotEmpty ? fallbackUnit : '';
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    final String name = (p['name'] ?? p['title'] ?? 'Product Details').toString();
    final String sku = (p['sku'] ?? 'N/A').toString();
    final String vendor = (p['vendor'] ?? p['brandName'] ?? '').toString();
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
    final _StructuredProductInfo structuredInfo = _parseDescription(rawDescription);

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
                                  if (AuthService().isAdmin) Expanded(flex: 2, child: _tableHeader('COST PRICE (CP)')),
                                  Expanded(flex: 3, child: _tableHeader('TIER PRICING (ALL TIERS)')),
                                  Expanded(flex: 2, child: _tableHeader('FARMER PRICE (₹)')),
                                  if (AuthService().isAdmin)
                                    Expanded(flex: 2, child: _tableHeader('GROSS PROFIT'))
                                  else
                                    Expanded(flex: 2, child: _tableHeader('EST. MARGIN')),
                                ],
                              ),
                            ),
                            const Divider(height: 1, color: AppTheme.lightBorderColor),

                            // Variants Rows
                            ...variants.asMap().entries.map((entry) {
                              final v = entry.value as Map;
                              final isLast = entry.key == variants.length - 1;
                              final bool isAdmin = AuthService().isAdmin;
                              final String packSize = (v['size'] ?? v['packSize'] ?? 'Default').toString();
                              final double defaultPrice = double.tryParse(v['price']?.toString() ?? v['dealerPrice']?.toString() ?? '0') ?? 0.0;
                              final double mrp = double.tryParse(v['compareAtPrice']?.toString() ?? '0') ?? 0.0;
                              final dynamic fpRaw = v['farmerPrice'] ?? v['farmer_price'];
                              final double farmerPrice = fpRaw != null ? (double.tryParse(fpRaw.toString()) ?? 0.0) : 0.0;
                              final dynamic cpRaw = v['costPrice'] ?? v['cost_price'];
                              final double costPrice = cpRaw != null ? (double.tryParse(cpRaw.toString()) ?? 0.0) : 0.0;
                              final dynamic crRaw = v['costRate'] ?? v['cost_rate'];
                              final double? costRate = _parseRateValue(crRaw);

                              // Parse Price Tiers
                              final priceTiers = (v['priceTiers'] as List?) ?? (p['priceTiers'] as List?);
                              final rates = v['rates'] as Map?;
                              final double packVolume = (v['packVolume'] as num?)?.toDouble() ?? 1.0;
                              final String baseUnit = (v['basePackingUnit'] ?? '').toString();

                              final List<Map<String, dynamic>> parsedTiers = [];
                              if (priceTiers != null && rates != null && rates.isNotEmpty) {
                                for (var t in priceTiers) {
                                  if (t is! Map) continue;
                                  final tId = t['id']?.toString() ?? '';
                                  final tName = t['name']?.toString() ?? '';
                                  final dynamic rawRate = rates[tId] ?? rates[int.tryParse(tId)];
                                  final rVal = _parseRateValue(rawRate);
                                  if (rVal != null) {
                                    final unit = _extractRateUnit(rawRate, baseUnit);
                                    parsedTiers.add({
                                      'id': tId,
                                      'name': tName,
                                      'rate': rVal,
                                      'unit': unit,
                                      'packPrice': rVal * packVolume,
                                    });
                                  }
                                }
                              }

                              double lowestTierPrice = defaultPrice;
                              if (parsedTiers.isNotEmpty) {
                                final prices = parsedTiers.map((t) => (t['rate'] as double)).toList();
                                prices.sort();
                                lowestTierPrice = prices.first;
                              }

                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                decoration: BoxDecoration(
                                  color: entry.key % 2 == 0 ? Colors.white : const Color(0xFFFAFAFA),
                                  border: isLast ? null : const Border(bottom: BorderSide(color: AppTheme.lightBorderColor)),
                                  borderRadius: isLast ? const BorderRadius.vertical(bottom: Radius.circular(11)) : null,
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    // Pack Size & Base Info
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
                                          if (packVolume > 0 && baseUnit.isNotEmpty)
                                            Text(
                                              'Vol: ${packVolume % 1 == 0 ? packVolume.toInt() : packVolume} $baseUnit',
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
                                          decoration: (mrp > lowestTierPrice && lowestTierPrice > 0) ? TextDecoration.lineThrough : null,
                                        ),
                                      ),
                                    ),
                                    // Cost Price (Admin Only)
                                    if (isAdmin)
                                      Expanded(
                                        flex: 2,
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              costRate != null && costRate > 0
                                                  ? '₹${costRate % 1 == 0 ? costRate.toInt() : costRate.toStringAsFixed(1)}${baseUnit.isNotEmpty ? ' / $baseUnit' : ''}'
                                                  : (costPrice > 0 ? '₹${costPrice % 1 == 0 ? costPrice.toInt() : costPrice.toStringAsFixed(2)}' : '—'),
                                              style: GoogleFonts.outfit(
                                                fontSize: 12.5,
                                                fontWeight: FontWeight.w700,
                                                color: const Color(0xFFD97706),
                                              ),
                                            ),
                                            if (costPrice > 0 && (costRate == null || costPrice != costRate || packVolume > 1))
                                              Text(
                                                'Total: ₹${costPrice % 1 == 0 ? costPrice.toInt() : costPrice.toStringAsFixed(0)}',
                                                style: GoogleFonts.outfit(
                                                  fontSize: 10.5,
                                                  color: AppTheme.textSecondary,
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    // ALL TIER PRICES
                                    Expanded(
                                      flex: 3,
                                      child: parsedTiers.isNotEmpty
                                          ? Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: parsedTiers.map((t) {
                                                final tName = t['name'] ?? '';
                                                final rVal = t['rate'] as double;
                                                final unit = (t['unit'] ?? '').toString();
                                                final unitSuffix = unit.isNotEmpty ? ' / $unit' : '';
                                                return Padding(
                                                  padding: const EdgeInsets.symmetric(vertical: 2.5),
                                                  child: Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                        decoration: BoxDecoration(
                                                          color: AppTheme.primaryColor.withValues(alpha: 0.08),
                                                          borderRadius: BorderRadius.circular(4),
                                                          border: Border.all(
                                                            color: AppTheme.primaryColor.withValues(alpha: 0.25),
                                                          ),
                                                        ),
                                                        child: Text(
                                                          tName,
                                                          style: GoogleFonts.outfit(
                                                            fontSize: 10,
                                                            fontWeight: FontWeight.bold,
                                                            color: AppTheme.primaryColor,
                                                          ),
                                                        ),
                                                      ),
                                                      const SizedBox(width: 6),
                                                      Text(
                                                        '₹${rVal % 1 == 0 ? rVal.toInt() : rVal.toStringAsFixed(1)}$unitSuffix',
                                                        style: GoogleFonts.outfit(
                                                          fontSize: 12.5,
                                                          fontWeight: FontWeight.w700,
                                                          color: AppTheme.textPrimary,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                );
                                              }).toList(),
                                            )
                                          : Text(
                                              '₹${defaultPrice % 1 == 0 ? defaultPrice.toInt() : defaultPrice.toStringAsFixed(2)}',
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
                                    // Gross Profit / Est. Margin
                                    if (isAdmin)
                                      Expanded(
                                        flex: 2,
                                        child: parsedTiers.isNotEmpty && costRate != null && costRate > 0
                                            ? Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: parsedTiers.map((t) {
                                                  final rVal = t['rate'] as double;
                                                  final profitAmt = rVal - costRate;
                                                  final marginPct = rVal > 0 ? (profitAmt / rVal) * 100 : 0.0;
                                                  return Padding(
                                                    padding: const EdgeInsets.symmetric(vertical: 2.5),
                                                    child: Text(
                                                      profitAmt != 0
                                                          ? '₹${profitAmt.toStringAsFixed(0)} (${marginPct.toStringAsFixed(0)}%)'
                                                          : '—',
                                                      style: GoogleFonts.outfit(
                                                        fontSize: 11,
                                                        fontWeight: FontWeight.bold,
                                                        color: profitAmt >= 0 ? const Color(0xFF059669) : const Color(0xFFDC2626),
                                                      ),
                                                    ),
                                                  );
                                                }).toList(),
                                              )
                                            : Builder(
                                                builder: (_) {
                                                  final effectiveCP = costRate ?? (packVolume > 0 ? costPrice / packVolume : costPrice);
                                                  final profitAmt = (effectiveCP > 0 && defaultPrice > 0) ? (defaultPrice - effectiveCP) : 0.0;
                                                  final marginPct = (defaultPrice > 0 && profitAmt != 0) ? (profitAmt / defaultPrice) * 100 : 0.0;
                                                  if (effectiveCP <= 0 || profitAmt == 0) {
                                                    return Text('—', style: GoogleFonts.outfit(fontSize: 12.5, color: AppTheme.textSecondary));
                                                  }
                                                  return Text(
                                                    '₹${profitAmt.toStringAsFixed(0)} (${marginPct.toStringAsFixed(1)}%)',
                                                    style: GoogleFonts.outfit(
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.bold,
                                                      color: profitAmt >= 0 ? const Color(0xFF059669) : const Color(0xFFDC2626),
                                                    ),
                                                  );
                                                },
                                              ),
                                      )
                                    else
                                      Expanded(
                                        flex: 2,
                                        child: parsedTiers.isNotEmpty && farmerPrice > 0
                                            ? Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: parsedTiers.map((t) {
                                                  final rVal = t['rate'] as double;
                                                  final marginAmt = farmerPrice - rVal;
                                                  final marginPct = (marginAmt / farmerPrice) * 100;
                                                  return Padding(
                                                    padding: const EdgeInsets.symmetric(vertical: 2.5),
                                                    child: Text(
                                                      marginAmt > 0
                                                          ? '₹${marginAmt.toStringAsFixed(0)} (${marginPct.toStringAsFixed(0)}%)'
                                                          : '—',
                                                      style: GoogleFonts.outfit(
                                                        fontSize: 11,
                                                        fontWeight: FontWeight.bold,
                                                        color: marginAmt > 0 ? const Color(0xFF059669) : AppTheme.textSecondary,
                                                      ),
                                                    ),
                                                  );
                                                }).toList(),
                                              )
                                            : Builder(
                                                builder: (_) {
                                                  final marginAmt = (farmerPrice > 0 && defaultPrice > 0) ? (farmerPrice - defaultPrice) : 0.0;
                                                  final marginPct = (farmerPrice > 0 && marginAmt > 0) ? (marginAmt / farmerPrice) * 100 : 0.0;
                                                  if (marginAmt <= 0) {
                                                    return Text('—', style: GoogleFonts.outfit(fontSize: 12.5, color: AppTheme.textSecondary));
                                                  }
                                                  return Text(
                                                    '₹${marginAmt.toStringAsFixed(0)} (${marginPct.toStringAsFixed(1)}%)',
                                                    style: GoogleFonts.outfit(
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.bold,
                                                      color: const Color(0xFF059669),
                                                    ),
                                                  );
                                                },
                                              ),
                                      ),
                                  ],
                                ),
                              );
                            }),
                          ],
                        ),
                      ),

                    // Section 3: Structured Professional Product Overview & Technical Specs
                    _buildStructuredProductDescription(structuredInfo, p),
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
                          final fp = v['farmerPrice'] ?? v['farmer_price'] ?? '—';
                          final priceTiers = (v['priceTiers'] as List?) ?? (p['priceTiers'] as List?);
                          final rates = v['rates'] as Map?;
                          final String baseUnit = (v['basePackingUnit'] ?? '').toString();
                          final double defaultPrice = double.tryParse(v['price']?.toString() ?? v['dealerPrice']?.toString() ?? '0') ?? 0.0;
                          final List<String> tiersList = [];
                          if (priceTiers != null && rates != null && rates.isNotEmpty) {
                            for (var t in priceTiers) {
                              if (t is Map) {
                                final tId = t['id']?.toString() ?? '';
                                final tName = t['name']?.toString() ?? '';
                                final dynamic rawRate = rates[tId] ?? rates[int.tryParse(tId)];
                                final r = _parseRateValue(rawRate);
                                if (r != null) {
                                  final unit = _extractRateUnit(rawRate, baseUnit);
                                  final uSuffix = unit.isNotEmpty ? ' / $unit' : '';
                                  tiersList.add('$tName: ₹${r % 1 == 0 ? r.toInt() : r.toStringAsFixed(1)}$uSuffix');
                                }
                              }
                            }
                          }
                          final tierStr = tiersList.isNotEmpty
                              ? tiersList.join(' | ')
                              : '₹$defaultPrice';
                          final dynamic cpVal = v['costPrice'] ?? v['cost_price'];
                          final String cpSuffix = (AuthService().isAdmin && cpVal != null && cpVal.toString().isNotEmpty && cpVal != 0)
                              ? ' | CP ₹$cpVal'
                              : '';
                          summary.writeln('• $pack: [$tierStr]$cpSuffix | Farmer ₹$fp');
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

  Widget _buildStructuredProductDescription(_StructuredProductInfo info, Map<String, dynamic> p) {
    final technicalName = (p['technicalName'] ?? '').toString();
    final assignedCollections = (p['assignedCollections'] as List?)?.map((c) => c.toString()).toList() ?? [];

    final hasOverview = info.overview.trim().isNotEmpty;
    final hasComposition = info.composition.isNotEmpty || technicalName.isNotEmpty;
    final hasBenefits = info.benefits.isNotEmpty;
    final hasCrops = info.suitableCrops.isNotEmpty || assignedCollections.isNotEmpty;
    final hasModeOfAction = info.modeOfAction.trim().isNotEmpty;
    final hasFaqs = info.faqs.isNotEmpty;

    if (!hasOverview && !hasComposition && !hasBenefits && !hasCrops && !hasModeOfAction && !hasFaqs) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.auto_awesome_rounded,
                size: 16,
                color: AppTheme.primaryColor,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Product Overview & Technical Details',
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // 1. Overview Paragraph Card
        if (hasOverview)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.borderColor),
            ),
            child: Text(
              info.overview,
              style: GoogleFonts.outfit(
                fontSize: 13,
                color: AppTheme.textBody,
                height: 1.6,
              ),
            ),
          ),

        // 2. Technical / Chemical Composition Card
        if (hasComposition)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.only(bottom: 16),
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
                Row(
                  children: [
                    const Icon(Icons.science_outlined, size: 18, color: Color(0xFF0284C7)),
                    const SizedBox(width: 8),
                    Text(
                      'Technical Composition & Chemistry',
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
                if (technicalName.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0F9FF),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFBAE6FD)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.biotech_rounded, size: 16, color: Color(0xFF0284C7)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            technicalName,
                            style: GoogleFonts.outfit(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF0369A1),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (info.composition.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 10,
                    children: info.composition.entries.map((e) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF9FAFB),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppTheme.lightBorderColor),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              e.key.toUpperCase(),
                              style: GoogleFonts.outfit(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textSecondary,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              e.value,
                              style: GoogleFonts.outfit(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textPrimary,
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
          ),

        // 3. Key Benefits Card
        if (hasBenefits)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.only(bottom: 16),
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
                Row(
                  children: [
                    const Icon(Icons.verified_rounded, size: 18, color: Color(0xFF059669)),
                    const SizedBox(width: 8),
                    Text(
                      'Key Benefits & Efficacy',
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Column(
                  children: info.benefits.map((benefit) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            margin: const EdgeInsets.only(top: 2),
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFECFDF5),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Icon(
                              Icons.check_rounded,
                              size: 13,
                              color: Color(0xFF059669),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              benefit,
                              style: GoogleFonts.outfit(
                                fontSize: 12.5,
                                color: AppTheme.textBody,
                                height: 1.4,
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

        // 4. Suitable Crops & Assigned Collections Card
        if (hasCrops)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.borderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.grass_rounded, size: 18, color: Color(0xFFD97706)),
                    const SizedBox(width: 8),
                    Text(
                      'Suitable Crops & Target Pests',
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (info.suitableCrops.isNotEmpty) ...[
                  Text(
                    'Recommended Crops',
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: info.suitableCrops.map((c) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFFDE68A)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.eco_outlined, size: 13, color: Color(0xFFB45309)),
                            const SizedBox(width: 5),
                            Flexible(
                              child: Text(
                                c,
                                style: GoogleFonts.outfit(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF92400E),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ],
                if (assignedCollections.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Target Pest & Crop Collections',
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: assignedCollections.map((col) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Text(
                          col,
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF475569),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),

        // 5. Mode of Action Card
        if (hasModeOfAction)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F3FF),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFDDD6FE)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.bolt_rounded, size: 18, color: Color(0xFF7C3AED)),
                    const SizedBox(width: 8),
                    Text(
                      'Mode of Action',
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF5B21B6),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  info.modeOfAction,
                  style: GoogleFonts.outfit(
                    fontSize: 12.5,
                    color: const Color(0xFF4C1D95),
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),

        // 6. Frequently Asked Questions (FAQ)
        if (hasFaqs)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.borderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.help_outline_rounded, size: 18, color: AppTheme.primaryColor),
                    const SizedBox(width: 8),
                    Text(
                      'Frequently Asked Questions',
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Column(
                  children: info.faqs.map((faq) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.lightBorderColor),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'Q',
                                  style: GoogleFonts.outfit(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.primaryColor,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  faq['q'] ?? '',
                                  style: GoogleFonts.outfit(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (faq['a'] != null && faq['a']!.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Padding(
                              padding: const EdgeInsets.only(left: 24),
                              child: Text(
                                faq['a']!,
                                style: GoogleFonts.outfit(
                                  fontSize: 12,
                                  color: AppTheme.textBody,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
