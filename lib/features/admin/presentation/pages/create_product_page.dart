import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kd_pannel/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:html_editor_enhanced/html_editor.dart';
import 'package:image_editor_plus/image_editor_plus.dart';
import 'package:image_picker/image_picker.dart';

class CreateProductPage extends StatefulWidget {
  final Map<String, dynamic>? initialData;
  final ValueChanged<Map<String, dynamic>> onSave;

  const CreateProductPage({super.key, this.initialData, required this.onSave});

  @override
  State<CreateProductPage> createState() => _CreateProductPageState();
}

class _CreateProductPageState extends State<CreateProductPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _vendorController = TextEditingController();
  final _tagController = TextEditingController();
  final HtmlEditorController _descriptionController = HtmlEditorController();
  List<String> _tags = [];
  List<Map<String, dynamic>> _formVariants = [];
  List<Map<String, String>> _priceTiers = [
    {'id': '1', 'name': 'Tier 1 (10-30)'},
    {'id': '2', 'name': 'Tier 2 (30-50)'},
    {'id': '3', 'name': 'Tier 3 (50+)'},
  ];
  List<Uint8List> _productImages = [];
  final ImagePicker _picker = ImagePicker();

  String _formCategory = 'Irrigation';
  String _formSubCategory = 'Drip';
  bool _formInStock = true;

  final List<String> _categories = [
    'Irrigation',
    'Seeds',
    'Machinery',
    'Fertilizers',
  ];

  @override
  void initState() {
    super.initState();
    final data = widget.initialData;
    if (data != null) {
      _nameController.text = data['name'] ?? '';
      _vendorController.text = data['vendor'] ?? '';
      _formCategory = data['category'] ?? 'Irrigation';
      _formSubCategory = data['subCategory'] ?? 'Drip';
      _formInStock = data['inStock'] ?? true;
      _tags = List<String>.from(data['tags'] ?? []);

      if (data['priceTiers'] != null) {
        try {
          _priceTiers = List<Map<String, String>>.from(
            (data['priceTiers'] as List).map(
              (t) => Map<String, String>.from(t as Map),
            ),
          );
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

      Future.delayed(const Duration(milliseconds: 100), () {
        _descriptionController.setText(data['description'] ?? '');
      });
    } else {
      _addVariant();
      Future.delayed(const Duration(milliseconds: 100), () {
        _descriptionController.clear();
      });
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
    _tagController.dispose();
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
    // Note: HtmlEditorController does not have a dispose() method in html_editor_enhanced.
    // Its lifecycle and webview resources are managed internally by the package.
    super.dispose();
  }

  void _addVariant({Map<String, dynamic>? data}) {
    final String initialPrice = data?['price'] ?? '';
    final String initialCompare = data?['compareAtPrice'] ?? '';
    final String initialPackSize = data?['packSize'] ?? '';
    final String initialQty = data?['baseQuantity'] ?? '1';
    final String initialBasePacking = data?['basePacking'] ?? '';

    // Parse pack size
    String packVal = '1';
    String packUnit = 'lit';
    if (initialPackSize.isNotEmpty) {
      final parsed = _parsePackSize(initialPackSize);
      packVal = parsed['val'] ?? '1';
      packUnit = (parsed['unit'] ?? 'lit').toLowerCase();
      if (packUnit.isEmpty) packUnit = 'lit';
    }

    // Parse base packing
    String basePackVal = '1';
    String basePackUnit = 'lit';
    if (initialBasePacking.isNotEmpty) {
      final parsed = _parsePackSize(initialBasePacking);
      basePackVal = parsed['val'] ?? '1';
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
      final String rateVal =
          data?['rates']?[id] ??
          data?['unitPriceRate${id == "1" ? "" : id}'] ??
          '';
      rates[id] = TextEditingController(text: _parseRate(rateVal));
      computed[id] = TextEditingController(
        text: data?['price$id'] ?? data?['computedPrices']?[id] ?? '',
      );
    }

    // Handle initial fallback or legacy values for rates
    final String legacyUnitPriceRate =
        data?['unitPriceRate'] ?? data?['price'] ?? '';
    final String legacyUnitCompareRate =
        data?['unitCompareRate'] ?? data?['compareAtPrice'] ?? '';

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
        'image': data?['image'],
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
    switch (cat) {
      case 'Irrigation':
        return ['Drip', 'Sprinkler'];
      case 'Seeds':
        return ['Vegetable', 'Grain'];
      case 'Machinery':
        return ['Pumps', 'Tillers'];
      case 'Fertilizers':
        return ['Organic', 'NPK'];
      default:
        return ['Other'];
    }
  }

  Future<void> _pickAndEditImage({
    required Function(Uint8List) onImageEdited,
  }) async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      final Uint8List imageBytes = await image.readAsBytes();
      if (!mounted) return;

      final Uint8List? editedImage = await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => ImageEditor(image: imageBytes)),
      );

      if (editedImage != null) {
        onImageEdited(editedImage);
      }
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

    String description = '';
    try {
      description = await _descriptionController.getText();
    } catch (_) {}

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
        'image': v['image'],
        'unitCompareRate': mrpRateWithSuffix,
        'rates': ratesJson,
        'computedPrices': computedJson,

        // Also map legacy properties for safety & backward compatibility
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

    final data = {
      'sku':
          widget.initialData?['sku'] ??
          'PROD-NEW-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
      'name': _nameController.text.trim(),
      'category': _formCategory,
      'subCategory': _formSubCategory,
      'vendor': _vendorController.text.trim(),
      'price': displayPrice,
      'inStock': _formInStock,
      'description': description,
      'variants': variantsData,
      'images': _productImages,
      'tags': _tags,
      'priceTiers': _priceTiers,
    };

    widget.onSave(data);
    if (!mounted) return;
    Navigator.pop(context);
  }

  void _addTag() {
    final text = _tagController.text.trim();
    if (text.isNotEmpty && !_tags.contains(text)) {
      setState(() {
        _tags.add(text);
        _tagController.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
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
                    onPressed: () => Navigator.pop(context),
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
                    onPressed: _handleSave,
                    icon: const Icon(Icons.check_rounded, size: 18),
                    label: Text(isEdit ? 'Save Changes' : 'Publish Product'),
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
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: AppTheme.borderColor),
                            borderRadius: BorderRadius.circular(12),
                            color: Colors.white,
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: HtmlEditor(
                              controller: _descriptionController,
                              htmlEditorOptions: const HtmlEditorOptions(
                                hint: '',
                                shouldEnsureVisible: true,
                              ),
                              htmlToolbarOptions: const HtmlToolbarOptions(
                                toolbarPosition: ToolbarPosition.aboveEditor,
                                toolbarType: ToolbarType.nativeScrollable,
                                defaultToolbarButtons: [
                                  StyleButtons(),
                                  FontSettingButtons(
                                    fontName: false,
                                    fontSizeUnit: false,
                                  ),
                                  FontButtons(
                                    superscript: false,
                                    subscript: false,
                                    strikethrough: false,
                                  ),
                                  ColorButtons(),
                                  ListButtons(listStyles: false),
                                  ParagraphButtons(
                                    lineHeight: false,
                                    caseConverter: false,
                                  ),
                                  InsertButtons(
                                    video: false,
                                    audio: false,
                                    otherFile: false,
                                  ),
                                  OtherButtons(fullscreen: false, help: false),
                                ],
                              ),
                              otherOptions: const OtherOptions(height: 450),
                            ),
                          ),
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
                            return null;
                          },
                        ),
                        const SizedBox(height: 20),
                        _buildTagsSection(),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildSectionCard(
                    title: 'Publishing Status',
                    icon: Icons.visibility_outlined,
                    child: _buildAvailabilitySelector(),
                  ),
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
              Row(
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
                  Text(
                    title,
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ],
              ),
              if (action != null) action,
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () {
            _pickAndEditImage(
              onImageEdited: (editedImage) {
                setState(() {
                  _productImages.add(editedImage);
                });
              },
            );
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 32),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.02),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppTheme.primaryColor.withValues(alpha: 0.3),
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.cloud_upload_outlined,
                    color: AppTheme.primaryColor,
                    size: 28,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Click to upload images',
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'SVG, PNG, JPG or GIF (max. 5MB)',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_productImages.isNotEmpty) ...[
          const SizedBox(height: 16),
          SizedBox(
            height: 80,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _productImages.length,
              itemBuilder: (context, index) {
                return Stack(
                  children: [
                    Container(
                      width: 80,
                      margin: const EdgeInsets.only(right: 12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.borderColor),
                        image: DecorationImage(
                          image: MemoryImage(_productImages[index]),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    Positioned(
                      top: 4,
                      right: 16,
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
                            size: 12,
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
        ],
      ],
    );
  }

  Widget _buildCategoryDropdowns() {
    final subCats = getFormSubCategories(_formCategory);
    if (!subCats.contains(_formSubCategory)) _formSubCategory = subCats.first;

    return Column(
      children: [
        _buildFormDropdown(
          label: 'Primary Category',
          value: _formCategory,
          options: _categories,
          onChanged: (val) {
            setState(() {
              _formCategory = val!;
              _formSubCategory = getFormSubCategories(_formCategory).first;
            });
          },
        ),
        const SizedBox(height: 20),
        _buildFormDropdown(
          label: 'Sub-category',
          value: _formSubCategory,
          options: subCats,
          onChanged: (val) => setState(() => _formSubCategory = val!),
        ),
      ],
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

  Widget _buildAvailabilitySelector() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _formInStock
            ? AppTheme.success.withValues(alpha: 0.05)
            : AppTheme.error.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _formInStock
              ? AppTheme.success.withValues(alpha: 0.2)
              : AppTheme.error.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _formInStock
                  ? AppTheme.success.withValues(alpha: 0.1)
                  : AppTheme.error.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _formInStock
                  ? Icons.check_circle_outline_rounded
                  : Icons.remove_circle_outline_rounded,
              color: _formInStock ? AppTheme.success : AppTheme.error,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _formInStock ? 'Active Product' : 'Draft / Out of Stock',
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _formInStock ? AppTheme.success : AppTheme.error,
                  ),
                ),
                Text(
                  _formInStock
                      ? 'This product will be visible to buyers.'
                      : 'This product is currently hidden.',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: _formInStock,
            activeColor: Colors.white,
            activeTrackColor: AppTheme.success,
            inactiveThumbColor: Colors.white,
            inactiveTrackColor: AppTheme.error.withValues(alpha: 0.5),
            onChanged: (val) => setState(() => _formInStock = val),
          ),
        ],
      ),
    );
  }

  Widget _buildTagsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Product Tags',
          style: GoogleFonts.outfit(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.only(left: 16, right: 8, top: 4, bottom: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppTheme.borderColor),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _tagController,
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    color: AppTheme.textPrimary,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Press enter to add tags...',
                    hintStyle: GoogleFonts.outfit(
                      color: AppTheme.textSecondary,
                      fontSize: 14,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                  ),
                  onSubmitted: (_) => _addTag(),
                ),
              ),
              IconButton(
                onPressed: _addTag,
                icon: const Icon(
                  Icons.add_circle_rounded,
                  color: AppTheme.primaryColor,
                  size: 24,
                ),
                splashRadius: 20,
              ),
            ],
          ),
        ),
        if (_tags.isNotEmpty) const SizedBox(height: 12),
        if (_tags.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _tags.map((tag) {
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppTheme.primaryColor.withValues(alpha: 0.3),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryColor.withValues(alpha: 0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      tag,
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 6),
                    InkWell(
                      onTap: () => setState(() => _tags.remove(tag)),
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close,
                          size: 10,
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
    );
  }

  Widget _buildVariantCard(
    int index,
    Map<String, dynamic> variant, {
    required bool isMobile,
  }) {
    final imagePickerWidget = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Image',
          style: GoogleFonts.outfit(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: () {
            _pickAndEditImage(
              onImageEdited: (editedImage) {
                setState(() => variant['image'] = editedImage);
              },
            );
          },
          child: Container(
            height: 70,
            width: 70,
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.borderColor),
              image: variant['image'] != null && variant['image'] is Uint8List
                  ? DecorationImage(
                      image: MemoryImage(variant['image'] as Uint8List),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: variant['image'] == null || variant['image'] is! Uint8List
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.add_photo_alternate_outlined,
                          color: AppTheme.textSecondary,
                          size: 20,
                        ),
                      ],
                    ),
                  )
                : null,
          ),
        ),
      ],
    );

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

    final Widget packSizeValueField = _buildFormTextField(
      label: 'Pack Size',
      hint: 'e.g. 250',
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

    final Widget basePackingValueField = _buildFormTextField(
      label: 'Base Packing',
      hint: 'e.g. 10',
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
            if (numVal == null || numVal <= 0) return 'Invalid';
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
                    if (numVal == null || numVal <= 0) return 'Invalid';
                    return null;
                  }
                : null,
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
              isMobile
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        imagePickerWidget,
                        const SizedBox(height: 16),
                        sizeFields,
                        const SizedBox(height: 16),
                        rateFields,
                      ],
                    )
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        imagePickerWidget,
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            children: [
                              sizeFields,
                              const SizedBox(height: 12),
                              rateFields,
                            ],
                          ),
                        ),
                      ],
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
