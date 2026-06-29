import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kd_pannel/app_theme.dart';
import 'package:kd_pannel/core/network/api_client.dart';
import 'package:kd_pannel/core/services/analytics_service.dart';

// ---------------------------------------------------------------------------
// Sales Agent – My Price-Override Coupons Page
// ---------------------------------------------------------------------------

class SalesCouponPage extends StatefulWidget {
  const SalesCouponPage({super.key});

  @override
  State<SalesCouponPage> createState() => _SalesCouponPageState();
}

class _SalesCouponPageState extends State<SalesCouponPage> {
  List<Map<String, dynamic>> _coupons = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchCoupons();
  }

  Future<void> _fetchCoupons() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final res = await ApiClient().get('/sales-coupons/mine');
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['success'] == true) {
          setState(() {
            _coupons = List<Map<String, dynamic>>.from(
              (data['coupons'] as List).map((c) => Map<String, dynamic>.from(c as Map)),
            );
          });
          return;
        }
      }
      setState(() => _error = 'Failed to load coupons');
    } catch (e) {
      setState(() => _error = 'Network error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteCoupon(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Delete Coupon?',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'This coupon will be permanently deleted.',
          style: GoogleFonts.outfit(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      final res = await ApiClient().delete('/sales-coupons/$id');
      if (res.statusCode == 200) {
        _showSnack('Coupon deleted');
        _fetchCoupons();
      } else {
        final data = jsonDecode(res.body);
        _showSnack(data['message'] ?? 'Delete failed', isError: true);
      }
    } catch (e) {
      _showSnack('Error: $e', isError: true);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.outfit(color: Colors.white)),
        backgroundColor: isError ? Colors.red.shade600 : AppTheme.primaryColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _openCreateSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _CreateCouponSheet(
        onCreated: () {
          Navigator.of(ctx).pop();
          _fetchCoupons();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'My Price Coupons',
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.bold,
                fontSize: 17,
                color: AppTheme.textPrimary,
              ),
            ),
            Text(
              'Single-use variant price overrides',
              style: GoogleFonts.outfit(
                fontSize: 11,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton.icon(
              onPressed: _openCreateSheet,
              icon: const Icon(Icons.add_rounded, size: 16),
              label: Text(
                'Create',
                style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              ),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppTheme.lightBorderColor),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryColor),
            )
          : _error != null
              ? _buildError()
              : _coupons.isEmpty
                  ? _buildEmpty()
                  : RefreshIndicator(
                      color: AppTheme.primaryColor,
                      onRefresh: _fetchCoupons,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _coupons.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (_, i) => _CouponCard(
                          coupon: _coupons[i],
                          onDelete: () => _deleteCoupon(_coupons[i]['_id']),
                          onCopy: () {
                            Clipboard.setData(
                              ClipboardData(text: _coupons[i]['code'] ?? ''),
                            );
                            _showSnack('Code copied to clipboard!');
                          },
                        ),
                      ),
                    ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline_rounded, size: 48, color: Colors.red),
          const SizedBox(height: 12),
          Text(_error!, style: GoogleFonts.outfit(color: AppTheme.textSecondary)),
          const SizedBox(height: 16),
          OutlinedButton(onPressed: _fetchCoupons, child: const Text('Retry')),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.price_change_outlined,
              size: 48,
              color: AppTheme.primaryColor.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'No active coupons',
            style: GoogleFonts.outfit(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Create a coupon to override a product\nvariant price for a specific order.',
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              color: AppTheme.textSecondary,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _openCreateSheet,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: Text('Create Coupon', style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Coupon Card
// ---------------------------------------------------------------------------

class _CouponCard extends StatelessWidget {
  final Map<String, dynamic> coupon;
  final VoidCallback onDelete;
  final VoidCallback onCopy;

  const _CouponCard({
    required this.coupon,
    required this.onDelete,
    required this.onCopy,
  });

  String _fmt(num v) {
    final int val = v.round();
    if (val == 0) return '0';
    final str = val.toString();
    if (str.length <= 3) return str;
    var lastThree = str.substring(str.length - 3);
    var remaining = str.substring(0, str.length - 3);
    lastThree = remaining.isEmpty ? lastThree : ',$lastThree';
    final result = StringBuffer();
    for (int i = 0; i < remaining.length; i++) {
      if (i != 0 && (remaining.length - i) % 2 == 0) result.write(',');
      result.write(remaining[i]);
    }
    return '${result.toString()}$lastThree';
  }

  @override
  Widget build(BuildContext context) {
    final List overrides = coupon['overrides'] ?? [];
    final code = coupon['code'] ?? '';
    final expiresAt = coupon['expiresAt'];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.lightBorderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header stripe
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.primaryColor.withValues(alpha: 0.08),
                  AppTheme.primaryColor.withValues(alpha: 0.03),
                ],
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Icon(Icons.price_change_rounded,
                    size: 16, color: AppTheme.primaryColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Multi-Product Coupon',
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${overrides.length} Items',
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Body
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ...overrides.map((ov) {
                  final original = (ov['originalPrice'] ?? 0) as num;
                  final override = (ov['overridePrice'] ?? 0) as num;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(ov['productTitle'] ?? 'Product', style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 13)),
                              Text(ov['variantSize'] ?? '', style: GoogleFonts.outfit(fontSize: 11, color: AppTheme.textSecondary)),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('₹${_fmt(original)}', style: GoogleFonts.outfit(fontSize: 11, decoration: TextDecoration.lineThrough, color: AppTheme.textSecondary)),
                            Text('₹${_fmt(override)}', style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
                          ],
                        ),
                      ],
                    ),
                  );
                }),
                const Divider(height: 24),
                // Coupon code row + actions
                Row(
                  children: [
                    // Code pill
                    Expanded(
                      child: GestureDetector(
                        onTap: onCopy,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF3F4F6),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: AppTheme.lightBorderColor),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.local_offer_rounded,
                                  size: 14,
                                  color: AppTheme.primaryColor),
                              const SizedBox(width: 6),
                              Text(
                                code,
                                style: GoogleFonts.sourceCodePro(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  letterSpacing: 1.2,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              const Spacer(),
                              Icon(Icons.copy_rounded,
                                  size: 14,
                                  color: AppTheme.textSecondary),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Delete button
                    GestureDetector(
                      onTap: onDelete,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Icon(
                          Icons.delete_outline_rounded,
                          size: 18,
                          color: Colors.red.shade600,
                        ),
                      ),
                    ),
                  ],
                ),
                if (expiresAt != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.schedule_rounded,
                          size: 12, color: AppTheme.textSecondary),
                      const SizedBox(width: 4),
                      Text(
                        'Expires: ${_formatDate(expiresAt.toString())}',
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String iso) {
    try {
      final d = DateTime.parse(iso).toLocal();
      return '${d.day}/${d.month}/${d.year}';
    } catch (_) {
      return iso;
    }
  }
}

class _PriceChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final bool strikethrough;
  final bool highlight;

  const _PriceChip({
    required this.label,
    required this.value,
    required this.color,
    this.strikethrough = false,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 10,
            color: AppTheme.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: GoogleFonts.outfit(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: color,
            decoration:
                strikethrough ? TextDecoration.lineThrough : null,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Create Coupon Bottom Sheet
// ---------------------------------------------------------------------------

class _CreateCouponSheet extends StatefulWidget {
  final VoidCallback onCreated;

  const _CreateCouponSheet({required this.onCreated});

  @override
  State<_CreateCouponSheet> createState() => _CreateCouponSheetState();
}

class _CreateCouponSheetState extends State<_CreateCouponSheet> {
  // Step 1: product search
  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _filtered = [];
  bool _loadingProducts = true;
  final TextEditingController _searchCtrl = TextEditingController();

  // Step 2: selected state (single item entry)
  Map<String, dynamic>? _selectedProduct;
  Map<String, dynamic>? _selectedVariant;
  final TextEditingController _priceCtrl = TextEditingController();
  
  // Final Collection
  final List<Map<String, dynamic>> _draftOverrides = [];
  DateTime? _expiresAt;

  bool _isSubmitting = false;
  String? _errorMsg;

  // 0 = product search, 1 = variant + price form, 2 = review list
  int _step = 0;

  @override
  void initState() {
    super.initState();
    _loadProducts();
    _searchCtrl.addListener(() {
      final q = _searchCtrl.text.toLowerCase();
      setState(() {
        _filtered = q.isEmpty
            ? _products
            : _products.where((p) {
                final title = (p['title'] ?? p['name'] ?? '').toString().toLowerCase();
                final vendor = (p['vendor'] ?? '').toString().toLowerCase();
                return title.contains(q) || vendor.contains(q);
              }).toList();
      });
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    try {
      final res = await ApiClient().get('/products?limit=1000');
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['success'] == true) {
          final List raw = data['products'] ?? [];
          final products = raw
              .map((p) => Map<String, dynamic>.from(p as Map))
              .where((p) => (p['variants'] as List?)?.isNotEmpty == true)
              .toList();
          if (mounted) {
            setState(() {
              _products = products;
              _filtered = products;
            });
          }
        }
      }
    } catch (_) {} finally {
      if (mounted) setState(() => _loadingProducts = false);
    }
  }

  void _addOverrideToDraft() {
    if (_selectedProduct == null || _selectedVariant == null) return;
    final overridePrice = double.tryParse(_priceCtrl.text.trim());
    if (overridePrice == null || overridePrice < 0) {
      setState(() => _errorMsg = 'Enter valid price');
      return;
    }

    setState(() {
      _draftOverrides.add({
        'productId': _selectedProduct!['_id'],
        'variantId': _selectedVariant!['_id'],
        'productTitle': _selectedProduct!['title'] ?? _selectedProduct!['name'],
        'variantSize': _selectedVariant!['size'] ?? '',
        'originalPrice': ((_selectedVariant!['price'] ?? 0) as num).toDouble(),
        'overridePrice': overridePrice,
      });
      // Reset for next
      _selectedProduct = null;
      _selectedVariant = null;
      _priceCtrl.clear();
      _step = 2; // Go to review list
    });
  }

  Future<void> _submit() async {
    if (_draftOverrides.isEmpty) {
      setState(() => _errorMsg = 'Add at least one product to the coupon');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMsg = null;
    });

    try {
      final body = {
        'overrides': _draftOverrides,
        if (_expiresAt != null) 'expiresAt': _expiresAt!.toIso8601String(),
      };

      debugPrint('Creating sales coupon with body: ${jsonEncode(body)}');
      final res = await ApiClient().post('/sales-coupons/', body); // Added trailing slash
      debugPrint('Sales coupon response: ${res.statusCode} - ${res.body}');
      
      final data = jsonDecode(res.body);
      
      if ((res.statusCode == 200 || res.statusCode == 201) && data['success'] == true) {
        // Track coupon created
        final couponData = data['coupon'] ?? {};
        AnalyticsService().logEvent('coupon_created', properties: {
          'couponCode': couponData['code'] ?? '',
          'overrideCount': _draftOverrides.length,
          'details': 'Created price coupon: ${couponData['code'] ?? ''}',
        });

        widget.onCreated();
        return;
      }
      
      setState(() {
        _errorMsg = data['message'] ?? 'Failed to create coupon (Server Error: ${res.statusCode})';
      });
    } catch (e) {
      debugPrint('Error creating sales coupon: $e');
      setState(() {
        _errorMsg = 'Network Error: $e';
      });
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Material(
        color: Colors.transparent,
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 4),
              width: 36, height: 4,
              decoration: BoxDecoration(color: const Color(0xFFE5E7EB), borderRadius: BorderRadius.circular(2)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  if (_step != 0)
                    GestureDetector(
                      onTap: () => setState(() => _step = _step == 1 ? 0 : 2),
                      child: const Padding(
                        padding: EdgeInsets.only(right: 12),
                        child: Icon(Icons.arrow_back_ios_new_rounded, size: 16),
                      ),
                    ),
                  Expanded(
                    child: Text(
                      _step == 0 ? 'Add Product' : (_step == 1 ? 'Set Price' : 'Review Overrides'),
                      style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                  IconButton(onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.close_rounded, size: 20)),
                ],
              ),
            ),
            if (_errorMsg != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: Colors.red.shade50,
                child: Text(_errorMsg!, style: GoogleFonts.outfit(color: Colors.red.shade700, fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            const Divider(height: 1),
            Expanded(
              child: _step == 0 
                ? _buildProductSearch() 
                : (_step == 1 ? _buildPriceForm() : _buildReviewList()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductSearch() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _searchCtrl,
            decoration: InputDecoration(
              hintText: 'Search product…',
              prefixIcon: const Icon(Icons.search_rounded, size: 18),
              filled: true, fillColor: const Color(0xFFF3F4F6),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
        ),
        Expanded(
          child: _loadingProducts
            ? const Center(child: CircularProgressIndicator())
            : ListView.builder(
                itemCount: _filtered.length,
                itemBuilder: (_, i) {
                  final p = _filtered[i];
                  return ListTile(
                    title: Text(p['title'] ?? p['name'] ?? '', style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold)),
                    subtitle: Text(p['vendor'] ?? '', style: GoogleFonts.outfit(fontSize: 11)),
                    onTap: () => setState(() { _selectedProduct = p; _step = 1; }),
                  );
                },
              ),
        ),
        if (_draftOverrides.isNotEmpty)
          Padding(
            padding: const EdgeInsets.all(16),
            child: OutlinedButton(
              onPressed: () => setState(() => _step = 2),
              child: Text('View Saved (${_draftOverrides.length})'),
            ),
          ),
      ],
    );
  }

  Widget _buildPriceForm() {
    final variants = (_selectedProduct?['variants'] as List?) ?? [];
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppTheme.primaryColor.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(10)),
            child: Row(
              children: [
                const Icon(Icons.inventory_2_outlined, size: 20, color: AppTheme.primaryColor),
                const SizedBox(width: 10),
                Expanded(child: Text(_selectedProduct?['title'] ?? '', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14))),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text('Select Variant', style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 8),
          ...variants.map((v) {
            final isSel = _selectedVariant?['_id'] == v['_id'];
            return Card(
              elevation: 0,
              color: isSel ? AppTheme.primaryColor.withValues(alpha: 0.08) : Colors.grey.shade50,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(color: isSel ? AppTheme.primaryColor : Colors.transparent),
              ),
              child: ListTile(
                title: Text(v['size'] ?? '', style: GoogleFonts.outfit(fontSize: 13, fontWeight: isSel ? FontWeight.bold : FontWeight.normal)),
                trailing: Text('₹${v['price']}', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                onTap: () => setState(() => _selectedVariant = v),
              ),
            );
          }),
          const SizedBox(height: 24),
          Text('Custom Override Price (₹)', style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 8),
          TextField(
            controller: _priceCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              hintText: 'e.g. 450',
              filled: true,
              fillColor: Colors.grey.shade50,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              prefixIcon: const Icon(Icons.currency_rupee_rounded, size: 18),
            ),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _addOverrideToDraft,
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Add to Coupon List', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewList() {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _draftOverrides.length,
            itemBuilder: (_, i) {
              final ov = _draftOverrides[i];
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                child: ListTile(
                  title: Text(ov['productTitle'], style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('${ov['variantSize']} · ₹${ov['originalPrice']} → ₹${ov['overridePrice']}'),
                  trailing: IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), onPressed: () => setState(() => _draftOverrides.removeAt(i))),
                ),
              );
            },
          ),
        ),
        const Divider(),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Expiry Picker
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now().add(const Duration(days: 7)),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (picked != null) setState(() => _expiresAt = picked);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(10)),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today_rounded, size: 16),
                      const SizedBox(width: 8),
                      Text(_expiresAt == null ? 'Optional Expiry Date' : 'Expires: ${_expiresAt!.day}/${_expiresAt!.month}/${_expiresAt!.year}'),
                      const Spacer(),
                      if (_expiresAt != null) GestureDetector(onTap: () => setState(() => _expiresAt = null), child: const Icon(Icons.close, size: 16)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextButton.icon(onPressed: () => setState(() => _step = 0), icon: const Icon(Icons.add), label: const Text('Add Another Product')),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _isSubmitting ? null : _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isSubmitting 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Generate Multi-Product Coupon', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
