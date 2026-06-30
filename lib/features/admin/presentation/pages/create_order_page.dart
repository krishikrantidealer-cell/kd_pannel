import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kd_pannel/app_theme.dart';
import 'package:kd_pannel/core/auth/auth_service.dart';
import 'package:kd_pannel/core/network/api_client.dart';
import 'package:kd_pannel/core/responsive/responsive.dart';
import 'package:kd_pannel/util/dealers.dart';
import 'package:kd_pannel/core/services/analytics_service.dart';

// ---------------------------------------------------------------------------
// Data Helpers
// ---------------------------------------------------------------------------

class _ParsedTier {
  final String id;
  final String name;
  final double? min;
  final double? max;
  final double rate;

  _ParsedTier({
    required this.id,
    required this.name,
    this.min,
    this.max,
    required this.rate,
  });
}

Map<String, double?> _parseTierRange(String name) {
  final regexParentheses = RegExp(r'\(([^)]+)\)');
  final match = regexParentheses.firstMatch(name);
  String content = '';
  if (match != null) {
    content = match.group(1)!;
  } else {
    content = name;
  }

  final clean = content.replaceAll(RegExp(r'[^0-9.\-+]'), '');

  if (clean.endsWith('+')) {
    final minStr = clean.substring(0, clean.length - 1);
    final min = double.tryParse(minStr);
    return {'min': min, 'max': null};
  } else if (clean.contains('-')) {
    final parts = clean.split('-');
    if (parts.length == 2) {
      final min = double.tryParse(parts[0]);
      final max = double.tryParse(parts[1]);
      return {'min': min, 'max': max};
    }
  }

  final numbers = RegExp(
    r'\d+(?:\.\d+)?',
  ).allMatches(clean).map((m) => double.tryParse(m.group(0) ?? '')).toList();
  if (numbers.isNotEmpty) {
    if (clean.contains('+') || numbers.length == 1) {
      return {'min': numbers.first, 'max': null};
    } else if (numbers.length >= 2) {
      return {'min': numbers[0], 'max': numbers[1]};
    }
  }

  return {'min': null, 'max': null};
}

double? _parseRateValue(String? rateStr) {
  if (rateStr == null || rateStr.isEmpty) return null;
  final clean = rateStr.split('/').first.replaceAll(RegExp(r'[^0-9.]'), '');
  return double.tryParse(clean);
}

double _getVariantPrice(Map<String, dynamic> variant, int quantity) {
  final double packVolume = ((variant['packVolume'] ?? 1) as num).toDouble();
  final double defaultPriceVal =
      ((variant['dealerPrice'] ?? variant['price'] ?? 0) as num).toDouble();
  final double fallbackPrice = variant['dealerPrice'] != null
      ? defaultPriceVal
      : defaultPriceVal * packVolume;

  final priceTiers = variant['priceTiers'] as List?;
  final rates = variant['rates'] as Map?;

  if (priceTiers == null ||
      priceTiers.isEmpty ||
      rates == null ||
      rates.isEmpty) {
    return fallbackPrice;
  }

  final double totalVolume = packVolume * quantity;

  final List<_ParsedTier> parsedTiers = [];
  for (var tier in priceTiers) {
    final tierMap = Map<String, dynamic>.from(tier as Map);
    final tierId = tierMap['id']?.toString() ?? '';
    final tierName = tierMap['name']?.toString() ?? '';

    final range = _parseTierRange(tierName);

    final parsedInt = int.tryParse(tierId);
    final dynamic rawRate =
        rates[tierId] ?? (parsedInt != null ? rates[parsedInt] : null);
    final rateStr = rawRate?.toString();
    final rateVal = _parseRateValue(rateStr);

    if (rateVal != null) {
      parsedTiers.add(
        _ParsedTier(
          id: tierId,
          name: tierName,
          min: range['min'],
          max: range['max'],
          rate: rateVal,
        ),
      );
    }
  }

  if (parsedTiers.isEmpty) {
    return fallbackPrice;
  }

  // Sort by min descending (highest volume requirement first) to match backend logic
  parsedTiers.sort((a, b) {
    final aMin = a.min ?? 0.0;
    final bMin = b.min ?? 0.0;
    return bMin.compareTo(aMin);
  });

  for (var tier in parsedTiers) {
    final min = tier.min;
    if (min != null && totalVolume >= min) {
      return tier.rate * packVolume;
    }
  }

  return fallbackPrice;
}

class _CartItem {
  final Map<String, dynamic> product;
  final Map<String, dynamic> variant;
  int quantity;
  double? priceOverride;

  _CartItem({
    required this.product,
    required this.variant,
    this.quantity = 1,
    this.priceOverride,
  });

  double get lineTotal => price * quantity;

  double get price {
    if (priceOverride != null) {
      final double packVolume = ((variant['packVolume'] ?? 1) as num).toDouble();
      return variant['dealerPrice'] != null
          ? priceOverride!
          : priceOverride! * packVolume;
    }
    return _getVariantPrice(variant, quantity);
  }
}

// ---------------------------------------------------------------------------
// Page Widget
// ---------------------------------------------------------------------------

class CreateOrderPage extends StatefulWidget {
  final Dealer dealer;

  const CreateOrderPage({super.key, required this.dealer});

  @override
  State<CreateOrderPage> createState() => _CreateOrderPageState();
}

class _CreateOrderPageState extends State<CreateOrderPage> {
  // --- State ---
  List<Map<String, dynamic>> _allProducts = [];
  List<Map<String, dynamic>> _filteredProducts = [];
  bool _isLoadingProducts = true;
  bool _isSubmitting = false;
  String _productSearch = '';

  final List<_CartItem> _cart = [];
  final Map<String, int> _selectedVariantIndex = {};

  // Shipping fields
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _villageController;
  late TextEditingController _cityController;
  late TextEditingController _stateController;
  late TextEditingController _pincodeController;
  late TextEditingController _nameController;
  late TextEditingController _phoneController;

  String _paymentMethod = 'FullPayment';
  double _advanceAmount = 0;
  late TextEditingController _paymentIdController;

  // Coupon
  Map<String, dynamic>? _appliedCoupon;
  Map<String, dynamic>? _appliedSalesCoupon;
  double _discountAmount = 0;
  String? _freeProductName;

  // Step control (1 = product selection, 2 = shipping & review)
  int _step = 1;

  // Search controller
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    final addr = widget.dealer.address;
    _villageController = TextEditingController(
      text: addr?['villageArea'] ?? '',
    );
    _cityController = TextEditingController(text: widget.dealer.city);
    _stateController = TextEditingController(text: widget.dealer.state);
    _pincodeController = TextEditingController(text: addr?['pincode'] ?? '');
    _nameController = TextEditingController(text: widget.dealer.name);
    _phoneController = TextEditingController(text: widget.dealer.phone);
    _paymentIdController = TextEditingController();

    _fetchProducts();
  }

  @override
  void dispose() {
    _villageController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _pincodeController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _paymentIdController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // API
  // ---------------------------------------------------------------------------

  Future<void> _fetchProducts() async {
    setState(() => _isLoadingProducts = true);
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
              _allProducts = products;
              _filteredProducts = products;
            });
          }
        }
      }
    } catch (e) {
      debugPrint('Error fetching products: $e');
    } finally {
      if (mounted) setState(() => _isLoadingProducts = false);
    }
  }

  void _filterProducts(String query) {
    setState(() {
      _productSearch = query;
      if (query.trim().isEmpty) {
        _filteredProducts = _allProducts;
      } else {
        _filteredProducts = _allProducts.where((p) {
          final name = (p['name'] ?? p['title'] ?? '').toString().toLowerCase();
          final vendor = (p['vendor'] ?? '').toString().toLowerCase();
          return name.contains(query.toLowerCase()) ||
              vendor.contains(query.toLowerCase());
        }).toList();
      }
    });
  }

  Future<void> _submitOrder() async {
    if (_cart.isEmpty) {
      _showSnack('Add at least one product to continue.', isError: true);
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    final double total = _cart.fold(0, (sum, c) => sum + c.lineTotal);
    final double finalTotal = (total - _discountAmount).clamp(0, double.infinity);

    // Track checkout started
    AnalyticsService().logEvent('checkout_started', properties: {
      'dealerId': widget.dealer.id,
      'dealerName': widget.dealer.name,
      'itemCount': _cart.length,
      'totalAmount': finalTotal,
      'details': 'Checkout started for dealer ${widget.dealer.name}',
    });

    try {
      final items = _cart
          .map(
            (c) => {
              'product': c.product['_id'],
              'variantId': c.variant['_id'],
              'title': c.product['title'] ?? c.product['name'] ?? '',
              'vendor': c.product['vendor'],
              'technicalName': c.product['technicalName'],
              'image': (c.product['images'] as List?)?.isNotEmpty == true
                  ? c.product['images'][0]
                  : null,
              'quantity': c.quantity,
              'price': c.price,
            },
          )
          .toList();

      final body = {
        'userId': widget.dealer.id,
        'items': items,
        'shippingAddress': {
          'name': _nameController.text.trim(),
          'phoneNumber': _phoneController.text.trim(),
          'villageArea': _villageController.text.trim(),
          'cityTehsil': _cityController.text.trim(),
          'state': _stateController.text.trim(),
          'pincode': _pincodeController.text.trim(),
        },
        'paymentMethod': _paymentMethod,
        'paymentId': _paymentIdController.text.trim(),
        'advanceAmount': _paymentMethod == 'Partial' ? _advanceAmount : finalTotal,
        'totalAmount': finalTotal,
        if (_appliedCoupon != null) 'couponCode': _appliedCoupon!['code'],
        if (_appliedSalesCoupon != null) 'salesCouponCode': _appliedSalesCoupon!['code'],
        if (_discountAmount > 0) 'discountAmount': _discountAmount,
        'orderStatus': 'Processing',
        'paymentStatus': _paymentMethod == 'FullPayment'
            ? 'Paid'
            : 'Partially Paid',
      };

      final res = await ApiClient().post('/orders/admin/create', body);
      if (res.statusCode == 200 || res.statusCode == 201) {
        final data = jsonDecode(res.body);
        if (data['success'] == true) {
          // Track payment success
          AnalyticsService().logEvent('payment_success', properties: {
            'dealerId': widget.dealer.id,
            'dealerName': widget.dealer.name,
            'amount': finalTotal,
            'paymentMethod': _paymentMethod,
            'couponUsed': _appliedCoupon != null ? _appliedCoupon!['code'] : 'None',
            'details': 'Completed payment of ₹${finalTotal} via $_paymentMethod',
          });

          _showSnack('Order created successfully!');
          if (mounted) Navigator.of(context).pop(true);
          return;
        }
        final msg = data['message'] ?? 'Order creation failed.';
        
        // Track payment failed
        AnalyticsService().logEvent('payment_failed', properties: {
          'dealerId': widget.dealer.id,
          'dealerName': widget.dealer.name,
          'amount': finalTotal,
          'reason': msg,
          'details': 'Failed payment of ₹${finalTotal}: $msg',
        });

        _showSnack(msg, isError: true);
      } else {
        final msg = 'Server error: ${res.statusCode}';
        // Track payment failed
        AnalyticsService().logEvent('payment_failed', properties: {
          'dealerId': widget.dealer.id,
          'dealerName': widget.dealer.name,
          'amount': finalTotal,
          'reason': msg,
          'details': 'Failed payment of ₹${finalTotal}: $msg',
        });

        _showSnack(
          'Server error: ${res.statusCode}. Please try again.',
          isError: true,
        );
      }
    } catch (e) {
      // Track payment failed
      AnalyticsService().logEvent('payment_failed', properties: {
        'dealerId': widget.dealer.id,
        'dealerName': widget.dealer.name,
        'amount': finalTotal,
        'reason': e.toString(),
        'details': 'Failed payment of ₹${finalTotal} with error: $e',
      });
      _showSnack('Error: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg,
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: isError ? AppTheme.error : AppTheme.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Cart Helpers
  // ---------------------------------------------------------------------------

  double? _getSalesOverride(String variantId) {
    if (_appliedSalesCoupon == null) return null;
    final List overrides = _appliedSalesCoupon!['overrides'] ?? [];
    for (var ov in overrides) {
      if (ov['variantId'] == variantId) {
        return (ov['overridePrice'] as num).toDouble();
      }
    }
    return null;
  }

  void _addToCart(Map<String, dynamic> product, Map<String, dynamic> variant) {
    final variantId = variant['_id'] ?? '';
    final idx = _cart.indexWhere(
      (c) =>
          c.product['_id'] == product['_id'] &&
          c.variant['_id'] == variantId,
    );
    setState(() {
      if (idx >= 0) {
        _cart[idx].quantity += 1;
      } else {
        _cart.add(_CartItem(
          product: product,
          variant: variant,
          priceOverride: _getSalesOverride(variantId),
        ));
      }
    });

    // Track add to cart event
    final double itemPrice = _getSalesOverride(variantId) ?? (variant['price'] as num?)?.toDouble() ?? 0.0;
    AnalyticsService().logEvent('add_to_cart', properties: {
      'productId': product['_id'] ?? '',
      'productName': product['title'] ?? product['name'] ?? '',
      'variantId': variantId,
      'dealerId': widget.dealer.id,
      'dealerName': widget.dealer.name,
      'price': itemPrice,
      'details': 'Added ${product['title'] ?? product['name'] ?? ''} to cart for dealer ${widget.dealer.name}',
    });
  }

  void _removeFromCart(int index) {
    setState(() => _cart.removeAt(index));
  }

  void _updateQty(int index, int delta) {
    setState(() {
      _cart[index].quantity = (_cart[index].quantity + delta).clamp(1, 999);
    });
  }

  double get _cartTotal => _cart.fold(0.0, (s, c) => s + c.lineTotal);

  int _qtyInCart(String productId, String variantId) {
    final item = _cart.where(
      (c) => c.product['_id'] == productId && c.variant['_id'] == variantId,
    );
    return item.isEmpty ? 0 : item.first.quantity;
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.textPrimary,
        elevation: 0,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: AppTheme.lightBorderColor),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Create Order', style: AppTheme.headingMD),
            Text(
              'For: ${widget.dealer.name}',
              style: AppTheme.bodySM.copyWith(color: AppTheme.textSecondary),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: _buildStepIndicator(),
          ),
        ],
      ),
      body: _step == 1
          ? _buildProductStep(isMobile)
          : _buildReviewStep(isMobile),
    );
  }

  Widget _buildStepIndicator() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _StepDot(
          number: 1,
          label: 'Products',
          isActive: _step == 1,
          isDone: _step > 1,
        ),
        Container(width: 24, height: 2, color: const Color(0xFFE5E7EB)),
        _StepDot(
          number: 2,
          label: 'Review',
          isActive: _step == 2,
          isDone: false,
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Step 1 – Product Selection
  // ---------------------------------------------------------------------------

  Widget _buildProductStep(bool isMobile) {
    return Column(
      children: [
        _buildDealerInfoBanner(),
        if (_cart.isNotEmpty) _buildCartSummaryBar(),
        _buildSearchBar(),
        Expanded(
          child: _isLoadingProducts
              ? const Center(
                  child: CircularProgressIndicator(
                    color: AppTheme.primaryColor,
                  ),
                )
              : _filteredProducts.isEmpty
              ? Center(
                  child: Text(
                    _productSearch.isEmpty
                        ? 'No products available'
                        : 'No products matching "$_productSearch"',
                    style: AppTheme.bodyMD.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: isMobile ? 2 : 4,
                    mainAxisExtent: isMobile ? 310 : 320,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: _filteredProducts.length,
                  itemBuilder: (context, index) {
                    return _buildProductCard(
                      _filteredProducts[index],
                      isMobile,
                    );
                  },
                ),
        ),
        _buildBottomBar(),
      ],
    );
  }

  Widget _buildCartSummaryBar() {
    final count = _cart.fold(0, (s, c) => s + c.quantity);
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(
            Icons.shopping_cart_outlined,
            color: Colors.white,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$count item${count == 1 ? '' : 's'} in cart',
              style: AppTheme.labelLG.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Text(
            '₹${_formatAmt(_cartTotal)}',
            style: AppTheme.headingSM.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDealerInfoBanner() {
    final d = widget.dealer;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderColor),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.storefront_rounded,
              color: AppTheme.primaryColor,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(d.name, style: AppTheme.headingMD),
                const SizedBox(height: 2),
                Row(
                  children: [
                    const Icon(
                      Icons.location_on_outlined,
                      size: 14,
                      color: AppTheme.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${d.city}, ${d.state}',
                      style: AppTheme.bodySM.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Icon(
                      Icons.phone_outlined,
                      size: 14,
                      color: AppTheme.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      d.phone,
                      style: AppTheme.bodySM.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (d.gstStatus.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: d.gstStatus.toLowerCase() == 'verified'
                    ? AppTheme.success.withValues(alpha: 0.1)
                    : AppTheme.warning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                d.gstStatus,
                style: AppTheme.labelSM.copyWith(
                  color: d.gstStatus.toLowerCase() == 'verified'
                      ? AppTheme.success
                      : AppTheme.warning,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.borderColor),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            const Icon(
              Icons.search_rounded,
              size: 20,
              color: AppTheme.textSecondary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _searchCtrl,
                onChanged: _filterProducts,
                textAlignVertical: TextAlignVertical.center,
                style: AppTheme.bodyMD,
                decoration: InputDecoration(
                  hintText: 'Search by product name or manufacturer...',
                  hintStyle: AppTheme.hint,
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
            if (_searchCtrl.text.isNotEmpty)
              GestureDetector(
                onTap: () {
                  _searchCtrl.clear();
                  _filterProducts('');
                },
                child: const Icon(
                  Icons.clear_rounded,
                  size: 18,
                  color: AppTheme.textSecondary,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductCard(Map<String, dynamic> product, bool isMobile) {
    final variants =
        (product['variants'] as List?)
            ?.map((v) => Map<String, dynamic>.from(v as Map))
            .toList() ??
        [];
    final productId = product['_id'] ?? '';
    final name = product['title'] ?? product['name'] ?? 'Product';
    final selectedIdx = _selectedVariantIndex[productId] ?? 0;
    final safeIdx = selectedIdx < variants.length ? selectedIdx : 0;
    final variant = variants[safeIdx];

    final variantId = variant['_id'] ?? '';
    final inCart = _qtyInCart(productId, variantId);
    final double currentPrice = _getVariantPrice(
      variant,
      inCart > 0 ? inCart : 1,
    );
    final priceStr = '₹${_formatAmt(currentPrice)}';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: inCart > 0
              ? AppTheme.primaryColor.withValues(alpha: 0.3)
              : AppTheme.borderColor,
          width: inCart > 0 ? 1.5 : 1,
        ),
        boxShadow: inCart > 0
            ? [
                BoxShadow(
                  color: AppTheme.primaryColor.withValues(alpha: 0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : AppTheme.cardShadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: AppTheme.headingSM.copyWith(
                          fontWeight: FontWeight.w800,
                          fontSize: 13.5,
                          color: AppTheme.textPrimary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        product['vendor'] ??
                            product['technicalName'] ??
                            'General',
                        style: AppTheme.bodySM.copyWith(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 11.5,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (inCart > 0) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primaryColor.withValues(alpha: 0.2),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.shopping_cart_rounded,
                          size: 10,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$inCart',
                          style: AppTheme.labelSM.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 9,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(height: 1, color: AppTheme.lightBorderColor),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Select Option:',
                        style: AppTheme.labelSM.copyWith(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (variants.length > 1)
                        Text(
                          '${variants.length} sizes',
                          style: AppTheme.bodySM.copyWith(
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Builder(
                    builder: (context) {
                      final packVolume = variant['packVolume'];
                      final basePackingUnit = (variant['basePackingUnit'] ?? '')
                          .toString()
                          .trim();
                      if (packVolume == null || basePackingUnit.isEmpty) {
                        return const SizedBox.shrink();
                      }
                      final volNum = (packVolume as num).toDouble();
                      final volStr = volNum % 1 == 0
                          ? volNum.toInt().toString()
                          : volNum.toStringAsFixed(1);
                      final unitLabel = basePackingUnit == 'pcs'
                          ? 'Pcs'
                          : basePackingUnit == 'kg'
                          ? 'Kg'
                          : 'L';
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          children: [
                            Icon(
                              Icons.inventory_2_outlined,
                              size: 10,
                              color: AppTheme.textSecondary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Base Pack: $volStr $unitLabel',
                              style: AppTheme.bodySM.copyWith(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  SizedBox(
                    height: 28,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: variants.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 6),
                      itemBuilder: (ctx, idx) {
                        final v = variants[idx];
                        final vSize = v['size'] ?? v['packSize'] ?? '';
                        final isSelected = (safeIdx == idx);
                        return GestureDetector(
                          onTap: () => setState(
                            () => _selectedVariantIndex[productId] = idx,
                          ),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppTheme.primaryColor.withValues(
                                      alpha: 0.08,
                                    )
                                  : const Color(0xFFF3F4F6),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isSelected
                                    ? AppTheme.primaryColor
                                    : Colors.transparent,
                                width: 1,
                              ),
                            ),
                            child: Text(
                              vSize.toString(),
                              style: AppTheme.labelSM.copyWith(
                                fontSize: 10.5,
                                color: isSelected
                                    ? AppTheme.primaryColor
                                    : AppTheme.textPrimary,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.w500,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  Flexible(
                    child: Builder(
                      builder: (context) {
                        final priceTiers = variant['priceTiers'] as List?;
                        final rates = variant['rates'] as Map?;
                        if (priceTiers == null ||
                            priceTiers.isEmpty ||
                            rates == null ||
                            rates.isEmpty) {
                          return const Spacer();
                        }
                        return _buildTierMilestonesSection(
                          variant: variant,
                          priceTiers: priceTiers,
                          rates: rates,
                          inCart: inCart,
                          productId: productId,
                          variantId: variantId,
                        );
                      },
                    ),
                  ),
                  const Divider(height: 1, color: AppTheme.lightBorderColor),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Dealer Price',
                              style: AppTheme.bodySM.copyWith(
                                color: AppTheme.textPrimary,
                                fontWeight: FontWeight.bold,
                                fontSize: 10.2,
                              ),
                            ),
                            Text(
                              priceStr,
                              style: AppTheme.headingSM.copyWith(
                                color: AppTheme.primaryColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (inCart == 0)
                        _AddButton(onTap: () => _addToCart(product, variant))
                      else
                        _QtyControl(
                          qty: inCart,
                          onDecrement: () {
                            final idx = _cart.indexWhere(
                              (c) =>
                                  c.product['_id'] == productId &&
                                  c.variant['_id'] == variantId,
                            );
                            if (idx >= 0) {
                              if (_cart[idx].quantity <= 1) {
                                _removeFromCart(idx);
                              } else {
                                _updateQty(idx, -1);
                              }
                            }
                          },
                          onIncrement: () {
                            final idx = _cart.indexWhere(
                              (c) =>
                                  c.product['_id'] == productId &&
                                  c.variant['_id'] == variantId,
                            );
                            if (idx >= 0) _updateQty(idx, 1);
                          },
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

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: _cart.isEmpty ? null : () => setState(() => _step = 2),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              disabledBackgroundColor: AppTheme.borderColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _cart.isEmpty
                      ? 'Add products to continue'
                      : 'Review Order  (${_cart.fold(0, (s, c) => s + c.quantity)} items)',
                  style: AppTheme.button.copyWith(
                    fontSize: 14,
                    color: _cart.isEmpty
                        ? AppTheme.textSecondary
                        : Colors.white,
                  ),
                ),
                if (_cart.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.arrow_forward_rounded,
                    size: 18,
                    color: Colors.white,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Step 2 – Shipping & Review (Mobile view helper)
  // ---------------------------------------------------------------------------

  Widget _buildReviewStep(bool isMobile) {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionHeader(
                    Icons.shopping_bag_outlined,
                    'Order Summary',
                    '${_cart.fold(0, (s, c) => s + c.quantity)} items',
                  ),
                  const SizedBox(height: 12),
                  _buildOrderSummaryCard(),
                  const SizedBox(height: 24),
                  _buildSectionHeader(
                    Icons.location_on_outlined,
                    'Shipping Address',
                    'Pre-filled from dealer profile',
                  ),
                  const SizedBox(height: 12),
                  _buildAddressForm(isMobile),
                  const SizedBox(height: 24),
                  _buildSectionHeader(
                    Icons.payments_outlined,
                    'Payment Method',
                    null,
                  ),
                  const SizedBox(height: 12),
                  _buildPaymentSection(),
                  const SizedBox(height: 24),
                  _buildSectionHeader(
                    Icons.local_offer_outlined,
                    'Coupon / Offer',
                    _appliedCoupon == null ? 'Save more with a coupon' : null,
                  ),
                  const SizedBox(height: 12),
                  _buildCouponRow(),
                  const SizedBox(height: 24),
                  _buildPriceBreakdown(),
                ],
              ),
            ),
          ),
          _buildReviewBottomBar(),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(IconData icon, String title, String? subtitle) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: AppTheme.primaryColor),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: AppTheme.headingSM.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: 14.5,
              ),
            ),
            if (subtitle != null)
              Text(
                subtitle,
                style: AppTheme.bodySM.copyWith(
                  fontSize: 11,
                  color: AppTheme.textSecondary,
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildOrderSummaryCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        children: [
          ..._cart.asMap().entries.map((entry) {
            final idx = entry.key;
            final item = entry.value;
            final size = item.variant['size'] ?? item.variant['packSize'] ?? '';
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                border: Border(
                  bottom: idx < _cart.length - 1
                      ? const BorderSide(color: AppTheme.lightBorderColor)
                      : BorderSide.none,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.product['title'] ?? item.product['name'] ?? '',
                          style: AppTheme.bodyLG.copyWith(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        if (size.toString().isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            size.toString(),
                            style: AppTheme.bodySM.copyWith(
                              fontSize: 11,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '₹${_formatAmt(item.price)} × ${item.quantity}',
                        style: AppTheme.bodySM.copyWith(
                          fontSize: 11.5,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      Text(
                        '₹${_formatAmt(item.lineTotal)}',
                        style: AppTheme.headingSM.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: () => _removeFromCart(idx),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppTheme.error.withValues(alpha: 0.05),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close_rounded,
                        size: 14,
                        color: AppTheme.error,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildAddressForm(bool isMobile) {
    Widget field(
      String label,
      TextEditingController ctrl, {
      String? hint,
      bool required = true,
      TextInputType? keyboardType,
    }) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTheme.labelMD.copyWith(color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: ctrl,
            keyboardType: keyboardType,
            style: AppTheme.bodyMD,
            validator: required
                ? (v) => v == null || v.trim().isEmpty ? 'Required' : null
                : null,
            decoration: InputDecoration(
              hintText: hint ?? label,
              hintStyle: AppTheme.hint.copyWith(
                color: AppTheme.textSecondary.withValues(alpha: 0.6),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
              filled: true,
              fillColor: AppTheme.backgroundColor,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppTheme.borderColor),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppTheme.borderColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(
                  color: AppTheme.primaryColor,
                  width: 1.5,
                ),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppTheme.error),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppTheme.error, width: 1.5),
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        field('Recipient Name', _nameController),
        const SizedBox(height: 12),
        field(
          'Phone Number',
          _phoneController,
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: 12),
        field('Village / Area', _villageController, required: false),
        const SizedBox(height: 12),
        isMobile
            ? Column(
                children: [
                  field('City / Tehsil', _cityController),
                  const SizedBox(height: 12),
                  field('State', _stateController),
                ],
              )
            : Row(
                children: [
                  Expanded(child: field('City / Tehsil', _cityController)),
                  const SizedBox(width: 12),
                  Expanded(child: field('State', _stateController)),
                ],
              ),
        const SizedBox(height: 12),
        field(
          'Pincode',
          _pincodeController,
          keyboardType: TextInputType.number,
        ),
      ],
    );
  }

  Widget _buildPaymentSection() {
    final inputDecoration = InputDecoration(
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      filled: true,
      fillColor: AppTheme.backgroundColor,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppTheme.borderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppTheme.borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppTheme.primaryColor, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppTheme.error, width: 1.2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppTheme.error, width: 1.5),
      ),
    );

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Payment Type Options ──
          _PaymentOption(
            label: 'Full Payment',
            subtitle: 'Complete amount paid upfront',
            icon: Icons.check_circle_outline_rounded,
            isSelected: _paymentMethod == 'FullPayment',
            onTap: () => setState(() {
              _paymentMethod = 'FullPayment';
              _advanceAmount = 0;
            }),
          ),
          const Divider(height: 1, color: AppTheme.lightBorderColor),
          _PaymentOption(
            label: 'Partial Payment',
            subtitle: 'Advance now, balance later',
            icon: Icons.account_balance_wallet_outlined,
            isSelected: _paymentMethod == 'Partial',
            onTap: () => setState(() => _paymentMethod = 'Partial'),
          ),

          const Divider(height: 1, color: AppTheme.lightBorderColor),

          // ── Shared fields panel ──
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Payment ID — always required
                Row(
                  children: [
                    const Icon(
                      Icons.receipt_long_outlined,
                      size: 14,
                      color: AppTheme.primaryColor,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Payment ID',
                      style: AppTheme.labelMD.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '(Required)',
                      style: AppTheme.bodySM.copyWith(
                        fontSize: 10.5,
                        color: AppTheme.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _paymentIdController,
                  style: AppTheme.bodyMD.copyWith(fontWeight: FontWeight.w600),
                  decoration: inputDecoration.copyWith(
                    hintText: 'Enter transaction / reference ID',
                    prefixIcon: const Icon(
                      Icons.tag_rounded,
                      size: 18,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Payment ID is required to place the order';
                    }
                    return null;
                  },
                ),

                // Advance Amount — only for Partial
                if (_paymentMethod == 'Partial') ...[
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      const Icon(
                        Icons.currency_rupee_rounded,
                        size: 14,
                        color: AppTheme.primaryColor,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Advance Amount',
                        style: AppTheme.labelMD.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    initialValue: _advanceAmount > 0
                        ? _advanceAmount.toStringAsFixed(0)
                        : '',
                    keyboardType: TextInputType.number,
                    style: AppTheme.bodyMD.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    onChanged: (v) => setState(
                      () => _advanceAmount = double.tryParse(v) ?? 0,
                    ),
                    validator: (v) {
                      if (_paymentMethod != 'Partial') return null;
                      final val = double.tryParse(v ?? '') ?? 0;
                      if (val <= 0) return 'Enter a valid advance amount';
                      if (val >= _cartTotal) return 'Must be less than total';
                      return null;
                    },
                    decoration: inputDecoration.copyWith(
                      hintText: 'e.g. 5000',
                      prefixIcon: const Icon(
                        Icons.currency_rupee_rounded,
                        size: 18,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriceBreakdown() {
    final subtotal = _cartTotal;
    final finalTotal = (subtotal - _discountAmount).clamp(0.0, double.infinity);
    final remaining = finalTotal - _advanceAmount;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        children: [
          _PriceRow('Subtotal', '₹${_formatAmt(subtotal)}'),
          if (_discountAmount > 0) ...[
            const SizedBox(height: 6),
            _PriceRow(
              'Coupon (${_appliedCoupon!['code']})',
              '- ₹${_formatAmt(_discountAmount)}',
              color: AppTheme.success,
            ),
          ],
          if (_freeProductName != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.card_giftcard_rounded,
                    size: 13, color: AppTheme.success),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'Free: $_freeProductName',
                    style: AppTheme.bodySM.copyWith(
                      color: AppTheme.success,
                      fontWeight: FontWeight.w700,
                      fontSize: 11.5,
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (_paymentMethod == 'Partial' && _advanceAmount > 0) ...[
            const SizedBox(height: 6),
            _PriceRow(
              'Advance Collected',
              '- ₹${_formatAmt(_advanceAmount)}',
              color: AppTheme.success,
            ),
            const SizedBox(height: 6),
            _PriceRow(
              'Remaining (Balance)',
              '₹${_formatAmt(remaining)}',
              color: AppTheme.warning,
            ),
          ],
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(color: AppTheme.lightBorderColor),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total Amount',
                style: AppTheme.headingSM.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 14.5,
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (_discountAmount > 0)
                    Text(
                      '₹${_formatAmt(subtotal)}',
                      style: AppTheme.bodySM.copyWith(
                        color: AppTheme.textSecondary,
                        fontSize: 11,
                        decoration: TextDecoration.lineThrough,
                      ),
                    ),
                  Text(
                    '₹${_formatAmt(finalTotal)}',
                    style: AppTheme.headingLG.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Coupon Row + Sheet
  // ---------------------------------------------------------------------------

  Widget _buildCouponRow() {
    final isApplied = _appliedCoupon != null;
    final isSalesApplied = _appliedSalesCoupon != null;

    if (!isApplied && !isSalesApplied) {
      return GestureDetector(
        onTap: () => _showCouponSheet(),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.borderColor),
            boxShadow: AppTheme.cardShadow,
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.local_offer_rounded,
                  size: 17,
                  color: AppTheme.primaryColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Apply Coupon / Price Override',
                  style: AppTheme.bodyMD.copyWith(
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppTheme.textSecondary,
                size: 20,
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        if (isSalesApplied)
          _buildCouponPill(
            code: _appliedSalesCoupon!['code'],
            label: 'Price Overrides Applied (${(_appliedSalesCoupon!['overrides'] as List).length} products)',
            isSales: true,
            onRemove: () => setState(() {
              final List overrides = _appliedSalesCoupon!['overrides'] ?? [];
              for (var ov in overrides) {
                final variantId = ov['variantId'];
                for (var item in _cart) {
                  if (item.variant['_id'] == variantId) {
                    item.priceOverride = null;
                  }
                }
              }
              _appliedSalesCoupon = null;
            }),
          ),
        if (isSalesApplied && isApplied) const SizedBox(height: 8),
        if (isApplied)
          _buildCouponPill(
            code: _appliedCoupon!['code'],
            label: 'Saving ₹${_formatAmt(_discountAmount)}',
            isSales: false,
            onRemove: () => setState(() {
              _appliedCoupon = null;
              _discountAmount = 0;
              _freeProductName = null;
            }),
          ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () => _showCouponSheet(),
          child: Text(
            '+ Add Another Coupon',
            style: GoogleFonts.outfit(
              fontSize: 12,
              color: AppTheme.primaryColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCouponPill({
    required String code,
    required String label,
    required bool isSales,
    required VoidCallback onRemove,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: (isSales ? Colors.blue : AppTheme.success).withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSales ? Colors.blue : AppTheme.success,
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isSales ? Icons.price_change_rounded : Icons.check_circle_rounded,
            size: 17,
            color: isSales ? Colors.blue : AppTheme.success,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  code,
                  style: AppTheme.bodyMD.copyWith(
                    fontWeight: FontWeight.w800,
                    color: isSales ? Colors.blue : AppTheme.success,
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  label,
                  style: AppTheme.bodySM.copyWith(
                    fontSize: 11,
                    color: isSales ? Colors.blue : AppTheme.success,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: onRemove,
            child: const Icon(
              Icons.close_rounded,
              size: 16,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showCouponSheet() async {
    final subtotal = _cartTotal;
    final isAdminOrSales = AuthService().isAdmin || AuthService().isSales;

    // Fetch standard coupons
    List<Map<String, dynamic>> standardCoupons = [];
    bool isLoadingStandard = true;
    String standardError = '';

    // Sheet state variables (declared outside builder to persist across setSheetState calls)
    final codeCtrl = TextEditingController();
    final salesCodeCtrl = TextEditingController();
    String standardApplyError = '';
    String salesApplyError = '';
    bool isApplyingSales = false;
    Map<String, dynamic>? validatedSalesCoupon;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return DefaultTabController(
          length: isAdminOrSales ? 2 : 1,
          child: StatefulBuilder(
            builder: (ctx, setSheetState) {

              // Fetch on first build
              if (isLoadingStandard) {
                ApiClient().get('/coupons/active').then((res) {
                  if (res.statusCode == 200) {
                    final data = jsonDecode(res.body);
                    if (data['success'] == true) {
                      final list = data['coupons'] as List? ?? [];
                      setSheetState(() {
                        standardCoupons = list
                            .map((c) => Map<String, dynamic>.from(c as Map))
                            .where((c) => c['isActive'] == true)
                            .toList();
                        isLoadingStandard = false;
                      });
                      return;
                    }
                  }
                  setSheetState(() {
                    isLoadingStandard = false;
                    standardError = 'Could not load coupons';
                  });
                }).catchError((_) {
                  setSheetState(() {
                    isLoadingStandard = false;
                    standardError = 'Network error';
                  });
                });
              }

              void applyStandardCoupon(Map<String, dynamic> coupon) {
                final minPurchase =
                    ((coupon['minimumPurchaseAmount'] ?? 0) as num).toDouble();
                if (subtotal < minPurchase) {
                  setSheetState(() => standardApplyError =
                      'Min. order ₹${_formatAmt(minPurchase)} required');
                  return;
                }

                final discountType = coupon['discountType'] ?? '';
                final discountValue =
                    ((coupon['discountValue'] ?? 0) as num).toDouble();
                double discount = 0;
                String? freeProduct;

                if (discountType == 'Percentage') {
                  discount = (subtotal * discountValue / 100).clamp(0, subtotal);
                  final maxDiscount =
                      ((coupon['maxDiscount'] ?? 0) as num).toDouble();
                  if (maxDiscount > 0 && discount > maxDiscount) {
                    discount = maxDiscount;
                  }
                } else if (discountType == 'Absolute') {
                  discount = discountValue.clamp(0, subtotal);
                } else if (discountType == 'FreeProduct') {
                  freeProduct = coupon['freeProductName'] as String?;
                }

                setState(() {
                  _appliedCoupon = coupon;
                  _discountAmount = discount;
                  _freeProductName = freeProduct;
                });

                // Track coupon application
                AnalyticsService().logEvent('apply_coupon', properties: {
                  'couponCode': coupon['code'],
                  'discountType': coupon['discountType'],
                  'discountValue': coupon['discountValue'],
                  'dealerId': widget.dealer.id,
                  'dealerName': widget.dealer.name,
                  'details': 'Coupon ${coupon['code']} applied successfully for dealer ${widget.dealer.name}',
                });

                Navigator.of(ctx).pop();
              }

              void applyStandardByCode() {
                final code = codeCtrl.text.trim().toUpperCase();
                if (code.isEmpty) return;
                final match = standardCoupons.firstWhere(
                  (c) => (c['code'] ?? '').toString().toUpperCase() == code,
                  orElse: () => {},
                );
                if (match.isEmpty) {
                  setSheetState(() => standardApplyError = 'Invalid or expired coupon code');
                  return;
                }
                applyStandardCoupon(match);
              }

              Future<void> validateSalesCoupon() async {
                final code = salesCodeCtrl.text.trim().toUpperCase();
                if (code.isEmpty) return;
                setSheetState(() {
                  isApplyingSales = true;
                  salesApplyError = '';
                });
                try {
                  final res = await ApiClient()
                      .post('/sales-coupons/validate', {'code': code});
                  final data = jsonDecode(res.body);
                  if (res.statusCode == 200 && data['success'] == true) {
                    setSheetState(() {
                      validatedSalesCoupon =
                          Map<String, dynamic>.from(data['coupon']);
                    });
                    return;
                  }
                  setSheetState(
                      () => salesApplyError = data['message'] ?? 'Invalid coupon');
                } catch (e) {
                  setSheetState(() => salesApplyError = 'Error: $e');
                } finally {
                  setSheetState(() => isApplyingSales = false);
                }
              }

              void applySalesCoupon() {
                if (validatedSalesCoupon == null) return;
                setState(() {
                  _appliedSalesCoupon = validatedSalesCoupon;
                  final List overrides = validatedSalesCoupon!['overrides'] ?? [];
                  for (var ov in overrides) {
                    final variantId = ov['variantId'];
                    final price = (ov['overridePrice'] as num).toDouble();
                    for (var item in _cart) {
                      if (item.variant['_id'] == variantId) {
                        item.priceOverride = price;
                      }
                    }
                  }
                });
                Navigator.of(ctx).pop();
              }

              return Container(
                height: MediaQuery.of(ctx).size.height * 0.78,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Column(
                  children: [
                    // Handle
                    Container(
                      margin: const EdgeInsets.only(top: 10, bottom: 6),
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE5E7EB),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    // Header
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Coupons & Offers',
                                  style: AppTheme.headingSM.copyWith(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                Text(
                                  'Order total: ₹${_formatAmt(subtotal)}',
                                  style: AppTheme.bodySM.copyWith(
                                    color: AppTheme.textSecondary,
                                    fontSize: 11.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(ctx).pop(),
                            icon: const Icon(Icons.close_rounded, size: 20),
                          ),
                        ],
                      ),
                    ),
                    if (isAdminOrSales)
                      TabBar(
                        labelColor: AppTheme.primaryColor,
                        unselectedLabelColor: AppTheme.textSecondary,
                        indicatorColor: AppTheme.primaryColor,
                        labelStyle: GoogleFonts.outfit(
                            fontWeight: FontWeight.bold, fontSize: 13),
                        tabs: const [
                          Tab(text: 'Standard'),
                          Tab(text: 'Price Override'),
                        ],
                      ),
                    const Divider(height: 1, color: AppTheme.lightBorderColor),
                    Expanded(
                      child: TabBarView(
                        physics: const NeverScrollableScrollPhysics(),
                        children: [
                          // Tab 1: Standard Coupons
                          _buildStandardTab(
                            codeCtrl,
                            applyStandardByCode,
                            standardApplyError,
                            isLoadingStandard,
                            standardError,
                            standardCoupons,
                            subtotal,
                            applyStandardCoupon,
                          ),
                          // Tab 2: Price Override (if admin or sales)
                          if (isAdminOrSales)
                            _buildPriceOverrideTab(
                              salesCodeCtrl,
                              validateSalesCoupon,
                              isApplyingSales,
                              salesApplyError,
                              validatedSalesCoupon,
                              applySalesCoupon,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildStandardTab(
    TextEditingController codeCtrl,
    VoidCallback onApplyCode,
    String applyError,
    bool isLoading,
    String errorMsg,
    List<Map<String, dynamic>> coupons,
    double subtotal,
    Function(Map<String, dynamic>) onSelect,
  ) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: codeCtrl,
                      textCapitalization: TextCapitalization.characters,
                      style: AppTheme.bodyMD.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Enter coupon code',
                        hintStyle: AppTheme.hint,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        filled: true,
                        fillColor: AppTheme.backgroundColor,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: AppTheme.borderColor),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      onPressed: onApplyCode,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child: Text('Apply',
                          style: AppTheme.button
                              .copyWith(fontSize: 13, color: Colors.white)),
                    ),
                  ),
                ],
              ),
              if (applyError.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(applyError,
                      style: AppTheme.bodySM.copyWith(
                          color: AppTheme.error, fontWeight: FontWeight.w600)),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              const Expanded(child: Divider()),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text('Available Offers',
                    style: AppTheme.bodySM.copyWith(
                        fontSize: 11,
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.w600)),
              ),
              const Expanded(child: Divider()),
            ],
          ),
        ),
        Expanded(
          child: isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: AppTheme.primaryColor))
              : errorMsg.isNotEmpty
                  ? Center(child: Text(errorMsg))
                  : coupons.isEmpty
                      ? const Center(child: Text('No active coupons'))
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: coupons.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (ctx, i) {
                            final c = coupons[i];
                            final minPurchase =
                                ((c['minimumPurchaseAmount'] ?? 0) as num)
                                    .toDouble();
                            final isEligible = subtotal >= minPurchase;
                            return _buildStandardCouponItem(
                                c, isEligible, () => onSelect(c));
                          },
                        ),
        ),
      ],
    );
  }

  Widget _buildStandardCouponItem(
      Map<String, dynamic> c, bool isEligible, VoidCallback onTap) {
    final code = (c['code'] ?? '').toString();
    final discountType = (c['discountType'] ?? '').toString();
    final discountValue = ((c['discountValue'] ?? 0) as num).toDouble();
    String savingLabel = '';
    if (discountType == 'Percentage') {
      savingLabel = '${discountValue.toInt()}% off';
    } else if (discountType == 'Absolute') {
      savingLabel = '₹${_formatAmt(discountValue)} off';
    } else if (discountType == 'FreeProduct') {
      savingLabel = 'Free product gift';
    }

    return GestureDetector(
      onTap: isEligible ? onTap : null,
      child: Opacity(
        opacity: isEligible ? 1.0 : 0.5,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: isEligible ? AppTheme.primaryColor : AppTheme.borderColor),
          ),
          child: Row(
            children: [
              const Icon(Icons.local_offer_outlined,
                  size: 16, color: AppTheme.primaryColor),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(code,
                        style: AppTheme.bodyMD.copyWith(
                            fontWeight: FontWeight.w800, letterSpacing: 0.8)),
                    Text(savingLabel,
                        style: AppTheme.bodySM.copyWith(
                            color: AppTheme.primaryColor,
                            fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
              if (isEligible)
                const Icon(Icons.arrow_forward_ios_rounded,
                    size: 14, color: AppTheme.primaryColor),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPriceOverrideTab(
    TextEditingController salesCodeCtrl,
    VoidCallback onValidate,
    bool isApplying,
    String applyError,
    Map<String, dynamic>? validatedCoupon,
    VoidCallback onApply,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Enter Sales Agent Coupon Code',
            style: GoogleFonts.outfit(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: AppTheme.textPrimary),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: salesCodeCtrl,
                  textCapitalization: TextCapitalization.characters,
                  style: GoogleFonts.sourceCodePro(
                      fontWeight: FontWeight.bold, letterSpacing: 1.5),
                  decoration: InputDecoration(
                    hintText: 'e.g. SA-XXXX',
                    hintStyle: AppTheme.hint,
                    filled: true,
                    fillColor: AppTheme.backgroundColor,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: AppTheme.borderColor)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: isApplying ? null : onValidate,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: isApplying
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : Text('Validate',
                          style: AppTheme.button.copyWith(color: Colors.white)),
                ),
              ),
            ],
          ),
          if (applyError.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(applyError,
                  style: AppTheme.bodySM.copyWith(
                      color: AppTheme.error, fontWeight: FontWeight.bold)),
            ),
          const SizedBox(height: 24),
          if (validatedCoupon != null) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: AppTheme.primaryColor.withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.check_circle_rounded,
                          size: 18, color: AppTheme.primaryColor),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Coupon Validated',
                          style: GoogleFonts.outfit(
                              fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'This coupon contains ${(validatedCoupon['overrides'] as List).length} price overrides:',
                    style: GoogleFonts.outfit(
                        color: AppTheme.textSecondary, fontSize: 13),
                  ),
                  const Divider(height: 20),
                  ... (validatedCoupon['overrides'] as List).map((ov) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(ov['productTitle'] ?? 'Product', style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 12)),
                                Text(ov['variantSize'] ?? '', style: GoogleFonts.outfit(fontSize: 10, color: AppTheme.textSecondary)),
                              ],
                            ),
                          ),
                          Text('₹${_formatAmt((ov['originalPrice'] ?? 0).toDouble())}', style: GoogleFonts.outfit(fontSize: 11, decoration: TextDecoration.lineThrough, color: AppTheme.textSecondary)),
                          const SizedBox(width: 8),
                          Text('₹${_formatAmt((ov['overridePrice'] ?? 0).toDouble())}', style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: onApply,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: Text('Apply All Overrides',
                    style: AppTheme.button.copyWith(color: Colors.white)),
              ),
            ),
          ],
        ],
      ),
    );
  }


  Widget _buildReviewBottomBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Container(
              height: 48,
              width: 48,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.borderColor),
              ),
              child: IconButton(
                onPressed: () => setState(() => _step = 1),
                icon: const Icon(
                  Icons.arrow_back_rounded,
                  size: 22,
                  color: AppTheme.textSecondary,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitOrder,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          'Place Order  •  ₹${_formatAmt(_cartTotal)}',
                          style: AppTheme.button.copyWith(fontSize: 14),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Tier Milestones Section (mirrors mobile app)
  // ---------------------------------------------------------------------------

  Widget _buildTierMilestonesSection({
    required Map<String, dynamic> variant,
    required List priceTiers,
    required Map rates,
    required int inCart,
    required String productId,
    required String variantId,
  }) {
    final String baseUnit = (variant['basePackingUnit'] ?? '').toString();
    final double packVolume = ((variant['packVolume'] ?? 1) as num).toDouble();
    final double totalVolume = packVolume * inCart;

    final List<Map<String, dynamic>> validTiers = [];
    for (var tier in priceTiers) {
      final tierMap = Map<String, dynamic>.from(tier as Map);
      final tierId = tierMap['id']?.toString() ?? '';
      final tierName = tierMap['name']?.toString() ?? '';
      final range = _parseTierRange(tierName);
      final rateVal = _parseRateValue(
        rates[tierId]?.toString() ?? rates[int.tryParse(tierId)]?.toString(),
      );
      if (rateVal != null) {
        validTiers.add({
          'key': tierId,
          'label': tierName,
          'threshold': range['min'] ?? 0.0,
          'price': rateVal,
          'max': range['max'],
        });
      }
    }
    validTiers.sort(
      (a, b) => (a['threshold'] as double).compareTo(b['threshold'] as double),
    );

    if (validTiers.isEmpty) return const SizedBox.shrink();

    String activeTierId = '';
    for (var t in validTiers) {
      if (inCart > 0 && totalVolume >= (t['threshold'] as double)) {
        activeTierId = t['key'] as String;
      }
    }

    final String volUnit = baseUnit == 'pcs'
        ? ' Pcs'
        : baseUnit == 'kg'
        ? 'Kg'
        : 'L';

    // Calculate current volume string for display
    String volumeLabel = '';
    if (inCart > 0 && packVolume > 0) {
      final totalVolumeStr =
          "${totalVolume % 1 == 0 ? totalVolume.toInt() : totalVolume.toStringAsFixed(1)}$volUnit";
      volumeLabel = totalVolumeStr;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        const Divider(height: 1, color: AppTheme.lightBorderColor),
        const SizedBox(height: 6),
        Row(
          children: [
            Text(
              'Wholesale Tier Pricing',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                color: Colors.grey.shade700,
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.info_outline_rounded,
              size: 11,
              color: Colors.grey.shade500,
            ),
            const Spacer(),
            if (inCart > 0 && volumeLabel.isNotEmpty)
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: 'Vol: ',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade500,
                      ),
                    ),
                    TextSpan(
                      text: volumeLabel,
                      style: const TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF298E4D),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: validTiers.asMap().entries.map((entry) {
            final idx = entry.key;
            final t = entry.value;
            final isUnlocked =
                inCart > 0 && totalVolume >= (t['threshold'] as double);
            final isActive = isUnlocked && t['key'] == activeTierId;

            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(left: idx == 0 ? 0.0 : 6.0),
                child: _TierMilestoneCard(
                  key: ValueKey('${variantId}_${t['key']}'),
                  label: t['label'] as String,
                  threshold: t['threshold'] as double,
                  price: t['price'] as double,
                  isUnlocked: isUnlocked,
                  isActive: isActive,
                  baseUnit: baseUnit,
                  onTap: () {
                    if (isUnlocked) {
                      final unitLabel = baseUnit == 'pcs'
                          ? 'pcs'
                          : baseUnit == 'kg'
                          ? 'kg'
                          : 'lit.';
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Row(
                            children: [
                              const Icon(
                                Icons.check_circle_outline,
                                color: Colors.white,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'You have unlocked ${t['label']}! Enjoying ₹${(t['price'] as double).toStringAsFixed(0)}/$unitLabel pricing. 🎉',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          backgroundColor: const Color(0xFF298E4D),
                          behavior: SnackBarBehavior.floating,
                          duration: const Duration(seconds: 2),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      );
                    } else {
                      _showUnlockTierDialog(
                        context: context,
                        tierLabel: t['label'] as String,
                        tierKey: t['key'] as String,
                        tierPrice: t['price'] as double,
                        threshold: t['threshold'] as double,
                        variant: variant,
                        baseUnit: baseUnit,
                        packVolume: packVolume,
                        currentQty: inCart,
                        productId: productId,
                        variantId: variantId,
                      );
                    }
                  },
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.lightbulb_outline_rounded,
              size: 11,
              color: Colors.amber.shade700,
            ),
            const SizedBox(width: 4),
            Text(
              'Tap any tier to view unlock targets',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600,
                letterSpacing: -0.15,
              ),
            ),
          ],
        ),
      ],
    );
  }

  int _getRequiredQtyForTier(
    Map<String, dynamic> variant,
    String tierKey,
    double threshold,
  ) {
    final double packVolume = ((variant['packVolume'] ?? 1) as num).toDouble();
    int qty = 1;
    while (qty <= 10000) {
      final double vol = packVolume * qty;
      if (vol >= threshold) return qty;
      qty++;
    }
    return qty;
  }

  void _showUnlockTierDialog({
    required BuildContext context,
    required String tierLabel,
    required String tierKey,
    required double tierPrice,
    required double threshold,
    required Map<String, dynamic> variant,
    required String baseUnit,
    required double packVolume,
    required int currentQty,
    required String productId,
    required String variantId,
  }) {
    final int requiredQty = _getRequiredQtyForTier(variant, tierKey, threshold);
    final int diffQty = (requiredQty - currentQty).clamp(0, 9999);
    final double currentUnitPrice = _getVariantPrice(
      variant,
      currentQty > 0 ? currentQty : 1,
    );
    final double targetUnitPrice = tierPrice * packVolume;
    final double savings =
        (requiredQty * targetUnitPrice) - (requiredQty * currentUnitPrice) > 0
        ? 0
        : (requiredQty * currentUnitPrice) - (requiredQty * targetUnitPrice);
    final double currentVol = packVolume * currentQty;
    final double targetVol = packVolume * requiredQty;
    final String unitLabel = baseUnit == 'pcs'
        ? 'pcs'
        : baseUnit == 'kg'
        ? 'kg'
        : 'lit.';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: EdgeInsets.fromLTRB(
            24,
            16,
            24,
            24 + MediaQuery.of(ctx).padding.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF298E4D).withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.lock_open_rounded,
                      color: Color(0xFF298E4D),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Unlock $tierLabel Pricing!',
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Get wholesale rates on bulk volume',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // Price comparison card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFE8F5E9), Colors.white],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: const Color(0xFF298E4D).withValues(alpha: 0.15),
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Current Price',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade600,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '₹${(currentUnitPrice / packVolume).toStringAsFixed(0)} / $unitLabel',
                              style: TextStyle(
                                fontSize: 15,
                                color: Colors.grey.shade700,
                                decoration: TextDecoration.lineThrough,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const Icon(
                          Icons.arrow_forward_rounded,
                          color: Color(0xFF298E4D),
                          size: 20,
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF298E4D),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'WHOLESALE RATE',
                                style: TextStyle(
                                  fontSize: 8,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '₹${tierPrice.toStringAsFixed(0)} / $unitLabel',
                              style: const TextStyle(
                                fontSize: 20,
                                color: Color(0xFF298E4D),
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    if (savings > 0) ...[
                      const Divider(height: 24, thickness: 1),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.stars_rounded,
                            color: Colors.orange.shade700,
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Total Bulk Savings: ₹${savings.toStringAsFixed(0)}!',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.orange.shade700,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Required Volume Progression',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 10),
              // Progress bar
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LayoutBuilder(
                  builder: (_, constraints) {
                    final double fillPercent = targetVol > 0
                        ? (currentVol / targetVol).clamp(0.0, 1.0)
                        : 0.0;
                    return Stack(
                      children: [
                        Container(
                          height: 8,
                          width: constraints.maxWidth,
                          color: Colors.grey.shade100,
                        ),
                        Container(
                          height: 8,
                          width: constraints.maxWidth * fillPercent,
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Color(0xFF81C784), Color(0xFF298E4D)],
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Current: ${currentVol % 1 == 0 ? currentVol.toInt() : currentVol.toStringAsFixed(1)} $unitLabel ($currentQty packs)',
                    style: TextStyle(
                      fontSize: 10.5,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    'Target: ${threshold % 1 == 0 ? threshold.toInt() : threshold.toStringAsFixed(1)} $unitLabel ($requiredQty packs)',
                    style: const TextStyle(
                      fontSize: 10.5,
                      color: Color(0xFF298E4D),
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // Info box
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.shade200, width: 0.5),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      color: Colors.orange.shade800,
                      size: 16,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        diffQty > 0
                            ? 'Adding $diffQty more pack${diffQty == 1 ? '' : 's'} unlocks ₹${(tierPrice - currentUnitPrice / packVolume).abs().toStringAsFixed(0)} discount per $unitLabel on ALL units!'
                            : 'You already have enough packs to unlock this tier!',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.orange.shade900,
                          fontWeight: FontWeight.bold,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(
                          color: Colors.grey.shade300,
                          width: 1.5,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        'KEEP CURRENT',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                  if (diffQty > 0) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          // Set quantity to required qty
                          final cartIdx = _cart.indexWhere(
                            (c) =>
                                c.product['_id'] == productId &&
                                c.variant['_id'] == variantId,
                          );
                          setState(() {
                            if (cartIdx >= 0) {
                              _cart[cartIdx].quantity = requiredQty;
                            } else {
                              // Not in cart yet — add with the required qty
                              final product = _allProducts.firstWhere(
                                (p) => p['_id'] == productId,
                                orElse: () => {},
                              );
                              if (product.isNotEmpty) {
                                _cart.add(
                                  _CartItem(
                                    product: product,
                                    variant: variant,
                                    quantity: requiredQty,
                                  ),
                                );
                              }
                            }
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF298E4D),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          elevation: 3,
                          shadowColor: const Color(
                            0xFF298E4D,
                          ).withValues(alpha: 0.3),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          'ADD $diffQty & SAVE',
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Formatters
  // ---------------------------------------------------------------------------

  String _formatAmt(double amount) {
    final int val = amount.round();
    if (val == 0) return '0';
    final str = val.toString();
    if (str.length <= 3) return str;
    var lastThree = str.substring(str.length - 3);
    var other = str.substring(0, str.length - 3);
    if (other.isNotEmpty) {
      other = other.replaceAllMapped(
        RegExp(r'(\d)(?=(\d\d)+(?!\d))'),
        (m) => '${m[1]},',
      );
    }
    return '$other,$lastThree';
  }
}

// ---------------------------------------------------------------------------
// Sub-Widgets
// ---------------------------------------------------------------------------

class _AddButton extends StatelessWidget {
  final VoidCallback onTap;
  const _AddButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        decoration: BoxDecoration(
          color: AppTheme.primaryColor,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primaryColor.withValues(alpha: 0.2),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          'Add',
          style: AppTheme.button.copyWith(
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

class _QtyControl extends StatelessWidget {
  final int qty;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;

  const _QtyControl({
    required this.qty,
    required this.onDecrement,
    required this.onIncrement,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppTheme.primaryColor),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withValues(alpha: 0.04),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: onDecrement,
            child: Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                borderRadius: BorderRadius.horizontal(left: Radius.circular(7)),
              ),
              child: Icon(
                qty <= 1 ? Icons.delete_outline_rounded : Icons.remove_rounded,
                size: 16,
                color: qty <= 1 ? AppTheme.error : AppTheme.primaryColor,
              ),
            ),
          ),
          Container(
            width: 32,
            height: 30,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              border: Border.symmetric(
                vertical: BorderSide(color: AppTheme.primaryColor, width: 0.5),
              ),
            ),
            child: Text(
              '$qty',
              style: AppTheme.headingSM.copyWith(
                fontSize: 12.5,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
          GestureDetector(
            onTap: onIncrement,
            child: Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                borderRadius: BorderRadius.horizontal(
                  right: Radius.circular(7),
                ),
              ),
              child: const Icon(
                Icons.add_rounded,
                size: 16,
                color: AppTheme.primaryColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StepDot extends StatelessWidget {
  final int number;
  final String label;
  final bool isActive;
  final bool isDone;

  const _StepDot({
    required this.number,
    required this.label,
    required this.isActive,
    required this.isDone,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: isActive || isDone
                ? AppTheme.primaryColor
                : const Color(0xFFE5E7EB),
            shape: BoxShape.circle,
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: AppTheme.primaryColor.withValues(alpha: 0.2),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: isDone
                ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
                : Text(
                    '$number',
                    style: AppTheme.labelSM.copyWith(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isActive ? Colors.white : AppTheme.textSecondary,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: AppTheme.labelSM.copyWith(
            fontSize: 10.5,
            color: isActive ? AppTheme.primaryColor : AppTheme.textSecondary,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }
}

class _PaymentOption extends StatelessWidget {
  final String label;
  final String subtitle;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _PaymentOption({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppTheme.primaryColor.withValues(alpha: 0.1)
                    : const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                size: 20,
                color: isSelected
                    ? AppTheme.primaryColor
                    : AppTheme.textSecondary,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: AppTheme.headingSM.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: AppTheme.bodySM.copyWith(
                      fontSize: 11.5,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected
                      ? AppTheme.primaryColor
                      : const Color(0xFFD1D5DB),
                  width: 2,
                ),
                color: isSelected ? AppTheme.primaryColor : Colors.transparent,
              ),
              child: isSelected
                  ? const Center(
                      child: Icon(
                        Icons.check_rounded,
                        size: 12,
                        color: Colors.white,
                      ),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _PriceRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;

  const _PriceRow(this.label, this.value, {this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: AppTheme.bodyMD.copyWith(color: AppTheme.textSecondary),
        ),
        Text(
          value,
          style: AppTheme.headingSM.copyWith(
            color: color ?? AppTheme.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

class _ProgressiveImage extends StatefulWidget {
  final String? lowResUrl;
  final String? highResUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final double errorIconSize;

  const _ProgressiveImage({
    required this.lowResUrl,
    required this.highResUrl,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    required this.errorIconSize,
  });

  @override
  State<_ProgressiveImage> createState() => _ProgressiveImageState();
}

class _ProgressiveImageState extends State<_ProgressiveImage> {
  bool _highResLoaded = false;
  String? _loadedHighResUrl;

  @override
  void didUpdateWidget(covariant _ProgressiveImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.highResUrl != widget.highResUrl) {
      setState(() {
        _highResLoaded = false;
        _loadedHighResUrl = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final lowUrl = widget.lowResUrl;
    final highUrl = widget.highResUrl;

    if ((highUrl == null || highUrl.isEmpty) &&
        (lowUrl == null || lowUrl.isEmpty)) {
      return SizedBox(
        width: widget.width,
        height: widget.height,
        child: Center(
          child: Icon(
            Icons.inventory_2_outlined,
            size: widget.errorIconSize,
            color: AppTheme.textSecondary,
          ),
        ),
      );
    }

    // When the high-res image has loaded completely and is the target URL,
    // only show the sharp high-res image. This completely hides the blurry
    // low-res image to prevent pixel bleed-through.
    if (_highResLoaded &&
        highUrl != null &&
        highUrl.isNotEmpty &&
        _loadedHighResUrl == highUrl) {
      return SizedBox(
        width: widget.width,
        height: widget.height,
        child: Image.network(
          highUrl,
          width: widget.width,
          height: widget.height,
          fit: widget.fit,
          filterQuality: FilterQuality.medium,
          errorBuilder: (context, error, stackTrace) {
            debugPrint(
              'Failed to load high-res image: $highUrl. Error: $error',
            );
            return Icon(
              Icons.image_not_supported_outlined,
              size: widget.errorIconSize,
              color: AppTheme.textSecondary,
            );
          },
        ),
      );
    }

    final lowResWidget = lowUrl != null && lowUrl.isNotEmpty
        ? Image.network(
            lowUrl,
            width: widget.width,
            height: widget.height,
            fit: widget.fit,
            filterQuality: FilterQuality.medium,
            errorBuilder: (context, error, stackTrace) {
              debugPrint(
                'Failed to load low-res image: $lowUrl. Error: $error',
              );
              return Icon(
                Icons.image_not_supported_outlined,
                size: widget.errorIconSize,
                color: AppTheme.textSecondary,
              );
            },
          )
        : Icon(
            Icons.inventory_2_outlined,
            size: widget.errorIconSize,
            color: AppTheme.textSecondary,
          );

    if (highUrl == null || highUrl.isEmpty) {
      return SizedBox(
        width: widget.width,
        height: widget.height,
        child: lowResWidget,
      );
    }

    final highResWidget = Image.network(
      highUrl,
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      filterQuality: FilterQuality.medium,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && (!_highResLoaded || _loadedHighResUrl != highUrl)) {
              setState(() {
                _highResLoaded = true;
                _loadedHighResUrl = highUrl;
              });
            }
          });
          return child;
        }
        return const SizedBox.shrink();
      },
      errorBuilder: (context, error, stackTrace) {
        debugPrint('Failed to load high-res image: $highUrl. Error: $error');
        return const SizedBox.shrink();
      },
    );

    if (lowUrl == null || lowUrl.isEmpty) {
      return SizedBox(
        width: widget.width,
        height: widget.height,
        child: highResWidget,
      );
    }

    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: Stack(
        fit: StackFit.expand,
        children: [lowResWidget, highResWidget],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _TierMilestoneCard — Animated, matches mobile app design exactly
// ---------------------------------------------------------------------------

class _TierMilestoneCard extends StatefulWidget {
  final String label;
  final double threshold;
  final double price;
  final bool isUnlocked;
  final bool isActive;
  final String baseUnit;
  final VoidCallback? onTap;

  const _TierMilestoneCard({
    super.key,
    required this.label,
    required this.threshold,
    required this.price,
    required this.isUnlocked,
    this.isActive = false,
    required this.baseUnit,
    this.onTap,
  });

  @override
  State<_TierMilestoneCard> createState() => _TierMilestoneCardState();
}

class _TierMilestoneCardState extends State<_TierMilestoneCard>
    with TickerProviderStateMixin {
  late AnimationController _unlockController;
  late AnimationController _bounceController;
  late Animation<double> _scaleAnimation;
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();

    _unlockController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );

    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    );

    _scaleAnimation =
        TweenSequence<double>([
          TweenSequenceItem<double>(
            tween: Tween<double>(
              begin: 1.0,
              end: 1.12,
            ).chain(CurveTween(curve: Curves.easeOut)),
            weight: 40.0,
          ),
          TweenSequenceItem<double>(
            tween: Tween<double>(
              begin: 1.12,
              end: 0.96,
            ).chain(CurveTween(curve: Curves.easeInOut)),
            weight: 30.0,
          ),
          TweenSequenceItem<double>(
            tween: Tween<double>(
              begin: 0.96,
              end: 1.0,
            ).chain(CurveTween(curve: Curves.easeOut)),
            weight: 30.0,
          ),
        ]).animate(
          CurvedAnimation(parent: _bounceController, curve: Curves.easeInOut),
        );

    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );

    _shakeAnimation =
        TweenSequence<double>([
          TweenSequenceItem<double>(
            tween: Tween<double>(begin: 0.0, end: 5.0),
            weight: 15,
          ),
          TweenSequenceItem<double>(
            tween: Tween<double>(begin: 5.0, end: -5.0),
            weight: 20,
          ),
          TweenSequenceItem<double>(
            tween: Tween<double>(begin: -5.0, end: 3.0),
            weight: 15,
          ),
          TweenSequenceItem<double>(
            tween: Tween<double>(begin: 3.0, end: -3.0),
            weight: 15,
          ),
          TweenSequenceItem<double>(
            tween: Tween<double>(begin: -3.0, end: 1.0),
            weight: 15,
          ),
          TweenSequenceItem<double>(
            tween: Tween<double>(begin: 1.0, end: 0.0),
            weight: 20,
          ),
        ]).animate(
          CurvedAnimation(parent: _shakeController, curve: Curves.easeInOut),
        );

    if (widget.isUnlocked) {
      _unlockController.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(covariant _TierMilestoneCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isUnlocked && !oldWidget.isUnlocked) {
      _unlockController.forward(from: 0.0);
      _bounceController.forward(from: 0.0);
    } else if (!widget.isUnlocked && oldWidget.isUnlocked) {
      _unlockController.reverse(from: 1.0);
    } else {
      if (!_unlockController.isAnimating) {
        _unlockController.value = widget.isUnlocked ? 1.0 : 0.0;
      }
    }
  }

  @override
  void dispose() {
    _unlockController.dispose();
    _bounceController.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryGreen = Color(0xFF298E4D);
    const Color secondaryGreen = Color(0xFFE8F5E9);

    final String unitLabel = widget.baseUnit == 'pcs'
        ? 'pcs'
        : widget.baseUnit == 'kg'
        ? 'kg'
        : 'lit.';
    final formattedPrice = widget.price % 1 == 0
        ? widget.price.toStringAsFixed(0)
        : widget.price.toStringAsFixed(2);
    final String perUnitStr = '₹$formattedPrice/$unitLabel';

    return GestureDetector(
      onTap: () {
        if (!widget.isUnlocked) {
          _shakeController.forward(from: 0.0);
        }
        widget.onTap?.call();
      },
      child: AnimatedBuilder(
        animation: Listenable.merge([
          _unlockController,
          _bounceController,
          _shakeAnimation,
        ]),
        builder: (context, child) {
          final double animValue = _unlockController.value;

          final Color backgroundColor = Color.lerp(
            Colors.grey.shade100,
            secondaryGreen,
            animValue,
          )!;

          final Color borderColor = Color.lerp(
            Colors.grey.shade300,
            primaryGreen,
            animValue,
          )!;

          final Color textColor = Color.lerp(
            Colors.grey.shade700,
            primaryGreen,
            animValue,
          )!;

          final Color subtextColor = Color.lerp(
            Colors.grey.shade500,
            primaryGreen.withValues(alpha: 0.85),
            animValue,
          )!;

          final double shadowOpacity = animValue * 0.15;

          final double cardOpacity = !widget.isUnlocked
              ? 1.0
              : widget.isActive
              ? 1.0
              : 0.55;

          return Transform.translate(
            offset: Offset(_shakeAnimation.value, 0),
            child: ScaleTransition(
              scale: _scaleAnimation,
              child: Opacity(
                opacity: cardOpacity,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: backgroundColor,
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(
                      color: borderColor,
                      width: animValue > 0.5 ? 1.5 : 1.0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: primaryGreen.withValues(alpha: shadowOpacity),
                        blurRadius: 6 * animValue,
                        spreadRadius: 1 * animValue,
                        offset: Offset(0, 2 * animValue),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.max,
                    children: [
                      // Animated lock → verified icon
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          Opacity(
                            opacity: (1.0 - animValue).clamp(0.0, 1.0),
                            child: Icon(
                              Icons.lock_outline_rounded,
                              color: Colors.grey.shade500,
                              size: 12,
                            ),
                          ),
                          Opacity(
                            opacity: animValue.clamp(0.0, 1.0),
                            child: const Icon(
                              Icons.verified_rounded,
                              color: primaryGreen,
                              size: 13,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                widget.label,
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w900,
                                  color: textColor,
                                  letterSpacing: -0.2,
                                ),
                              ),
                            ),
                            const SizedBox(height: 2),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                perUnitStr,
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w800,
                                  color: subtextColor,
                                  decoration:
                                      (widget.isUnlocked && !widget.isActive)
                                      ? TextDecoration.lineThrough
                                      : TextDecoration.none,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
