import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kd_pannel/app_theme.dart';
import 'package:kd_pannel/core/auth/auth_service.dart';
import 'package:kd_pannel/core/network/api_client.dart';
import 'package:kd_pannel/core/responsive/responsive.dart';
import 'package:kd_pannel/util/dealers.dart';
import 'package:kd_pannel/core/services/analytics_service.dart';
import 'package:kd_pannel/features/admin/presentation/widgets/order/order_models.dart';
import 'package:kd_pannel/features/admin/presentation/widgets/order/order_controls.dart';
import 'package:kd_pannel/features/admin/presentation/widgets/order/tier_milestone_card.dart';
import 'package:kd_pannel/features/admin/presentation/widgets/order/unlock_tier_sheet.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kd_pannel/features/admin/presentation/bloc/orders_bloc.dart';
import 'package:kd_pannel/features/admin/presentation/bloc/orders_event.dart';
import 'package:kd_pannel/features/admin/presentation/bloc/dealers_bloc.dart';
import 'package:kd_pannel/features/admin/presentation/bloc/dealers_event.dart';
import 'package:kd_pannel/features/admin/presentation/bloc/products_bloc.dart';
import 'package:kd_pannel/core/utils/local_cache_helper.dart';
import 'package:kd_pannel/core/repositories/product_repository.dart';
import 'package:kd_pannel/core/repositories/order_repository.dart';

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

  final List<CartItem> _cart = [];
  final Map<String, int> _selectedVariantIndex = {};
  final Map<String, double> _customPackVolumes = {};
  final Map<String, String> _customBaseUnits = {};
  final Map<String, double> _customPrices = {};

  // Shipping fields
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _villageController;
  late TextEditingController _cityController;
  late TextEditingController _stateController;
  late TextEditingController _pincodeController;
  late TextEditingController _nameController;
  late TextEditingController _phoneController;

  String? _paymentMethod;
  String _paymentMode = 'UPI'; // 'UPI', 'Bank Transfer', 'Cheque', 'Cash'
  double _advanceAmount = 0;
  late TextEditingController _paymentIdController;
  late TextEditingController _advanceAmountCtrl;

  // Coupon
  Map<String, dynamic>? _appliedCoupon;
  Map<String, dynamic>? _appliedSalesCoupon;
  double _discountAmount = 0;
  String? _freeProductName;

  // Manual Discount
  String _manualDiscountType = 'None'; // 'None', 'Fixed', 'Percentage'
  final TextEditingController _manualDiscountCtrl = TextEditingController();

  // Step control (1 = product selection, 2 = shipping & review)
  int _step = 1;

  // Search controller
  final TextEditingController _searchCtrl = TextEditingController();

  // Order Placement Date & Time (Customizable for Panel Orders)
  DateTime _orderPlacementDateTime = DateTime.now();
  bool _isCustomOrderDate = false;

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
    _advanceAmountCtrl = TextEditingController(
      text: _advanceAmount > 0 ? _advanceAmount.toStringAsFixed(0) : '',
    );

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
    _advanceAmountCtrl.dispose();
    _searchCtrl.dispose();
    _manualDiscountCtrl.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // API
  // ---------------------------------------------------------------------------

  Future<void> _fetchProducts() async {
    setState(() => _isLoadingProducts = true);
    try {
      List<Map<String, dynamic>> raw = [];
      try {
        raw = await ProductRepository().getProducts(forceRefresh: false);
      } catch (e) {
        debugPrint('[CreateOrderPage] ProductRepository error: $e');
      }

      // Fallback: check ProductsBloc in memory
      if (raw.isEmpty && mounted) {
        try {
          final blocProducts = context.read<ProductsBloc>().state.allProducts;
          if (blocProducts.isNotEmpty) {
            raw = blocProducts;
          }
        } catch (_) {}
      }

      // Fallback: check LocalCacheHelper
      if (raw.isEmpty) {
        try {
          final local = await LocalCacheHelper.getCachedProducts();
          if (local != null && local.isNotEmpty) {
            raw = local;
          }
        } catch (_) {}
      }

      final List<Map<String, dynamic>> products = [];
      for (var item in raw) {
        var p = Map<String, dynamic>.from(item);
        final pId = (p['_id'] ?? p['id'] ?? '').toString();
        p['_id'] = pId;
        p['id'] = pId;
        final title = (p['title'] ?? p['name'] ?? 'Product').toString();
        p['title'] = title;
        p['name'] = title;

        final variantsRaw = p['variants'];
        List<Map<String, dynamic>> variants = [];
        if (variantsRaw is List && variantsRaw.isNotEmpty) {
          for (var v in variantsRaw) {
            if (v is Map) {
              var vMap = Map<String, dynamic>.from(v);
              final vId = (vMap['_id'] ?? vMap['id'] ?? '').toString();
              vMap['_id'] = vId;
              vMap['id'] = vId;
              variants.add(vMap);
            }
          }
        }

        // If product doesn't have an explicit variants array, synthesize standard variant
        if (variants.isEmpty) {
          variants.add({
            '_id': pId,
            'id': pId,
            'size': p['packSize'] ?? p['size'] ?? 'Standard',
            'price': (p['price'] ?? p['dealerPrice'] ?? p['mrp'] ?? 0),
            'dealerPrice': (p['dealerPrice'] ?? p['price'] ?? 0),
            'mrp': (p['mrp'] ?? p['comparePrice'] ?? p['price'] ?? 0),
            'packVolume': (p['packVolume'] ?? 1),
            'inventoryQuantity': (p['inventoryQuantity'] ?? p['stock'] ?? 0),
          });
        }
        p['variants'] = variants;

        products.add(p);
      }

      if (mounted) {
        setState(() {
          _allProducts = products;
          _filteredProducts = products;
        });
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
        final q = query.trim().toLowerCase();
        _filteredProducts = _allProducts.where((p) {
          final name = (p['name'] ?? p['title'] ?? '').toString().toLowerCase();
          final vendor = (p['vendor'] ?? '').toString().toLowerCase();
          final techName = (p['technicalName'] ?? '').toString().toLowerCase();
          final category = (p['category'] ?? p['categories'] ?? '').toString().toLowerCase();
          return name.contains(q) ||
              vendor.contains(q) ||
              techName.contains(q) ||
              category.contains(q);
        }).toList();
      }
    });
  }

  Future<void> _submitOrder() async {
    if (_isSubmitting) return;
    if (_cart.isEmpty) {
      _showSnack('Add at least one product to continue.', isError: true);
      return;
    }
    if (_paymentMethod == null) {
      _showSnack(
          'Please select a payment type (Full Payment or Partial Payment).',
          isError: true);
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    final double total = _cart.fold(0, (sum, c) => sum + c.lineTotal);
    
    // Calculate Sales Cart Discount for final payload
    double salesCartDiscount = 0;
    if (_appliedSalesCoupon != null) {
      final type = _appliedSalesCoupon!['cartDiscountType'] ?? 'None';
      final val = (_appliedSalesCoupon!['cartDiscountValue'] ?? 0) as num;
      if (type == 'Fixed') {
        salesCartDiscount = val.toDouble();
      } else if (type == 'Percentage') {
        salesCartDiscount = (total * val.toDouble()) / 100;
      }
    }

    // Calculate Manual Discount
    double manualDiscountValue = 0;
    final manualVal = double.tryParse(_manualDiscountCtrl.text.trim()) ?? 0;
    if (_manualDiscountType == 'Fixed') {
      manualDiscountValue = manualVal;
    } else if (_manualDiscountType == 'Percentage') {
      manualDiscountValue = (total * manualVal) / 100;
    }

    final double finalTotal = (total - _discountAmount - salesCartDiscount - manualDiscountValue).clamp(0, double.infinity);

    // Track checkout started
    AnalyticsService().logEvent('checkout_started', properties: {
      'dealerId': widget.dealer.id,
      'dealerName': widget.dealer.name,
      'itemCount': _cart.length,
      'totalAmount': finalTotal,
      'manualDiscount': manualDiscountValue,
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
              'variant': c.variant['size'] ?? c.variant['packSize'] ?? 'Standard',
              'packVolume': c.effectivePackVolume,
              'basePackingUnit': c.effectiveBaseUnit,
              'basePacking': '${c.effectivePackVolume % 1 == 0 ? c.effectivePackVolume.toInt() : c.effectivePackVolume} ${c.effectiveBaseUnit}'.trim(),
              'isCustomBasePack': c.isCustomBasePack,
              'isCustomPrice': c.isCustomPrice,
              'originalPrice': getVariantPrice(c.variant, c.quantity, customPackVolume: c.customPackVolume),
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
        'paymentMode': _paymentMode,
        'paymentId': _paymentIdController.text.trim(),
        'advanceAmount': _paymentMethod == 'Partial' ? _advanceAmount : finalTotal,
        'totalAmount': finalTotal,
        'discountAmount': (_discountAmount + salesCartDiscount + manualDiscountValue),
        if (_appliedCoupon != null) 'couponCode': _appliedCoupon!['code'],
        if (_appliedSalesCoupon != null) 'salesCouponCode': _appliedSalesCoupon!['code'],
        'orderStatus': 'Processing',
        'paymentStatus': _paymentMethod == 'FullPayment'
            ? 'Paid'
            : 'Partially Paid',
        'placedAt': _orderPlacementDateTime.toUtc().toIso8601String(),
        'createdAt': _orderPlacementDateTime.toUtc().toIso8601String(),
        'source': 'panel',
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
          if (mounted) {
            try {
              context.read<OrdersBloc>().add(const FetchOrdersEvent(forceRefresh: true));
              context.read<DealersBloc>().add(const FetchDealersDataEvent(forceRefresh: true));
            } catch (_) {}
            Navigator.of(context).pop(true);
          }
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

  void _openCustomBasePackingDialog({
    required String productId,
    required Map<String, dynamic> variant,
    CartItem? cartItem,
  }) {
    final variantId = variant['_id'] ?? '';
    final defaultPackVol = ((variant['packVolume'] ?? 1) as num).toDouble();
    final defaultUnit = (variant['basePackingUnit'] ?? 'L').toString().trim();

    final currentVol = cartItem != null
        ? cartItem.effectivePackVolume
        : (_customPackVolumes[variantId] ?? defaultPackVol);
    final currentUnit = cartItem != null
        ? cartItem.effectiveBaseUnit
        : (_customBaseUnits[variantId] ?? (defaultUnit.isEmpty ? 'L' : defaultUnit));

    final volCtrl = TextEditingController(
      text: currentVol % 1 == 0 ? currentVol.toInt().toString() : currentVol.toString(),
    );
    String selectedUnit = currentUnit.toLowerCase() == 'kg'
        ? 'kg'
        : (currentUnit.toLowerCase() == 'pcs' ? 'pcs' : 'L');

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              backgroundColor: Colors.white,
              child: Container(
                width: 440,
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.inventory_2_rounded,
                            color: AppTheme.primaryColor,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Custom Base Packing',
                                style: GoogleFonts.outfit(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              Text(
                                'Specific to this order • Database unmodified',
                                style: GoogleFonts.outfit(
                                  fontSize: 11,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(ctx),
                          icon: const Icon(Icons.close_rounded, size: 20, color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Divider(height: 1, color: AppTheme.lightBorderColor),
                    const SizedBox(height: 16),

                    // Variant Info Card
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppTheme.borderColor),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Variant Size: ${variant['size'] ?? variant['packSize'] ?? 'Standard'}',
                            style: GoogleFonts.outfit(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          Text(
                            'Default: ${defaultPackVol % 1 == 0 ? defaultPackVol.toInt() : defaultPackVol} $defaultUnit',
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              color: AppTheme.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Pack Volume input
                    Text(
                      'Base Pack Volume',
                      style: GoogleFonts.outfit(
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: volCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600),
                      decoration: InputDecoration(
                        hintText: 'e.g. 25, 50, 10...',
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: AppTheme.borderColor),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: AppTheme.primaryColor, width: 1.5),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Unit Selection Chips
                    Text(
                      'Base Unit',
                      style: GoogleFonts.outfit(
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: ['L', 'kg', 'pcs'].map((u) {
                        final isSelected = selectedUnit.toLowerCase() == u.toLowerCase();
                        final label = u == 'pcs' ? 'Pieces (Pcs)' : (u == 'kg' ? 'Kilograms (Kg)' : 'Liters (L)');
                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: InkWell(
                              onTap: () => setDialogState(() => selectedUnit = u),
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? AppTheme.primaryColor.withValues(alpha: 0.1)
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: isSelected ? AppTheme.primaryColor : AppTheme.borderColor,
                                    width: isSelected ? 1.5 : 1,
                                  ),
                                ),
                                child: Text(
                                  label,
                                  style: GoogleFonts.outfit(
                                    fontSize: 11,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                    color: isSelected ? AppTheme.primaryColor : AppTheme.textBody,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),

                    // Action buttons
                    Row(
                      children: [
                        TextButton(
                          onPressed: () {
                            setState(() {
                              if (cartItem != null) {
                                cartItem.customPackVolume = null;
                                cartItem.customBasePackingUnit = null;
                              } else {
                                _customPackVolumes.remove(variantId);
                                _customBaseUnits.remove(variantId);
                              }
                            });
                            Navigator.pop(ctx);
                          },
                          child: Text(
                            'Reset Default',
                            style: GoogleFonts.outfit(
                              fontSize: 13,
                              color: AppTheme.error,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const Spacer(),
                        ElevatedButton(
                          onPressed: () {
                            final parsed = double.tryParse(volCtrl.text.trim());
                            if (parsed != null && parsed > 0) {
                              setState(() {
                                if (cartItem != null) {
                                  cartItem.customPackVolume = parsed;
                                  cartItem.customBasePackingUnit = selectedUnit;
                                } else {
                                  _customPackVolumes[variantId] = parsed;
                                  _customBaseUnits[variantId] = selectedUnit;
                                  for (var item in _cart) {
                                    if (item.variant['_id'] == variantId) {
                                      item.customPackVolume = parsed;
                                      item.customBasePackingUnit = selectedUnit;
                                    }
                                  }
                                }
                              });
                              Navigator.pop(ctx);
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: Text(
                            'Apply for Order',
                            style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _openCustomPriceDialog({
    required String productId,
    required Map<String, dynamic> variant,
    CartItem? cartItem,
  }) {
    final variantId = variant['_id'] ?? '';
    final defaultPrice = getVariantPrice(
      variant,
      cartItem?.quantity ?? 1,
      customPackVolume: cartItem?.customPackVolume ?? _customPackVolumes[variantId],
    );
    final currentCustomPrice = cartItem != null
        ? cartItem.priceOverride
        : (_customPrices[variantId] ?? _getSalesOverride(variantId));

    final priceCtrl = TextEditingController(
      text: currentCustomPrice != null
          ? (currentCustomPrice % 1 == 0
              ? currentCustomPrice.toInt().toString()
              : currentCustomPrice.toString())
          : (defaultPrice % 1 == 0
              ? defaultPrice.toInt().toString()
              : defaultPrice.toString()),
    );

    final vSize = variant['size'] ?? variant['packSize'] ?? 'Standard';

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              backgroundColor: Colors.white,
              child: Container(
                width: 440,
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.currency_rupee_rounded,
                            color: Color(0xFFD97706),
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Custom Variant Price',
                                style: GoogleFonts.outfit(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              Text(
                                'Specific to this order • Database unmodified',
                                style: GoogleFonts.outfit(
                                  fontSize: 11,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(ctx),
                          icon: const Icon(Icons.close_rounded, size: 20, color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Divider(height: 1, color: AppTheme.lightBorderColor),
                    const SizedBox(height: 16),

                    // Info summary container
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppTheme.borderColor),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Variant: $vSize',
                                style: GoogleFonts.outfit(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              Text(
                                'Standard Catalog Price',
                                style: GoogleFonts.outfit(
                                  fontSize: 11,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            '₹${defaultPrice % 1 == 0 ? defaultPrice.toInt() : defaultPrice.toStringAsFixed(2)}',
                            style: GoogleFonts.outfit(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    Text(
                      'Custom Unit / Pack Price (₹)',
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),

                    TextField(
                      controller: priceCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      autofocus: true,
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.currency_rupee, size: 18, color: Color(0xFFD97706)),
                        hintText: 'Enter custom price',
                        hintStyle: GoogleFonts.outfit(color: AppTheme.textSecondary, fontSize: 14),
                        filled: true,
                        fillColor: const Color(0xFFFFFBEB),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFFF59E0B)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFFF59E0B)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFFD97706), width: 1.5),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Action buttons
                    Row(
                      children: [
                        TextButton(
                          onPressed: () {
                            setState(() {
                              if (cartItem != null) {
                                cartItem.priceOverride = null;
                              } else {
                                _customPrices.remove(variantId);
                              }
                            });
                            Navigator.pop(ctx);
                          },
                          child: Text(
                            'Reset to Default',
                            style: GoogleFonts.outfit(
                              fontSize: 13,
                              color: AppTheme.error,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const Spacer(),
                        ElevatedButton(
                          onPressed: () {
                            final parsed = double.tryParse(priceCtrl.text.trim());
                            if (parsed != null && parsed >= 0) {
                              setState(() {
                                if (cartItem != null) {
                                  cartItem.priceOverride = parsed;
                                } else {
                                  _customPrices[variantId] = parsed;
                                  for (var item in _cart) {
                                    if (item.variant['_id'] == variantId) {
                                      item.priceOverride = parsed;
                                    }
                                  }
                                }
                              });
                              Navigator.pop(ctx);
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFD97706),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: Text(
                            'Apply for Order',
                            style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _addToCart(Map<String, dynamic> product, Map<String, dynamic> variant) {
    final variantId = variant['_id'] ?? '';
    final customVol = _customPackVolumes[variantId];
    final customUnit = _customBaseUnits[variantId];
    final customPrice = _customPrices[variantId] ?? _getSalesOverride(variantId);

    final idx = _cart.indexWhere(
      (c) =>
          c.product['_id'] == product['_id'] &&
          c.variant['_id'] == variantId &&
          c.customPackVolume == customVol &&
          c.customBasePackingUnit == customUnit &&
          c.priceOverride == customPrice,
    );
    setState(() {
      if (idx >= 0) {
        _cart[idx].quantity += 1;
      } else {
        _cart.add(CartItem(
          product: product,
          variant: variant,
          priceOverride: customPrice,
          customPackVolume: customVol,
          customBasePackingUnit: customUnit,
        ));
      }
    });

    // Track add to cart event
    final double itemPrice = customPrice ?? (variant['price'] as num?)?.toDouble() ?? 0.0;
    AnalyticsService().logEvent('add_to_cart', properties: {
      'productId': product['_id'] ?? '',
      'productName': product['title'] ?? product['name'] ?? '',
      'variantId': variantId,
      'dealerId': widget.dealer.id,
      'dealerName': widget.dealer.name,
      'price': itemPrice,
      'isCustomPrice': customPrice != null,
      'details': 'Added ${product['title'] ?? product['name'] ?? ''} to cart for dealer ${widget.dealer.name}',
    });
  }

  void _removeFromCart(int index) {
    setState(() {
      _cart.removeAt(index);
      if (_cart.isEmpty && _step == 2) {
        _step = 1;
      }
    });
  }

  void _updateQty(int index, int delta) {
    setState(() {
      final newQty = _cart[index].quantity + delta;
      if (newQty <= 0) {
        _cart.removeAt(index);
        if (_cart.isEmpty && _step == 2) {
          _step = 1;
        }
      } else {
        _cart[index].quantity = newQty.clamp(1, 999);
      }
    });
  }

  double get _cartTotal => _cart.fold(0.0, (s, c) => s + c.lineTotal);

  double get _finalOrderTotal {
    final subtotal = _cartTotal;

    // Calculate Sales Cart Discount
    double salesCartDiscount = 0;
    if (_appliedSalesCoupon != null) {
      final type = _appliedSalesCoupon!['cartDiscountType'] ?? 'None';
      final val = (_appliedSalesCoupon!['cartDiscountValue'] ?? 0) as num;
      if (type == 'Fixed') {
        salesCartDiscount = val.toDouble();
      } else if (type == 'Percentage') {
        salesCartDiscount = (subtotal * val.toDouble()) / 100;
      }
    }

    // Calculate Manual Discount
    double manualDiscountValue = 0;
    final manualVal = double.tryParse(_manualDiscountCtrl.text.trim()) ?? 0;
    if (_manualDiscountType == 'Fixed') {
      manualDiscountValue = manualVal;
    } else if (_manualDiscountType == 'Percentage') {
      manualDiscountValue = (subtotal * manualVal) / 100;
    }

    return (subtotal - _discountAmount - salesCartDiscount - manualDiscountValue)
        .clamp(0.0, double.infinity);
  }

  double get _totalDiscountSavings {
    final subtotal = _cartTotal;
    final finalTotal = _finalOrderTotal;
    return (subtotal - finalTotal).clamp(0.0, double.infinity);
  }

  String _getOrderLogisticsSummary() {
    int totalItems = 0;
    double totalLiters = 0;
    double totalKgs = 0;
    double totalPcs = 0;

    for (final item in _cart) {
      totalItems += item.quantity;
      final vol = item.effectivePackVolume * item.quantity;
      final unit = item.effectiveBaseUnit.toLowerCase().trim();
      if (unit.contains('lit') || unit == 'l' || unit == 'ml') {
        if (unit == 'ml') {
          totalLiters += vol / 1000.0;
        } else {
          totalLiters += vol;
        }
      } else if (unit.contains('kg') || unit == 'gm' || unit == 'g') {
        if (unit == 'gm' || unit == 'g') {
          totalKgs += vol / 1000.0;
        } else {
          totalKgs += vol;
        }
      } else {
        totalPcs += vol;
      }
    }

    final List<String> parts = [];
    parts.add('$totalItems ${totalItems == 1 ? 'Unit' : 'Units'}');
    if (totalLiters > 0) {
      parts.add('${totalLiters % 1 == 0 ? totalLiters.toInt() : totalLiters.toStringAsFixed(1)} L');
    }
    if (totalKgs > 0) {
      parts.add('${totalKgs % 1 == 0 ? totalKgs.toInt() : totalKgs.toStringAsFixed(1)} Kg');
    }
    if (totalPcs > 0 && totalLiters == 0 && totalKgs == 0) {
      parts.add('${totalPcs % 1 == 0 ? totalPcs.toInt() : totalPcs.toStringAsFixed(0)} Pcs');
    }

    return parts.join(' • ');
  }

  void _resetShippingAddressToDealer() {
    final addr = widget.dealer.address;
    setState(() {
      _nameController.text = widget.dealer.name;
      _phoneController.text = widget.dealer.phone;
      _villageController.text = addr?['villageArea'] ?? '';
      _cityController.text = widget.dealer.city;
      _stateController.text = widget.dealer.state;
      _pincodeController.text = addr?['pincode'] ?? '';
    });
    _showSnack('Address reset to Dealer profile default.');
  }

  void _setAdvancePercentage(double percentage) {
    final finalTotal = _finalOrderTotal;
    final calculated = (finalTotal * percentage / 100).roundToDouble();
    setState(() {
      _advanceAmount = calculated;
      _advanceAmountCtrl.text =
          calculated > 0 ? calculated.toStringAsFixed(0) : '';
    });
  }

  int _qtyInCart(String productId, String variantId) {
    final items = _cart.where(
      (c) => c.product['_id'] == productId && c.variant['_id'] == variantId,
    );
    return items.fold(0, (sum, c) => sum + c.quantity);
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
        StepDot(
          number: 1,
          label: 'Products',
          isActive: _step == 1,
          isDone: _step > 1,
        ),
        Container(width: 24, height: 2, color: const Color(0xFFE5E7EB)),
        StepDot(
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
                  hintText: 'Search by product name, manufacturer, or category...',
                  hintStyle: AppTheme.hint,
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
            if (_searchCtrl.text.isNotEmpty) ...[
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
              const SizedBox(width: 8),
            ],
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppTheme.primaryColor.withValues(alpha: 0.15),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.inventory_2_outlined,
                    size: 14,
                    color: AppTheme.primaryColor,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    _isLoadingProducts
                        ? 'Loading...'
                        : (_productSearch.isEmpty
                            ? '${_allProducts.length} Products'
                            : '${_filteredProducts.length} / ${_allProducts.length} Products'),
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Tooltip(
              message: 'Refresh Catalog',
              child: InkWell(
                onTap: _isLoadingProducts ? null : _fetchProducts,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    Icons.refresh_rounded,
                    size: 18,
                    color: _isLoadingProducts
                        ? AppTheme.textSecondary.withValues(alpha: 0.4)
                        : AppTheme.textSecondary,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductCard(Map<String, dynamic> product, bool isMobile) {
    final variantsRaw = product['variants'];
    List<Map<String, dynamic>> variants = [];
    if (variantsRaw is List) {
      for (var v in variantsRaw) {
        if (v is Map) {
          variants.add(Map<String, dynamic>.from(v));
        }
      }
    }
    final productId = (product['_id'] ?? product['id'] ?? '').toString();
    if (variants.isEmpty) {
      variants.add({
        '_id': productId,
        'id': productId,
        'size': 'Standard',
        'price': 0,
        'dealerPrice': 0,
        'mrp': 0,
        'packVolume': 1,
        'inventoryQuantity': 0,
      });
    }

    final name = product['title'] ?? product['name'] ?? 'Product';
    final selectedIdx = _selectedVariantIndex[productId] ?? 0;
    final safeIdx = (selectedIdx >= 0 && selectedIdx < variants.length) ? selectedIdx : 0;
    final variant = variants[safeIdx];

    final variantId = (variant['_id'] ?? variant['id'] ?? '').toString();
    final inCart = _qtyInCart(productId, variantId);
    final customVol = _customPackVolumes[variantId];
    final customPrice = _customPrices[variantId] ?? _getSalesOverride(variantId);
    final bool isCustomPrice = customPrice != null;
    final double defaultPrice = getVariantPrice(
      variant,
      inCart > 0 ? inCart : 1,
      customPackVolume: customVol,
    );
    final double effectivePrice = customPrice ?? defaultPrice;
    final priceStr = '₹${_formatAmt(effectivePrice)}';

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
                      final customVol = _customPackVolumes[variantId];
                      final customUnit = _customBaseUnits[variantId];
                      final isCustom = customVol != null;

                      final packVolume = customVol ?? variant['packVolume'];
                      final basePackingUnit = (customUnit ?? variant['basePackingUnit'] ?? '')
                          .toString()
                          .trim();
                      if (packVolume == null || basePackingUnit.isEmpty) {
                        return const SizedBox.shrink();
                      }
                      final volNum = (packVolume as num).toDouble();
                      final volStr = volNum % 1 == 0
                          ? volNum.toInt().toString()
                          : volNum.toStringAsFixed(1);
                      final unitLabel = basePackingUnit.toLowerCase() == 'pcs'
                          ? 'Pcs'
                          : basePackingUnit.toLowerCase() == 'kg'
                          ? 'Kg'
                          : 'L';
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: InkWell(
                          onTap: () => _openCustomBasePackingDialog(
                            productId: productId,
                            variant: variant,
                          ),
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2.5,
                            ),
                            decoration: BoxDecoration(
                              color: isCustom
                                  ? const Color(0xFFFEF3C7)
                                  : AppTheme.primaryColor.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: isCustom
                                    ? const Color(0xFFF59E0B)
                                    : AppTheme.primaryColor.withValues(alpha: 0.15),
                                width: isCustom ? 1.2 : 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.inventory_2_outlined,
                                  size: 11,
                                  color: isCustom ? const Color(0xFFD97706) : AppTheme.primaryColor,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Base Pack: $volStr $unitLabel${isCustom ? ' (Custom)' : ''}',
                                  style: AppTheme.bodySM.copyWith(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    color: isCustom ? const Color(0xFFB45309) : AppTheme.textPrimary,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(
                                  Icons.edit_outlined,
                                  size: 10.5,
                                  color: isCustom ? const Color(0xFFB45309) : AppTheme.primaryColor,
                                ),
                              ],
                            ),
                          ),
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
                        final fp = v['farmerPrice'] ?? v['farmer_price'];
                        final fpNum = fp != null ? double.tryParse(fp.toString()) : null;
                        final fpLabel = (fpNum != null && fpNum > 0) ? ' • FP: ₹${fpNum % 1 == 0 ? fpNum.toInt() : fpNum.toStringAsFixed(0)}' : '';

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
                              '${vSize.toString()}$fpLabel',
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
                            Row(
                              children: [
                                Text(
                                  isCustomPrice ? 'Custom Price' : 'Dealer Price',
                                  style: AppTheme.bodySM.copyWith(
                                    color: isCustomPrice ? const Color(0xFFD97706) : AppTheme.textPrimary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 10.2,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                InkWell(
                                  onTap: () => _openCustomPriceDialog(
                                    productId: productId,
                                    variant: variant,
                                  ),
                                  borderRadius: BorderRadius.circular(4),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: isCustomPrice
                                          ? const Color(0xFFFEF3C7)
                                          : AppTheme.primaryColor.withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(
                                        color: isCustomPrice
                                            ? const Color(0xFFF59E0B)
                                            : AppTheme.primaryColor.withValues(alpha: 0.2),
                                        width: 0.8,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          isCustomPrice ? Icons.edit_rounded : Icons.add_rounded,
                                          size: 9,
                                          color: isCustomPrice ? const Color(0xFFB45309) : AppTheme.primaryColor,
                                        ),
                                        const SizedBox(width: 2),
                                        Text(
                                          isCustomPrice ? 'Custom' : 'Edit',
                                          style: GoogleFonts.outfit(
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                            color: isCustomPrice ? const Color(0xFFB45309) : AppTheme.primaryColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                Text(
                                  priceStr,
                                  style: AppTheme.headingSM.copyWith(
                                    color: isCustomPrice ? const Color(0xFFD97706) : AppTheme.primaryColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                if (isCustomPrice) ...[
                                  const SizedBox(width: 6),
                                  Text(
                                    '₹${_formatAmt(defaultPrice)}',
                                    style: GoogleFonts.outfit(
                                      fontSize: 10.5,
                                      color: AppTheme.textSecondary,
                                      decoration: TextDecoration.lineThrough,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                      if (inCart == 0)
                        AddButton(onTap: () => _addToCart(product, variant))
                      else
                        QtyControl(
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
  // Step 2 – Shipping & Review (Advanced ERP Layout)
  // ---------------------------------------------------------------------------

  Widget _buildReviewStep(bool isMobile) {
    if (_cart.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.remove_shopping_cart_outlined,
                  size: 48,
                  color: AppTheme.primaryColor,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Your Order is Empty',
                style: GoogleFonts.outfit(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Please select products from the catalog before reviewing.',
                textAlign: TextAlign.center,
                style: AppTheme.bodyMD.copyWith(color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () => setState(() => _step = 1),
                icon: const Icon(Icons.arrow_back_rounded, size: 18),
                label: const Text('Back to Product Catalog'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Form(
      key: _formKey,
      child: isMobile ? _buildMobileReviewLayout() : _buildDesktopReviewLayout(),
    );
  }

  // ---------------------------------------------------------------------------
  // Desktop 2-Column Layout
  // ---------------------------------------------------------------------------

  Widget _buildDesktopReviewLayout() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left Column (~60%)
          Expanded(
            flex: 6,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildReviewExecutiveBanner(),
                const SizedBox(height: 18),
                _buildOrderDateTimeCard(),
                const SizedBox(height: 18),
                _buildOrderSummaryCard(),
                const SizedBox(height: 18),
                _buildAddressForm(false),
                const SizedBox(height: 24),
              ],
            ),
          ),
          const SizedBox(width: 24),
          // Right Column (~40%)
          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildPaymentSection(),
                const SizedBox(height: 18),
                _buildCouponAndDiscountCard(),
                const SizedBox(height: 18),
                _buildPriceBreakdown(),
                const SizedBox(height: 18),
                _buildDesktopOrderActionPanel(),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Mobile 1-Column Layout
  // ---------------------------------------------------------------------------

  Widget _buildMobileReviewLayout() {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildReviewExecutiveBanner(),
                const SizedBox(height: 14),
                _buildOrderDateTimeCard(),
                const SizedBox(height: 14),
                _buildOrderSummaryCard(),
                const SizedBox(height: 16),
                _buildAddressForm(true),
                const SizedBox(height: 16),
                _buildPaymentSection(),
                const SizedBox(height: 16),
                _buildCouponAndDiscountCard(),
                const SizedBox(height: 16),
                _buildPriceBreakdown(),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
        _buildReviewBottomBar(),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Order Date & Time Selection (For Panel Created Orders)
  // ---------------------------------------------------------------------------

  Future<void> _selectOrderDateTime() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _orderPlacementDateTime,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppTheme.primaryColor,
              onPrimary: Colors.white,
              onSurface: AppTheme.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedDate != null && mounted) {
      final pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_orderPlacementDateTime),
        builder: (context, child) {
          return Theme(
            data: Theme.of(context).copyWith(
              colorScheme: const ColorScheme.light(
                primary: AppTheme.primaryColor,
                onPrimary: Colors.white,
                onSurface: AppTheme.textPrimary,
              ),
            ),
            child: child!,
          );
        },
      );

      if (pickedTime != null && mounted) {
        setState(() {
          _orderPlacementDateTime = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            pickedTime.hour,
            pickedTime.minute,
          );
          _isCustomOrderDate = true;
        });
      }
    }
  }

  Widget _buildOrderDateTimeCard() {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final dt = _orderPlacementDateTime;
    final hr = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    final min = dt.minute < 10 ? '0${dt.minute}' : '${dt.minute}';
    final dateStr =
        '${dt.day} ${months[dt.month - 1]} ${dt.year}, $hr:$min $ampm';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _isCustomOrderDate
              ? const Color(0xFF7E22CE).withValues(alpha: 0.5)
              : AppTheme.borderColor,
        ),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: (_isCustomOrderDate
                          ? const Color(0xFF7E22CE)
                          : AppTheme.primaryColor)
                      .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.access_time_rounded,
                  size: 18,
                  color: _isCustomOrderDate
                      ? const Color(0xFF7E22CE)
                      : AppTheme.primaryColor,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Order Placement Date & Time',
                          style: GoogleFonts.outfit(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        if (_isCustomOrderDate) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF3E8FF),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: const Color(0xFFD8B4FE),
                              ),
                            ),
                            child: Text(
                              'Custom Date',
                              style: GoogleFonts.outfit(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF7E22CE),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    Text(
                      'Record when this deal was finalized or backdate offline orders',
                      style: GoogleFonts.outfit(
                        fontSize: 11.5,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.lightBorderColor),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.event_note_rounded,
                  size: 18,
                  color: AppTheme.textSecondary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    dateStr,
                    style: GoogleFonts.outfit(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
                if (_isCustomOrderDate) ...[
                  MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _orderPlacementDateTime = DateTime.now();
                          _isCustomOrderDate = false;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppTheme.borderColor),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.refresh_rounded,
                              size: 13,
                              color: AppTheme.textSecondary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Reset (Now)',
                              style: GoogleFonts.outfit(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: _selectOrderDateTime,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: _isCustomOrderDate
                            ? const Color(0xFF7E22CE)
                            : AppTheme.primaryColor,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.edit_calendar_rounded,
                            size: 13,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            'Change Date',
                            style: GoogleFonts.outfit(
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
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
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Review Executive Dealer Banner
  // ---------------------------------------------------------------------------

  Widget _buildReviewExecutiveBanner() {
    final dealer = widget.dealer;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderColor),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF298E4D), Color(0xFF1E6B3A)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF298E4D).withValues(alpha: 0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    dealer.name.isNotEmpty ? dealer.name[0].toUpperCase() : 'D',
                    style: GoogleFonts.outfit(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            dealer.name,
                            style: GoogleFonts.outfit(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8F5E9),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                                color: const Color(0xFF298E4D).withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.verified_rounded,
                                size: 12,
                                color: Color(0xFF298E4D),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Dealer',
                                style: GoogleFonts.outfit(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF298E4D),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '📞 ${dealer.phone}  •  📍 ${dealer.city.isNotEmpty ? dealer.city : 'Location N/A'}, ${dealer.state}',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => setState(() => _step = 1),
                icon: const Icon(Icons.add_shopping_cart_rounded, size: 14),
                label: const Text('Add Items'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.primaryColor,
                  side: const BorderSide(color: AppTheme.primaryColor),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  visualDensity: VisualDensity.compact,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.backgroundColor,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.lightBorderColor),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.local_shipping_outlined,
                  size: 15,
                  color: AppTheme.primaryColor,
                ),
                const SizedBox(width: 8),
                Text(
                  'Order Metrics:',
                  style: GoogleFonts.outfit(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _getOrderLogisticsSummary(),
                    style: GoogleFonts.outfit(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primaryColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }



  // ---------------------------------------------------------------------------
  // Interactive Cart Items Review Card
  // ---------------------------------------------------------------------------

  Widget _buildOrderSummaryCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderColor),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.inventory_2_outlined,
                      size: 18,
                      color: AppTheme.primaryColor,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Order Items',
                      style: GoogleFonts.outfit(
                        fontSize: 14.5,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${_cart.fold(0, (s, c) => s + c.quantity)} units',
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ),
                  ],
                ),
                Text(
                  '${_cart.length} SKUs',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppTheme.lightBorderColor),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _cart.length,
            separatorBuilder: (_, __) =>
                const Divider(height: 1, color: AppTheme.lightBorderColor),
            itemBuilder: (context, idx) {
              final item = _cart[idx];
              final images = item.product['images'] as List?;
              final String? imageUrl =
                  images != null && images.isNotEmpty ? images[0] : null;
              final size =
                  item.variant['size'] ?? item.variant['packSize'] ?? '';
              final technicalName = item.product['technicalName'] ?? '';

              return Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Product Thumbnail
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppTheme.lightBorderColor),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: imageUrl != null && imageUrl.isNotEmpty
                          ? Image.network(
                              imageUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Center(
                                child: Icon(
                                  Icons.inventory_2_outlined,
                                  size: 22,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            )
                          : const Center(
                              child: Icon(
                                Icons.inventory_2_outlined,
                                size: 22,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                    ),
                    const SizedBox(width: 12),

                    // Title + Technical + Pack Badges
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.product['title'] ?? item.product['name'] ?? '',
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.bold,
                              fontSize: 13.5,
                              color: AppTheme.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (technicalName.toString().isNotEmpty) ...[
                            const SizedBox(height: 1),
                            Text(
                              technicalName.toString(),
                              style: GoogleFonts.outfit(
                                fontSize: 11,
                                color: AppTheme.textSecondary,
                                fontStyle: FontStyle.italic,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              if (size.toString().isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF3F4F6),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                        color: const Color(0xFFE5E7EB)),
                                  ),
                                  child: Text(
                                    size.toString(),
                                    style: GoogleFonts.outfit(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.textPrimary,
                                    ),
                                  ),
                                ),
                              InkWell(
                                onTap: () => _openCustomBasePackingDialog(
                                  productId: item.product['_id'] ?? '',
                                  variant: item.variant,
                                  cartItem: item,
                                ),
                                borderRadius: BorderRadius.circular(4),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: item.isCustomBasePack
                                        ? const Color(0xFFFEF3C7)
                                        : const Color(0xFFF9FAFB),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                      color: item.isCustomBasePack
                                          ? const Color(0xFFF59E0B)
                                          : const Color(0xFFE5E7EB),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.inventory_2_outlined,
                                        size: 10,
                                        color: item.isCustomBasePack
                                            ? const Color(0xFFD97706)
                                            : AppTheme.textSecondary,
                                      ),
                                      const SizedBox(width: 3),
                                      Text(
                                        'Pack: ${item.effectivePackVolume % 1 == 0 ? item.effectivePackVolume.toInt() : item.effectivePackVolume} ${item.effectiveBaseUnit}${item.isCustomBasePack ? '*' : ''}',
                                        style: GoogleFonts.outfit(
                                          fontSize: 10.5,
                                          fontWeight: item.isCustomBasePack
                                              ? FontWeight.bold
                                              : FontWeight.w500,
                                          color: item.isCustomBasePack
                                              ? const Color(0xFFD97706)
                                              : AppTheme.textSecondary,
                                        ),
                                      ),
                                      const SizedBox(width: 3),
                                      Icon(
                                        Icons.edit_outlined,
                                        size: 10,
                                        color: item.isCustomBasePack
                                            ? const Color(0xFFD97706)
                                            : AppTheme.textSecondary,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              InkWell(
                                onTap: () => _openCustomPriceDialog(
                                  productId: item.product['_id'] ?? '',
                                  variant: item.variant,
                                  cartItem: item,
                                ),
                                borderRadius: BorderRadius.circular(4),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: item.priceOverride != null
                                        ? const Color(0xFFFEF3C7)
                                        : const Color(0xFFF9FAFB),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                      color: item.priceOverride != null
                                          ? const Color(0xFFF59E0B)
                                          : const Color(0xFFE5E7EB),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.currency_rupee,
                                        size: 10,
                                        color: item.priceOverride != null
                                            ? const Color(0xFFD97706)
                                            : AppTheme.textSecondary,
                                      ),
                                      const SizedBox(width: 2),
                                      Text(
                                        item.priceOverride != null
                                            ? 'Rate: ₹${_formatAmt(item.price)}*'
                                            : 'Custom Rate',
                                        style: GoogleFonts.outfit(
                                          fontSize: 10.5,
                                          fontWeight: item.priceOverride != null
                                              ? FontWeight.bold
                                              : FontWeight.w500,
                                          color: item.priceOverride != null
                                              ? const Color(0xFFD97706)
                                              : AppTheme.textSecondary,
                                        ),
                                      ),
                                      const SizedBox(width: 3),
                                      Icon(
                                        Icons.edit_outlined,
                                        size: 10,
                                        color: item.priceOverride != null
                                            ? const Color(0xFFD97706)
                                            : AppTheme.textSecondary,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Inline Quantity Stepper
                    _buildInlineQtyStepper(idx, item.quantity),
                    const SizedBox(width: 14),

                    // Line Total & Unit Rate
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '₹${_formatAmt(item.lineTotal)}',
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: item.priceOverride != null
                                ? const Color(0xFFD97706)
                                : AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '₹${_formatAmt(item.price)} / unit${item.priceOverride != null ? ' (Custom)' : ''}',
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            color: item.priceOverride != null
                                ? const Color(0xFFD97706)
                                : AppTheme.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 10),

                    // Remove Button
                    IconButton(
                      onPressed: () => _removeFromCart(idx),
                      icon: const Icon(
                        Icons.delete_outline_rounded,
                        size: 18,
                        color: AppTheme.error,
                      ),
                      tooltip: 'Remove item',
                      splashRadius: 18,
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Inline Quantity Stepper
  // ---------------------------------------------------------------------------

  Widget _buildInlineQtyStepper(int index, int qty) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFD1D5DB)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: () => _updateQty(index, -1),
            borderRadius:
                const BorderRadius.horizontal(left: Radius.circular(7)),
            child: Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              child: Icon(
                qty <= 1 ? Icons.delete_outline_rounded : Icons.remove_rounded,
                size: 14,
                color: qty <= 1 ? AppTheme.error : AppTheme.textPrimary,
              ),
            ),
          ),
          Container(
            width: 32,
            height: 28,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              border: Border.symmetric(
                vertical: BorderSide(color: Color(0xFFE5E7EB)),
              ),
            ),
            child: Text(
              '$qty',
              style: GoogleFonts.outfit(
                fontSize: 12.5,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
          InkWell(
            onTap: () => _updateQty(index, 1),
            borderRadius:
                const BorderRadius.horizontal(right: Radius.circular(7)),
            child: Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              child: const Icon(
                Icons.add_rounded,
                size: 14,
                color: AppTheme.primaryColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Shipping Address Form Card
  // ---------------------------------------------------------------------------

  Widget _buildAddressForm(bool isMobile) {
    Widget field(
      String label,
      TextEditingController ctrl, {
      String? hint,
      bool required = true,
      TextInputType? keyboardType,
      IconData? prefixIcon,
    }) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                label,
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              if (required) ...[
                const SizedBox(width: 4),
                Text(
                  '*',
                  style: GoogleFonts.outfit(
                    color: AppTheme.error,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: ctrl,
            keyboardType: keyboardType,
            style: GoogleFonts.outfit(
              fontSize: 13.5,
              fontWeight: FontWeight.w500,
              color: AppTheme.textPrimary,
            ),
            validator: required
                ? (v) => v == null || v.trim().isEmpty ? 'Required' : null
                : null,
            decoration: InputDecoration(
              hintText: hint ?? label,
              hintStyle: GoogleFonts.outfit(
                fontSize: 13,
                color: AppTheme.textSecondary.withValues(alpha: 0.6),
              ),
              prefixIcon: prefixIcon != null
                  ? Icon(prefixIcon, size: 17, color: AppTheme.textSecondary)
                  : null,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 11,
              ),
              filled: true,
              fillColor: AppTheme.backgroundColor,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(9),
                borderSide: const BorderSide(color: AppTheme.borderColor),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(9),
                borderSide: const BorderSide(color: AppTheme.borderColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(9),
                borderSide: const BorderSide(
                  color: AppTheme.primaryColor,
                  width: 1.5,
                ),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(9),
                borderSide: const BorderSide(color: AppTheme.error),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(9),
                borderSide: const BorderSide(color: AppTheme.error, width: 1.5),
              ),
            ),
          ),
        ],
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderColor),
        boxShadow: AppTheme.cardShadow,
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.local_shipping_outlined,
                    size: 18,
                    color: AppTheme.primaryColor,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Shipping & Dispatch Details',
                    style: GoogleFonts.outfit(
                      fontSize: 14.5,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ],
              ),
              TextButton.icon(
                onPressed: _resetShippingAddressToDealer,
                icon: const Icon(Icons.refresh_rounded, size: 14),
                label: const Text('Reset to Profile'),
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.primaryColor,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  visualDensity: VisualDensity.compact,
                  textStyle: GoogleFonts.outfit(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          isMobile
              ? Column(
                  children: [
                    field('Recipient Name', _nameController,
                        prefixIcon: Icons.person_outline_rounded),
                    const SizedBox(height: 12),
                    field(
                      'Phone Number',
                      _phoneController,
                      keyboardType: TextInputType.phone,
                      prefixIcon: Icons.phone_outlined,
                    ),
                    const SizedBox(height: 12),
                    field('Village / Area', _villageController,
                        required: false,
                        prefixIcon: Icons.location_on_outlined),
                    const SizedBox(height: 12),
                    field('City / Tehsil', _cityController,
                        prefixIcon: Icons.location_city_outlined),
                    const SizedBox(height: 12),
                    field('State', _stateController,
                        prefixIcon: Icons.map_outlined),
                    const SizedBox(height: 12),
                    field(
                      'Pincode',
                      _pincodeController,
                      keyboardType: TextInputType.number,
                      prefixIcon: Icons.pin_drop_outlined,
                    ),
                  ],
                )
              : Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: field('Recipient Name', _nameController,
                              prefixIcon: Icons.person_outline_rounded),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: field(
                            'Phone Number',
                            _phoneController,
                            keyboardType: TextInputType.phone,
                            prefixIcon: Icons.phone_outlined,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: field(
                            'Village / Area',
                            _villageController,
                            required: false,
                            prefixIcon: Icons.location_on_outlined,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: field('City / Tehsil', _cityController,
                              prefixIcon: Icons.location_city_outlined),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: field('State', _stateController,
                              prefixIcon: Icons.map_outlined),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: field(
                            'Pincode',
                            _pincodeController,
                            keyboardType: TextInputType.number,
                            prefixIcon: Icons.pin_drop_outlined,
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
  // Payment Section
  // ---------------------------------------------------------------------------

  Widget _buildPaymentSection() {
    final finalTotal = _finalOrderTotal;
    final balanceRemaining = (finalTotal - _advanceAmount).clamp(0.0, finalTotal);

    final inputDecoration = InputDecoration(
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      filled: true,
      fillColor: AppTheme.backgroundColor,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(9),
        borderSide: const BorderSide(color: AppTheme.borderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(9),
        borderSide: const BorderSide(color: AppTheme.borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(9),
        borderSide: const BorderSide(color: AppTheme.primaryColor, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(9),
        borderSide: const BorderSide(color: AppTheme.error, width: 1.2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(9),
        borderSide: const BorderSide(color: AppTheme.error, width: 1.5),
      ),
    );

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderColor),
        boxShadow: AppTheme.cardShadow,
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.payments_outlined,
                    size: 18,
                    color: AppTheme.primaryColor,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Payment Configuration',
                    style: GoogleFonts.outfit(
                      fontSize: 14.5,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ],
              ),
              if (_paymentMethod == null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFFCD34D)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline_rounded,
                          size: 12, color: Color(0xFFD97706)),
                      const SizedBox(width: 4),
                      Text(
                        'Select Type',
                        style: GoogleFonts.outfit(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFFB45309),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),

          // Payment Type Option Tiles
          Row(
            children: [
              Expanded(
                child: _buildPaymentTypeCard(
                  title: 'Full Payment',
                  subtitle: '100% Upfront',
                  icon: Icons.check_circle_outline_rounded,
                  isSelected: _paymentMethod == 'FullPayment',
                  onTap: () => setState(() {
                    _paymentMethod = 'FullPayment';
                    _advanceAmount = 0;
                    _advanceAmountCtrl.clear();
                  }),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildPaymentTypeCard(
                  title: 'Partial Payment',
                  subtitle: 'Advance + Balance',
                  icon: Icons.account_balance_wallet_outlined,
                  isSelected: _paymentMethod == 'Partial',
                  onTap: () => setState(() {
                    _paymentMethod = 'Partial';
                    if (_advanceAmount == 0 && finalTotal > 0) {
                      _setAdvancePercentage(10);
                    }
                  }),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Payment Channel / Mode Selector Chips
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Payment Mode / Channel',
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildModeChip('UPI', Icons.qr_code_rounded),
                    const SizedBox(width: 8),
                    _buildModeChip(
                        'Bank Transfer', Icons.account_balance_rounded),
                    const SizedBox(width: 8),
                    _buildModeChip('Cheque', Icons.receipt_rounded),
                    const SizedBox(width: 8),
                    _buildModeChip('Cash', Icons.payments_rounded),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Payment ID (UTR / Reference)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    '$_paymentMode Reference / Transaction ID',
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '*',
                    style: GoogleFonts.outfit(
                      color: AppTheme.error,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _paymentIdController,
                style: GoogleFonts.outfit(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                ),
                decoration: inputDecoration.copyWith(
                  hintText: _paymentIdHint,
                  hintStyle: GoogleFonts.outfit(
                    fontSize: 13,
                    color: AppTheme.textSecondary.withValues(alpha: 0.6),
                  ),
                  prefixIcon: Icon(
                    _paymentMode == 'UPI'
                        ? Icons.qr_code_rounded
                        : _paymentMode == 'Bank Transfer'
                            ? Icons.account_balance_rounded
                            : _paymentMode == 'Cheque'
                                ? Icons.receipt_rounded
                                : Icons.tag_rounded,
                    size: 18,
                    color: AppTheme.textSecondary,
                  ),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return '$_paymentMode reference ID is required';
                  }
                  return null;
                },
              ),
            ],
          ),

          // Advance Amount configuration if Partial Payment
          if (_paymentMethod == 'Partial') ...[
            const SizedBox(height: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Advance Collected (₹)',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    Row(
                      children: [
                        _buildPresetChip('10%', () => _setAdvancePercentage(10)),
                        const SizedBox(width: 4),
                        _buildPresetChip('20%', () => _setAdvancePercentage(20)),
                        const SizedBox(width: 4),
                        _buildPresetChip('50%', () => _setAdvancePercentage(50)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _advanceAmountCtrl,
                  keyboardType: TextInputType.number,
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF298E4D),
                  ),
                  onChanged: (v) {
                    setState(() {
                      _advanceAmount = double.tryParse(v) ?? 0;
                    });
                  },
                  validator: (v) {
                    if (_paymentMethod != 'Partial') return null;
                    final val = double.tryParse(v ?? '') ?? 0;
                    if (val <= 0) return 'Enter a valid advance amount';
                    if (val >= finalTotal) return 'Must be less than order total';
                    return null;
                  },
                  decoration: inputDecoration.copyWith(
                    hintText: 'Enter advance amount',
                    prefixIcon: const Icon(
                      Icons.currency_rupee_rounded,
                      size: 17,
                      color: Color(0xFF298E4D),
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Payment Split Visualizer Bar
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.backgroundColor,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.lightBorderColor),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF298E4D),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Advance: ₹${_formatAmt(_advanceAmount)}',
                                style: GoogleFonts.outfit(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF298E4D),
                                ),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: Color(0xFFD97706),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Due: ₹${_formatAmt(balanceRemaining)}',
                                style: GoogleFonts.outfit(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFFD97706),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: SizedBox(
                          height: 6,
                          child: LinearProgressIndicator(
                            value: finalTotal > 0
                                ? (_advanceAmount / finalTotal).clamp(0.0, 1.0)
                                : 0.0,
                            backgroundColor: const Color(0xFFFDE68A),
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              Color(0xFF298E4D),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPaymentTypeCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryColor.withValues(alpha: 0.08)
              : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppTheme.primaryColor : AppTheme.borderColor,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? AppTheme.primaryColor : AppTheme.textSecondary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.outfit(
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                      color: isSelected
                          ? AppTheme.primaryColor
                          : AppTheme.textPrimary,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.outfit(
                      fontSize: 10.5,
                      color: AppTheme.textSecondary,
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

  Widget _buildPresetChip(String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 10.5,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
          ),
        ),
      ),
    );
  }

  String get _paymentIdHint {
    switch (_paymentMode) {
      case 'UPI':
        return 'e.g. 12-digit UPI Ref / UTR (e.g. 423987123456)';
      case 'Bank Transfer':
        return 'e.g. NEFT / RTGS / IMPS Reference Number';
      case 'Cheque':
        return 'e.g. Cheque No. & Bank Name';
      case 'Cash':
        return 'e.g. Cash Receipt / Voucher Reference';
      default:
        return 'e.g. UTR / NEFT / Cheque / Cash Ref';
    }
  }

  Widget _buildModeChip(String mode, IconData icon) {
    final isSelected = _paymentMode == mode;
    return InkWell(
      onTap: () => setState(() => _paymentMode = mode),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryColor.withValues(alpha: 0.1)
              : const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AppTheme.primaryColor : const Color(0xFFE5E7EB),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected ? AppTheme.primaryColor : AppTheme.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              mode,
              style: GoogleFonts.outfit(
                fontSize: 11.5,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? AppTheme.primaryColor : AppTheme.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Coupons & Manual Discounts Card
  // ---------------------------------------------------------------------------

  Widget _buildCouponAndDiscountCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderColor),
        boxShadow: AppTheme.cardShadow,
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.local_offer_outlined,
                size: 18,
                color: AppTheme.primaryColor,
              ),
              const SizedBox(width: 8),
              Text(
                'Coupons & Discounts',
                style: GoogleFonts.outfit(
                  fontSize: 14.5,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildCouponRow(),
          const SizedBox(height: 14),
          const Divider(height: 1, color: AppTheme.lightBorderColor),
          const SizedBox(height: 12),
          Text(
            'Manual Order Discount',
            style: GoogleFonts.outfit(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          _buildManualDiscountSection(),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Manual Discount Controls
  // ---------------------------------------------------------------------------

  Widget _buildManualDiscountSection() {
    return Column(
      children: [
        Row(
          children: [
            _buildManualTypeTab('None', 'None'),
            const SizedBox(width: 8),
            _buildManualTypeTab('Fixed', 'Fixed ₹'),
            const SizedBox(width: 8),
            _buildManualTypeTab('Percentage', 'Percent %'),
          ],
        ),
        if (_manualDiscountType != 'None') ...[
          const SizedBox(height: 10),
          Container(
            height: 42,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: AppTheme.backgroundColor,
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: AppTheme.borderColor),
            ),
            child: Row(
              children: [
                Icon(
                  _manualDiscountType == 'Percentage'
                      ? Icons.percent_rounded
                      : Icons.currency_rupee_rounded,
                  size: 16,
                  color: AppTheme.textSecondary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _manualDiscountCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    style: GoogleFonts.outfit(
                      fontSize: 13.5,
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: InputDecoration(
                      hintText: _manualDiscountType == 'Percentage'
                          ? 'Discount % (max 100)'
                          : 'Discount amount in ₹',
                      hintStyle: GoogleFonts.outfit(
                        fontSize: 12.5,
                        color: AppTheme.textSecondary.withValues(alpha: 0.7),
                      ),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                    onChanged: (v) {
                      final val = double.tryParse(v);
                      if (_manualDiscountType == 'Percentage') {
                        if (val != null && val > 100) {
                          _manualDiscountCtrl.text = '100';
                          _manualDiscountCtrl.selection =
                              TextSelection.fromPosition(
                            const TextPosition(offset: 3),
                          );
                        }
                      } else if (_manualDiscountType == 'Fixed') {
                        final subtotal = _cartTotal;
                        if (val != null && val > subtotal) {
                          _manualDiscountCtrl.text =
                              subtotal.toStringAsFixed(0);
                          _manualDiscountCtrl.selection =
                              TextSelection.fromPosition(
                            TextPosition(
                                offset: _manualDiscountCtrl.text.length),
                          );
                        }
                      }
                      setState(() {});
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildManualTypeTab(String type, String label) {
    final isSel = _manualDiscountType == type;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() {
          _manualDiscountType = type;
          if (type == 'None') _manualDiscountCtrl.clear();
        }),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 7),
          decoration: BoxDecoration(
            color: isSel
                ? AppTheme.primaryColor.withValues(alpha: 0.1)
                : const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSel ? AppTheme.primaryColor : const Color(0xFFE5E7EB),
              width: isSel ? 1.5 : 1,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 11.5,
                color: isSel ? AppTheme.primaryColor : AppTheme.textSecondary,
                fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Executive Price Breakdown / Invoice Card
  // ---------------------------------------------------------------------------

  Widget _buildPriceBreakdown() {
    final subtotal = _cartTotal;

    // Calculate Sales Cart Discount
    double salesCartDiscount = 0;
    if (_appliedSalesCoupon != null) {
      final type = _appliedSalesCoupon!['cartDiscountType'] ?? 'None';
      final val = (_appliedSalesCoupon!['cartDiscountValue'] ?? 0) as num;
      if (type == 'Fixed') {
        salesCartDiscount = val.toDouble();
      } else if (type == 'Percentage') {
        salesCartDiscount = (subtotal * val.toDouble()) / 100;
      }
    }

    // Calculate Manual Discount
    double manualDiscountValue = 0;
    final manualVal = double.tryParse(_manualDiscountCtrl.text.trim()) ?? 0;
    if (_manualDiscountType == 'Fixed') {
      manualDiscountValue = manualVal;
    } else if (_manualDiscountType == 'Percentage') {
      manualDiscountValue = (subtotal * manualVal) / 100;
    }

    final finalTotal = _finalOrderTotal;
    final totalSavings = _totalDiscountSavings;
    final remaining = (finalTotal - _advanceAmount).clamp(0.0, finalTotal);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderColor),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.receipt_long_outlined,
                    size: 18,
                    color: AppTheme.primaryColor,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Billing Summary',
                    style: GoogleFonts.outfit(
                      fontSize: 14.5,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ],
              ),
              if (totalSavings > 0)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Save ₹${_formatAmt(totalSavings)}',
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF298E4D),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          PriceRow('Gross Subtotal', '₹${_formatAmt(subtotal)}'),
          if (_discountAmount > 0) ...[
            const SizedBox(height: 6),
            PriceRow(
              'Coupon (${_appliedCoupon!['code']})',
              '- ₹${_formatAmt(_discountAmount)}',
              color: AppTheme.success,
            ),
          ],
          if (salesCartDiscount > 0) ...[
            const SizedBox(height: 6),
            PriceRow(
              'Sales Cart Discount',
              '- ₹${_formatAmt(salesCartDiscount)}',
              color: Colors.blue,
            ),
          ],
          if (manualDiscountValue > 0) ...[
            const SizedBox(height: 6),
            PriceRow(
              'Manual Discount',
              '- ₹${_formatAmt(manualDiscountValue)}',
              color: Colors.orange,
            ),
          ],
          if (_freeProductName != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                    color: const Color(0xFF298E4D).withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.card_giftcard_rounded,
                      size: 14, color: Color(0xFF298E4D)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Free Promotional Item: $_freeProductName',
                      style: GoogleFonts.outfit(
                        color: const Color(0xFF298E4D),
                        fontWeight: FontWeight.w700,
                        fontSize: 11.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Divider(color: AppTheme.lightBorderColor),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Net Payable Amount',
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  Text(
                    'Inclusive of applicable discounts',
                    style: GoogleFonts.outfit(
                      fontSize: 10.5,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (totalSavings > 0)
                    Text(
                      '₹${_formatAmt(subtotal)}',
                      style: GoogleFonts.outfit(
                        color: AppTheme.textSecondary,
                        fontSize: 11.5,
                        decoration: TextDecoration.lineThrough,
                      ),
                    ),
                  Text(
                    '₹${_formatAmt(finalTotal)}',
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.w900,
                      fontSize: 20,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (_paymentMethod == 'Partial' && _advanceAmount > 0) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Advance: ₹${_formatAmt(_advanceAmount)}',
                    style: GoogleFonts.outfit(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF298E4D),
                    ),
                  ),
                  Text(
                    'Balance Due: ₹${_formatAmt(remaining)}',
                    style: GoogleFonts.outfit(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFFD97706),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Desktop Action Panel (Right Column Footer)
  // ---------------------------------------------------------------------------

  Widget _buildDesktopOrderActionPanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderColor),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _submitOrder,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                disabledBackgroundColor:
                    AppTheme.primaryColor.withValues(alpha: 0.5),
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
                        strokeWidth: 2.2,
                        color: Colors.white,
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.check_circle_outline_rounded,
                            size: 18, color: Colors.white),
                        const SizedBox(width: 8),
                        Text(
                          'Place Order  •  ₹${_formatAmt(_finalOrderTotal)}',
                          style: GoogleFonts.outfit(
                            fontSize: 14.5,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 40,
            child: OutlinedButton.icon(
              onPressed: () => setState(() => _step = 1),
              icon: const Icon(Icons.arrow_back_rounded, size: 16),
              label: const Text('Back to Products'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.textSecondary,
                side: const BorderSide(color: AppTheme.borderColor),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                textStyle: GoogleFonts.outfit(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
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
                OrderRepository().getActiveCoupons().then((list) {
                  setSheetState(() {
                    standardCoupons = list;
                    isLoadingStandard = false;
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
                  final result = await OrderRepository().validateSalesCoupon(
                    code: code,
                    subtotal: subtotal,
                  );
                  if (result['success'] == true) {
                    setSheetState(() {
                      validatedSalesCoupon =
                          Map<String, dynamic>.from(result['coupon']);
                    });
                    return;
                  }
                  setSheetState(
                      () => salesApplyError = result['message'] ?? 'Invalid coupon');
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
                  if (validatedCoupon['cartDiscountType'] != 'None') ...[
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.shopping_cart_checkout_rounded, size: 16, color: Colors.blue),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Cart Discount: ${validatedCoupon['cartDiscountType'] == 'Percentage' ? '${validatedCoupon['cartDiscountValue']}% off' : '₹${validatedCoupon['cartDiscountValue']} off'}',
                              style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.blue.shade800),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
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
                          'Place Order  •  ₹${_formatAmt(_finalOrderTotal)}',
                          style: GoogleFonts.outfit(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
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
    final customVol = _customPackVolumes[variantId];
    final customUnit = _customBaseUnits[variantId];
    final String baseUnit = customUnit ?? (variant['basePackingUnit'] ?? '').toString();
    final double packVolume = customVol ?? ((variant['packVolume'] ?? 1) as num).toDouble();
    final double totalVolume = packVolume * inCart;

    final List<Map<String, dynamic>> validTiers = [];
    for (var tier in priceTiers) {
      final tierMap = Map<String, dynamic>.from(tier as Map);
      final tierId = tierMap['id']?.toString() ?? '';
      final tierName = tierMap['name']?.toString() ?? '';
      final range = parseTierRange(tierName);
      final rateVal = parseRateValue(
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

    final String volUnit = baseUnit.toLowerCase() == 'pcs'
        ? ' Pcs'
        : baseUnit.toLowerCase() == 'kg'
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
                child: TierMilestoneCard(
                  key: ValueKey('${variantId}_${t['key']}'),
                  label: t['label'] as String,
                  threshold: t['threshold'] as double,
                  price: t['price'] as double,
                  isUnlocked: isUnlocked,
                  isActive: isActive,
                  baseUnit: baseUnit,
                  onTap: () {
                    if (isUnlocked) {
                      final unitLabel = baseUnit.toLowerCase() == 'pcs'
                          ? 'pcs'
                          : baseUnit.toLowerCase() == 'kg'
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
    double threshold, {
    double? customPackVolume,
  }) {
    final double packVolume =
        customPackVolume ?? ((variant['packVolume'] ?? 1) as num).toDouble();
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
    final int requiredQty = _getRequiredQtyForTier(
      variant,
      tierKey,
      threshold,
      customPackVolume: packVolume,
    );
    final double currentUnitPrice = getVariantPrice(
      variant,
      currentQty > 0 ? currentQty : 1,
      customPackVolume: packVolume,
    );
    final double targetUnitPrice = tierPrice * packVolume;
    final double savings =
        (requiredQty * targetUnitPrice) - (requiredQty * currentUnitPrice) > 0
        ? 0
        : (requiredQty * currentUnitPrice) - (requiredQty * targetUnitPrice);

    UnlockTierBottomSheet.show(
      context: context,
      tierLabel: tierLabel,
      currentUnitPrice: currentUnitPrice,
      tierPrice: tierPrice,
      packVolume: packVolume,
      baseUnit: baseUnit,
      currentQty: currentQty,
      requiredQty: requiredQty,
      savings: savings,
      onUpgrade: () {
        final cartIdx = _cart.indexWhere(
          (c) =>
              c.product['_id'] == productId &&
              c.variant['_id'] == variantId,
        );
        setState(() {
          if (cartIdx >= 0) {
            _cart[cartIdx].quantity = requiredQty;
          } else {
            final product = _allProducts.firstWhere(
              (p) => p['_id'] == productId,
              orElse: () => {},
            );
            if (product.isNotEmpty) {
              final customVol = _customPackVolumes[variantId];
              final customUnit = _customBaseUnits[variantId];
              _cart.add(
                CartItem(
                  product: product,
                  variant: variant,
                  quantity: requiredQty,
                  customPackVolume: customVol,
                  customBasePackingUnit: customUnit,
                ),
              );
            }
          }
        });
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
