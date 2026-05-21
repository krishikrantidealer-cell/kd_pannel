import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:kd_pannel/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_quill_delta_from_html/flutter_quill_delta_from_html.dart';
import 'package:vsc_quill_delta_to_html/vsc_quill_delta_to_html.dart';
import 'package:image_editor_plus/image_editor_plus.dart';
import 'package:image_picker/image_picker.dart';
import 'package:kd_pannel/core/network/api_client.dart';
import 'package:kd_pannel/features/shared/widgets/main_layout.dart';

class CreateProductPage extends StatefulWidget {
  final Map<String, dynamic>? initialData;
  final ValueChanged<Map<String, dynamic>> onSave;
  final List<dynamic>? preloadedCategories;

  const CreateProductPage({
    super.key,
    this.initialData,
    required this.onSave,
    this.preloadedCategories,
  });

  @override
  State<CreateProductPage> createState() => _CreateProductPageState();
}

class _CreateProductPageState extends State<CreateProductPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _vendorController = TextEditingController();
  late final quill.QuillController _descriptionController;
  List<Map<String, dynamic>> _formVariants = [];
  List<Map<String, String>> _priceTiers = [
    {'id': '1', 'name': 'Tier 1 (10-30)'},
    {'id': '2', 'name': 'Tier 2 (30-50)'},
    {'id': '3', 'name': 'Tier 3 (50+)'},
  ];
  List<Uint8List> _productImages = [];
  // URLs of images already uploaded to GCS (shown in edit mode)
  List<String> _existingImageUrls = [];
  List<String> _existingMediumUrls = [];
  List<String> _existingOriginalUrls = [];
  final ImagePicker _picker = ImagePicker();

  final _tagController = TextEditingController();
  List<String> _tags = [];
  String _formCategory = '';
  String _formSubCategory = '';
  List<dynamic> _backendCategories = [];
  bool _isSaving = false;
  bool _isLoadingDetails = false;
  bool _isTransitionComplete = false;
  late final Stopwatch _perfStopwatch;

  @override
  void initState() {
    _perfStopwatch = Stopwatch()..start();
    debugPrint('[PERF] CreateProductPage.initState started');
    super.initState();
    _loadCategories();

    final data = widget.initialData;
    quill.Document doc;
    if (data != null && data['description'] != null && data['description'].toString().isNotEmpty) {
      try {
        final delta = HtmlToDelta().convert(data['description'].toString());
        doc = quill.Document.fromDelta(delta);
        debugPrint('[PERF] CreateProductPage.initState - Parsed description HTML to Quill Delta. Elapsed: ${_perfStopwatch.elapsedMilliseconds}ms');
      } catch (e) {
        debugPrint('Error parsing HTML to Quill Delta: $e');
        doc = quill.Document();
      }
    } else {
      doc = quill.Document();
    }

    _descriptionController = quill.QuillController(
      document: doc,
      selection: const TextSelection.collapsed(offset: 0),
    );

    // Quill is a native Flutter widget, so we don't need any delay transitions!
    _isTransitionComplete = true;

    if (data != null) {
      debugPrint('[PERF] CreateProductPage.initState - data is NOT null (Edit Mode). Elapsed: ${_perfStopwatch.elapsedMilliseconds}ms');
      _nameController.text = data['name'] ?? '';
      _vendorController.text = data['vendor'] ?? '';
      _formCategory = data['category'] ?? '';
      _formSubCategory = data['subCategory'] ?? '';
      _tags = List<String>.from(data['tags'] ?? []);
      // Load existing uploaded images for edit mode
      _existingImageUrls = List<String>.from(data['images'] ?? []);
      _existingMediumUrls = List<String>.from(data['mediumImages'] ?? []);
      _existingOriginalUrls = List<String>.from(data['originalImages'] ?? []);

      if (data['priceTiers'] != null) {
        try {
          _priceTiers = (data['priceTiers'] as List).map((t) {
            final map = t as Map;
            return {
              for (var entry in map.entries)
                entry.key.toString(): entry.value.toString(),
            };
          }).toList();
        } catch (_) {}
      }

      if (data['variants'] != null) {
        for (var v in data['variants']) {
          _addVariant(data: v);
        }
      }
      if (_formVariants.isEmpty) {
        _addVariant();
      }
    } else {
      debugPrint('[PERF] CreateProductPage.initState - data is null (Create Mode). Elapsed: ${_perfStopwatch.elapsedMilliseconds}ms');
      _addVariant();
    }
  }

  Future<void> _loadCategories() async {
    debugPrint('[PERF] CreateProductPage._loadCategories started. Elapsed: ${_perfStopwatch.elapsedMilliseconds}ms');
    
    // 1. Try to use preloaded categories passed down from parent page/BLoC
    if (widget.preloadedCategories != null && widget.preloadedCategories!.isNotEmpty) {
      debugPrint('[PERF] CreateProductPage._loadCategories - Using preloaded categories. Elapsed: ${_perfStopwatch.elapsedMilliseconds}ms');
      setState(() {
        _backendCategories = widget.preloadedCategories!;
        _initializeCategorySelection();
      });
      return;
    }

    // 2. Try to load from memory cache
    final cached = ApiClient().cachedCategories;
    if (cached != null && cached.isNotEmpty) {
      debugPrint('[PERF] CreateProductPage._loadCategories - Found cached categories in ApiClient. Elapsed: ${_perfStopwatch.elapsedMilliseconds}ms');
      setState(() {
        _backendCategories = cached;
        _initializeCategorySelection();
      });
      return;
    }

    try {
      debugPrint('[PERF] CreateProductPage._loadCategories - Dispatching API call to /products/categories. Elapsed: ${_perfStopwatch.elapsedMilliseconds}ms');
      final response = await ApiClient().get('/products/categories');
      debugPrint('[PERF] CreateProductPage._loadCategories - API call completed with code ${response.statusCode}. Elapsed: ${_perfStopwatch.elapsedMilliseconds}ms');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['categories'] is List) {
          final List categories = data['categories'];
          ApiClient().cachedCategories = categories; // Update cache
          if (mounted) {
            setState(() {
              _backendCategories = categories;
              _initializeCategorySelection();
            });
          }
        }
      }
    } catch (e) {
      debugPrint('[PERF] CreateProductPage._loadCategories - Error fetching categories: $e. Elapsed: ${_perfStopwatch.elapsedMilliseconds}ms');
    }
  }

  void _initializeCategorySelection() {
    if (widget.initialData == null && _backendCategories.isNotEmpty) {
      _formCategory = _backendCategories.first['name']?.toString() ?? '';
      final subCats = getFormSubCategories(_formCategory);
      _formSubCategory = subCats.isNotEmpty ? subCats.first : '';
    }
  }

  Map<String, String> _parsePackSize(String packSizeText) {
    final match = RegExp(
      r'^(\d+\.?\d*)\s*([a-zA-Z]+)$',
    ).firstMatch(packSizeText.trim());
    if (match != null) {
      return {'val': match.group(1) ?? '1', 'unit': match.group(2) ?? 'lit'};
    }
    final valOnly = packSizeText.replaceAll(RegExp(r'[^0-9.]'), '');
    final unitOnly = packSizeText.replaceAll(RegExp(r'[0-9.]'), '').trim();
    return {
      'val': valOnly.isEmpty ? '1' : valOnly,
      'unit': unitOnly.isEmpty ? 'lit' : unitOnly,
    };
  }

  String _parseRate(String rateString) {
    // Extract digits and decimals from the beginning of the string
    final match = RegExp(r'^([0-9.]+)').firstMatch(rateString.trim());
    return match?.group(1) ?? rateString.trim();
  }

  String _getRateSuffix(String packUnit) {
    final unit = packUnit.toLowerCase().trim();
    if (unit == 'ml' || unit == 'lit') return '/lit';
    if (unit == 'gm' || unit == 'kg') return '/kg';
    return '/pcs';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _vendorController.dispose();
    for (var variant in _formVariants) {
      variant['price']?.dispose();
      variant['compareAtPrice']?.dispose();
      variant['packSizeVal']?.dispose();
      variant['baseQuantity']?.dispose();
      variant['compareRate']?.dispose();
      variant['basePackingVal']?.dispose();

      final rates = variant['rates'] as Map<String, TextEditingController>?;
      rates?.values.forEach((ctrl) => ctrl.dispose());

      final computed =
          variant['computed'] as Map<String, TextEditingController>?;
      computed?.values.forEach((ctrl) => ctrl.dispose());
    }
    _descriptionController.dispose();
    super.dispose();
  }

  void _addVariant({Map<String, dynamic>? data}) {
    final String initialPrice = data?['price'] != null
        ? data!['price'].toString()
        : '';
    final String initialCompare = data?['compareAtPrice'] != null
        ? data!['compareAtPrice'].toString()
        : '';
    // 'packSize' is the carton/booking total string (new field).
    // Old products store the same value as a number in 'packVolume' (always in litres).
    String initialPackSize = '';
    if (data?['packSize'] != null) {
      initialPackSize = data!['packSize'].toString();
    } else if (data?['packVolume'] != null) {
      // packVolume is stored in litres as a number, convert back to readable string
      final pvNum = data!['packVolume'];
      final pvDouble = pvNum is num ? pvNum.toDouble() : double.tryParse(pvNum.toString());
      if (pvDouble != null && pvDouble > 0) {
        initialPackSize = pvDouble % 1 == 0
            ? '${pvDouble.toInt()}lit'
            : '${pvDouble}lit';
      }
    }

    final String initialQty = data?['baseQuantity'] != null
        ? data!['baseQuantity'].toString()
        : '1';
    // 'basePacking' is the individual bottle/unit size.
    // For old products the backend stored this under the 'size' field, so fall back to it.
    final String initialBasePacking =
        (data?['basePacking'] ?? data?['size']) != null
            ? (data!['basePacking'] ?? data['size']).toString()
            : '';

    // Parse pack size
    String packVal = '';
    String packUnit = 'lit';
    if (initialPackSize.isNotEmpty) {
      final parsed = _parsePackSize(initialPackSize);
      packVal = parsed['val'] ?? '';
      packUnit = (parsed['unit'] ?? 'lit').toLowerCase();
      if (packUnit.isEmpty) packUnit = 'lit';
    }

    // Parse base packing
    String basePackVal = '';
    String basePackUnit = 'lit';
    if (initialBasePacking.isNotEmpty) {
      final parsed = _parsePackSize(initialBasePacking);
      basePackVal = parsed['val'] ?? '';
      basePackUnit = (parsed['unit'] ?? 'lit').toLowerCase();
      if (basePackUnit.isEmpty) basePackUnit = 'lit';
    }

    final priceCtrl = TextEditingController(text: initialPrice);
    final compareCtrl = TextEditingController(text: initialCompare);
    final packValCtrl = TextEditingController(text: packVal);
    final qtyCtrl = TextEditingController(text: initialQty);
    final compareRateCtrl = TextEditingController();
    final basePackingValCtrl = TextEditingController(text: basePackVal);

    // Map of rates for each tier
    final rates = <String, TextEditingController>{};
    final computed = <String, TextEditingController>{};

    for (var tier in _priceTiers) {
      final id = tier['id']!;
      // Read rate from data if available
      final dynamic rawRateVal =
          data?['rates']?[id] ?? data?['unitPriceRate${id == "1" ? "" : id}'];
      final String rateVal = rawRateVal != null ? rawRateVal.toString() : '';
      rates[id] = TextEditingController(text: _parseRate(rateVal));

      String computedVal = '';
      if (data?['price$id'] != null) {
        computedVal = data!['price$id'].toString();
      } else if (data?['computedPrices']?[id] != null) {
        computedVal = data!['computedPrices'][id].toString();
      }
      computed[id] = TextEditingController(text: computedVal);
    }

    // Handle initial fallback or legacy values for rates
    final String legacyUnitPriceRate = data?['unitPriceRate'] != null
        ? data!['unitPriceRate'].toString()
        : (data?['price'] != null ? data!['price'].toString() : '');
    final String legacyUnitCompareRate = data?['unitCompareRate'] != null
        ? data!['unitCompareRate'].toString()
        : (data?['compareAtPrice'] != null
              ? data!['compareAtPrice'].toString()
              : '');

    if (rates['1']!.text.isEmpty && legacyUnitPriceRate.isNotEmpty) {
      rates['1']!.text = _parseRate(legacyUnitPriceRate);
    }
    if (compareRateCtrl.text.isEmpty && legacyUnitCompareRate.isNotEmpty) {
      compareRateCtrl.text = _parseRate(legacyUnitCompareRate);
    }

    // If unit rates are empty but we have final prices and pack size, let's reverse calculate!
    final double? finalPrice = double.tryParse(initialPrice);
    final double? finalCompare = double.tryParse(initialCompare);
    final double? sizeVal = double.tryParse(packVal);

    double getFactor() {
      double factor = 1.0;
      final String currentUnit = packUnit.toLowerCase().trim();
      if (currentUnit == 'ml' || currentUnit == 'gm' || currentUnit == 'g')
        factor = 0.001;
      return factor;
    }

    if (rates['1']!.text.isEmpty &&
        finalPrice != null &&
        sizeVal != null &&
        sizeVal > 0) {
      rates['1']!.text = (finalPrice / (sizeVal * getFactor())).toStringAsFixed(
        2,
      );
    }
    if (compareRateCtrl.text.isEmpty &&
        finalCompare != null &&
        sizeVal != null &&
        sizeVal > 0) {
      compareRateCtrl.text = (finalCompare / (sizeVal * getFactor()))
          .toStringAsFixed(2);
    }

    // Setup listeners to calculate prices on the fly!
    void recalculate() {
      final double? cRateVal = double.tryParse(compareRateCtrl.text);
      final double? sVal = double.tryParse(packValCtrl.text);

      if (sVal != null && sVal > 0) {
        final factor = getFactor();

        if (cRateVal != null) {
          final computedMRP = cRateVal * sVal * factor;
          compareCtrl.text = computedMRP % 1 == 0
              ? computedMRP.toStringAsFixed(0)
              : computedMRP.toStringAsFixed(2);
        }

        for (var tier in _priceTiers) {
          final id = tier['id']!;
          final rateCtrl = rates[id];
          final compCtrl = computed[id];
          if (rateCtrl != null && compCtrl != null) {
            final double? rVal = double.tryParse(rateCtrl.text);
            if (rVal != null) {
              final computedVal = rVal * sVal * factor;
              compCtrl.text = computedVal % 1 == 0
                  ? computedVal.toStringAsFixed(0)
                  : computedVal.toStringAsFixed(2);

              if (id == '1') {
                priceCtrl.text = compCtrl.text;
              }
            } else {
              compCtrl.clear();
              if (id == '1') priceCtrl.clear();
            }
          }
        }
      }
    }

    compareRateCtrl.addListener(recalculate);
    packValCtrl.addListener(recalculate);
    for (var controller in rates.values) {
      controller.addListener(recalculate);
    }

    setState(() {
      _formVariants.add({
        'price': priceCtrl,
        'compareAtPrice': compareCtrl,
        'packSizeVal': packValCtrl,
        'packSizeUnit': packUnit,
        'baseQuantity': qtyCtrl,
        'compareRate': compareRateCtrl,
        'basePackingVal': basePackingValCtrl,
        'basePackingUnit': basePackUnit,
        'rates': rates,
        'computed': computed,
        // Maintain recalculate reference for update on unit dropdown change
        'recalculate': recalculate,
      });
    });
  }

  void _removeVariant(int index) {
    final variant = _formVariants[index];
    variant['price']?.dispose();
    variant['compareAtPrice']?.dispose();
    variant['packSizeVal']?.dispose();
    variant['baseQuantity']?.dispose();
    variant['compareRate']?.dispose();
    variant['basePackingVal']?.dispose();

    final rates = variant['rates'] as Map<String, TextEditingController>?;
    rates?.values.forEach((ctrl) => ctrl.dispose());

    final computed = variant['computed'] as Map<String, TextEditingController>?;
    computed?.values.forEach((ctrl) => ctrl.dispose());

    setState(() {
      _formVariants.removeAt(index);
    });
  }

  void _addNewTier(String name) {
    final newId = (DateTime.now().millisecondsSinceEpoch).toString();
    setState(() {
      _priceTiers.add({'id': newId, 'name': name});

      // Update all variants to have this tier's controllers
      for (var variant in _formVariants) {
        final ratesMap = variant['rates'] as Map<String, TextEditingController>;
        final computedMap =
            variant['computed'] as Map<String, TextEditingController>;
        final recalculate = variant['recalculate'] as VoidCallback;

        final rateCtrl = TextEditingController();
        ratesMap[newId] = rateCtrl;
        computedMap[newId] = TextEditingController();

        rateCtrl.addListener(recalculate);
      }
    });
  }

  void _deleteTier(String id) {
    if (id == '1') return; // Primary is required
    setState(() {
      _priceTiers.removeWhere((t) => t['id'] == id);

      for (var variant in _formVariants) {
        final ratesMap = variant['rates'] as Map<String, TextEditingController>;
        final computedMap =
            variant['computed'] as Map<String, TextEditingController>;

        final rateCtrl = ratesMap.remove(id);
        if (rateCtrl != null) {
          final recalculate = variant['recalculate'] as VoidCallback;
          rateCtrl.removeListener(recalculate);
          rateCtrl.dispose();
        }
        final compCtrl = computedMap.remove(id);
        compCtrl?.dispose();

        // Trigger recalculate after removing tier
        final recalculate = variant['recalculate'] as VoidCallback;
        recalculate();
      }
    });
  }

  void _showManageTiersDialog() {
    showDialog(
      context: context,
      builder: (context) {
        final addController = TextEditingController();
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Container(
                width: 400,
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Configure Pricing Tiers',
                          style: GoogleFonts.outfit(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            Navigator.pop(context);
                            setState(() {});
                          },
                          icon: const Icon(
                            Icons.close,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Tiers are applied globally. Tier 1 is the primary selling price.',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 250),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: _priceTiers.length,
                        itemBuilder: (context, idx) {
                          final tier = _priceTiers[idx];
                          final isPrimary = tier['id'] == '1';

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    initialValue: tier['name'],
                                    decoration: InputDecoration(
                                      isDense: true,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 8,
                                          ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    style: GoogleFonts.outfit(fontSize: 13),
                                    onChanged: (val) {
                                      tier['name'] = val;
                                    },
                                  ),
                                ),
                                const SizedBox(width: 8),
                                isPrimary
                                    ? Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppTheme.primaryColor
                                              .withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                        ),
                                        child: Text(
                                          'Primary',
                                          style: GoogleFonts.outfit(
                                            fontSize: 11,
                                            color: AppTheme.primaryColor,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      )
                                    : IconButton(
                                        onPressed: () {
                                          _deleteTier(tier['id']!);
                                          setDialogState(() {});
                                        },
                                        icon: const Icon(
                                          Icons.delete_outline,
                                          color: AppTheme.error,
                                          size: 18,
                                        ),
                                      ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    const Divider(height: 24),
                    Text(
                      'Add New Tier',
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: addController,
                            decoration: InputDecoration(
                              hintText: 'e.g. Tier 4 (Bulk)',
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 8,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            style: GoogleFonts.outfit(fontSize: 13),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () {
                            if (addController.text.trim().isNotEmpty) {
                              _addNewTier(addController.text.trim());
                              addController.clear();
                              setDialogState(() {});
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                          ),
                          child: Text(
                            'Add',
                            style: GoogleFonts.outfit(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
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
    ).then((_) {
      setState(() {});
    });
  }

  List<String> getFormSubCategories(String cat) {
    if (_backendCategories.isNotEmpty) {
      final matchingCat = _backendCategories.firstWhere(
        (c) => c['name'].toString().toLowerCase() == cat.toLowerCase(),
        orElse: () => null,
      );
      if (matchingCat != null) {
        final List subs = matchingCat['subCategories'] ?? [];
        final List<String> list = [];
        for (var sub in subs) {
          final sName = sub['name']?.toString();
          if (sName != null && sName.isNotEmpty) {
            list.add(sName);
          }
        }
        if (list.isNotEmpty) {
          // Make sure current subcategory is in list to prevent crashes
          if (!list.contains(_formSubCategory) &&
              cat.toLowerCase() == _formCategory.toLowerCase()) {
            list.add(_formSubCategory);
          }
          list.add('+ Create Custom...');
          return list;
        }
      }
    }

    final List<String> list = [];
    if (_formSubCategory.isNotEmpty &&
        cat.toLowerCase() == _formCategory.toLowerCase()) {
      list.add(_formSubCategory);
    }
    if (list.isEmpty) {
      list.add('');
    }
    list.add('+ Create Custom...');
    return list;
  }

  Future<void> _pickMultipleProductImages() async {
    try {
      final List<XFile> images = await _picker.pickMultiImage(
        imageQuality: 85, // Compress to 85% quality to save space and upload time
        maxWidth: 1440,   // Limit maximum width to 1440 pixels
        maxHeight: 1440,  // Limit maximum height to 1440 pixels
      );
      if (images.isNotEmpty) {
        for (var image in images) {
          final Uint8List imageBytes = await image.readAsBytes();
          setState(() {
            _productImages.add(imageBytes);
          });
        }
      }
    } catch (e) {
      print('Error picking multiple images: $e');
    }
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please correct the validation errors in the form.'),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }

    // Check at least one image is present
    if (_existingImageUrls.isEmpty && _productImages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please upload at least one product image.'),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }

    // Check description is not empty
    final descPlainText = _descriptionController.document.toPlainText().trim();
    if (descPlainText.isEmpty || descPlainText == '\n') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Product description cannot be empty.'),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      String description = '';
      try {
        final deltaJson = _descriptionController.document.toDelta().toJson();
        final converter = QuillDeltaToHtmlConverter(
          List<Map<String, dynamic>>.from(deltaJson),
          ConverterOptions.forEmail(),
        );
        description = converter.convert();
      } catch (e) {
        debugPrint('[PERF] Error converting Quill Delta to HTML: $e');
      }

      List<Map<String, dynamic>> variantsData = [];
      for (var v in _formVariants) {
        final ratesMap = v['rates'] as Map<String, TextEditingController>;
        final computedMap = v['computed'] as Map<String, TextEditingController>;

        final ratesJson = <String, String>{};
        final computedJson = <String, String>{};

        final suffix = _getRateSuffix(v['packSizeUnit']);

        ratesMap.forEach((key, ctrl) {
          final val = ctrl.text.trim();
          ratesJson[key] = val.isNotEmpty ? '$val$suffix' : '';
        });
        computedMap.forEach((key, ctrl) {
          computedJson[key] = ctrl.text;
        });

        final String primaryRateVal = ratesMap['1']?.text.trim() ?? '';
        final String primaryRateWithSuffix = primaryRateVal.isNotEmpty
            ? '$primaryRateVal$suffix'
            : '';

        final String mrpRateVal = v['compareRate'].text.trim();
        final String mrpRateWithSuffix = mrpRateVal.isNotEmpty
            ? '$mrpRateVal$suffix'
            : '';

        variantsData.add({
          'price': primaryRateWithSuffix,
          'compareAtPrice': mrpRateWithSuffix,
          'packSize': '${v['packSizeVal'].text}${v['packSizeUnit']}',
          'basePacking': '${v['basePackingVal'].text}${v['basePackingUnit']}',
          'baseQuantity': v['baseQuantity'].text,
          'unitCompareRate': mrpRateWithSuffix,
          'rates': ratesJson,
          'computedPrices': computedJson,

          // Legacy mappings
          'unitPriceRate': primaryRateWithSuffix,
          'unitPriceRate2': (ratesMap['2']?.text.isNotEmpty ?? false)
              ? '${ratesMap['2']!.text}$suffix'
              : '',
          'unitPriceRate3': (ratesMap['3']?.text.isNotEmpty ?? false)
              ? '${ratesMap['3']!.text}$suffix'
              : '',
          'price2': computedMap['2']?.text ?? '',
          'price3': computedMap['3']?.text ?? '',
        });
      }

      String displayPrice = '₹0';
      if (variantsData.isNotEmpty && variantsData.first['price'].isNotEmpty) {
        displayPrice = variantsData.first['price'].startsWith('₹')
            ? variantsData.first['price']
            : '₹${variantsData.first['price']}';
      }

      // Find Category ID and Sub-category ID from backendCategories
      String? categoryId;
      String? subCategoryId;

      if (_backendCategories.isNotEmpty) {
        final matchingCat = _backendCategories.firstWhere(
          (c) =>
              c['name'].toString().toLowerCase() == _formCategory.toLowerCase(),
          orElse: () => _backendCategories.first,
        );
        if (matchingCat != null) {
          categoryId =
              matchingCat['id']?.toString() ?? matchingCat['_id']?.toString();
          final List subs = matchingCat['subCategories'] ?? [];
          if (subs.isNotEmpty) {
            final matchingSub = subs.firstWhere(
              (s) =>
                  s['name'].toString().toLowerCase() ==
                  _formSubCategory.toLowerCase(),
              orElse: () => subs.first,
            );
            if (matchingSub != null) {
              subCategoryId =
                  matchingSub['id']?.toString() ??
                  matchingSub['_id']?.toString();
            }
          }
        }
      }

      if (categoryId == null) {
        throw Exception(
          'Product category hierarchy could not be resolved. Please wait or reload.',
        );
      }

      final mappedVariants = variantsData.map((v) {
        final priceVal =
            double.tryParse(v['price'].replaceAll(RegExp(r'[^0-9.]'), '')) ??
            0.0;
        final compareVal =
            double.tryParse(
              v['compareAtPrice'].replaceAll(RegExp(r'[^0-9.]'), ''),
            ) ??
            0.0;

        final rates = v['rates'] as Map<String, String>;
        final rate2 =
            double.tryParse(
              rates['2']?.replaceAll(RegExp(r'[^0-9.]'), '') ?? '',
            ) ??
            priceVal;
        final rate3 =
            double.tryParse(
              rates['3']?.replaceAll(RegExp(r'[^0-9.]'), '') ?? '',
            ) ??
            priceVal;

        return {
          'size': v['packSize'],
          'price': priceVal,
          'compareAtPrice': compareVal,
          'price10_30': priceVal,
          'price30_50': rate2,
          'price50_plus': rate3,
          'packVolume': _getPackVolume(v['packSize'] ?? ''),
          'weight': 0.0,
        };
      }).toList();

      final bool isEdit = widget.initialData != null;

      final productData = {
        'title': _nameController.text.trim(),
        'brandName': _vendorController.text.trim(),
        'technicalName': _nameController.text.trim(),
        'vendor': _vendorController.text.trim(),
        'categoryId': categoryId,
        'subCategoryId': subCategoryId,
        'description': description,
        'variants': mappedVariants,
        'tags': _tags,
        // Tell the backend which existing images to keep
        if (isEdit) 'keepImages': _existingImageUrls,
        if (isEdit) 'keepMediumImages': _existingMediumUrls,
        if (isEdit) 'keepOriginalImages': _existingOriginalUrls,
      };

      http.Response response;
      if (_productImages.isNotEmpty) {
        // Multipart Upload
        final fields = {'data': jsonEncode(productData)};
        final List<http.MultipartFile> files = [];
        for (int i = 0; i < _productImages.length; i++) {
          final imgBytes = _productImages[i];
          files.add(
            http.MultipartFile.fromBytes(
              'images',
              imgBytes,
              filename: 'product_image_$i.png',
              contentType: MediaType('image', 'png'),
            ),
          );
        }

        response = await ApiClient().multipartRequest(
          method: isEdit ? 'PUT' : 'POST',
          endpoint: isEdit
              ? '/products/${widget.initialData!['id']}'
              : '/products',
          fields: fields,
          files: files,
        );
      } else {
        // Standard JSON PUT/POST
        response = isEdit
            ? await ApiClient().put(
                '/products/${widget.initialData!['id']}',
                productData,
              )
            : await ApiClient().post('/products', productData);
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        final resData = jsonDecode(response.body);
        widget.onSave(resData['product'] ?? {});
        if (mounted) {
          Navigator.pop(context);
        }
      } else {
        throw Exception(
          'Failed to save product (Status ${response.statusCode}): ${response.body}',
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save product: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  double _getPackVolume(String sizeStr) {
    final clean = sizeStr.toLowerCase().replaceAll(RegExp(r'\s+'), '');
    final match = RegExp(r'^([\d.]+)(ml|lit|litre|l|gm|gram|g|kg|kilogram|k)$').firstMatch(clean);
    if (match == null) return 1.0;
    
    final value = double.tryParse(match.group(1) ?? '') ?? 1.0;
    final unit = match.group(2) ?? '';
    
    if (unit == 'ml' || unit == 'gm' || unit == 'gram' || unit == 'g') {
      return value / 1000.0;
    }
    return value;
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('[PERF] CreateProductPage.build called. _isTransitionComplete = $_isTransitionComplete. Elapsed: ${_perfStopwatch.elapsedMilliseconds}ms');
    final bool isEdit = widget.initialData != null;

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 1,
        shadowColor: Colors.black.withValues(alpha: 0.1),
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.close_rounded, color: AppTheme.textPrimary),
          tooltip: 'Cancel',
        ),
        title: Text(
          isEdit ? 'Edit Product' : 'Create New Product',
          style: GoogleFonts.outfit(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: Row(
                children: [
                  OutlinedButton(
                    onPressed: _isSaving ? null : () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      side: const BorderSide(color: AppTheme.borderColor),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      foregroundColor: AppTheme.textPrimary,
                    ),
                    child: Text(
                      'Discard',
                      style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _isSaving ? null : _handleSave,
                    icon: _isSaving
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : const Icon(Icons.check_rounded, size: 18),
                    label: Text(
                      _isSaving
                          ? 'Saving...'
                          : (isEdit ? 'Save Changes' : 'Publish Product'),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: EdgeInsets.all(
            MediaQuery.of(context).size.width > 800 ? 24.0 : 16.0,
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final bool isWide = constraints.maxWidth > 800;

              final leftColumn = Column(
                children: [
                  _buildSectionCard(
                    title: 'Basic Details',
                    icon: Icons.info_outline_rounded,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildFormTextField(
                          label: 'Product Title',
                          hint: 'e.g. Premium Drip Irrigation Kit',
                          controller: _nameController,
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'Product Title is required';
                            }
                            if (val.trim().length < 5) {
                              return 'Title must be at least 5 characters';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Description',
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Provide a detailed description of the product features, benefits, and specifications.',
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Stack(
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                border: Border.all(color: AppTheme.borderColor),
                                borderRadius: BorderRadius.circular(12),
                                color: Colors.white,
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Column(
                                  children: [
                                    quill.QuillSimpleToolbar(
                                      controller: _descriptionController,
                                      config: const quill.QuillSimpleToolbarConfig(
                                        showFontFamily: false,
                                        showFontSize: false,
                                        
                                        
                                        showInlineCode: false,
                                        showSubscript: false,
                                        showSuperscript: false,
                                        showCodeBlock: false,
                                        showSearchButton: false,
                                        showUndo: true,
                                        showRedo: true,
                                        showBoldButton: true,
                                        showItalicButton: true,
                                        showUnderLineButton: true,
                                        showStrikeThrough: true,
                                        showColorButton: true,
                                        showBackgroundColorButton: true,
                                        showListNumbers: true,
                                        showListBullets: true,
                                        showListCheck: false,
                                        showIndent: true,
                                        showAlignmentButtons: true,
                                        showLink: true,
                                        showQuote: true,
                                        showClearFormat: true,
                                      ),
                                    ),
                                    const Divider(height: 1, color: AppTheme.borderColor),
                                    Container(
                                      height: 350,
                                      padding: const EdgeInsets.all(16),
                                      child: quill.QuillEditor.basic(
                                        controller: _descriptionController,
                                        config: const quill.QuillEditorConfig(
                                          placeholder: 'Provide a detailed description of the product features, benefits, and specifications...',
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            if (_isLoadingDetails)
                              Positioned.fill(
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.7),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Center(
                                    child: CircularProgressIndicator(
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        AppTheme.primaryColor,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildSectionCard(
                    title: 'Product Variants',
                    icon: Icons.style_outlined,
                    action: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextButton.icon(
                          onPressed: _showManageTiersDialog,
                          icon: const Icon(Icons.settings_outlined, size: 18),
                          label: Text(
                            'Manage Tiers',
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: TextButton.styleFrom(
                            foregroundColor: AppTheme.textSecondary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        TextButton.icon(
                          onPressed: _addVariant,
                          icon: const Icon(Icons.add_rounded, size: 18),
                          label: Text(
                            'Add Variant',
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: TextButton.styleFrom(
                            foregroundColor: AppTheme.primaryColor,
                          ),
                        ),
                      ],
                    ),
                    child: Column(
                      children: _formVariants.asMap().entries.map((entry) {
                        return _buildVariantCard(
                          entry.key,
                          entry.value,
                          isMobile: !isWide,
                        );
                      }).toList(),
                    ),
                  ),
                ],
              );

              final rightColumn = Column(
                children: [
                  _buildSectionCard(
                    title: 'Product Media',
                    icon: Icons.image_outlined,
                    child: _buildMediaUploader(),
                  ),
                  const SizedBox(height: 24),
                  _buildSectionCard(
                    title: 'Organization',
                    icon: Icons.category_outlined,
                    child: Column(
                      children: [
                        _buildCategoryDropdowns(),
                        const SizedBox(height: 20),
                        _buildFormTextField(
                          label: 'Vendor',
                          hint: 'e.g. Jain Irrigation, Mahyco',
                          controller: _vendorController,
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'Vendor is required';
                            }
                            if (val.trim().length < 2) {
                              return 'Vendor name must be at least 2 characters';
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildTagsCard(),
                ],
              );

              if (isWide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 2, child: leftColumn),
                    const SizedBox(width: 24),
                    Expanded(flex: 1, child: rightColumn),
                  ],
                );
              } else {
                return Column(
                  children: [
                    leftColumn,
                    const SizedBox(height: 24),
                    rightColumn,
                  ],
                );
              }
            },
          ),
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Widget child,
    Widget? action,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
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
                    Expanded(
                      child: Text(
                        title,
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              if (action != null) ...[const SizedBox(width: 8), action!],
            ],
          ),
          const SizedBox(height: 24),
          child,
        ],
      ),
    );
  }

  Widget _buildFormTextField({
    required String label,
    required String hint,
    required TextEditingController controller,
    Widget? prefixIcon,
    bool isCompact = false,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
    void Function(String)? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: isCompact ? 12 : 13,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          validator: validator,
          onChanged: onChanged,
          style: GoogleFonts.outfit(
            fontSize: isCompact ? 13 : 14,
            color: AppTheme.textPrimary,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.outfit(
              color: AppTheme.textSecondary,
              fontSize: isCompact ? 13 : 14,
            ),
            prefixIcon: prefixIcon,
            filled: true,
            fillColor: const Color(0xFFF9FAFB),
            contentPadding: EdgeInsets.symmetric(
              horizontal: 16,
              vertical: isCompact ? 10 : 16,
            ),
            isDense: isCompact,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(isCompact ? 8 : 10),
              borderSide: const BorderSide(color: AppTheme.borderColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(isCompact ? 8 : 10),
              borderSide: const BorderSide(color: AppTheme.borderColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(isCompact ? 8 : 10),
              borderSide: const BorderSide(
                color: AppTheme.primaryColor,
                width: 1.5,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(isCompact ? 8 : 10),
              borderSide: const BorderSide(color: AppTheme.error, width: 1.0),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(isCompact ? 8 : 10),
              borderSide: const BorderSide(color: AppTheme.error, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMediaUploader() {
    final bool hasAnyImages = _existingImageUrls.isNotEmpty || _productImages.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Existing uploaded images (from GCS) ──────────────────────────
        if (_existingImageUrls.isNotEmpty) ...[
          Text(
            'Current Images',
            style: GoogleFonts.outfit(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 90,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _existingImageUrls.length,
              itemBuilder: (context, index) {
                final url = _existingImageUrls[index];
                return Stack(
                  children: [
                    Container(
                      width: 90,
                      margin: const EdgeInsets.only(right: 10),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: index == 0
                              ? AppTheme.primaryColor
                              : AppTheme.borderColor,
                          width: index == 0 ? 2 : 1,
                        ),
                        image: DecorationImage(
                          image: NetworkImage(url),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    if (index == 0)
                      Positioned(
                        bottom: 4,
                        left: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Main',
                            style: GoogleFonts.outfit(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    Positioned(
                      top: 4,
                      right: 14,
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            // Remove from all 3 image lists at the same index
                            _existingImageUrls.removeAt(index);
                            if (index < _existingMediumUrls.length) {
                              _existingMediumUrls.removeAt(index);
                            }
                            if (index < _existingOriginalUrls.length) {
                              _existingOriginalUrls.removeAt(index);
                            }
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.85),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close,
                            size: 11,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 12),
        ],

        // ── New images (picked from device) ─────────────────────────────
        if (_productImages.isNotEmpty) ...[
          Text(
            'New Images (will be uploaded)',
            style: GoogleFonts.outfit(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 90,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _productImages.length,
              itemBuilder: (context, index) {
                return Stack(
                  children: [
                    GestureDetector(
                      onTap: () async {
                        final Uint8List? editedImage = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                ImageEditor(image: _productImages[index]),
                          ),
                        );
                        if (editedImage != null) {
                          setState(() {
                            _productImages[index] = editedImage;
                          });
                        }
                      },
                      child: Container(
                        width: 90,
                        margin: const EdgeInsets.only(right: 10),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: const Color(0xFFF59E0B),
                            width: 2,
                          ),
                          image: DecorationImage(
                            image: MemoryImage(_productImages[index]),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 4,
                      left: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF59E0B),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'New',
                          style: GoogleFonts.outfit(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 4,
                      right: 14,
                      child: InkWell(
                        onTap: () =>
                            setState(() => _productImages.removeAt(index)),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.6),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close,
                            size: 11,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 12),
        ],

        // ── Upload button ────────────────────────────────────────────────
        InkWell(
          onTap: _pickMultipleProductImages,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(
              vertical: hasAnyImages ? 16 : 32,
            ),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.02),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppTheme.primaryColor.withValues(alpha: 0.3),
                style: BorderStyle.solid,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: EdgeInsets.all(hasAnyImages ? 8 : 12),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.add_photo_alternate_outlined,
                    color: AppTheme.primaryColor,
                    size: hasAnyImages ? 20 : 28,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  hasAnyImages ? 'Add more images' : 'Click to upload images',
                  style: GoogleFonts.outfit(
                    fontSize: hasAnyImages ? 12 : 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryColor,
                  ),
                ),
                if (!hasAnyImages) ...[
                  const SizedBox(height: 4),
                  Text(
                    'PNG, JPG or GIF (max. 5MB each)',
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  List<String> get _dropdownCategories {
    final List<String> list = [];
    for (var cat in _backendCategories) {
      final name = cat['name']?.toString();
      if (name != null && name.isNotEmpty && !list.contains(name)) {
        list.add(name);
      }
    }
    // Crucially, make sure the current _formCategory is in the list to prevent assertion failure
    if (_formCategory.isNotEmpty && !list.contains(_formCategory)) {
      list.add(_formCategory);
    }
    if (list.isEmpty) {
      list.add('');
    }
    list.add('+ Create Custom...');
    return list;
  }

  Widget _buildCategoryDropdowns() {
    final subCats = getFormSubCategories(_formCategory);
    if (!subCats.contains(_formSubCategory)) _formSubCategory = subCats.first;

    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: _buildFormDropdown(
                label: 'Primary Category',
                value: _formCategory,
                options: _dropdownCategories,
                onChanged: (val) {
                  if (val == '+ Create Custom...') {
                    _showCreateCategoryDialog();
                    return;
                  }
                  setState(() {
                    _formCategory = val!;
                    _formSubCategory = getFormSubCategories(
                      _formCategory,
                    ).first;
                  });
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: _buildFormDropdown(
                label: 'Sub-category',
                value: _formSubCategory,
                options: subCats,
                onChanged: (val) {
                  if (val == '+ Create Custom...') {
                    _showCreateSubCategoryDialog();
                    return;
                  }
                  setState(() => _formSubCategory = val!);
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _showCreateCategoryDialog() async {
    final textCtrl = TextEditingController();
    bool isLoading = false;
    String? errorText;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Text(
                'Create New Category',
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                  fontSize: 18,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Enter name of the category to add to catalog.',
                    style: GoogleFonts.outfit(
                      color: AppTheme.textSecondary,
                      fontSize: 13.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: textCtrl,
                    decoration: InputDecoration(
                      labelText: 'Category Name',
                      labelStyle: GoogleFonts.outfit(fontSize: 14),
                      errorText: errorText,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(
                          color: AppTheme.borderColor,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(
                          color: AppTheme.primaryColor,
                          width: 1.5,
                        ),
                      ),
                    ),
                    style: GoogleFonts.outfit(fontSize: 14),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isLoading ? null : () => Navigator.pop(context),
                  child: Text(
                    'Cancel',
                    style: GoogleFonts.outfit(
                      color: AppTheme.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: isLoading
                      ? null
                      : () async {
                          final name = textCtrl.text.trim();
                          if (name.isEmpty) {
                            setDialogState(
                              () => errorText = 'Name cannot be empty',
                            );
                            return;
                          }

                          setDialogState(() {
                            isLoading = true;
                            errorText = null;
                          });

                          try {
                            final response = await ApiClient().post(
                              '/products/categories',
                              {'name': name},
                            );

                            if (response.statusCode == 201) {
                              final body = jsonDecode(response.body);
                              if (body['success'] == true) {
                                // Reload categories
                                await _loadCategories();
                                setState(() {
                                  _formCategory = name;
                                  _formSubCategory = getFormSubCategories(
                                    _formCategory,
                                  ).first;
                                });
                                if (context.mounted) Navigator.pop(context);
                                return;
                              }
                            }

                            final errMsg =
                                jsonDecode(response.body)['message'] ??
                                'Failed to create category';
                            setDialogState(() {
                              isLoading = false;
                              errorText = errMsg;
                            });
                          } catch (e) {
                            setDialogState(() {
                              isLoading = false;
                              errorText = 'Error: $e';
                            });
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                  ),
                  child: isLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : Text(
                          'Create',
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showCreateSubCategoryDialog() async {
    final textCtrl = TextEditingController();
    bool isLoading = false;
    String? errorText;

    // Find the category ID from the _backendCategories list
    String? categoryId;
    if (_backendCategories.isNotEmpty) {
      final matchingCat = _backendCategories.firstWhere(
        (c) =>
            c['name'].toString().toLowerCase() == _formCategory.toLowerCase(),
        orElse: () => null,
      );
      if (matchingCat != null) {
        categoryId =
            matchingCat['id']?.toString() ?? matchingCat['_id']?.toString();
      }
    }

    if (categoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Cannot add subcategory to an unsaved category. Please select or create a primary category first.',
          ),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Text(
                'Create New Sub-category',
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                  fontSize: 18,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Enter sub-category name to add under $_formCategory.',
                    style: GoogleFonts.outfit(
                      color: AppTheme.textSecondary,
                      fontSize: 13.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: textCtrl,
                    decoration: InputDecoration(
                      labelText: 'Sub-category Name',
                      labelStyle: GoogleFonts.outfit(fontSize: 14),
                      errorText: errorText,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(
                          color: AppTheme.borderColor,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(
                          color: AppTheme.primaryColor,
                          width: 1.5,
                        ),
                      ),
                    ),
                    style: GoogleFonts.outfit(fontSize: 14),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isLoading ? null : () => Navigator.pop(context),
                  child: Text(
                    'Cancel',
                    style: GoogleFonts.outfit(
                      color: AppTheme.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: isLoading
                      ? null
                      : () async {
                          final name = textCtrl.text.trim();
                          if (name.isEmpty) {
                            setDialogState(
                              () => errorText = 'Name cannot be empty',
                            );
                            return;
                          }

                          setDialogState(() {
                            isLoading = true;
                            errorText = null;
                          });

                          try {
                            final response = await ApiClient().post(
                              '/products/categories/$categoryId/subcategories',
                              {'name': name},
                            );

                            if (response.statusCode == 201) {
                              final body = jsonDecode(response.body);
                              if (body['success'] == true) {
                                // Reload categories
                                await _loadCategories();
                                setState(() {
                                  _formSubCategory = name;
                                });
                                if (context.mounted) Navigator.pop(context);
                                return;
                              }
                            }

                            final errMsg =
                                jsonDecode(response.body)['message'] ??
                                'Failed to create sub-category';
                            setDialogState(() {
                              isLoading = false;
                              errorText = errMsg;
                            });
                          } catch (e) {
                            setDialogState(() {
                              isLoading = false;
                              errorText = 'Error: $e';
                            });
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                  ),
                  child: isLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : Text(
                          'Create',
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildFormDropdown({
    required String label,
    required String value,
    required List<String> options,
    required ValueChanged<String?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppTheme.borderColor),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              value: value,
              onChanged: onChanged,
              dropdownColor: Colors.white,
              borderRadius: BorderRadius.circular(12),
              icon: const Icon(
                Icons.unfold_more_rounded,
                size: 20,
                color: AppTheme.textSecondary,
              ),
              items: options
                  .map(
                    (val) => DropdownMenuItem(
                      value: val,
                      child: Text(
                        val,
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildVariantCard(
    int index,
    Map<String, dynamic> variant, {
    required bool isMobile,
  }) {


    final bool isLiquid = ['ml', 'lit'].contains(variant['packSizeUnit']);
    final bool isSolid = ['gm', 'kg'].contains(variant['packSizeUnit']);

    // Get compatible units for base packing
    List<String> basePackingUnits = [];
    if (isLiquid) {
      basePackingUnits = ['lit', 'ml'];
    } else if (isSolid) {
      basePackingUnits = ['kg', 'gm'];
    } else {
      basePackingUnits = ['pcs'];
    }

    // Ensure basePackingUnit is in the valid list, otherwise reset to default
    if (!basePackingUnits.contains(variant['basePackingUnit'])) {
      variant['basePackingUnit'] = basePackingUnits.first;
    }

    final String packSizeHint = switch (variant['packSizeUnit']) {
      'ml' => 'e.g. 250',
      'lit' => 'e.g. 1',
      'gm' => 'e.g. 500',
      'kg' => 'e.g. 1',
      'pcs' => 'e.g. 1',
      _ => 'e.g. 250',
    };

    final Widget packSizeValueField = _buildFormTextField(
      label: 'Pack Size',
      hint: packSizeHint,
      controller: variant['packSizeVal'],
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
      ],
      validator: (val) {
        if (val == null || val.trim().isEmpty) return 'Required';
        final numVal = double.tryParse(val);
        if (numVal == null || numVal <= 0) return 'Invalid';
        return null;
      },
      isCompact: true,
    );

    final Widget packSizeUnitField = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Pack Unit',
          style: GoogleFonts.outfit(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          height: 32,
          width: double.infinity,
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.borderColor),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              value:
                  [
                    'ml',
                    'lit',
                    'gm',
                    'kg',
                    'pcs',
                  ].contains(variant['packSizeUnit'])
                  ? variant['packSizeUnit']
                  : 'lit',
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    variant['packSizeUnit'] = val;
                    // Auto-resolve base packing unit category mismatch
                    if (['ml', 'lit'].contains(val)) {
                      variant['basePackingUnit'] = 'lit';
                    } else if (['gm', 'kg'].contains(val)) {
                      variant['basePackingUnit'] = 'kg';
                    } else {
                      variant['basePackingUnit'] = 'pcs';
                    }
                  });
                  variant['recalculate']();
                }
              },
              dropdownColor: Colors.white,
              borderRadius: BorderRadius.circular(12),
              icon: const Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 16,
                color: AppTheme.textSecondary,
              ),
              items: const [
                DropdownMenuItem(value: 'ml', child: Text('ml')),
                DropdownMenuItem(value: 'lit', child: Text('lit')),
                DropdownMenuItem(value: 'gm', child: Text('gm')),
                DropdownMenuItem(value: 'kg', child: Text('kg')),
                DropdownMenuItem(value: 'pcs', child: Text('pcs')),
              ],
              style: GoogleFonts.outfit(
                fontSize: 13,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
        ),
      ],
    );

    final String basePackingHint = switch (variant['basePackingUnit']) {
      'ml' => 'e.g. 1000',
      'lit' => 'e.g. 10',
      'gm' => 'e.g. 1000',
      'kg' => 'e.g. 10',
      'pcs' => 'e.g. 10',
      _ => 'e.g. 10',
    };

    final Widget basePackingValueField = _buildFormTextField(
      label: 'Base Packing',
      hint: basePackingHint,
      controller: variant['basePackingVal'],
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
      ],
      validator: (val) {
        if (val == null || val.trim().isEmpty) return 'Required';
        final numVal = double.tryParse(val);
        if (numVal == null || numVal <= 0) return 'Invalid';
        return null;
      },
      isCompact: true,
    );

    final Widget basePackingUnitField = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Base Unit',
          style: GoogleFonts.outfit(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          height: 32,
          width: double.infinity,
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.borderColor),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              value: variant['basePackingUnit'],
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    variant['basePackingUnit'] = val;
                  });
                }
              },
              dropdownColor: Colors.white,
              borderRadius: BorderRadius.circular(12),
              icon: const Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 16,
                color: AppTheme.textSecondary,
              ),
              items: basePackingUnits.map((u) {
                return DropdownMenuItem<String>(value: u, child: Text(u));
              }).toList(),
              style: GoogleFonts.outfit(
                fontSize: 13,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
        ),
      ],
    );

    final sizeFields = isMobile
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: packSizeValueField),
                  const SizedBox(width: 12),
                  Expanded(child: packSizeUnitField),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: basePackingValueField),
                  const SizedBox(width: 12),
                  Expanded(child: basePackingUnitField),
                ],
              ),
            ],
          )
        : Row(
            children: [
              Expanded(flex: 2, child: packSizeValueField),
              const SizedBox(width: 12),
              Expanded(flex: 2, child: packSizeUnitField),
              const SizedBox(width: 12),
              Expanded(flex: 2, child: basePackingValueField),
              const SizedBox(width: 12),
              Expanded(flex: 2, child: basePackingUnitField),
            ],
          );

    // MRP rate is always first
    final List<Widget> rateRowChildren = [
      Expanded(
        child: _buildFormTextField(
          label: 'MRP Rate (Per Unit)',
          hint: 'e.g. 2400',
          controller: variant['compareRate'],
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
          ],
          validator: (val) {
            if (val == null || val.trim().isEmpty) return 'Required';
            final numVal = double.tryParse(val);
            if (numVal == null || numVal <= 0) return 'Must be > 0';
            // MRP rate must be >= Tier 1 selling rate
            final t1RateVal = double.tryParse(
              (variant['rates'] as Map<String, TextEditingController>)['1']
                  ?.text
                  .trim() ??
                  '',
            );
            if (t1RateVal != null && numVal < t1RateVal) {
              return 'MRP ≥ Tier 1';
            }
            return null;
          },
          prefixIcon: const Icon(
            Icons.currency_rupee_rounded,
            size: 14,
            color: AppTheme.textSecondary,
          ),
          isCompact: true,
        ),
      ),
    ];

    // Build the fields for each tier dynamically
    final ratesMap = variant['rates'] as Map<String, TextEditingController>;
    final List<Widget> dynamicTierFields = [];

    for (var tier in _priceTiers) {
      final id = tier['id']!;
      final ctrl = ratesMap[id];
      if (ctrl != null) {
        final isPrimary = id == '1';
        dynamicTierFields.add(
          _buildFormTextField(
            label: '${tier['name']} Rate',
            hint: isPrimary ? 'e.g. 950' : 'Optional',
            controller: ctrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
            ],
            validator: isPrimary
                ? (val) {
                    if (val == null || val.trim().isEmpty) return 'Required';
                    final numVal = double.tryParse(val);
                    if (numVal == null || numVal <= 0) return 'Must be > 0';
                    return null;
                  }
                : (val) {
                    if (val == null || val.trim().isEmpty) return null; // Optional
                    final numVal = double.tryParse(val);
                    if (numVal == null || numVal <= 0) return 'Must be > 0';
                    // Tier 2/3 rates should be <= Tier 1 (descending price tiers)
                    final t1Val = double.tryParse(
                      (variant['rates'] as Map<String, TextEditingController>)['1']
                          ?.text
                          .trim() ??
                          '',
                    );
                    if (t1Val != null && numVal > t1Val) {
                      return '≤ Tier 1';
                    }
                    return null;
                  },
            prefixIcon: const Icon(
              Icons.currency_rupee_rounded,
              size: 14,
              color: AppTheme.textSecondary,
            ),
            isCompact: true,
          ),
        );
      }
    }

    // Lay out the fields in rows of 2
    final List<Widget> rateRows = [];

    // First row: MRP + Primary Tier (Tier 1)
    if (dynamicTierFields.isNotEmpty) {
      rateRowChildren.add(const SizedBox(width: 12));
      rateRowChildren.add(Expanded(child: dynamicTierFields[0]));
    }
    rateRows.add(Row(children: rateRowChildren));

    // Next rows: 2 tiers per row
    for (int i = 1; i < dynamicTierFields.length; i += 2) {
      final List<Widget> rowItems = [];
      rowItems.add(Expanded(child: dynamicTierFields[i]));
      if (i + 1 < dynamicTierFields.length) {
        rowItems.add(const SizedBox(width: 12));
        rowItems.add(Expanded(child: dynamicTierFields[i + 1]));
      } else {
        rowItems.add(const SizedBox(width: 12));
        rowItems.add(const Spacer()); // fill empty spot
      }
      rateRows.add(const SizedBox(height: 10));
      rateRows.add(Row(children: rowItems));
    }

    final rateFields = Column(children: rateRows);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Container(
          decoration: const BoxDecoration(
            border: Border(
              left: BorderSide(color: AppTheme.primaryColor, width: 3),
            ),
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Text(
                        'Variant Option ${index + 1}',
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  if (_formVariants.length > 1)
                    IconButton(
                      onPressed: () => _removeVariant(index),
                      icon: const Icon(
                        Icons.delete_outline_rounded,
                        size: 18,
                        color: AppTheme.error,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      tooltip: 'Remove Variant',
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  sizeFields,
                  const SizedBox(height: 12),
                  _buildFormTextField(
                    label: 'Base Quantity (Units per Carton)',
                    hint: 'e.g. 12',
                    controller: variant['baseQuantity'],
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Base quantity is required';
                      }
                      final numVal = int.tryParse(val.trim());
                      if (numVal == null || numVal < 1) {
                        return 'Must be at least 1';
                      }
                      if (numVal > 10000) {
                        return 'Must be 10,000 or less';
                      }
                      return null;
                    },
                    isCompact: true,
                  ),
                  const SizedBox(height: 16),
                  rateFields,
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTagsCard() {
    return _buildSectionCard(
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
              controller: _tagController,
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
                    onTap: () {
                      final val = _tagController.text;
                      if (val.trim().isNotEmpty &&
                          !_tags.contains(val.trim())) {
                        setState(() {
                          _tags.add(val.trim());
                          _tagController.clear();
                        });
                      }
                    },
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
              onSubmitted: (val) {
                if (val.trim().isNotEmpty && !_tags.contains(val.trim())) {
                  setState(() {
                    _tags.add(val.trim());
                    _tagController.clear();
                  });
                }
              },
            ),
          ),
          if (_tags.isNotEmpty) const SizedBox(height: 20),
          if (_tags.isNotEmpty)
            Wrap(
              spacing: 8,
              runSpacing: 10,
              children: _tags.map((tag) {
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
                        onTap: () {
                          setState(() {
                            _tags.remove(tag);
                          });
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withValues(
                              alpha: 0.15,
                            ),
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
      ),
    );
  }
}
