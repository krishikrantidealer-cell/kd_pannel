import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:kd_pannel/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_quill_delta_from_html/flutter_quill_delta_from_html.dart';
import 'package:vsc_quill_delta_to_html/vsc_quill_delta_to_html.dart' hide TableRow;
import 'package:kd_pannel/features/shared/widgets/morphing_save_button.dart';
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
            .replaceAll('class="ql-align-center"', 'style="text-align: center;"')
            .replaceAll('class="ql-align-right"', 'style="text-align: right;"')
            .replaceAll('class="ql-align-justify"', 'style="text-align: justify;"')
            .replaceAll(RegExp(r'''class=\s*["']ql-align-center["']''', caseSensitive: false), 'style="text-align: center;"')
            .replaceAll(RegExp(r'''class=\s*["']ql-align-right["']''', caseSensitive: false), 'style="text-align: right;"')
            .replaceAll(RegExp(r'''class=\s*["']ql-align-justify["']''', caseSensitive: false), 'style="text-align: justify;"');

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
      _nameController.text = data['name'] ?? '';
      _vendorController.text = data['vendor'] ?? '';
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
    debugPrint(
      '[PERF] CreateProductPage._loadCategories started. Elapsed: ${_perfStopwatch.elapsedMilliseconds}ms',
    );

    // 1. Try to use preloaded categories passed down from parent page/BLoC
    if (widget.preloadedCategories != null &&
        widget.preloadedCategories!.isNotEmpty) {
      debugPrint(
        '[PERF] CreateProductPage._loadCategories - Using preloaded categories. Elapsed: ${_perfStopwatch.elapsedMilliseconds}ms',
      );
      setState(() {
        _backendCategories = widget.preloadedCategories!;
        _initializeCategorySelection();
      });
      return;
    }

    // 2. Try to load from memory cache
    final cached = ApiClient().cachedCategories;
    if (cached != null && cached.isNotEmpty) {
      debugPrint(
        '[PERF] CreateProductPage._loadCategories - Found cached categories in ApiClient. Elapsed: ${_perfStopwatch.elapsedMilliseconds}ms',
      );
      setState(() {
        _backendCategories = cached;
        _initializeCategorySelection();
      });
      return;
    }

    try {
      debugPrint(
        '[PERF] CreateProductPage._loadCategories - Dispatching API call to /products/categories. Elapsed: ${_perfStopwatch.elapsedMilliseconds}ms',
      );
      final response = await ApiClient().get('/products/categories');
      debugPrint(
        '[PERF] CreateProductPage._loadCategories - API call completed with code ${response.statusCode}. Elapsed: ${_perfStopwatch.elapsedMilliseconds}ms',
      );
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
      debugPrint(
        '[PERF] CreateProductPage._loadCategories - Error fetching categories: $e. Elapsed: ${_perfStopwatch.elapsedMilliseconds}ms',
      );
    }
  }

  Future<void> _loadCollections() async {
    try {
      final response = await ApiClient().get('/collections?all=true');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['collections'] is List) {
          final List collections = data['collections'];
          final Map<String, String> map = {};

          for (var col in collections) {
            final colId = col['id']?.toString() ?? col['_id']?.toString() ?? '';
            final colName = col['name']?.toString() ?? '';

            if (colId.isNotEmpty && colName.isNotEmpty) {
              map[colId] = colName;
              // Map legacy name string to itself for fallback
              map[colName] = colName;
            }

            final List subs = col['subCollections'] ?? [];
            for (var sub in subs) {
              final subId =
                  sub['id']?.toString() ?? sub['_id']?.toString() ?? '';
              final subName = sub['name']?.toString() ?? '';
              if (subId.isNotEmpty && subName.isNotEmpty) {
                map[subId] = '$colName > $subName';
                // Map legacy sub-collection name as fallback
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
        }
      }
    } catch (e) {
      debugPrint('Error fetching collections: $e');
    }
  }

  void _initializeCategorySelection() {
    if (widget.initialData != null) {
      final String catString = widget.initialData?['category']?.toString() ?? '';
      final String subCatString = widget.initialData?['subCategory']?.toString() ?? '';

      final List<String> resolvedCategories = [];
      if (catString.isNotEmpty && catString != 'N/A') {
        resolvedCategories.addAll(
          catString.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty),
        );
      }

      final List<String> resolvedSubCategories = [];
      if (subCatString.isNotEmpty && subCatString != 'N/A') {
        resolvedSubCategories.addAll(
          subCatString.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty),
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
          if (catId is Map && catId['name'] != null && catId['name'].toString().isNotEmpty) {
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
          if (subCatId is Map && subCatId['name'] != null && subCatId['name'].toString().isNotEmpty) {
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
                  (s['id']?.toString() ?? s['_id']?.toString()) == cleanSubCatId,
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
      });
    } else {
      setState(() {
        _formCategories = [];
        _formSubCategories = [];
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
      final hasComplexHtml = htmlText.contains('<table') ||
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
              .replaceAll('class="ql-align-center"', 'style="text-align: center;"')
              .replaceAll('class="ql-align-right"', 'style="text-align: right;"')
              .replaceAll('class="ql-align-justify"', 'style="text-align: justify;"')
              .replaceAll(RegExp(r'''class=\s*["']ql-align-center["']''', caseSensitive: false), 'style="text-align: center;"')
              .replaceAll(RegExp(r'''class=\s*["']ql-align-right["']''', caseSensitive: false), 'style="text-align: right;"')
              .replaceAll(RegExp(r'''class=\s*["']ql-align-justify["']''', caseSensitive: false), 'style="text-align: justify;"');
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
            final attrs = Map<String, dynamic>.from(op['attributes'] as Map);
            bool modified = false;
            if (attrs.containsKey('color') && attrs['color'] is String) {
              final color = attrs['color'] as String;
              if (color.startsWith('#') && color.length == 9) {
                attrs['color'] = '#${color.substring(3)}';
                modified = true;
              }
            }
            if (attrs.containsKey('background') && attrs['background'] is String) {
              final bg = attrs['background'] as String;
              if (bg.startsWith('#') && bg.length == 9) {
                attrs['background'] = '#${bg.substring(3)}';
                modified = true;
              }
            }
            if (modified) {
              return {
                ...op,
                'attributes': attrs,
              };
            }
          }
          return op;
        }).toList();

        final converter = QuillDeltaToHtmlConverter(
          normalizedDeltaJson,
          ConverterOptions.forEmail(),
        );
        _htmlDescriptionController.text = _stripHtmlCssAndClasses(converter.convert());
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
            final attrs = Map<String, dynamic>.from(op['attributes'] as Map);
            bool modified = false;
            if (attrs.containsKey('color') && attrs['color'] is String) {
              final color = attrs['color'] as String;
              if (color.startsWith('#') && color.length == 9) {
                attrs['color'] = '#' + color.substring(3);
                modified = true;
              }
            }
            if (attrs.containsKey('background') && attrs['background'] is String) {
              final bg = attrs['background'] as String;
              if (bg.startsWith('#') && bg.length == 9) {
                attrs['background'] = '#' + bg.substring(3);
                modified = true;
              }
            }
            if (modified) {
              return {
                ...op,
                'attributes': attrs,
              };
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

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return _MobilePreviewDialog(html: html);
      },
    );
  }

  void _addVariant({Map<String, dynamic>? data}) {
    final String? variantId = data?['id']?.toString() ?? data?['_id']?.toString();
    final String initialPrice = data?['price'] != null
        ? data!['price'].toString()
        : '';
    final String initialCompare = data?['compareAtPrice'] != null
        ? data!['compareAtPrice'].toString()
        : '';
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
    final packValCtrl = TextEditingController(text: packVal);
    final compareRateCtrl = TextEditingController();
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

    double getFactor() {
      double factor = 1.0;
      final String currentUnit = packUnit.toLowerCase().trim();
      if (currentUnit == 'ml' || currentUnit == 'gm' || currentUnit == 'g') {
        factor = 0.001;
      }
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

        for (var tier in variantPriceTiers) {
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
        if (variantId != null) 'id': variantId,
        if (variantId != null) '_id': variantId,
        'price': priceCtrl,
        'compareAtPrice': compareCtrl,
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
      });
    });
  }

  void _removeVariant(int index) {
    final variant = _formVariants[index];
    variant['price']?.dispose();
    variant['compareAtPrice']?.dispose();
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
    return _topLevelStripHtmlCssAndClasses(html);
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
              final attrs = Map<String, dynamic>.from(op['attributes'] as Map);
              bool modified = false;
              if (attrs.containsKey('color') && attrs['color'] is String) {
                final color = attrs['color'] as String;
                if (color.startsWith('#') && color.length == 9) {
                  attrs['color'] = '#' + color.substring(3);
                  modified = true;
                }
              }
              if (attrs.containsKey('background') && attrs['background'] is String) {
                final bg = attrs['background'] as String;
                if (bg.startsWith('#') && bg.length == 9) {
                  attrs['background'] = '#' + bg.substring(3);
                  modified = true;
                }
              }
              if (modified) {
                return {
                  ...op,
                  'attributes': attrs,
                };
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

        final variantPriceTiers = v['priceTiers'] as List<Map<String, String>>;

        variantsData.add({
          if (v['id'] != null) 'id': v['id'],
          if (v['_id'] != null) '_id': v['_id'],
          'price': primaryRateWithSuffix,
          'compareAtPrice': mrpRateWithSuffix,
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
                  s['name'].toString().toLowerCase() == subCatName.toLowerCase(),
              orElse: () => null,
            );
            if (matchingSub != null) {
              final id =
                  matchingSub['id']?.toString() ?? matchingSub['_id']?.toString();
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

        return {
          if (v['id'] != null) 'id': v['id'],
          if (v['_id'] != null) '_id': v['_id'],
          'size': v['packSize'],
          'price': priceVal,
          'compareAtPrice': compareVal,
          'packVolume': _getPackVolume(v['basePacking'] ?? ''),
          'basePacking': v['basePacking'],
          'weight': 0.0,
          'rates': v['rates'],
          'computedPrices': v['computedPrices'],
          'priceTiers': v['priceTiers'],
        };
      }).toList();

      final bool isEdit = widget.initialData != null;

      final productData = {
        'title': _nameController.text.trim(),
        'brandName': _vendorController.text.trim(),
        'technicalName': _nameController.text.trim(),
        'vendor': _vendorController.text.trim(),
        'categoryId': categoryIds.first,
        'subCategoryId': subCategoryIds.isNotEmpty
            ? subCategoryIds.first
            : null,
        'categoryIds': categoryIds,
        'subCategoryIds': subCategoryIds,
        'description': description,
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
    final match = RegExp(
      r'^([\d.]+)(ml|lit|litre|l|gm|gram|g|kg|kilogram|k|pcs|piece|pieces)$',
    ).firstMatch(clean);
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
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                                    _isHtmlMode ? Icons.remove_red_eye_rounded : Icons.code_rounded,
                                    size: 16,
                                    color: AppTheme.primaryColor,
                                  ),
                                  label: Text(
                                    _isHtmlMode ? 'Visual Editor' : 'HTML Editor',
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
                                        config:
                                            quill.QuillSimpleToolbarConfig(
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
                                              controller: _htmlDescriptionController,
                                              maxLines: null,
                                              minLines: 15,
                                              keyboardType: TextInputType.multiline,
                                              style: GoogleFonts.robotoMono(
                                                fontSize: 13,
                                                color: Colors.blueGrey.shade900,
                                              ),
                                              decoration: const InputDecoration(
                                                border: InputBorder.none,
                                                hintText: 'Write raw HTML here (e.g. <p>Hello <b>World</b></p>)...',
                                                hintStyle: TextStyle(
                                                  color: AppTheme.textSecondary,
                                                  fontSize: 13,
                                                ),
                                              ),
                                            )
                                          : quill.QuillEditor.basic(
                                              controller: _descriptionController,
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
                  _buildTagsCard(),
                  const SizedBox(height: 24),
                  _buildAssignedCollectionsCard(),
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
    final bool hasAnyImages =
        _existingImageUrls.isNotEmpty || _productImages.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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

        InkWell(
          onTap: _pickMultipleProductImages,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(vertical: hasAnyImages ? 16 : 32),
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
                          final remainingCategories = _formCategories.where((c) => c != cat).toList();
                          final List<String> retainedSubs = [];
                          for (var rCat in remainingCategories) {
                            final matchingCat = _backendCategories.firstWhere(
                              (c) => c['name'].toString().toLowerCase() == rCat.toLowerCase(),
                              orElse: () => null,
                            );
                            if (matchingCat != null) {
                              final List subs = matchingCat['subCategories'] ?? [];
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
                            (c) => c['name'].toString().toLowerCase() == cat.toLowerCase(),
                            orElse: () => null,
                          );
                          if (matchingCat != null) {
                            final List subs =
                                matchingCat['subCategories'] ?? [];
                            for (var sub in subs) {
                              final name = sub['name']?.toString() ?? '';
                              if (name.isNotEmpty && !retainedSubs.contains(name.toLowerCase())) {
                                subsToRemove.add(name);
                              }
                            }
                          }
                          _formSubCategories.removeWhere(
                            (sub) => subsToRemove.any((s) => s.toLowerCase() == sub.toLowerCase()),
                          );
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
                      items: categoryOptions.map((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(
                            value,
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
                                  if (!_formCategories.contains(name)) {
                                    _formCategories.add(name);
                                  }
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
      builder: (context) {
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
                  if (_formCategories.length > 1) ...[
                    Text(
                      'Select Category:',
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.borderColor),
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
                                    style: GoogleFonts.outfit(fontSize: 14),
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
                    const SizedBox(height: 16),
                  ],
                  Text(
                    'Enter sub-category name to add under $targetCategoryName.',
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
    final priceTiers = variant['priceTiers'] as List<Map<String, String>>;

    for (var tier in priceTiers) {
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
                    if (val == null || val.trim().isEmpty) {
                      return null; // Optional
                    }
                    final numVal = double.tryParse(val);
                    if (numVal == null || numVal <= 0) return 'Must be > 0';
                    // Tier 2/3 rates should be <= Tier 1 (descending price tiers)
                    final t1Val = double.tryParse(
                      (variant['rates']
                                  as Map<String, TextEditingController>)['1']
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
                  Row(
                    children: [
                      TextButton.icon(
                        onPressed: () => _showManageTiersDialog(variant),
                        icon: const Icon(Icons.settings_outlined, size: 16),
                        label: Text(
                          'Manage Tiers',
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: TextButton.styleFrom(
                          foregroundColor: AppTheme.primaryColor,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                      if (_formVariants.length > 1) ...[
                        const SizedBox(width: 12),
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
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [sizeFields, const SizedBox(height: 16), rateFields],
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
                    splashColor: Colors.transparent,
                    highlightColor: Colors.transparent,
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
                        splashColor: Colors.transparent,
                        highlightColor: Colors.transparent,
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

  Widget _buildAssignedCollectionsCard() {
    // Generate top-level collection options
    final List<String> collectionOptions = [];
    final Map<String, List<Map<String, String>>> subCollectionMap = {};
    final Map<String, String> collectionNameToId = {};

    for (var col in _backendCollections) {
      final colId = col['id']?.toString() ?? col['_id']?.toString() ?? '';
      final colName = col['name']?.toString() ?? '';
      if (colId.isNotEmpty && colName.isNotEmpty) {
        collectionOptions.add(colName);
        collectionNameToId[colName] = colId;

        final List subs = col['subCollections'] ?? [];
        final List<Map<String, String>> subList = [];
        for (var sub in subs) {
          final subId = sub['id']?.toString() ?? sub['_id']?.toString() ?? '';
          final subName = sub['name']?.toString() ?? '';
          if (subId.isNotEmpty && subName.isNotEmpty) {
            subList.add({'id': subId, 'name': subName});
          }
        }
        subCollectionMap[colName] = subList;
      }
    }

    final currentSubOptions = _formSelectedCollection != null
        ? (subCollectionMap[_formSelectedCollection] ?? [])
        : <Map<String, String>>[];

    final List<String> subCollectionNames = currentSubOptions
        .map((e) => e['name']!)
        .toList();
    subCollectionNames.insert(0, 'All Sub-collections');

    return _buildSectionCard(
      title: 'Collections',
      icon: Icons.collections_bookmark_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_assignedCollections.isNotEmpty) ...[
            Wrap(
              spacing: 8,
              runSpacing: 10,
              children: _assignedCollections.map((col) {
                final displayName = _collectionIdToName[col] ?? col;
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
                          displayName,
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
                            _assignedCollections.remove(col);
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
            const SizedBox(height: 16),
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
                  flex: 5,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 16),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        hint: Text(
                          'Select Collection',
                          style: GoogleFonts.outfit(
                            fontSize: 14,
                            color: const Color(0xFF94A3B8),
                          ),
                        ),
                        value: _formSelectedCollection,
                        icon: const Padding(
                          padding: EdgeInsets.only(right: 8),
                          child: Icon(
                            Icons.keyboard_arrow_down_rounded,
                            size: 18,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                        items: collectionOptions.map((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(
                              value,
                              style: GoogleFonts.outfit(
                                fontSize: 14,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          setState(() {
                            _formSelectedCollection = val;
                            _formSelectedSubCollection = 'All Sub-collections';
                          });
                        },
                      ),
                    ),
                  ),
                ),
                if (_formSelectedCollection != null) ...[
                  Container(
                    width: 1,
                    height: 24,
                    color: const Color(0xFFE2E8F0),
                  ),
                  Expanded(
                    flex: 5,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 12),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          isExpanded: true,
                          value: _formSelectedSubCollection,
                          icon: const Padding(
                            padding: EdgeInsets.only(right: 8),
                            child: Icon(
                              Icons.keyboard_arrow_down_rounded,
                              size: 18,
                              // var= 1;
                              //mid= 98;
                              color: Color(0xFF94A3B8),
                            ),
                          ),
                          items: subCollectionNames.map((String value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(
                                value,
                                style: GoogleFonts.outfit(
                                  fontSize: 14,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            setState(() {
                              _formSelectedSubCollection = val;
                            });
                          },
                        ),
                      ),
                    ),
                  ),
                ],
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: InkWell(
                    onTap: _formSelectedCollection == null
                        ? null
                        : () {
                            setState(() {
                              String idToAssign = '';
                              if (_formSelectedSubCollection !=
                                  'All Sub-collections') {
                                idToAssign = _formSelectedSubCollection!;
                              } else {
                                idToAssign = _formSelectedCollection!;
                              }
                              if (idToAssign.isNotEmpty &&
                                  !_assignedCollections.contains(idToAssign)) {
                                _assignedCollections.add(idToAssign);
                                _formSelectedCollection = null;
                                _formSelectedSubCollection = null;
                              }
                            });
                          },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: _formSelectedCollection == null
                            ? const Color(0xFFE2E8F0)
                            : AppTheme.primaryColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.add_rounded,
                        color: Colors.white,
                        size: 20,
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
}

class PreviewHtmlBlock {
  final List<InlineSpan> spans;
  final TextAlign alignment;
  final String blockType;
  final Widget? widget;

  PreviewHtmlBlock({
    required this.spans,
    this.alignment = TextAlign.left,
    this.blockType = 'p',
    this.widget,
  });
}

class _MobilePreviewDialog extends StatefulWidget {
  final String html;

  const _MobilePreviewDialog({required this.html});

  @override
  State<_MobilePreviewDialog> createState() => _MobilePreviewDialogState();
}

class _MobilePreviewDialogState extends State<_MobilePreviewDialog> {
  bool _isDarkMode = false;

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final screenHeight = mediaQuery.size.height;

    // Simulated phone background and text colors
    final phoneBg = _isDarkMode ? const Color(0xFF121212) : Colors.white;
    final phoneAppBarBg = _isDarkMode ? const Color(0xFF1F1F1F) : const Color(0xFF00A651);
    final phoneAppBarText = Colors.white;

    return Container(
      height: screenHeight * 0.9,
      decoration: const BoxDecoration(
        color: Color(0xFFF1F5F9), // Slate background behind the phone
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Column(
        children: [
          // Header of the Bottom Sheet
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 4,
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.phone_android_rounded, color: AppTheme.primaryColor),
                    const SizedBox(width: 8),
                    Text(
                      'KrishiKranti Mobile Simulator',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    // Theme Toggle
                    IconButton(
                      icon: Icon(
                        _isDarkMode ? Icons.wb_sunny_rounded : Icons.nights_stay_rounded,
                        color: AppTheme.primaryColor,
                      ),
                      tooltip: 'Toggle Light/Dark Preview',
                      onPressed: () {
                        setState(() {
                          _isDarkMode = !_isDarkMode;
                        });
                      },
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: AppTheme.textSecondary),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Content Area containing the simulated phone frame
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Container(
                  width: 375, // Standard iPhone/Android width
                  height: 680,
                  decoration: BoxDecoration(
                    color: phoneBg,
                    borderRadius: BorderRadius.circular(36),
                    border: Border.all(color: const Color(0xFF1E293B), width: 12), // Phone Bezel
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 20,
                        spreadRadius: 5,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      // Simulated Phone Status Bar
                      Container(
                        height: 24,
                        color: phoneAppBarBg,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '9:41',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: phoneAppBarText,
                              ),
                            ),
                            Row(
                              children: [
                                Icon(Icons.signal_cellular_4_bar, size: 11, color: phoneAppBarText),
                                const SizedBox(width: 4),
                                Icon(Icons.wifi, size: 11, color: phoneAppBarText),
                                const SizedBox(width: 4),
                                Icon(Icons.battery_std_rounded, size: 11, color: phoneAppBarText),
                              ],
                            ),
                          ],
                        ),
                      ),
                      
                      // Simulated App Bar
                      Container(
                        height: 48,
                        color: phoneAppBarBg,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Row(
                          children: [
                            Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: phoneAppBarText),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Product Details',
                                style: GoogleFonts.outfit(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: phoneAppBarText,
                                ),
                              ),
                            ),
                            Icon(Icons.share_rounded, size: 18, color: phoneAppBarText),
                            const SizedBox(width: 12),
                            Icon(Icons.shopping_cart_rounded, size: 18, color: phoneAppBarText),
                            const SizedBox(width: 8),
                          ],
                        ),
                      ),
                      
                      // Simulated Mobile Screen Body (Scrollable description details)
                      Expanded(
                        child: Container(
                          color: phoneBg,
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Mock Product Media / Title Header just to frame the description nicely
                                Container(
                                  height: 180,
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    color: _isDarkMode ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Center(
                                    child: Icon(
                                      Icons.image,
                                      size: 48,
                                      color: _isDarkMode ? Colors.white30 : Colors.black26,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Container(
                                  width: 120,
                                  height: 16,
                                  decoration: BoxDecoration(
                                    color: _isDarkMode ? Colors.white12 : Colors.black12,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  width: 220,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    color: _isDarkMode ? Colors.white24 : Colors.black26,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                
                                // Tab selection simulated
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                      decoration: const BoxDecoration(
                                        border: Border(
                                          bottom: BorderSide(
                                            color: Color(0xFF00A651),
                                            width: 2,
                                          ),
                                        ),
                                      ),
                                      child: const Text(
                                        'Description',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          color: Color(0xFF00A651),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Text(
                                      'Specifications',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: _isDarkMode ? Colors.white54 : Colors.black54,
                                      ),
                                    ),
                                  ],
                                ),
                                Divider(height: 1, color: _isDarkMode ? Colors.white12 : Colors.black12),
                                const SizedBox(height: 16),
                                
                                // Actual Rich HTML Description Rendered
                                Builder(
                                  builder: (context) {
                                    final parsedBlocks = previewParseHtml(widget.html);
                                    if (parsedBlocks.isEmpty) {
                                      return Center(
                                        child: Padding(
                                          padding: const EdgeInsets.only(top: 32.0),
                                          child: Text(
                                            'No description provided.',
                                            style: TextStyle(
                                              color: _isDarkMode ? Colors.white54 : Colors.black54,
                                              fontStyle: FontStyle.italic,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ),
                                      );
                                    }
                                    return previewBuildHtmlContent(
                                      context,
                                      parsedBlocks,
                                      isDarkMode: _isDarkMode,
                                    );
                                  },
                                ),
                                const SizedBox(height: 32),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewFaqExpansionTile extends StatelessWidget {
  final String question;
  final String answerHtml;
  final Map<String, Widget> widgetMap;

  const _PreviewFaqExpansionTile({
    required this.question,
    required this.answerHtml,
    required this.widgetMap,
  });

  @override
  Widget build(BuildContext context) {
    final cleanQuestion = question
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .trim();

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            cleanQuestion,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 6),
          Builder(
            builder: (context) {
              final innerBlocks = previewParseHtml(
                answerHtml,
                widgetMap: widgetMap,
              );
              return previewBuildHtmlContent(context, innerBlocks);
            },
          ),
        ],
      ),
    );
  }
}

class _PreviewFaqTableWidget extends StatelessWidget {
  final String tableHtml;

  const _PreviewFaqTableWidget({required this.tableHtml});

  @override
  Widget build(BuildContext context) {
    final trRegex = RegExp(
      r'<tr[^>]*>(.*?)</tr>',
      dotAll: true,
      caseSensitive: false,
    );
    final cellRegex = RegExp(
      r'<(td|th)[^>]*>(.*?)</\1>',
      dotAll: true,
      caseSensitive: false,
    );

    final trMatches = trRegex.allMatches(tableHtml).toList();
    if (trMatches.isEmpty) return const SizedBox.shrink();

    final List<TableRow> rows = [];

    for (int rowIndex = 0; rowIndex < trMatches.length; rowIndex++) {
      final trHtml = trMatches[rowIndex].group(1)!;
      final cellMatches = cellRegex.allMatches(trHtml).toList();

      final List<Widget> rowCells = [];
      final bool isHeader =
          trMatches[rowIndex].group(0)!.toLowerCase().startsWith('<tr') &&
          trHtml.toLowerCase().contains('<th');

      for (int colIndex = 0; colIndex < cellMatches.length; colIndex++) {
        final cellMatch = cellMatches[colIndex];
        final cellInnerHtml = cellMatch.group(2)!;

        Widget cellContent;
        if (isHeader) {
          final cellBlocks = previewParseHtml(cellInnerHtml);
          cellContent = previewBuildHtmlContent(
            context,
            cellBlocks,
            defaultTextColor: Colors.black87,
          );
        } else {
          bool enforceBold = false;
          if (colIndex == 0) {
            enforceBold = true;
          }

          final cellBlocks = previewParseHtml(cellInnerHtml);
          Widget child = previewBuildHtmlContent(
            context,
            cellBlocks,
          );

          if (enforceBold) {
            child = DefaultTextStyle.merge(
              style: const TextStyle(fontWeight: FontWeight.bold),
              child: child,
            );
          }
          cellContent = child;
        }

        rowCells.add(
          Container(
            color: Colors.transparent,
            padding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 8,
            ),
            alignment: Alignment.centerLeft,
            child: cellContent,
          ),
        );
      }

      if (rowCells.isNotEmpty) {
        rows.add(TableRow(children: rowCells));
      }
    }

    if (rows.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Table(
          defaultColumnWidth: const IntrinsicColumnWidth(),
          border: TableBorder.all(color: const Color(0xFFDDDDDD), width: 1),
          children: rows,
        ),
      ),
    );
  }
}

Widget _buildPreviewStyledBox(
  String innerHtml,
  String boxClass,
  Map<String, Widget> wMap,
) {
  Color? defaultTextColor;
  BoxDecoration decoration;

  if (boxClass == 'intro') {
    decoration = const BoxDecoration(
      color: Color(0xFFF9F9F9),
      border: Border(left: BorderSide(color: Color(0xFF00A651), width: 6)),
    );
  } else if (boxClass == 'warn') {
    defaultTextColor = const Color(0xFFCC0000);
    decoration = const BoxDecoration(
      color: Color(0xFFFFF5F5),
      border: Border(left: BorderSide(color: Color(0xFFCC0000), width: 6)),
    );
  } else if (boxClass == 'highlight') {
    decoration = const BoxDecoration(
      color: Color(0xFFF9F9F9),
      border: Border(left: BorderSide(color: Colors.black, width: 6)),
    );
  } else {
    // table-note
    decoration = const BoxDecoration(
      color: Color(0xFFF9F9F9),
      border: Border(
        top: BorderSide(color: Color(0xFF00A651), width: 3),
        left: BorderSide(color: Color(0xFFDDDDDD), width: 1),
        right: BorderSide(color: Color(0xFFDDDDDD), width: 1),
        bottom: BorderSide(color: Color(0xFFDDDDDD), width: 1),
      ),
    );
  }

  return Container(
    width: double.infinity,
    margin: const EdgeInsets.symmetric(vertical: 12),
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
    decoration: decoration,
    child: Builder(
      builder: (context) {
        final innerBlocks = previewParseHtml(innerHtml, widgetMap: wMap);
        return previewBuildHtmlContent(
          context,
          innerBlocks,
          defaultTextColor: defaultTextColor,
        );
      },
    ),
  );
}

Widget _buildPreviewTableWidget(String tableHtml) {
  return _PreviewFaqTableWidget(tableHtml: tableHtml);
}

Widget _buildPreviewFaqWidget(String detailsHtml, Map<String, Widget> wMap) {
  final summaryRegex = RegExp(
    r'<summary[^>]*>(.*?)</summary>',
    dotAll: true,
    caseSensitive: false,
  );
  final summaryMatch = summaryRegex.firstMatch(detailsHtml);
  String question = 'FAQ';
  if (summaryMatch != null) {
    question = summaryMatch.group(1)!;
  }

  String answerHtml = detailsHtml
      .replaceFirst(summaryRegex, '')
      .replaceFirst(RegExp(r'^<details[^>]*>', caseSensitive: false), '')
      .replaceFirst(RegExp(r'</details>$', caseSensitive: false), '')
      .trim();

  return _PreviewFaqExpansionTile(
    question: question,
    answerHtml: answerHtml,
    widgetMap: wMap,
  );
}

Color? _previewParseColor(String colorStr) {
  if (colorStr.startsWith('#')) {
    final hex = colorStr.substring(1);
    if (hex.length == 8) {
      return Color(int.parse(hex, radix: 16));
    } else if (hex.length == 6) {
      return Color(int.parse('FF$hex', radix: 16));
    } else if (hex.length == 3) {
      final r = hex[0];
      final g = hex[1];
      final b = hex[2];
      return Color(int.parse('FF$r$r$g$g$b$b', radix: 16));
    }
  }
  if (colorStr.startsWith('rgb')) {
    final match = RegExp(
      r'rgb\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*\)',
    ).firstMatch(colorStr);
    if (match != null) {
      final r = int.parse(match.group(1)!);
      final g = int.parse(match.group(2)!);
      final b = int.parse(match.group(3)!);
      return Color.fromARGB(255, r, g, b);
    }
  }
  final lower = colorStr.toLowerCase();
  if (lower == 'red') return Colors.red;
  if (lower == 'blue') return Colors.blue;
  if (lower == 'green') return Colors.green;
  if (lower == 'yellow') return Colors.yellow;
  if (lower == 'orange') return Colors.orange;
  if (lower == 'black') return Colors.black;
  if (lower == 'white') return Colors.white;
  if (lower == 'grey' || lower == 'gray') return Colors.grey;
  return null;
}

String _topLevelStripHtmlCssAndClasses(String html) {
  return html
      .replaceAll('\r', '')
      .replaceAll(RegExp(r'''\s*style\s*=\s*["'][^"']*["']''', caseSensitive: false), '')
      .replaceAll(RegExp(r'''\s*class\s*=\s*["'][^"']*["']''', caseSensitive: false), '')
      .replaceAll(RegExp(r'''\s*id\s*=\s*["'][^"']*["']''', caseSensitive: false), '')
      .replaceAll(RegExp(r'<style[^>]*>.*?</style>', dotAll: true, caseSensitive: false), '')
      .replaceAll(RegExp(r'<script[^>]*>.*?</script>', dotAll: true, caseSensitive: false), '');
}

List<PreviewHtmlBlock> previewParseHtml(String html, {Map<String, Widget>? widgetMap}) {
  final List<PreviewHtmlBlock> blocks = [];
  final Map<String, Widget> wMap = widgetMap ?? {};

  String cleanHtml = _topLevelStripHtmlCssAndClasses(html);

  int placeholderCount = wMap.length;

  // 1. Extract <details> (FAQ)
  final detailsRegex = RegExp(
    r'<details[^>]*>.*?</details>',
    dotAll: true,
    caseSensitive: false,
  );
  while (true) {
    final match = detailsRegex.firstMatch(cleanHtml);
    if (match == null) break;
    final detailsHtml = match.group(0)!;
    final placeholder = '<!--W_${placeholderCount++}-->';
    wMap[placeholder] = _buildPreviewFaqWidget(detailsHtml, wMap);
    cleanHtml = cleanHtml.replaceRange(match.start, match.end, placeholder);
  }

  // 2. Extract <table>
  final tableRegex = RegExp(
    r'<table[^>]*>.*?</table>',
    dotAll: true,
    caseSensitive: false,
  );
  while (true) {
    final match = tableRegex.firstMatch(cleanHtml);
    if (match == null) break;
    final tableHtml = match.group(0)!;
    final placeholder = '<!--W_${placeholderCount++}-->';
    wMap[placeholder] = _buildPreviewTableWidget(tableHtml);
    cleanHtml = cleanHtml.replaceRange(match.start, match.end, placeholder);
  }

  // 3. Extract styled boxes (divs with class intro, warn, highlight, table-note)
  final divRegex = RegExp(
    r'''<div\s+class=["'](intro|warn|highlight|table-note)["'][^>]*>(.*?)</div>''',
    dotAll: true,
    caseSensitive: false,
  );
  while (true) {
    final match = divRegex.firstMatch(cleanHtml);
    if (match == null) break;
    final boxClass = match.group(1)!.toLowerCase();
    final innerHtml = match.group(2)!;
    final placeholder = '<!--W_${placeholderCount++}-->';
    wMap[placeholder] = _buildPreviewStyledBox(innerHtml, boxClass, wMap);
    cleanHtml = cleanHtml.replaceRange(match.start, match.end, placeholder);
  }

  final regex = RegExp(r'<!--W_\d+-->|<[^>]+>|[^<]+');
  final matches = regex.allMatches(cleanHtml);

  bool isBold = false;
  bool isItalic = false;
  bool isUnderline = false;
  bool isStrike = false;
  List<Color> colorStack = [];
  List<Color> bgStack = [];
  List<String> fontStack = [];
  List<Map<String, bool>> spanPushedStack = [];
  String? currentLinkUrl;

  List<InlineSpan> currentSpans = [];
  TextAlign currentAlignment = TextAlign.left;
  String currentBlockType = 'p';

  bool inOrderedList = false;
  int orderedListIndex = 0;

  void commitBlock() {
    if (currentSpans.isNotEmpty) {
      blocks.add(
        PreviewHtmlBlock(
          spans: List.from(currentSpans),
          alignment: currentAlignment,
          blockType: currentBlockType,
        ),
      );
      currentSpans.clear();
    }
    currentAlignment = TextAlign.left;
    currentBlockType = 'p';
  }

  for (final match in matches) {
    final token = match.group(0)!;
    if (token.startsWith('<!--W_') && token.endsWith('-->')) {
      commitBlock();
      final widget = wMap[token];
      if (widget != null) {
        blocks.add(PreviewHtmlBlock(spans: [], blockType: 'widget', widget: widget));
      }
      continue;
    }
    if (token.startsWith('<') && token.endsWith('>')) {
      final tag = token.toLowerCase();

      if (tag.startsWith('<span')) {
        final styleMatch = RegExp(
          r'''style=["']([^"']*)["']''',
        ).firstMatch(token);
        bool pushedColor = false;
        bool pushedBg = false;
        bool pushedFont = false;
        if (styleMatch != null) {
          final styleContent = styleMatch.group(1)!;
          final colorMatch = RegExp(
            r'(?<!-)color:\s*([^;]+)',
          ).firstMatch(styleContent);
          if (colorMatch != null) {
            final colorStr = colorMatch.group(1)!.trim();
            final parsedColor = _previewParseColor(colorStr);
            if (parsedColor != null) {
              colorStack.add(parsedColor);
              pushedColor = true;
            }
          }
          final bgMatch = RegExp(
            r'background-color:\s*([^;]+)',
          ).firstMatch(styleContent);
          if (bgMatch != null) {
            final bgStr = bgMatch.group(1)!.trim();
            final parsedBg = _previewParseColor(bgStr);
            if (parsedBg != null) {
              bgStack.add(parsedBg);
              pushedBg = true;
            }
          }
          final fontMatch = RegExp(
            r'font-family:\s*([^;]+)',
          ).firstMatch(styleContent);
          if (fontMatch != null) {
            final fontStr = fontMatch
                .group(1)!
                .trim()
                .replaceAll(RegExp(r'''['"]'''), '');
            if (fontStr.isNotEmpty) {
              fontStack.add(fontStr);
              pushedFont = true;
            }
          }
        }
        spanPushedStack.add({
          'color': pushedColor,
          'bg': pushedBg,
          'font': pushedFont,
        });
      } else if (tag == '</span>') {
        if (spanPushedStack.isNotEmpty) {
          final pushed = spanPushedStack.removeLast();
          if (pushed['color'] == true && colorStack.isNotEmpty) {
            colorStack.removeLast();
          }
          if (pushed['bg'] == true && bgStack.isNotEmpty) {
            bgStack.removeLast();
          }
          if (pushed['font'] == true && fontStack.isNotEmpty) {
            fontStack.removeLast();
          }
        } else {
          if (colorStack.isNotEmpty) colorStack.removeLast();
          if (bgStack.isNotEmpty) bgStack.removeLast();
          if (fontStack.isNotEmpty) fontStack.removeLast();
        }
      } else if (tag.startsWith('<a')) {
        final hrefMatch = RegExp(
          r'''href=["']([^"']*)["']''',
        ).firstMatch(token);
        if (hrefMatch != null) {
          currentLinkUrl = hrefMatch.group(1);
        }
      } else if (tag == '</a>') {
        currentLinkUrl = null;
      } else if (tag.startsWith('<p') || tag.startsWith('<div')) {
        commitBlock();
        if (tag.contains('ql-align-center') ||
            tag.contains('text-align: center') ||
            tag.contains('text-align:center')) {
          currentAlignment = TextAlign.center;
        } else if (tag.contains('ql-align-right') ||
            tag.contains('text-align: right') ||
            tag.contains('text-align:right')) {
          currentAlignment = TextAlign.right;
        } else if (tag.contains('ql-align-justify') ||
            tag.contains('text-align: justify') ||
            tag.contains('text-align:justify')) {
          currentAlignment = TextAlign.justify;
        }
      } else if (tag == '<strong>' || tag == '<b>') {
        isBold = true;
      } else if (tag == '</strong>' || tag == '</b>') {
        isBold = false;
      } else if (tag == '<em>' || tag == '<i>') {
        isItalic = true;
      } else if (tag == '</em>' || tag == '</i>') {
        isItalic = false;
      } else if (tag == '<u>') {
        isUnderline = true;
      } else if (tag == '</u>') {
        isUnderline = false;
      } else if (tag == '<s>' || tag == '<strike>' || tag == '<del>') {
        isStrike = true;
      } else if (tag == '</s>' || tag == '</strike>' || tag == '</del>') {
        isStrike = false;
      } else if (tag == '<ol>') {
        inOrderedList = true;
        orderedListIndex = 0;
      } else if (tag == '</ol>') {
        inOrderedList = false;
      } else if (tag == '<ul>') {
        inOrderedList = false;
      } else if (tag == '</ul>') {
        // No-op
      } else if (tag.startsWith('<li')) {
        commitBlock();
        if (inOrderedList) {
          orderedListIndex++;
          currentBlockType = 'ol-li-$orderedListIndex';
        } else {
          currentBlockType = 'ul-li';
        }
      } else if (tag == '</li>') {
        commitBlock();
      } else if (tag.startsWith('<h1')) {
        commitBlock();
        currentBlockType = 'h1';
      } else if (tag == '</h1>') {
        commitBlock();
      } else if (tag.startsWith('<h2')) {
        commitBlock();
        currentBlockType = 'h2';
      } else if (tag == '</h2>') {
        commitBlock();
      } else if (tag.startsWith('<h3')) {
        commitBlock();
        currentBlockType = 'h3';
      } else if (tag == '</h3>') {
        commitBlock();
      } else if (tag == '<br>' || tag == '<br/>' || tag == '<br />') {
        currentSpans.add(const TextSpan(text: '\n'));
      }
    } else {
      final text = token;
      if (text.isNotEmpty) {
        final Color? textColor = colorStack.isNotEmpty ? colorStack.last : null;
        final Color? bgColor = bgStack.isNotEmpty ? bgStack.last : null;
        final String? fontFam = fontStack.isNotEmpty ? fontStack.last : null;

        TextStyle textStyle = TextStyle(
          fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          fontStyle: isItalic ? FontStyle.italic : FontStyle.normal,
          decoration: TextDecoration.combine([
            if (isUnderline) TextDecoration.underline,
            if (isStrike) TextDecoration.lineThrough,
          ]),
          color: textColor,
          backgroundColor: bgColor,
        );

        if (fontFam != null) {
          try {
            textStyle = GoogleFonts.getFont(fontFam, textStyle: textStyle);
          } catch (_) {
            textStyle = textStyle.copyWith(fontFamily: fontFam);
          }
        }

        if (currentLinkUrl != null) {
          final targetUrl = currentLinkUrl;
          textStyle = textStyle.copyWith(
            color: Colors.blue.shade800,
            decoration: TextDecoration.underline,
          );
          currentSpans.add(
            TextSpan(
              text: text,
              style: textStyle,
              recognizer: TapGestureRecognizer()
                ..onTap = () async {
                  final uri = Uri.tryParse(targetUrl);
                  if (uri != null && await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
            ),
          );
        } else {
          currentSpans.add(TextSpan(text: text, style: textStyle));
        }
      }
    }
  }
  commitBlock();
  return blocks;
}

Widget previewBuildHtmlContent(
  BuildContext context,
  List<PreviewHtmlBlock> blocks, {
  Color? defaultTextColor,
  bool isDarkMode = false,
}) {
  final Color kBodyColor = defaultTextColor ?? (isDarkMode ? Colors.white70 : const Color(0xFF111111));
  const Color kGreen = Color(0xFF00A651);
  const double kBodyFontSize = 13.0;
  const double kLineHeight = 1.9;

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: blocks.map((block) {
      if (block.widget != null) {
        final blockPadding = block.blockType == 'widget'
            ? EdgeInsets.zero
            : const EdgeInsets.only(bottom: 12);
        return Padding(padding: blockPadding, child: block.widget!);
      }

      final spans = block.spans.map((span) {
        if (span is TextSpan && span.text != null) {
          final existing = span.style;
          return TextSpan(
            text: span.text,
            style: (existing ?? const TextStyle()).copyWith(
              color: existing?.color ?? kBodyColor,
              height: existing?.height ?? kLineHeight,
              fontSize: existing?.fontSize ?? kBodyFontSize,
            ),
            recognizer: span.recognizer,
          );
        }
        return span;
      }).toList();

      Widget widget;

      // ── ORDERED LIST ITEM ──
      if (block.blockType.startsWith('ol-li-')) {
        final number = block.blockType.substring(6);
        widget = Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$number. ',
                style: TextStyle(
                  fontSize: kBodyFontSize,
                  height: kLineHeight,
                  color: kBodyColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Expanded(
                child: RichText(
                  text: TextSpan(children: spans),
                  textAlign: block.alignment,
                ),
              ),
            ],
          ),
        );

        // ── UNORDERED LIST ITEM ──
      } else if (block.blockType == 'ul-li' || block.blockType == 'li') {
        widget = Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '• ',
                style: TextStyle(
                  fontSize: kBodyFontSize,
                  height: kLineHeight,
                  color: kBodyColor,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Expanded(
                child: RichText(
                  text: TextSpan(children: spans),
                  textAlign: block.alignment,
                ),
              ),
            ],
          ),
        );

        // ── H1 ──
      } else if (block.blockType == 'h1') {
        widget = RichText(
          text: TextSpan(
            children: spans.map((s) {
              if (s is TextSpan) {
                return TextSpan(
                  text: s.text,
                  recognizer: s.recognizer,
                  style: (s.style ?? const TextStyle()).copyWith(
                    fontSize: 20.0,
                    fontWeight: FontWeight.w800,
                    color: s.style?.color ?? kBodyColor,
                    height: 1.35,
                  ),
                );
              }
              return s;
            }).toList(),
          ),
          textAlign: block.alignment,
        );

        // ── H2 ──
      } else if (block.blockType == 'h2') {
        widget = RichText(
          text: TextSpan(
            children: spans.map((s) {
              if (s is TextSpan) {
                return TextSpan(
                  text: s.text,
                  recognizer: s.recognizer,
                  style: (s.style ?? const TextStyle()).copyWith(
                    fontSize: 16.0,
                    fontWeight: FontWeight.w700,
                    color: s.style?.color ?? kBodyColor,
                    height: 1.4,
                  ),
                );
              }
              return s;
            }).toList(),
          ),
          textAlign: block.alignment,
        );

        // ── H3 ──
      } else if (block.blockType == 'h3') {
        widget = SizedBox(
          width: double.infinity,
          child: RichText(
            text: TextSpan(
              children: spans.map((s) {
                if (s is TextSpan) {
                  return TextSpan(
                    text: s.text,
                    recognizer: s.recognizer,
                    style: (s.style ?? const TextStyle()).copyWith(
                      fontSize: 14.0,
                      fontWeight: FontWeight.w700,
                      color: s.style?.color ?? kBodyColor,
                      height: 1.5,
                    ),
                  );
                }
                return s;
              }).toList(),
            ),
            textAlign: block.alignment,
          ),
        );

        // ── PARAGRAPH / DEFAULT ──
      } else {
        widget = SizedBox(
          width: double.infinity,
          child: RichText(
            text: TextSpan(children: spans),
            textAlign: block.alignment,
          ),
        );
      }

      // Spacing between blocks
      EdgeInsets blockPadding;
      if (block.blockType == 'h1') {
        blockPadding = const EdgeInsets.only(bottom: 14, top: 4);
      } else if (block.blockType == 'h2') {
        blockPadding = const EdgeInsets.only(top: 24, bottom: 12);
      } else if (block.blockType == 'h3') {
        blockPadding = const EdgeInsets.only(top: 14, bottom: 8);
      } else if (block.blockType == 'ul-li' ||
          block.blockType == 'li' ||
          block.blockType.startsWith('ol-li-')) {
        blockPadding = const EdgeInsets.only(bottom: 6);
      } else {
        blockPadding = const EdgeInsets.only(bottom: 12);
      }

      return Padding(padding: blockPadding, child: widget);
    }).toList(),
  );
}
