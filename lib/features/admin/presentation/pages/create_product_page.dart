import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:kd_pannel/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_quill_delta_from_html/flutter_quill_delta_from_html.dart';
import 'package:vsc_quill_delta_to_html/vsc_quill_delta_to_html.dart'
    hide TableRow;
import 'package:kd_pannel/features/shared/widgets/morphing_save_button.dart';
import 'package:image_picker/image_picker.dart';
import 'package:kd_pannel/core/network/api_client.dart';
import 'package:kd_pannel/features/admin/presentation/widgets/product/mobile_preview_dialog.dart';
import 'package:kd_pannel/features/admin/presentation/widgets/product/product_variant_card.dart';
import 'package:kd_pannel/features/admin/presentation/widgets/product/product_media_uploader.dart';
import 'package:kd_pannel/features/admin/presentation/widgets/product/product_collections_card.dart';
import 'package:kd_pannel/core/repositories/product_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kd_pannel/features/admin/presentation/bloc/products_bloc.dart';
import 'package:kd_pannel/features/admin/presentation/bloc/products_event.dart';

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
  final _dosagePerLiterController = TextEditingController();
  final _dosagePerAcreController = TextEditingController();
  final _dosageMethodController = TextEditingController();
  String _dosagePerLiterUnit = 'gm';
  String _dosagePerAcreUnit = 'gm';
  final List<String> _dosageUnits = [
    'gm',
    'kg',
    'lit',
    'ml',
  ];
  final _orderController = TextEditingController(text: '0');
  final Map<String, TextEditingController> _customOrdersControllers = {};
  late final quill.QuillController _descriptionController;
  bool _isHtmlMode = false;
  final _htmlDescriptionController = TextEditingController();
  List<Map<String, dynamic>> _formVariants = [];
  List<Map<String, String>> _priceTiers = [
    {'id': '1', 'name': 'Tier 1 (10-30)'},
    {'id': '2', 'name': 'Tier 2 (30-50)'},
    {'id': '3', 'name': 'Tier 3 (50+)'},
  ];
  final Map<String, String> _googleFontFamilies = {
    'Roboto': 'Roboto',
    'Lato': 'Lato',
    'Poppins': 'Poppins',
    'Montserrat': 'Montserrat',
    'Open Sans': 'Open Sans',
    'Oswald': 'Oswald',
    'Merriweather': 'Merriweather',
    'Playfair Display': 'Playfair Display',
    'Nunito': 'Nunito',
    'Raleway': 'Raleway',
    'Ubuntu': 'Ubuntu',
    'Pacifico': 'Pacifico',
    'Outfit': 'Outfit',
    'Inter': 'Inter',
  };
  List<Uint8List> _productImages = [];
  // URLs of images already uploaded to GCS (shown in edit mode)
  List<String> _existingImageUrls = [];
  List<String> _existingMediumUrls = [];
  List<String> _existingOriginalUrls = [];
  final ImagePicker _picker = ImagePicker();

  final _tagController = TextEditingController();
  List<String> _tags = [];
  bool _inStock = true;
  bool _isFeatured = false;
  List<String> _assignedCollections = [];
  List<String> _formCategories = [];
  List<String> _formSubCategories = [];
  List<dynamic> _backendCategories = [];
  List<dynamic> _backendCollections = [];
  Map<String, String> _collectionIdToName = {};
  String? _formSelectedCollection;
  String? _formSelectedSubCollection;
  bool _isSaving = false;
  bool _isLoadingDetails = false;
  bool _isTransitionComplete = false;
  late final Stopwatch _perfStopwatch;

  static const Map<String, List<String>> _categoryToMethods = {
    'Fertilizer': [
      'Broadcasting',
      'Basal Application',
      'Top Dressing',
      'Row Placement',
      'Band Placement',
      'Hill Placement',
      'Side Dressing',
      'Deep Placement',
      'Plough Sole Placement',
      'Localized Placement',
      'Spot Application',
      'Ring Application',
      'Fertigation',
      'Foliar Spray',
      'Starter Solution',
      'Soil Application',
    ],
    'Water Soluble Fertilizer (WSF)': [
      'Fertigation',
      'Foliar Spray',
      'Soil Drenching',
    ],
    'WSF': ['Fertigation', 'Foliar Spray', 'Soil Drenching'],
    'Bio Fertilizer': [
      'Fertigation',
      'Foliar Spray',
      'Seed Treatment',
      'Seedling Root Dip',
      'Root Dip',
      'Soil Application',
    ],
    'Micronutrient': [
      'Fertigation',
      'Foliar Spray',
      'Seed Treatment',
      'Soil Application',
    ],
    'PGR': [
      'Fertigation',
      'Foliar Spray',
      'Soil Drenching',
      'Root Drenching',
      'Trunk Injection',
    ],
    'Insecticide': [
      'Seed Treatment',
      'Soil Application',
      'Soil Drenching',
      'Root Drenching',
      'Granule Application',
      'Bait Application',
      'Spraying',
      'Dusting',
      'Fumigation',
      'Trunk Injection',
    ],
    'Fungicide': [
      'Seed Treatment',
      'Soil Application',
      'Soil Drenching',
      'Root Drenching',
      'Spraying',
      'Nursery Treatment',
      'Trunk Injection',
      'Wound Dressing',
    ],
    'Herbicide': [
      'Spot Application',
      'Spraying',
      'Pre-Plant Application',
      'Pre-Plant Incorporated (PPI)',
      'Pre-Emergence Spray',
      'Early Post-Emergence Spray',
      'Post-Emergence Spray',
      'Directed Spray',
      'Shielded Spray',
      'Spot Spray',
      'Wiper Application',
    ],
    'Biopesticide': [
      'Seed Treatment',
      'Soil Application',
      'Soil Drenching',
      'Root Drenching',
      'Spraying',
    ],
    'Organic Fertilizer': ['Soil Application'],
  };

  void _updateDosageMethod() {
    final methods = <String>{};
    for (final cat in _formCategories) {
      final key = _categoryToMethods.keys.firstWhere(
        (k) => k.toLowerCase() == cat.toLowerCase(),
        orElse: () => '',
      );
      if (key.isNotEmpty) {
        methods.addAll(_categoryToMethods[key]!);
      }
    }

    final options = methods.toList()..sort();
    final currentMethod = _dosageMethodController.text;

    if (currentMethod.isNotEmpty &&
        currentMethod != 'Select Method' &&
        options.isNotEmpty &&
        !options.contains(currentMethod)) {
      // If categories changed and the previous method is no longer valid, reset it
      _dosageMethodController.text = 'Select Method';
    }
  }

  @override
  void initState() {
    _perfStopwatch = Stopwatch()..start();
    debugPrint('[PERF] CreateProductPage.initState started');
    super.initState();

    final data = widget.initialData;
    quill.Document doc;
    if (data != null &&
        data['description'] != null &&
        data['description'].toString().isNotEmpty) {
      try {
        final rawHtml = data['description'].toString();
        // Convert class-based alignment to inline styles so HtmlToDelta can parse them
        final sanitizedHtml = rawHtml
            .replaceAll(
              'class="ql-align-center"',
              'style="text-align: center;"',
            )
            .replaceAll('class="ql-align-right"', 'style="text-align: right;"')
            .replaceAll(
              'class="ql-align-justify"',
              'style="text-align: justify;"',
            )
            .replaceAll(
              RegExp(
                r'''class=\s*["']ql-align-center["']''',
                caseSensitive: false,
              ),
              'style="text-align: center;"',
            )
            .replaceAll(
              RegExp(
                r'''class=\s*["']ql-align-right["']''',
                caseSensitive: false,
              ),
              'style="text-align: right;"',
            )
            .replaceAll(
              RegExp(
                r'''class=\s*["']ql-align-justify["']''',
                caseSensitive: false,
              ),
              'style="text-align: justify;"',
            );

        final delta = HtmlToDelta().convert(sanitizedHtml);
        doc = quill.Document.fromDelta(delta);
        debugPrint(
          '[PERF] CreateProductPage.initState - Parsed description HTML to Quill Delta. Elapsed: ${_perfStopwatch.elapsedMilliseconds}ms',
        );
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
      debugPrint(
        '[PERF] CreateProductPage.initState - data is NOT null (Edit Mode). Elapsed: ${_perfStopwatch.elapsedMilliseconds}ms',
      );
      _nameController.text = data['name'] ?? data['title'] ?? '';
      _vendorController.text = data['vendor'] ?? '';
      if (data['dosage'] != null) {
        final dosage = data['dosage'] as Map;
        final perLiter = dosage['perLiterWater']?.toString() ?? '';
        final perAcre = dosage['perAcre']?.toString() ?? '';

        if (perLiter.isNotEmpty) {
          final parts = perLiter.split(' ');
          if (parts.length >= 2) {
            final unit = parts.last.toLowerCase();
            if (_dosageUnits.contains(unit)) {
              _dosagePerLiterUnit = unit;
              _dosagePerLiterController.text =
                  parts.sublist(0, parts.length - 1).join(' ');
            } else {
              _dosagePerLiterController.text = perLiter;
            }
          } else {
            _dosagePerLiterController.text = perLiter;
          }
        }

        if (perAcre.isNotEmpty) {
          final parts = perAcre.split(' ');
          if (parts.length >= 2) {
            final unit = parts.last.toLowerCase();
            if (_dosageUnits.contains(unit)) {
              _dosagePerAcreUnit = unit;
              _dosagePerAcreController.text =
                  parts.sublist(0, parts.length - 1).join(' ');
            } else {
              _dosagePerAcreController.text = perAcre;
            }
          } else {
            _dosagePerAcreController.text = perAcre;
          }
        }

        _dosageMethodController.text = dosage['method'] ?? '';
      }
      _orderController.text = (data['order'] ?? 0).toString();
      final customOrdersMap = data['customOrders'] as Map? ?? {};
      customOrdersMap.forEach((key, val) {
        _customOrdersControllers[key.toString()] = TextEditingController(text: val.toString());
      });
      _htmlDescriptionController.text = data['description']?.toString() ?? '';
      _formCategories = [];
      _formSubCategories = [];
      _tags = List<String>.from(data['tags'] ?? []);
      _inStock = data['availabilityStatus'] != null
          ? data['availabilityStatus'] != 'Out of Stock'
          : (data['inStock'] ?? true);
      _isFeatured = data['isFeatured'] ?? false;
      _assignedCollections = List<String>.from(
        data['assignedCollections'] ?? [],
      );
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
      debugPrint(
        '[PERF] CreateProductPage.initState - data is null (Create Mode). Elapsed: ${_perfStopwatch.elapsedMilliseconds}ms',
      );
      _addVariant();
    }

    _loadCategories();
    _loadCollections();
  }

  Future<void> _loadCategories() async {
    if (widget.preloadedCategories != null &&
        widget.preloadedCategories!.isNotEmpty) {
      setState(() {
        _backendCategories = widget.preloadedCategories!;
        _initializeCategorySelection();
      });
      return;
    }

    try {
      final categories = await ProductRepository().getCategories();
      if (mounted) {
        setState(() {
          _backendCategories = categories;
          _initializeCategorySelection();
        });
      }
    } catch (e) {
      debugPrint('Error fetching categories: $e');
    }
  }

  Future<void> _loadCollections() async {
    try {
      final collections = await ProductRepository().getCollections();
      final Map<String, String> map = {};

      for (var col in collections) {
        final colId = col['id']?.toString() ?? col['_id']?.toString() ?? '';
        final colName = col['name']?.toString() ?? '';

        if (colId.isNotEmpty && colName.isNotEmpty) {
          map[colId] = colName;
          map[colName] = colName;
        }

        final List subs = col['subCollections'] ?? [];
        for (var sub in subs) {
          final subId =
              sub['id']?.toString() ?? sub['_id']?.toString() ?? '';
          final subName = sub['name']?.toString() ?? '';
          if (subId.isNotEmpty && subName.isNotEmpty) {
            map[subId] = '$colName > $subName';
            map[subName] = '$colName > $subName';
          }
        }
      }
      if (mounted) {
        setState(() {
          _backendCollections = collections;
          _collectionIdToName = map;
        });
      }
    } catch (e) {
      debugPrint('Error fetching collections: $e');
    }
  }

  void _initializeCategorySelection() {
    if (widget.initialData != null) {
      final String catString =
          widget.initialData?['category']?.toString() ?? '';
      final String subCatString =
          widget.initialData?['subCategory']?.toString() ?? '';

      final List<String> resolvedCategories = [];
      if (catString.isNotEmpty && catString != 'N/A') {
        resolvedCategories.addAll(
          catString.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty),
        );
      }

      final List<String> resolvedSubCategories = [];
      if (subCatString.isNotEmpty && subCatString != 'N/A') {
        resolvedSubCategories.addAll(
          subCatString
              .split(',')
              .map((s) => s.trim())
              .where((s) => s.isNotEmpty),
        );
      }

      // If category string was not found/parsed (e.g. from local cache with stale model fields),
      // fallback to resolving them via categoryIds/categoryId from _backendCategories
      if (resolvedCategories.isEmpty) {
        final initialCatIds = widget.initialData?['categoryIds'] as List?;
        final List<dynamic> catIds =
            (initialCatIds != null && initialCatIds.isNotEmpty)
            ? initialCatIds
            : (widget.initialData?['categoryId'] != null
                  ? [widget.initialData?['categoryId']]
                  : []);

        String getCleanId(dynamic item) {
          if (item == null) return '';
          if (item is String) return item;
          if (item is Map) {
            return item['id']?.toString() ??
                item['_id']?.toString() ??
                item['\$oid']?.toString() ??
                '';
          }
          return item.toString();
        }

        for (var catId in catIds) {
          if (catId is Map &&
              catId['name'] != null &&
              catId['name'].toString().isNotEmpty) {
            final String name = catId['name'].toString();
            if (!resolvedCategories.contains(name)) {
              resolvedCategories.add(name);
            }
            continue;
          }
          final cleanCatId = getCleanId(catId);
          if (cleanCatId.isEmpty) continue;
          final matchingCat = _backendCategories.firstWhere(
            (c) => (c['id']?.toString() ?? c['_id']?.toString()) == cleanCatId,
            orElse: () => null,
          );
          if (matchingCat != null) {
            final catName = matchingCat['name']?.toString() ?? '';
            if (catName.isNotEmpty && !resolvedCategories.contains(catName)) {
              resolvedCategories.add(catName);
            }
          }
        }
      }

      if (resolvedSubCategories.isEmpty) {
        final initialSubCatIds = widget.initialData?['subCategoryIds'] as List?;
        final List<dynamic> subCatIds =
            (initialSubCatIds != null && initialSubCatIds.isNotEmpty)
            ? initialSubCatIds
            : (widget.initialData?['subCategoryId'] != null
                  ? [widget.initialData?['subCategoryId']]
                  : []);

        String getCleanId(dynamic item) {
          if (item == null) return '';
          if (item is String) return item;
          if (item is Map) {
            return item['id']?.toString() ??
                item['_id']?.toString() ??
                item['\$oid']?.toString() ??
                '';
          }
          return item.toString();
        }

        for (var subCatId in subCatIds) {
          if (subCatId is Map &&
              subCatId['name'] != null &&
              subCatId['name'].toString().isNotEmpty) {
            final String name = subCatId['name'].toString();
            if (!resolvedSubCategories.contains(name)) {
              resolvedSubCategories.add(name);
            }
            continue;
          }
          final cleanSubCatId = getCleanId(subCatId);
          if (cleanSubCatId.isEmpty) continue;
          for (var cat in _backendCategories) {
            final List subs = cat['subCategories'] ?? [];
            final matchingSub = subs.firstWhere(
              (s) =>
                  (s['id']?.toString() ?? s['_id']?.toString()) ==
                  cleanSubCatId,
              orElse: () => null,
            );
            if (matchingSub != null) {
              final subName = matchingSub['name']?.toString() ?? '';
              if (subName.isNotEmpty &&
                  !resolvedSubCategories.contains(subName)) {
                resolvedSubCategories.add(subName);
              }
              break;
            }
          }
        }
      }

      setState(() {
        _formCategories = resolvedCategories;
        _formSubCategories = resolvedSubCategories;
        _updateDosageMethod();
      });
    } else {
      setState(() {
        _formCategories = [];
        _formSubCategories = [];
        _updateDosageMethod();
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

  String _getRateSuffix(String baseUnit) {
    final unit = baseUnit.toLowerCase().trim();
    if (unit == 'ml' || unit == 'lit') return '/lit';
    if (unit == 'gm' || unit == 'kg') return '/kg';
    return '/pcs';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _vendorController.dispose();
    _dosagePerLiterController.dispose();
    _dosagePerAcreController.dispose();
    _dosageMethodController.dispose();
    _orderController.dispose();
    _customOrdersControllers.values.forEach((ctrl) => ctrl.dispose());
    _htmlDescriptionController.dispose();
    for (var variant in _formVariants) {
      variant['price']?.dispose();
      variant['compareAtPrice']?.dispose();
      variant['packSizeVal']?.dispose();
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

  Future<void> _toggleEditorMode() async {
    if (_isHtmlMode) {
      // HTML -> Visual: check if there are advanced/complex tags that could be lost
      final htmlText = _htmlDescriptionController.text.trim();
      final hasComplexHtml =
          htmlText.contains('<table') ||
          htmlText.contains('<details') ||
          htmlText.contains('class="intro"') ||
          htmlText.contains("class='intro'") ||
          htmlText.contains('class="warn"') ||
          htmlText.contains("class='warn'") ||
          htmlText.contains('class="highlight"') ||
          htmlText.contains("class='highlight'") ||
          htmlText.contains('class="table-note"') ||
          htmlText.contains("class='table-note'");

      if (hasComplexHtml) {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(
              'Switch to Visual Editor?',
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
            ),
            content: Text(
              'Your HTML contains advanced layout elements (such as tables, FAQ accordions, or custom styled callout boxes) that the Visual Editor does not support.\n\nSwitching to the Visual Editor will discard these advanced formats.',
              style: GoogleFonts.outfit(),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(
                  'Stay in HTML',
                  style: GoogleFonts.outfit(
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.error,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(
                  'Switch Anyway',
                  style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        );
        if (confirmed != true) return;
      }

      // Code -> Visual conversion
      quill.Document doc;
      if (htmlText.isNotEmpty) {
        try {
          final sanitizedHtml = htmlText
              .replaceAll(
                'class="ql-align-center"',
                'style="text-align: center;"',
              )
              .replaceAll(
                'class="ql-align-right"',
                'style="text-align: right;"',
              )
              .replaceAll(
                'class="ql-align-justify"',
                'style="text-align: justify;"',
              )
              .replaceAll(
                RegExp(
                  r'''class=\s*["']ql-align-center["']''',
                  caseSensitive: false,
                ),
                'style="text-align: center;"',
              )
              .replaceAll(
                RegExp(
                  r'''class=\s*["']ql-align-right["']''',
                  caseSensitive: false,
                ),
                'style="text-align: right;"',
              )
              .replaceAll(
                RegExp(
                  r'''class=\s*["']ql-align-justify["']''',
                  caseSensitive: false,
                ),
                'style="text-align: justify;"',
              );
          final delta = HtmlToDelta().convert(sanitizedHtml);
          doc = quill.Document.fromDelta(delta);
        } catch (e) {
          debugPrint('Error parsing HTML to Quill Delta: $e');
          doc = quill.Document();
        }
      } else {
        doc = quill.Document();
      }
      setState(() {
        _descriptionController.document = doc;
        _isHtmlMode = false;
      });
    } else {
      // Visual -> Code conversion
      try {
        final deltaJson = _descriptionController.document.toDelta().toJson();
        final List<Map<String, dynamic>> normalizedDeltaJson =
            List<Map<String, dynamic>>.from(deltaJson).map((op) {
              if (op.containsKey('attributes')) {
                final attrs = Map<String, dynamic>.from(
                  op['attributes'] as Map,
                );
                bool modified = false;
                if (attrs.containsKey('color') && attrs['color'] is String) {
                  final color = attrs['color'] as String;
                  if (color.startsWith('#') && color.length == 9) {
                    attrs['color'] = '#${color.substring(3)}';
                    modified = true;
                  }
                }
                if (attrs.containsKey('background') &&
                    attrs['background'] is String) {
                  final bg = attrs['background'] as String;
                  if (bg.startsWith('#') && bg.length == 9) {
                    attrs['background'] = '#${bg.substring(3)}';
                    modified = true;
                  }
                }
                if (modified) {
                  return {...op, 'attributes': attrs};
                }
              }
              return op;
            }).toList();

        final converter = QuillDeltaToHtmlConverter(
          normalizedDeltaJson,
          ConverterOptions.forEmail(),
        );
        _htmlDescriptionController.text = _stripHtmlCssAndClasses(
          converter.convert(),
        );
      } catch (e) {
        debugPrint('Error converting Quill Delta to HTML: $e');
        _htmlDescriptionController.text = '';
      }
      setState(() {
        _isHtmlMode = true;
      });
    }
  }

  void _showMobilePreview() {
    String html = '';
    if (_isHtmlMode) {
      html = _htmlDescriptionController.text;
    } else {
      try {
        final deltaJson = _descriptionController.document.toDelta().toJson();
        final List<Map<String, dynamic>> normalizedDeltaJson =
            List<Map<String, dynamic>>.from(deltaJson).map((op) {
              if (op.containsKey('attributes')) {
                final attrs = Map<String, dynamic>.from(
                  op['attributes'] as Map,
                );
                bool modified = false;
                if (attrs.containsKey('color') && attrs['color'] is String) {
                  final color = attrs['color'] as String;
                  if (color.startsWith('#') && color.length == 9) {
                    attrs['color'] = '#' + color.substring(3);
                    modified = true;
                  }
                }
                if (attrs.containsKey('background') &&
                    attrs['background'] is String) {
                  final bg = attrs['background'] as String;
                  if (bg.startsWith('#') && bg.length == 9) {
                    attrs['background'] = '#' + bg.substring(3);
                    modified = true;
                  }
                }
                if (modified) {
                  return {...op, 'attributes': attrs};
                }
              }
              return op;
            }).toList();

        final converter = QuillDeltaToHtmlConverter(
          normalizedDeltaJson,
          ConverterOptions.forEmail(),
        );
        html = converter.convert();
      } catch (e) {
        debugPrint('Error converting Quill Delta to HTML for preview: $e');
      }
    }

    MobilePreviewDialog.show(context, html: html);
  }

  void _addVariant({Map<String, dynamic>? data}) {
    final String? variantId =
        data?['id']?.toString() ?? data?['_id']?.toString();
    final String initialPrice = data?['price'] != null
        ? data!['price'].toString()
        : '';
    final String initialCompare = data?['compareAtPrice'] != null
        ? data!['compareAtPrice'].toString()
        : '';
    final String initialFarmerPrice = data?['farmerPrice'] != null
        ? data!['farmerPrice'].toString()
        : (data?['farmer_price'] != null ? data!['farmer_price'].toString() : '');
    // 'packSize' is the carton/booking total string (new field).
    // Old products store the same value as a number in 'packVolume' (always in litres).
    String initialPackSize = '';
    if (data?['size'] != null && data!['size'].toString().isNotEmpty) {
      initialPackSize = data['size'].toString();
    } else if (data?['packSize'] != null &&
        data!['packSize'].toString().isNotEmpty) {
      initialPackSize = data['packSize'].toString();
    }

    String initialBasePacking = '';
    if (data?['basePacking'] != null &&
        data!['basePacking'].toString().isNotEmpty) {
      initialBasePacking = data['basePacking'].toString();
    } else if (data?['packVolume'] != null) {
      final pvNum = data!['packVolume'];
      final pvDouble = pvNum is num
          ? pvNum.toDouble()
          : double.tryParse(pvNum.toString());
      if (pvDouble != null && pvDouble > 0) {
        final val = pvDouble % 1 == 0
            ? pvDouble.toInt().toString()
            : pvDouble.toString();
        String unit = 'lit';
        final parsedPackSize = _parsePackSize(initialPackSize);
        final packU = parsedPackSize['unit']?.toLowerCase() ?? '';
        if (packU == 'gm' || packU == 'kg' || packU == 'gram' || packU == 'g') {
          unit = 'kg';
        } else if (packU == 'pcs' || packU == 'piece' || packU == 'pieces') {
          unit = 'pcs';
        }
        initialBasePacking = '$val$unit';
      }
    }

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
    final farmerCtrl = TextEditingController(text: initialFarmerPrice);
    final packValCtrl = TextEditingController(text: packVal);
    final compareRateCtrl = TextEditingController();
    final farmerRateCtrl = TextEditingController();
    final basePackingValCtrl = TextEditingController(text: basePackVal);

    // Resolve variant-level pricing tiers with proper fallbacks
    List<Map<String, String>> variantPriceTiers = [];
    if (data != null && data['priceTiers'] != null) {
      try {
        variantPriceTiers = (data['priceTiers'] as List).map((t) {
          final map = t as Map;
          return {
            for (var entry in map.entries)
              entry.key.toString(): entry.value.toString(),
          };
        }).toList();
      } catch (_) {}
    }

    if (variantPriceTiers.isEmpty) {
      // Fallback to global product-level priceTiers if populated from backend
      if (_priceTiers.isNotEmpty) {
        variantPriceTiers = _priceTiers
            .map((t) => Map<String, String>.from(t))
            .toList();
      }
    }

    if (variantPriceTiers.isEmpty && _formVariants.isNotEmpty) {
      // Copy tiers from the first variant as a smart default
      final firstVariantTiers =
          _formVariants.first['priceTiers'] as List<Map<String, String>>;
      variantPriceTiers = firstVariantTiers
          .map((t) => Map<String, String>.from(t))
          .toList();
    }

    if (variantPriceTiers.isEmpty) {
      // Fallback to default static tiers
      variantPriceTiers = [
        {'id': '1', 'name': 'Tier 1 (10-30)'},
        {'id': '2', 'name': 'Tier 2 (30-50)'},
        {'id': '3', 'name': 'Tier 3 (50+)'},
      ];
    }

    // Map of rates for each tier
    final rates = <String, TextEditingController>{};
    final computed = <String, TextEditingController>{};

    for (var tier in variantPriceTiers) {
      final id = tier['id']!;
      // Read rate from data if available
      dynamic rawRateVal =
          data?['rates']?[id] ?? data?['unitPriceRate${id == "1" ? "" : id}'];
      if (rawRateVal == null) {
        if (id == '1') rawRateVal = data?['price10_30'];
        if (id == '2') rawRateVal = data?['price30_50'];
        if (id == '3') rawRateVal = data?['price50_plus'];
      }
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

    // --- Industry-standard factor: converts pack size value to base unit quantity ---
    // Rate is per BASE unit; pack size is measured in PACK unit.
    // factor = how many base units one pack-unit equals.

    // Temporary variant map ref for the closure to read live values from.
    // We use a late-bound reference via a list so the closure captures the list,
    // not a String variable that was set at add-time.
    final variantRef = <Map<String, dynamic>>[];

    final double? initBasePackingVal = double.tryParse(basePackingValCtrl.text);
    final double initialCanonicalVolume =
        initBasePackingVal != null && initBasePackingVal > 0
        ? _getPackVolume('${basePackingValCtrl.text}$basePackUnit')
        : 1.0;

    if (rates['1']!.text.isEmpty &&
        finalPrice != null &&
        initialCanonicalVolume > 0) {
      rates['1']!.text = (finalPrice / initialCanonicalVolume).toStringAsFixed(
        2,
      );
    }
    if (compareRateCtrl.text.isEmpty &&
        finalCompare != null &&
        initialCanonicalVolume > 0) {
      compareRateCtrl.text = (finalCompare / initialCanonicalVolume)
          .toStringAsFixed(2);
    }

    final double? finalFarmerPrice = double.tryParse(initialFarmerPrice);
    if (farmerRateCtrl.text.isEmpty &&
        finalFarmerPrice != null &&
        initialCanonicalVolume > 0) {
      farmerRateCtrl.text = (finalFarmerPrice / initialCanonicalVolume)
          .toStringAsFixed(2);
    }

    // Setup listeners to calculate prices on the fly!
    void recalculate() {
      final double? cRateVal = double.tryParse(compareRateCtrl.text);
      final double? fRateVal = double.tryParse(farmerRateCtrl.text);
      final double? bpVal = double.tryParse(basePackingValCtrl.text);
      final String bpUnit = variantRef.isNotEmpty
          ? (variantRef[0]['basePackingUnit'] as String? ?? basePackUnit)
          : basePackUnit;

      if (bpVal != null && bpVal > 0) {
        final double canonicalVolume = _getPackVolume('$bpVal$bpUnit');

        if (cRateVal != null) {
          final computedMRP = cRateVal * canonicalVolume;
          compareCtrl.text = computedMRP % 1 == 0
              ? computedMRP.toStringAsFixed(0)
              : computedMRP.toStringAsFixed(2);
        }

        if (fRateVal != null) {
          final computedFarmerPrice = fRateVal * canonicalVolume;
          farmerCtrl.text = computedFarmerPrice % 1 == 0
              ? computedFarmerPrice.toStringAsFixed(0)
              : computedFarmerPrice.toStringAsFixed(2);
        }

        for (var tier in variantPriceTiers) {
          final id = tier['id']!;
          final rateCtrl = rates[id];
          final compCtrl = computed[id];
          if (rateCtrl != null && compCtrl != null) {
            final double? rVal = double.tryParse(rateCtrl.text);
            if (rVal != null) {
              final computedVal = rVal * canonicalVolume;
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
    farmerRateCtrl.addListener(recalculate);
    packValCtrl.addListener(recalculate);
    basePackingValCtrl.addListener(recalculate);
    for (var controller in rates.values) {
      controller.addListener(recalculate);
    }

    setState(() {
      final variantMap = {
        if (variantId != null) 'id': variantId,
        if (variantId != null) '_id': variantId,
        'price': priceCtrl,
        'compareAtPrice': compareCtrl,
        'farmerPrice': farmerCtrl,
        'farmerRate': farmerRateCtrl,
        'packSizeVal': packValCtrl,
        'packSizeUnit': packUnit,
        'compareRate': compareRateCtrl,
        'basePackingVal': basePackingValCtrl,
        'basePackingUnit': basePackUnit,
        'rates': rates,
        'computed': computed,
        'priceTiers': variantPriceTiers,
        // Maintain recalculate reference for update on unit dropdown change
        'recalculate': recalculate,
      };
      _formVariants.add(variantMap);
      // Wire the live-factor closure to the actual variant map
      variantRef.add(variantMap);
    });
  }

  void _removeVariant(int index) {
    final variant = _formVariants[index];
    variant['price']?.dispose();
    variant['compareAtPrice']?.dispose();
    variant['farmerPrice']?.dispose();
    variant['farmerRate']?.dispose();
    variant['packSizeVal']?.dispose();
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

  void _addNewTierForVariant(Map<String, dynamic> variant, String name) {
    final newId = (DateTime.now().millisecondsSinceEpoch).toString();
    setState(() {
      final priceTiers = variant['priceTiers'] as List<Map<String, String>>;
      priceTiers.add({'id': newId, 'name': name});

      final ratesMap = variant['rates'] as Map<String, TextEditingController>;
      final computedMap =
          variant['computed'] as Map<String, TextEditingController>;
      final recalculate = variant['recalculate'] as VoidCallback;

      final rateCtrl = TextEditingController();
      ratesMap[newId] = rateCtrl;
      computedMap[newId] = TextEditingController();

      rateCtrl.addListener(recalculate);
    });
  }

  void _deleteTierForVariant(Map<String, dynamic> variant, String id) {
    if (id == '1') return; // Primary is required
    setState(() {
      final priceTiers = variant['priceTiers'] as List<Map<String, String>>;
      priceTiers.removeWhere((t) => t['id'] == id);

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
    });
  }

  void _showManageTiersDialog(Map<String, dynamic> variant) {
    showDialog(
      context: context,
      builder: (context) {
        final addController = TextEditingController();
        final priceTiers = variant['priceTiers'] as List<Map<String, String>>;
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
                      'Tiers are managed for this variant. Tier 1 is the primary selling price.',
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
                        itemCount: priceTiers.length,
                        itemBuilder: (context, idx) {
                          final tier = priceTiers[idx];
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
                                          _deleteTierForVariant(
                                            variant,
                                            tier['id']!,
                                          );
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
                              _addNewTierForVariant(
                                variant,
                                addController.text.trim(),
                              );
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

  Future<void> _pickMultipleProductImages() async {
    try {
      final List<XFile> images = await _picker.pickMultiImage(
        imageQuality:
            85, // Compress to 85% quality to save space and upload time
        maxWidth: 1440, // Limit maximum width to 1440 pixels
        maxHeight: 1440, // Limit maximum height to 1440 pixels
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

  String _stripHtmlCssAndClasses(String html) {
    return topLevelStripHtmlCssAndClasses(html);
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
    final bool isDescEmpty = _isHtmlMode
        ? _htmlDescriptionController.text.trim().isEmpty
        : (_descriptionController.document.toPlainText().trim().isEmpty ||
              _descriptionController.document.toPlainText().trim() == '\n');

    if (isDescEmpty) {
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
      if (_isHtmlMode) {
        description = _htmlDescriptionController.text.trim();
      } else {
        try {
          final deltaJson = _descriptionController.document.toDelta().toJson();
          final List<Map<String, dynamic>> normalizedDeltaJson =
              List<Map<String, dynamic>>.from(deltaJson).map((op) {
                if (op.containsKey('attributes')) {
                  final attrs = Map<String, dynamic>.from(
                    op['attributes'] as Map,
                  );
                  bool modified = false;
                  if (attrs.containsKey('color') && attrs['color'] is String) {
                    final color = attrs['color'] as String;
                    if (color.startsWith('#') && color.length == 9) {
                      attrs['color'] = '#' + color.substring(3);
                      modified = true;
                    }
                  }
                  if (attrs.containsKey('background') &&
                      attrs['background'] is String) {
                    final bg = attrs['background'] as String;
                    if (bg.startsWith('#') && bg.length == 9) {
                      attrs['background'] = '#' + bg.substring(3);
                      modified = true;
                    }
                  }
                  if (modified) {
                    return {...op, 'attributes': attrs};
                  }
                }
                return op;
              }).toList();

          final converter = QuillDeltaToHtmlConverter(
            normalizedDeltaJson,
            ConverterOptions.forEmail(),
          );
          description = converter.convert();
        } catch (e) {
          debugPrint('[PERF] Error converting Quill Delta to HTML: $e');
        }
      }
      description = _stripHtmlCssAndClasses(description);

      List<Map<String, dynamic>> variantsData = [];
      for (var v in _formVariants) {
        final ratesMap = v['rates'] as Map<String, TextEditingController>;
        final computedMap = v['computed'] as Map<String, TextEditingController>;

        final ratesJson = <String, String>{};
        final computedJson = <String, String>{};

        final suffix = _getRateSuffix(
          v['basePackingUnit'] ?? v['packSizeUnit'],
        );

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

        final String farmerRateVal = (v['farmerRate'] as TextEditingController?)?.text.trim() ?? '';
        final String farmerRateWithSuffix = farmerRateVal.isNotEmpty
            ? '$farmerRateVal$suffix'
            : '';

        final variantPriceTiers = v['priceTiers'] as List<Map<String, String>>;

        variantsData.add({
          if (v['id'] != null) 'id': v['id'],
          if (v['_id'] != null) '_id': v['_id'],
          'price': primaryRateWithSuffix,
          'compareAtPrice': mrpRateWithSuffix,
          'farmerPrice': (v['farmerPrice'] as TextEditingController?)?.text.trim() ?? '',
          'farmerRate': farmerRateWithSuffix,
          'packSize': '${v['packSizeVal'].text}${v['packSizeUnit']}',
          'basePacking': '${v['basePackingVal'].text}${v['basePackingUnit']}',
          'unitCompareRate': mrpRateWithSuffix,
          'rates': ratesJson,
          'computedPrices': computedJson,
          'priceTiers': variantPriceTiers,
        });
      }

      String displayPrice = '₹0';
      if (variantsData.isNotEmpty && variantsData.first['price'].isNotEmpty) {
        displayPrice = variantsData.first['price'].startsWith('₹')
            ? variantsData.first['price']
            : '₹${variantsData.first['price']}';
      }

      // Find Category IDs and Sub-category IDs from backendCategories
      final List<String> categoryIds = [];
      final List<String> subCategoryIds = [];

      for (var catName in _formCategories) {
        final matchingCat = _backendCategories.firstWhere(
          (c) => c['name'].toString().toLowerCase() == catName.toLowerCase(),
          orElse: () => null,
        );
        if (matchingCat != null) {
          final id =
              matchingCat['id']?.toString() ?? matchingCat['_id']?.toString();
          if (id != null) categoryIds.add(id);
        }
      }

      for (var subCatName in _formSubCategories) {
        for (var catName in _formCategories) {
          final matchingCat = _backendCategories.firstWhere(
            (c) => c['name'].toString().toLowerCase() == catName.toLowerCase(),
            orElse: () => null,
          );
          if (matchingCat != null) {
            final List subs = matchingCat['subCategories'] ?? [];
            final matchingSub = subs.firstWhere(
              (s) =>
                  s['name'].toString().toLowerCase() ==
                  subCatName.toLowerCase(),
              orElse: () => null,
            );
            if (matchingSub != null) {
              final id =
                  matchingSub['id']?.toString() ??
                  matchingSub['_id']?.toString();
              if (id != null && !subCategoryIds.contains(id)) {
                subCategoryIds.add(id);
              }
            }
          }
        }
      }

      if (categoryIds.isEmpty) {
        throw Exception('Please select at least one primary category.');
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
        final farmerPriceVal =
            double.tryParse(
              (v['farmerPrice'] ?? '').toString().replaceAll(RegExp(r'[^0-9.]'), ''),
            ) ??
            0.0;

        return {
          if (v['id'] != null) 'id': v['id'],
          if (v['_id'] != null) '_id': v['_id'],
          'size': v['packSize'],
          'price': priceVal,
          'compareAtPrice': compareVal,
          'farmerPrice': farmerPriceVal,
          // packVolume: legacy numeric field = total base-packing in canonical unit
          // e.g. 10lit → 10.0, 5000ml → 5.0, 2kg → 2.0, 500gm → 0.5, 10pcs → 10.0
          'packVolume': _getPackVolume(v['basePacking'] ?? ''),
          'basePacking': v['basePacking'],
          // Explicit unit so backend/mobile can display ₹/pcs, ₹/lit, ₹/kg correctly
          'basePackingUnit': _getBasePackingUnitFromString(
            v['basePacking'] ?? '',
          ),
          'weight': 0.0,
          'rates': v['rates'],
          'computedPrices': v['computedPrices'],
          'priceTiers': v['priceTiers'],
        };
      }).toList();

      final bool isEdit = widget.initialData != null;

      final Map<String, int> customOrdersPayload = {};
      _customOrdersControllers.forEach((key, controller) {
        final bool isAssignedCategory = categoryIds.contains(key);
        final bool isAssignedSubCategory = subCategoryIds.contains(key);
        final bool isAssignedCollection = _assignedCollections.contains(key);
        final bool isFeaturedContext = key == 'featured' && _isFeatured;

        if (isAssignedCategory || isAssignedSubCategory || isAssignedCollection || isFeaturedContext) {
          final text = controller.text.trim();
          if (text.isNotEmpty) {
            final parsed = int.tryParse(text);
            if (parsed != null) {
              customOrdersPayload[key] = parsed;
            }
          }
        }
      });

      final productData = {
        'title': _nameController.text.trim(),
        'brandName': _vendorController.text.trim(),
        'technicalName': _nameController.text.trim(),
        'vendor': _vendorController.text.trim(),
        'order': int.tryParse(_orderController.text) ?? 0,
        'customOrders': customOrdersPayload,
        'categoryId': categoryIds.first,
        'subCategoryId': subCategoryIds.isNotEmpty
            ? subCategoryIds.first
            : null,
        'categoryIds': categoryIds,
        'subCategoryIds': subCategoryIds,
        'description': description,
        'dosage': {
          'perLiterWater': _dosagePerLiterController.text.trim().isNotEmpty
              ? '${_dosagePerLiterController.text.trim()} $_dosagePerLiterUnit'
              : '',
          'perAcre': _dosagePerAcreController.text.trim().isNotEmpty
              ? '${_dosagePerAcreController.text.trim()} $_dosagePerAcreUnit'
              : '',
          'method': _dosageMethodController.text == 'Select Method'
              ? ''
              : _dosageMethodController.text.trim(),
        },
        'variants': mappedVariants,
        'tags': _tags,
        'assignedCollections': _assignedCollections,
        'availabilityStatus': _inStock ? 'In Stock' : 'Out of Stock',
        'isFeatured': _isFeatured,
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

        final capturedImages = List<Uint8List>.from(_productImages);
        response = await ApiClient().multipartRequest(
          method: isEdit ? 'PUT' : 'POST',
          endpoint: isEdit
              ? '/products/${widget.initialData!['id'] ?? widget.initialData!['_id']}'
              : '/products',
          fields: fields,
          filesBuilder: () {
            final builtFiles = <http.MultipartFile>[];
            for (int i = 0; i < capturedImages.length; i++) {
              builtFiles.add(
                http.MultipartFile.fromBytes(
                  'images',
                  capturedImages[i],
                  filename: 'product_image_$i.png',
                  contentType: MediaType('image', 'png'),
                ),
              );
            }
            return builtFiles;
          },
        );
      } else {
        // Standard JSON PUT/POST
        response = isEdit
            ? await ApiClient().put(
                '/products/${widget.initialData!['id'] ?? widget.initialData!['_id']}',
                productData,
              )
            : await ApiClient().post('/products', productData);
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        final resData = jsonDecode(response.body);
        ProductRepository().invalidateCache();
        widget.onSave(resData['product'] ?? {});
        if (mounted) {
          try {
            context.read<ProductsBloc>().add(const LoadProductsEvent(forceRefresh: true));
          } catch (_) {}
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

  /// Returns the numeric packVolume normalized to the canonical unit:
  /// ml → litres (÷1000), gm/gram/g → kg (÷1000), all others (lit/kg/pcs) → raw value.
  double _getPackVolume(String sizeStr) {
    final clean = sizeStr.toLowerCase().replaceAll(RegExp(r'\s+'), '');
    final match = RegExp(
      r'^([\d.]+)(ml|lit|litre|l|gm|gram|g|kg|kilogram|k|pcs|piece|pieces)$',
    ).firstMatch(clean);
    if (match == null) return 1.0;

    final value = double.tryParse(match.group(1) ?? '') ?? 1.0;
    final unit = match.group(2) ?? '';

    // Sub-units: convert to the canonical larger unit
    if (unit == 'ml') return value / 1000.0; // ml → litres
    if (unit == 'gm' || unit == 'gram' || unit == 'g')
      return value / 1000.0; // gm → kg
    // Canonical units: lit, kg, pcs — return value as-is
    return value;
  }

  /// Extracts the base packing unit string from a basePacking string like "10lit", "5kg", "20pcs".
  /// Returns the unit portion normalized to a standard token.
  String _getBasePackingUnitFromString(String sizeStr) {
    final clean = sizeStr.toLowerCase().replaceAll(RegExp(r'\s+'), '');
    final match = RegExp(
      r'^[\d.]+(ml|lit|litre|l|gm|gram|g|kg|kilogram|k|pcs|piece|pieces)$',
    ).firstMatch(clean);
    if (match == null) return 'lit';
    final raw = match.group(1) ?? 'lit';
    if (raw == 'ml') return 'lit'; // ml stored as lit (volume)
    if (raw == 'gm' || raw == 'gram' || raw == 'g')
      return 'kg'; // gm stored as kg (mass)
    if (raw == 'litre' || raw == 'l') return 'lit';
    if (raw == 'kilogram' || raw == 'k') return 'kg';
    if (raw == 'piece' || raw == 'pieces') return 'pcs';
    return raw; // lit, kg, pcs
  }

  @override
  Widget build(BuildContext context) {
    debugPrint(
      '[PERF] CreateProductPage.build called. _isTransitionComplete = $_isTransitionComplete. Elapsed: ${_perfStopwatch.elapsedMilliseconds}ms',
    );
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
                  MorphingSaveButton(
                    isLoading: _isSaving,
                    onTap: _handleSave,
                    text: isEdit ? 'Save Changes' : 'Publish Product',
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
                        Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 12,
                          runSpacing: 8,
                          children: [
                            Text(
                              'Description',
                              style: GoogleFonts.outfit(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                TextButton.icon(
                                  onPressed: _showMobilePreview,
                                  icon: const Icon(
                                    Icons.phone_android_rounded,
                                    size: 16,
                                    color: AppTheme.primaryColor,
                                  ),
                                  label: Text(
                                    'Mobile Preview',
                                    style: GoogleFonts.outfit(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.primaryColor,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                TextButton.icon(
                                  onPressed: _toggleEditorMode,
                                  icon: Icon(
                                    _isHtmlMode
                                        ? Icons.remove_red_eye_rounded
                                        : Icons.code_rounded,
                                    size: 16,
                                    color: AppTheme.primaryColor,
                                  ),
                                  label: Text(
                                    _isHtmlMode
                                        ? 'Visual Editor'
                                        : 'HTML Editor',
                                    style: GoogleFonts.outfit(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.primaryColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
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
                                    if (!_isHtmlMode) ...[
                                      quill.QuillSimpleToolbar(
                                        controller: _descriptionController,
                                        config: quill.QuillSimpleToolbarConfig(
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
                                          showColorButton: false,
                                          showBackgroundColorButton: false,
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
                                      const Divider(
                                        height: 1,
                                        color: AppTheme.borderColor,
                                      ),
                                    ],
                                    Container(
                                      height: 350,
                                      padding: const EdgeInsets.all(16),
                                      child: _isHtmlMode
                                          ? TextField(
                                              controller:
                                                  _htmlDescriptionController,
                                              maxLines: null,
                                              minLines: 15,
                                              keyboardType:
                                                  TextInputType.multiline,
                                              style: GoogleFonts.robotoMono(
                                                fontSize: 13,
                                                color: Colors.blueGrey.shade900,
                                              ),
                                              decoration: const InputDecoration(
                                                border: InputBorder.none,
                                                hintText:
                                                    'Write raw HTML here (e.g. <p>Hello <b>World</b></p>)...',
                                                hintStyle: TextStyle(
                                                  color: AppTheme.textSecondary,
                                                  fontSize: 13,
                                                ),
                                              ),
                                            )
                                          : quill.QuillEditor.basic(
                                              controller:
                                                  _descriptionController,
                                              config: const quill.QuillEditorConfig(
                                                placeholder:
                                                    'Provide a detailed description of the product features, benefits, and specifications...',
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
                    title: 'Dosage & Application Method',
                    icon: Icons.medication_liquid_rounded,
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: _buildFormTextField(
                                label: 'Per Liter Water',
                                hint: '0.3 – 0.5',
                                controller: _dosagePerLiterController,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 2,
                              child: _buildFormDropdown(
                                label: 'Unit',
                                value: _dosagePerLiterUnit,
                                options: _dosageUnits,
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() => _dosagePerLiterUnit = val);
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: _buildFormTextField(
                                label: 'Per Acre',
                                hint: '100 – 120',
                                controller: _dosagePerAcreController,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 2,
                              child: _buildFormDropdown(
                                label: 'Unit',
                                value: _dosagePerAcreUnit,
                                options: _dosageUnits,
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() => _dosagePerAcreUnit = val);
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Builder(
                          builder: (context) {
                            final methods = <String>{};
                            for (final cat in _formCategories) {
                              final key = _categoryToMethods.keys.firstWhere(
                                (k) => k.toLowerCase() == cat.toLowerCase(),
                                orElse: () => '',
                              );
                              if (key.isNotEmpty) {
                                methods.addAll(_categoryToMethods[key]!);
                              }
                            }

                            final options = ['Select Method', ...methods.toList()..sort()];
                            final currentMethod = _dosageMethodController.text;

                            final selectedValue = (currentMethod.isNotEmpty &&
                                    options.contains(currentMethod))
                                ? currentMethod
                                : 'Select Method';

                            return _buildFormDropdown(
                              label: 'Method',
                              value: selectedValue,
                              options: options,
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() {
                                    _dosageMethodController.text = val;
                                  });
                                }
                              },
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildSectionCard(
                    title: 'Product Variants',
                    icon: Icons.style_outlined,
                    action: TextButton.icon(
                      onPressed: _addVariant,
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: Text(
                        'Add Variant',
                        style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
                      ),
                      style: TextButton.styleFrom(
                        foregroundColor: AppTheme.primaryColor,
                      ),
                    ),
                    child: Column(
                      children: _formVariants.asMap().entries.map((entry) {
                        return ProductVariantCard(
                          index: entry.key,
                          variant: entry.value,
                          isMobile: !isWide,
                          totalVariants: _formVariants.length,
                          onManageTiers: () => _showManageTiersDialog(entry.value),
                          onRemove: () => _removeVariant(entry.key),
                          onStateChanged: () => setState(() {}),
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
                    child: ProductMediaUploader(
                      existingImageUrls: _existingImageUrls,
                      productImages: _productImages,
                      onPickImages: _pickMultipleProductImages,
                      onRemoveExistingImage: (index) {
                        setState(() {
                          _existingImageUrls.removeAt(index);
                          if (index < _existingMediumUrls.length) {
                            _existingMediumUrls.removeAt(index);
                          }
                          if (index < _existingOriginalUrls.length) {
                            _existingOriginalUrls.removeAt(index);
                          }
                        });
                      },
                      onRemoveNewImage: (index) {
                        setState(() => _productImages.removeAt(index));
                      },
                      onEditNewImage: (index, newBytes) {
                        setState(() {
                          _productImages[index] = newBytes;
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildSectionCard(
                    title: 'Organization & Status',
                    icon: Icons.category_outlined,
                    child: Column(
                      children: [
                        _buildCategoryDropdowns(),
                        const SizedBox(height: 16),
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

                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Product Status',
                                    style: GoogleFonts.outfit(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Toggle to hide from store',
                                    style: GoogleFonts.outfit(
                                      fontSize: 11,
                                      color: AppTheme.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  _inStock = !_inStock;
                                });
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 400),
                                curve: Curves.fastOutSlowIn,
                                height: 36,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: _inStock
                                      ? const Color(
                                          0xFF10B981,
                                        ).withValues(alpha: 0.1)
                                      : const Color(
                                          0xFFEF4444,
                                        ).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color: _inStock
                                        ? const Color(
                                            0xFF10B981,
                                          ).withValues(alpha: 0.3)
                                        : const Color(
                                            0xFFEF4444,
                                          ).withValues(alpha: 0.3),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    AnimatedSwitcher(
                                      duration: const Duration(
                                        milliseconds: 300,
                                      ),
                                      transitionBuilder: (child, animation) {
                                        return ScaleTransition(
                                          scale: animation,
                                          child: FadeTransition(
                                            opacity: animation,
                                            child: child,
                                          ),
                                        );
                                      },
                                      child: Icon(
                                        _inStock
                                            ? Icons.check_circle_rounded
                                            : Icons.cancel_rounded,
                                        key: ValueKey(_inStock),
                                        color: _inStock
                                            ? const Color(0xFF10B981)
                                            : const Color(0xFFEF4444),
                                        size: 16,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    AnimatedSize(
                                      duration: const Duration(
                                        milliseconds: 300,
                                      ),
                                      curve: Curves.fastOutSlowIn,
                                      child: Text(
                                        _inStock ? 'In Stock' : 'Out of Stock',
                                        style: GoogleFonts.outfit(
                                          color: _inStock
                                              ? const Color(0xFF059669)
                                              : const Color(0xFFDC2626),
                                          fontWeight: FontWeight.w600,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Featured Product',
                                    style: GoogleFonts.outfit(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Show in featured products section',
                                    style: GoogleFonts.outfit(
                                      fontSize: 11,
                                      color: AppTheme.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  _isFeatured = !_isFeatured;
                                });
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 400),
                                curve: Curves.fastOutSlowIn,
                                height: 36,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: _isFeatured
                                      ? const Color(
                                          0xFF3B82F6,
                                        ).withValues(alpha: 0.1)
                                      : const Color(
                                          0xFF6B7280,
                                        ).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color: _isFeatured
                                        ? const Color(
                                            0xFF3B82F6,
                                          ).withValues(alpha: 0.3)
                                        : const Color(
                                            0xFF6B7280,
                                          ).withValues(alpha: 0.3),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    AnimatedSwitcher(
                                      duration: const Duration(
                                        milliseconds: 300,
                                      ),
                                      transitionBuilder: (child, animation) {
                                        return ScaleTransition(
                                          scale: animation,
                                          child: FadeTransition(
                                            opacity: animation,
                                            child: child,
                                          ),
                                        );
                                      },
                                      child: Icon(
                                        _isFeatured
                                            ? Icons.star_rounded
                                            : Icons.star_outline_rounded,
                                        key: ValueKey(_isFeatured),
                                        color: _isFeatured
                                            ? const Color(0xFF3B82F6)
                                            : const Color(0xFF6B7280),
                                        size: 16,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    AnimatedSize(
                                      duration: const Duration(
                                        milliseconds: 300,
                                      ),
                                      curve: Curves.fastOutSlowIn,
                                      child: Text(
                                        _isFeatured
                                            ? 'Featured'
                                            : 'Not Featured',
                                        style: GoogleFonts.outfit(
                                          color: _isFeatured
                                              ? const Color(0xFF2563EB)
                                              : const Color(0xFF4B5563),
                                          fontWeight: FontWeight.w600,
                                          fontSize: 12,
                                        ),
                                      ),
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
                  const SizedBox(height: 24),
                  ProductTagsCard(
                    tags: _tags,
                    tagController: _tagController,
                    onTagsChanged: () => setState(() {}),
                  ),
                  const SizedBox(height: 24),
                  ProductCollectionsCard(
                    backendCollections: _backendCollections,
                    assignedCollections: _assignedCollections,
                    collectionIdToName: _collectionIdToName,
                    onCollectionsChanged: () => setState(() {}),
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

  Widget _buildCategoryDropdowns() {
    // Generate dropdown options for categories
    final List<String> categoryOptions = [];
    for (var cat in _backendCategories) {
      final name = cat['name']?.toString() ?? '';
      if (name.isNotEmpty && !_formCategories.contains(name)) {
        categoryOptions.add(name);
      }
    }
    categoryOptions.add('+ Create Custom...');

    // Generate subcategory options under all selected categories
    final List<String> subCategoryOptions = [];
    for (var catName in _formCategories) {
      final matchingCat = _backendCategories.firstWhere(
        (c) => c['name'].toString().toLowerCase() == catName.toLowerCase(),
        orElse: () => null,
      );
      if (matchingCat != null) {
        final List subs = matchingCat['subCategories'] ?? [];
        for (var sub in subs) {
          final sName = sub['name']?.toString() ?? '';
          if (sName.isNotEmpty &&
              !_formSubCategories.contains(sName) &&
              !subCategoryOptions.contains(sName)) {
            subCategoryOptions.add(sName);
          }
        }
      }
    }
    subCategoryOptions.add('+ Create Custom...');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Categories list & selection
        Text(
          'Categories',
          style: GoogleFonts.outfit(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        if (_formCategories.isNotEmpty) ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _formCategories.map((cat) {
              return Container(
                padding: const EdgeInsets.only(
                  left: 12,
                  right: 8,
                  top: 6,
                  bottom: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        cat,
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: () {
                        setState(() {
                          _formCategories.remove(cat);
                          // Also remove subcategories that belong only to this removed category
                          final remainingCategories = _formCategories
                              .where((c) => c != cat)
                              .toList();
                          final List<String> retainedSubs = [];
                          for (var rCat in remainingCategories) {
                            final matchingCat = _backendCategories.firstWhere(
                              (c) =>
                                  c['name'].toString().toLowerCase() ==
                                  rCat.toLowerCase(),
                              orElse: () => null,
                            );
                            if (matchingCat != null) {
                              final List subs =
                                  matchingCat['subCategories'] ?? [];
                              for (var sub in subs) {
                                final name = sub['name']?.toString() ?? '';
                                if (name.isNotEmpty) {
                                  retainedSubs.add(name.toLowerCase());
                                }
                              }
                            }
                          }

                          final List<String> subsToRemove = [];
                          final matchingCat = _backendCategories.firstWhere(
                            (c) =>
                                c['name'].toString().toLowerCase() ==
                                cat.toLowerCase(),
                            orElse: () => null,
                          );
                          if (matchingCat != null) {
                            final List subs =
                                matchingCat['subCategories'] ?? [];
                            for (var sub in subs) {
                              final name = sub['name']?.toString() ?? '';
                              if (name.isNotEmpty &&
                                  !retainedSubs.contains(name.toLowerCase())) {
                                subsToRemove.add(name);
                              }
                            }
                          }
                          _formSubCategories.removeWhere(
                            (sub) => subsToRemove.any(
                              (s) => s.toLowerCase() == sub.toLowerCase(),
                            ),
                          );
                          _updateDosageMethod();
                        });
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          color: Color(0xFFF1F5F9),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close_rounded,
                          size: 14,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
        ],
        Container(
          height: 48,
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: 16),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      hint: Text(
                        'Add Category',
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          color: const Color(0xFF94A3B8),
                        ),
                      ),
                      icon: const Padding(
                        padding: EdgeInsets.only(right: 8),
                        child: Icon(
                          Icons.keyboard_arrow_down_rounded,
                          size: 18,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                      padding: EdgeInsets.zero,
                      items: categoryOptions.map((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(
                            value,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                            style: GoogleFonts.outfit(
                              fontSize: 14,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val == null) return;
                        if (val == '+ Create Custom...') {
                          _showCreateCategoryDialog();
                          return;
                        }
                        setState(() {
                          if (!_formCategories.contains(val)) {
                            _formCategories.add(val);
                            _updateDosageMethod();
                          }
                        });
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Sub-categories list & selection
        Text(
          'Sub-categories',
          style: GoogleFonts.outfit(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        if (_formSubCategories.isNotEmpty) ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _formSubCategories.map((sub) {
              return Container(
                padding: const EdgeInsets.only(
                  left: 12,
                  right: 8,
                  top: 6,
                  bottom: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        sub,
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: () {
                        setState(() {
                          _formSubCategories.remove(sub);
                        });
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          color: Color(0xFFF1F5F9),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close_rounded,
                          size: 14,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
        ],
        Container(
          height: 48,
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: 16),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      hint: Text(
                        _formCategories.isEmpty
                            ? 'Select Category First'
                            : 'Add Sub-category',
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          color: const Color(0xFF94A3B8),
                        ),
                      ),
                      disabledHint: Text(
                        'Select Category First',
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          color: const Color(0xFFCBD5E1),
                        ),
                      ),
                      padding: EdgeInsets.zero,
                      icon: const Padding(
                        padding: EdgeInsets.only(right: 8),
                        child: Icon(
                          Icons.keyboard_arrow_down_rounded,
                          size: 18,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                      items: _formCategories.isEmpty
                          ? null
                          : subCategoryOptions.map((String value) {
                              return DropdownMenuItem<String>(
                                value: value,
                                child: Text(
                                  value,
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                  style: GoogleFonts.outfit(
                                    fontSize: 14,
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                              );
                            }).toList(),
                      onChanged: _formCategories.isEmpty
                          ? null
                          : (val) {
                              if (val == null) return;
                              if (val == '+ Create Custom...') {
                                _showCreateSubCategoryDialog();
                                return;
                              }
                              setState(() {
                                if (!_formSubCategories.contains(val)) {
                                  _formSubCategories.add(val);
                                }
                              });
                            },
                    ),
                  ),
                ),
              ),
            ],
          ),
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
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              elevation: 12,
              child: Container(
                width: 480,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // HEADER
                    Row(
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
                                Icons.grid_view_rounded,
                                color: Color(0xFF059669),
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Create Category',
                                  style: GoogleFonts.outfit(
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF0F172A),
                                    fontSize: 17,
                                  ),
                                ),
                                Text(
                                  'Add new primary product category',
                                  style: GoogleFonts.outfit(
                                    color: const Color(0xFF64748B),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        InkWell(
                          onTap: isLoading ? null : () => Navigator.pop(dialogCtx),
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

                    const SizedBox(height: 20),

                    Text(
                      'Category Name *',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.w600,
                        fontSize: 12.5,
                        color: const Color(0xFF334155),
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: textCtrl,
                      style: GoogleFonts.outfit(fontSize: 13.5, color: const Color(0xFF0F172A)),
                      decoration: InputDecoration(
                        hintText: 'e.g. Bio-Fertilizers, Insecticides...',
                        hintStyle: GoogleFonts.outfit(fontSize: 13, color: const Color(0xFF94A3B8)),
                        prefixIcon: const Icon(Icons.label_outline_rounded, size: 18, color: AppTheme.primaryColor),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        errorText: errorText,
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
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ACTIONS
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton(
                          onPressed: isLoading ? null : () => Navigator.pop(dialogCtx),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF64748B),
                            side: const BorderSide(color: Color(0xFFE2E8F0)),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: Text(
                            'Cancel',
                            style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                        ),
                        const SizedBox(width: 10),
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
                                          if (!_formCategories.contains(name)) {
                                            _formCategories.add(name);
                                            _updateDosageMethod();
                                          }
                                        });
                                        if (context.mounted) Navigator.pop(dialogCtx);
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
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
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
                                  'Create Category',
                                  style: GoogleFonts.outfit(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
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
    );
  }

  Future<void> _showCreateSubCategoryDialog() async {
    final textCtrl = TextEditingController();
    bool isLoading = false;
    String? errorText;

    if (_formCategories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select or create a primary category first.'),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }

    String targetCategoryName = _formCategories.first;

    await showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            String? categoryId;
            final matchingCat = _backendCategories.firstWhere(
              (c) =>
                  c['name'].toString().toLowerCase() ==
                  targetCategoryName.toLowerCase(),
              orElse: () => null,
            );
            if (matchingCat != null) {
              categoryId =
                  matchingCat['id']?.toString() ??
                  matchingCat['_id']?.toString();
            }

            return Dialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              elevation: 12,
              child: Container(
                width: 480,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // HEADER
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEFF6FF),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFBFDBFE)),
                              ),
                              child: const Icon(
                                Icons.folder_open_rounded,
                                color: Color(0xFF2563EB),
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Create Sub-category',
                                  style: GoogleFonts.outfit(
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF0F172A),
                                    fontSize: 17,
                                  ),
                                ),
                                Text(
                                  'Add sub-division under category',
                                  style: GoogleFonts.outfit(
                                    color: const Color(0xFF64748B),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        InkWell(
                          onTap: isLoading ? null : () => Navigator.pop(dialogCtx),
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

                    const SizedBox(height: 20),

                    if (_formCategories.length > 1) ...[
                      Text(
                        'Parent Category',
                        style: GoogleFonts.outfit(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF334155),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            isExpanded: true,
                            value: targetCategoryName,
                            items: _formCategories
                                .map(
                                  (c) => DropdownMenuItem(
                                    value: c,
                                    child: Text(
                                      c,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.outfit(fontSize: 13.5, color: const Color(0xFF0F172A)),
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setDialogState(() {
                                  targetCategoryName = val;
                                });
                              }
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],

                    Text(
                      'Sub-category Name *',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.w600,
                        fontSize: 12.5,
                        color: const Color(0xFF334155),
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: textCtrl,
                      style: GoogleFonts.outfit(fontSize: 13.5, color: const Color(0xFF0F172A)),
                      decoration: InputDecoration(
                        hintText: 'e.g. Granules, Liquid, Organic...',
                        hintStyle: GoogleFonts.outfit(fontSize: 13, color: const Color(0xFF94A3B8)),
                        prefixIcon: const Icon(Icons.label_outline_rounded, size: 18, color: AppTheme.primaryColor),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        errorText: errorText,
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
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ACTIONS
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton(
                          onPressed: isLoading ? null : () => Navigator.pop(dialogCtx),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF64748B),
                            side: const BorderSide(color: Color(0xFFE2E8F0)),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: Text(
                            'Cancel',
                            style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton(
                          onPressed: isLoading || categoryId == null
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
                                          if (!_formSubCategories.contains(name)) {
                                            _formSubCategories.add(name);
                                          }
                                        });
                                        if (context.mounted) Navigator.pop(dialogCtx);
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
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
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
                                  'Add Sub-category',
                                  style: GoogleFonts.outfit(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
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
              padding: EdgeInsets.zero,
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
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
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

  String _extractId(dynamic item) {
    if (item == null) return '';
    if (item is String) return item;
    if (item is Map) {
      if (item['\$oid'] != null) return item['\$oid'].toString();
      if (item['_id'] != null) return _extractId(item['_id']);
      if (item['id'] != null) return _extractId(item['id']);
    }
    return item.toString();
  }

  String _normalizeName(String name) {
    String n = name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '').trim();
    if (n.endsWith('s')) {
      n = n.substring(0, n.length - 1);
    }
    return n;
  }

  TextEditingController _getOrCreateContextController(String contextId, {String initialValue = ''}) {
    if (!_customOrdersControllers.containsKey(contextId)) {
      _customOrdersControllers[contextId] = TextEditingController(text: initialValue);
    }
    return _customOrdersControllers[contextId]!;
  }

  Widget _buildContextSpecificFields() {
    // 1. Resolve IDs for selected categories
    final List<MapEntry<String, String>> categoryItems = [];
    for (var catName in _formCategories) {
      final matchingCat = _backendCategories.firstWhere(
        (c) => _normalizeName(c['name']?.toString() ?? '') == _normalizeName(catName),
        orElse: () => null,
      );
      if (matchingCat != null) {
        final idStr = _extractId(matchingCat);
        if (idStr.isNotEmpty) {
          categoryItems.add(MapEntry(idStr, 'Order in Category: $catName'));
        }
      }
    }

    if (_isFeatured) {
      categoryItems.add(const MapEntry('featured', 'Order in Featured Products'));
    }

    // 2. Resolve IDs for selected subcategories
    final List<MapEntry<String, String>> subCategoryItems = [];
    for (var subName in _formSubCategories) {
      for (var cat in _backendCategories) {
        final List subs = cat['subCategories'] ?? [];
        final matchingSub = subs.firstWhere(
          (s) => _normalizeName(s['name']?.toString() ?? '') == _normalizeName(subName),
          orElse: () => null,
        );
        if (matchingSub != null) {
          final idStr = _extractId(matchingSub);
          if (idStr.isNotEmpty) {
            subCategoryItems.add(MapEntry(idStr, 'Order in Subcategory: $subName'));
          }
          break;
        }
      }
    }

    // 3. Resolve IDs for selected collections
    final List<MapEntry<String, String>> collectionItems = [];
    for (var col in _assignedCollections) {
      final displayName = _collectionIdToName[col] ?? col;
      collectionItems.add(MapEntry(col, 'Order in Collection: $displayName'));
    }

    final allContexts = [...categoryItems, ...subCategoryItems, ...collectionItems];
    if (allContexts.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Text(
          'Context-Specific Ordering',
          style: GoogleFonts.outfit(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Specify custom positions for this product within individual categories or collections (lower numbers appear first).',
          style: GoogleFonts.outfit(
            fontSize: 11,
            color: AppTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 12),
        ...allContexts.map((entry) {
          final contextId = entry.key;
          final contextLabel = entry.value;
          final ctrl = _getOrCreateContextController(contextId);
          return Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: _buildFormTextField(
              label: contextLabel,
              hint: 'e.g. 0, 1, 2...',
              controller: ctrl,
              keyboardType: TextInputType.number,
              validator: (val) {
                if (val != null && val.trim().isNotEmpty && int.tryParse(val) == null) {
                  return 'Must be a valid integer';
                }
                return null;
              },
            ),
          );
        }),
      ],
    );
  }
}

