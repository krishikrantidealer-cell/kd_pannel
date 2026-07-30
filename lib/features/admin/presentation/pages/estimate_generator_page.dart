// estimate_generator_page.dart
// Interactive Estimate & Quotation creator for Sales Agents and Admins.

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kd_pannel/app_theme.dart';
import 'package:kd_pannel/core/network/api_client.dart';
import 'package:kd_pannel/util/export_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';

class EstimateGeneratorPage extends StatefulWidget {
  const EstimateGeneratorPage({super.key});

  @override
  State<EstimateGeneratorPage> createState() => _EstimateGeneratorPageState();
}

class _EstimateGeneratorPageState extends State<EstimateGeneratorPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // History list
  List<Map<String, dynamic>> _savedEstimates = [];
  String _searchQuery = '';
  bool _isLoadingHistory = true;

  // Active editing state (null if in list view)
  Map<String, dynamic>? _activeEstimate;

  // Form Controllers
  final _companyNameCtrl = TextEditingController(text: 'KRISHIKRANTI ORGANICS');
  final _companyGstCtrl = TextEditingController(text: '23ABEFK9255G1Z9');
  final _companyStateCtrl = TextEditingController(text: '23-Madhya Pradesh');
  final _companyPhoneCtrl = TextEditingController(text: '9399022060');
  final _companyEmailCtrl = TextEditingController(
    text: 'krishikrantiorganics@gmail.com',
  );
  final _companyAddressCtrl = TextEditingController(
    text:
        'EWS - 101, The Bellaire Appartment, Gondermau Gandhi Nagar, Bhopal 462036, Madhya Pradesh',
  );

  final _estimateNoCtrl = TextEditingController();
  final _estimateDateCtrl = TextEditingController();

  final _clientNameCtrl = TextEditingController();
  final _clientAddressCtrl = TextEditingController();
  final _clientPhoneCtrl = TextEditingController();
  final _searchCtrl = TextEditingController();

  // Product Search / Selection
  List<Map<String, dynamic>> _availableProducts = [];
  bool _isLoadingProducts = false;
  int? _focusedItemIdx;

  // Active list of items in editing
  List<Map<String, dynamic>> _editingItems = [];

  // Submitting state
  bool _isSaving = false;

  // GST Toggle
  bool _isGstEnabled = true;

  // Cache text controllers per item map instance to prevent cursor jumping
  final Map<Map<String, dynamic>, Map<String, TextEditingController>>
  _controllersCache = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadHistory();
    _fetchProducts();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _companyNameCtrl.dispose();
    _companyGstCtrl.dispose();
    _companyStateCtrl.dispose();
    _companyPhoneCtrl.dispose();
    _companyEmailCtrl.dispose();
    _companyAddressCtrl.dispose();
    _estimateNoCtrl.dispose();
    _estimateDateCtrl.dispose();
    _clientNameCtrl.dispose();
    _clientAddressCtrl.dispose();
    _clientPhoneCtrl.dispose();
    _searchCtrl.dispose();
    for (final ctrls in _controllersCache.values) {
      ctrls['name']?.dispose();
      ctrls['price']?.dispose();
      ctrls['quantity']?.dispose();
      ctrls['gst']?.dispose();
    }
    _controllersCache.clear();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoadingHistory = true);
    bool loadedFromBackend = false;
    try {
      final res = await ApiClient().get('/admin/estimates');
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        if (decoded['success'] == true) {
          final List raw = decoded['estimates'] ?? [];
          setState(() {
            _savedEstimates = raw
                .map((e) => Map<String, dynamic>.from(e as Map))
                .toList();
          });
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(
            'saved_estimates_history',
            jsonEncode(_savedEstimates),
          );
          loadedFromBackend = true;
        }
      }
    } catch (e) {
      debugPrint('Failed to load history from backend: $e');
    }

    if (!loadedFromBackend) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final data = prefs.getString('saved_estimates_history');
        if (data != null) {
          final List decoded = jsonDecode(data);
          setState(() {
            _savedEstimates = decoded
                .map((e) => Map<String, dynamic>.from(e as Map))
                .toList();
          });
        }
      } catch (_) {}
    }

    setState(() => _isLoadingHistory = false);
  }

  Future<void> _saveHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'saved_estimates_history',
        jsonEncode(_savedEstimates),
      );
    } catch (_) {}
  }

  Future<void> _fetchProducts() async {
    setState(() => _isLoadingProducts = true);
    try {
      final res = await ApiClient().get('/products?limit=1000');
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['success'] == true) {
          final List raw = data['products'] ?? [];
          setState(() {
            _availableProducts = raw
                .map((p) => Map<String, dynamic>.from(p as Map))
                .toList();
          });
        }
      }
    } catch (_) {
    } finally {
      setState(() => _isLoadingProducts = false);
    }
  }

  String _generateEstimateNo() {
    final now = DateTime.now();
    final year = now.year % 100;
    final nextYear = (now.year + 1) % 100;
    final rand = (1000 + (now.millisecondsSinceEpoch % 9000)).toString();
    return 'EBS/$year-$nextYear/EST/$rand';
  }

  String _formatToday() {
    final now = DateTime.now();
    return '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';
  }

  void _startNewEstimate() {
    setState(() {
      _isGstEnabled = true;
      for (final ctrls in _controllersCache.values) {
        ctrls['name']?.dispose();
        ctrls['price']?.dispose();
        ctrls['quantity']?.dispose();
        ctrls['gst']?.dispose();
      }
      _controllersCache.clear();
      _estimateNoCtrl.text = _generateEstimateNo();
      _estimateDateCtrl.text = _formatToday();
      _clientNameCtrl.clear();
      _clientAddressCtrl.clear();
      _clientPhoneCtrl.clear();

      _editingItems = [
        {
          'name': '',
          'quantity': 1.0,
          'unit': 'liter',
          'price': 0.0,
          'gst': 18.0,
          'amount': 0.0,
        },
      ];

      _activeEstimate = {
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
      };

      _tabController.index = 0; // Default to Editor Tab
    });
  }

  void _editEstimate(Map<String, dynamic> est) {
    setState(() {
      for (final ctrls in _controllersCache.values) {
        ctrls['name']?.dispose();
        ctrls['price']?.dispose();
        ctrls['quantity']?.dispose();
        ctrls['gst']?.dispose();
      }
      _controllersCache.clear();
      _activeEstimate = est;

      _companyNameCtrl.text = est['companyName'] ?? 'KRISHIKRANTI ORGANICS';
      _companyGstCtrl.text = est['companyGst'] ?? '23ABEFK9255G1Z9';
      _companyStateCtrl.text = est['companyState'] ?? '23-Madhya Pradesh';
      _companyPhoneCtrl.text = est['companyPhone'] ?? '9399022060';
      _companyEmailCtrl.text =
          est['companyEmail'] ?? 'krishikrantiorganics@gmail.com';
      _companyAddressCtrl.text =
          est['companyAddress'] ??
          'EWS - 101, The Bellaire Appartment, Gondermau Gandhi Nagar, Bhopal 462036, Madhya Pradesh';

      _estimateNoCtrl.text = est['estimateNo'] ?? '';
      _estimateDateCtrl.text = est['estimateDate'] ?? '';
      _clientNameCtrl.text = est['clientName'] ?? '';
      _clientAddressCtrl.text = est['clientAddress'] ?? '';
      _clientPhoneCtrl.text = est['clientPhone'] ?? '';
      _isGstEnabled = est['isGstEnabled'] ?? true;

      final List rawItems = est['items'] ?? [];
      _editingItems = rawItems.map((i) {
        final map = Map<String, dynamic>.from(i as Map);
        if (!map.containsKey('gst')) {
          map['gst'] = 18.0;
        }
        return map;
      }).toList();

      _tabController.index = 0;
    });
  }

  void _deleteFromHistory(Map<String, dynamic> est) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Delete Estimate',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Are you sure you want to delete this estimate? This action cannot be undone.',
          style: GoogleFonts.outfit(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final String? dbId = est['_id'] ?? est['id'];
      if (dbId != null && dbId.length == 24) {
        try {
          await ApiClient().delete('/admin/estimates/$dbId');
        } catch (e) {
          debugPrint('Failed to delete estimate from backend: $e');
        }
      }
      setState(() {
        _savedEstimates.removeWhere((e) => (e['_id'] ?? e['id']) == dbId);
      });
      _saveHistory();
    }
  }

  double get _calculateBaseSubtotal {
    double total = 0.0;
    for (final item in _editingItems) {
      final double price = ((item['price'] ?? 0.0) as num).toDouble();
      final double qty = ((item['quantity'] ?? 0.0) as num).toDouble();
      total += price * qty;
    }
    return total;
  }

  double get _calculateGstTotal {
    if (!_isGstEnabled) return 0.0;
    double total = 0.0;
    for (final item in _editingItems) {
      final double price = ((item['price'] ?? 0.0) as num).toDouble();
      final double qty = ((item['quantity'] ?? 0.0) as num).toDouble();
      final double gst = ((item['gst'] ?? 18.0) as num).toDouble();
      total += price * qty * (gst / 100);
    }
    return total;
  }

  double get _calculateGrandTotal {
    return _calculateBaseSubtotal + _calculateGstTotal;
  }

  int get _calculateTotalQty {
    int total = 0;
    for (final item in _editingItems) {
      final double qty = ((item['quantity'] ?? 0.0) as num).toDouble();
      total += qty.round();
    }
    return total;
  }

  Map<String, dynamic> _collectEstimateData() {
    final total = _calculateGrandTotal;
    return {
      'id':
          _activeEstimate?['id'] ??
          _activeEstimate?['_id'] ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      if (_activeEstimate?['_id'] != null) '_id': _activeEstimate?['_id'],
      'companyName': _companyNameCtrl.text.trim(),
      'companyGst': _companyGstCtrl.text.trim(),
      'companyState': _companyStateCtrl.text.trim(),
      'companyPhone': _companyPhoneCtrl.text.trim(),
      'companyEmail': _companyEmailCtrl.text.trim(),
      'companyAddress': _companyAddressCtrl.text.trim(),

      'estimateNo': _estimateNoCtrl.text.trim(),
      'estimateDate': _estimateDateCtrl.text.trim(),

      'clientName': _clientNameCtrl.text.trim(),
      'clientAddress': _clientAddressCtrl.text.trim(),
      'clientPhone': _clientPhoneCtrl.text.trim(),
      'isGstEnabled': _isGstEnabled,

      'items': _editingItems.map((it) {
        final price = ((it['price'] ?? 0.0) as num).toDouble();
        final qty = ((it['quantity'] ?? 0.0) as num).toDouble();
        final gst = _isGstEnabled ? (((it['gst'] ?? 18.0) as num).toDouble()) : 0.0;
        return {
          'name': it['name'] ?? '',
          'quantity': qty,
          'unit': it['unit'] ?? 'liter',
          'price': price,
          'gst': gst,
          'amount': price * qty * (1 + gst / 100),
        };
      }).toList(),
      'grandTotal': total,
      'totalQty': _calculateTotalQty,
      'lastUpdated': DateTime.now().toIso8601String(),
    };
  }

  Future<bool> _saveEstimate({bool goBack = false}) async {
    if (_clientNameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter customer name'),
          backgroundColor: Colors.red,
        ),
      );
      return false;
    }

    // Validate Items: Ensure all items have a name
    for (int i = 0; i < _editingItems.length; i++) {
      final name = (_editingItems[i]['name'] ?? '').toString().trim();
      if (name.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Please enter a name for item #${i + 1}'),
            backgroundColor: Colors.red,
          ),
        );
        return false;
      }
    }

    setState(() => _isSaving = true);

    final estData = _collectEstimateData();
    final String? dbId = estData['_id'] ?? _activeEstimate?['_id'];

    bool backendSuccess = false;
    Map<String, dynamic>? savedBackendData;

    try {
      if (dbId != null && dbId.length == 24) {
        final res = await ApiClient().put('/admin/estimates/$dbId', estData);
        if (res.statusCode == 200) {
          final decoded = jsonDecode(res.body);
          if (decoded['success'] == true) {
            savedBackendData = Map<String, dynamic>.from(
              decoded['estimate'] as Map,
            );
            backendSuccess = true;
          }
        }
      } else {
        final res = await ApiClient().post('/admin/estimates', estData);
        if (res.statusCode == 201 || res.statusCode == 200) {
          final decoded = jsonDecode(res.body);
          if (decoded['success'] == true) {
            savedBackendData = Map<String, dynamic>.from(
              decoded['estimate'] as Map,
            );
            backendSuccess = true;
          }
        }
      }
    } catch (e) {
      debugPrint('Failed to save estimate to backend: $e');
    }

    setState(() {
      final localData = savedBackendData ?? estData;
      final String idToMatch = localData['_id'] ?? localData['id'] ?? '';

      final int idx = _savedEstimates.indexWhere(
        (e) => (e['_id'] == idToMatch || e['id'] == idToMatch),
      );

      if (idx >= 0) {
        _savedEstimates[idx] = localData;
      } else {
        _savedEstimates.insert(0, localData);
      }

      if (_activeEstimate != null) {
        _activeEstimate = localData;
      }
    });

    await _saveHistory();

    setState(() {
      _isSaving = false;
      if (goBack) {
        _activeEstimate = null;
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          backendSuccess
              ? 'Estimate saved to database successfully!'
              : 'Estimate saved locally (backend offline)!',
          style: GoogleFonts.outfit(),
        ),
        backgroundColor: backendSuccess ? AppTheme.primaryColor : Colors.orange,
      ),
    );

    return true;
  }

  void _downloadPdf() async {
    if (_isSaving) return;
    if (_clientNameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter customer name'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Save state first so it persists in history
    final bool saved = await _saveEstimate();
    if (!saved) return;

    final estData = _collectEstimateData();

    try {
      final logoBytes = await rootBundle.load('assets/images/logo_copy.png');
      final base64Logo = base64Encode(logoBytes.buffer.asUint8List());
      estData['logoBase64'] = base64Logo;
    } catch (_) {}

    try {
      final sealBytes = await rootBundle.load('assets/images/sign.png');
      final base64Seal = base64Encode(sealBytes.buffer.asUint8List());
      estData['sealBase64'] = base64Seal;
    } catch (_) {}

    printQuotation(estData);
  }

  // Live number to words for preview
  String _previewNumberToWords(double amount) {
    if (amount == 0) return 'Zero Rupees only';

    final units = [
      '',
      'One',
      'Two',
      'Three',
      'Four',
      'Five',
      'Six',
      'Seven',
      'Eight',
      'Nine',
      'Ten',
      'Eleven',
      'Twelve',
      'Thirteen',
      'Fourteen',
      'Fifteen',
      'Sixteen',
      'Seventeen',
      'Eighteen',
      'Nineteen',
    ];
    final tens = [
      '',
      '',
      'Twenty',
      'Thirty',
      'Forty',
      'Fifty',
      'Sixty',
      'Seventy',
      'Eighty',
      'Ninety',
    ];

    String convertLessThanOneThousand(int number) {
      if (number <= 0) return '';
      String soFar = '';
      if (number % 100 < 20) {
        final idx = (number % 100).toInt();
        if (idx >= 0 && idx < units.length) {
          soFar = units[idx];
        }
        number = number ~/ 100;
      } else {
        final unitIdx = (number % 10).toInt();
        if (unitIdx >= 0 && unitIdx < units.length) {
          soFar = units[unitIdx];
        }
        number = number ~/ 10;
        final tenIdx = (number % 10).toInt();
        if (tenIdx >= 0 && tenIdx < tens.length) {
          soFar = tens[tenIdx] + (soFar.isNotEmpty ? ' $soFar' : '');
        }
        number = number ~/ 10;
      }
      if (number == 0) return soFar;
      final hundredIdx = number.toInt();
      if (hundredIdx >= 0 && hundredIdx < units.length) {
        return units[hundredIdx] +
            ' Hundred' +
            (soFar.isNotEmpty ? ' and $soFar' : '');
      }
      return soFar;
    }

    int numVal = amount.floor();
    String words = '';

    int crores = numVal ~/ 10000000;
    numVal = numVal % 10000000;

    int lakhs = numVal ~/ 100000;
    numVal = numVal % 100000;

    int thousands = numVal ~/ 1000;
    numVal = numVal % 1000;

    int hundreds = numVal;

    if (crores > 0) {
      words += convertLessThanOneThousand(crores) + ' Crore ';
    }
    if (lakhs > 0) {
      words += convertLessThanOneThousand(lakhs) + ' Lakh ';
    }
    if (thousands > 0) {
      words += convertLessThanOneThousand(thousands) + ' Thousand ';
    }
    if (hundreds > 0) {
      words += convertLessThanOneThousand(hundreds) + ' ';
    }

    words = words.trim();

    int paise = ((amount - amount.floor()) * 100).round();
    String paiseStr = '';
    if (paise > 0) {
      paiseStr = ' and ' + convertLessThanOneThousand(paise) + ' Paise';
    }

    return '$words Rupees$paiseStr only'.replaceAll(RegExp(r'\s+'), ' ');
  }

  void _openProductSelectorDialog(int itemIdx, {String initialQuery = ''}) {
    final searchCtrl = TextEditingController(text: initialQuery);
    showDialog(
      context: context,
      builder: (ctx) {
        String query = initialQuery;
        return StatefulBuilder(
          builder: (context, setDlgState) {
            final List<Map<String, dynamic>> filtered = query.isEmpty
                ? _availableProducts
                : _availableProducts.where((p) {
                    final title = (p['title'] ?? p['name'] ?? '')
                        .toString()
                        .toLowerCase();
                    final vendor = (p['vendor'] ?? '').toString().toLowerCase();
                    final variants = p['variants'] as List? ?? [];
                    final matchesVariant = variants.any((v) {
                      final size = (v['size'] ?? '').toString().toLowerCase();
                      return size.contains(query.toLowerCase());
                    });
                    return title.contains(query.toLowerCase()) ||
                        vendor.contains(query.toLowerCase()) ||
                        matchesVariant;
                  }).toList();

            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Text(
                'Select Catalog Product',
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
              ),
              content: SizedBox(
                width: 500,
                height: 450,
                child: Column(
                  children: [
                    TextField(
                      controller: searchCtrl,
                      decoration: InputDecoration(
                        hintText: 'Search inventory...',
                        prefixIcon: const Icon(Icons.search),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                        suffixIcon: query.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () {
                                  searchCtrl.clear();
                                  setDlgState(() => query = '');
                                },
                              )
                            : null,
                      ),
                      onChanged: (val) {
                        setDlgState(() => query = val);
                      },
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: _isLoadingProducts
                          ? const Center(
                              child: CircularProgressIndicator(
                                color: AppTheme.primaryColor,
                              ),
                            )
                          : filtered.isEmpty
                          ? const Center(
                              child: Text('No products matching query'),
                            )
                          : ListView.builder(
                              itemCount: filtered.length,
                              itemBuilder: (_, pIdx) {
                                final p = filtered[pIdx];
                                final variants = p['variants'] as List? ?? [];
                                return Theme(
                                  data: Theme.of(
                                    context,
                                  ).copyWith(dividerColor: Colors.transparent),
                                  child: ExpansionTile(
                                    title: Text(
                                      p['title'] ?? p['name'] ?? '',
                                      style: GoogleFonts.outfit(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                    subtitle: Text(
                                      p['vendor'] ?? '',
                                      style: GoogleFonts.outfit(fontSize: 11),
                                    ),
                                    leading: const Icon(
                                      Icons.inventory_2_outlined,
                                      color: AppTheme.primaryColor,
                                    ),
                                    children: variants.map((v) {
                                      final fp =
                                          v['farmerPrice'] ?? v['farmer_price'];
                                      final fpNum = fp != null
                                          ? double.tryParse(fp.toString())
                                          : null;
                                      final fpText =
                                          (fpNum != null && fpNum > 0)
                                          ? 'Farmer Price: ₹${fpNum % 1 == 0 ? fpNum.toInt() : fpNum.toStringAsFixed(0)}'
                                          : null;

                                      return ListTile(
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 24,
                                            ),
                                        title: Text(
                                          'Size/Var: ${v['size']}',
                                          style: GoogleFonts.outfit(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        subtitle: fpText != null
                                            ? Text(
                                                fpText,
                                                style: GoogleFonts.outfit(
                                                  fontSize: 11,
                                                  color: const Color(
                                                    0xFF059669,
                                                  ),
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              )
                                            : null,
                                        trailing: Text(
                                          'Dealer: ₹${v['price']}',
                                          style: GoogleFonts.outfit(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                            color: AppTheme.primaryColor,
                                          ),
                                        ),
                                        onTap: () {
                                          setState(() {
                                            final item = _editingItems[itemIdx];
                                            final name =
                                                '${p['title']} - ${v['size']}';
                                            final price =
                                                ((v['price'] ?? 0.0) as num)
                                                    .toDouble();

                                            item['name'] = name;
                                            item['price'] = price;
                                            item['unit'] = _parseUnitFromSize(
                                              v['size']?.toString() ?? '',
                                            );
                                            final double g = _isGstEnabled
                                                ? (((item['gst'] ?? 18.0)
                                                        as num)
                                                    .toDouble())
                                                : 0.0;
                                            item['amount'] =
                                                price *
                                                (item['quantity'] ?? 0.0) *
                                                (1 + g / 100);

                                            final ctrls =
                                                _controllersCache[item];
                                            if (ctrls != null) {
                                              ctrls['name']?.text = name;
                                              ctrls['price']?.text =
                                                  price == 0.0
                                                  ? ''
                                                  : price.toString();
                                            }
                                          });
                                          Navigator.of(ctx).pop();
                                        },
                                      );
                                    }).toList(),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    ).then((_) {
      searchCtrl.dispose();
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool isDesktop = MediaQuery.of(context).size.width >= 1000;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: _activeEstimate != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
                onPressed: () => setState(() => _activeEstimate = null),
              )
            : null,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _activeEstimate == null
                  ? 'Estimate History'
                  : 'Estimate Generator',
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.bold,
                fontSize: 17,
                color: AppTheme.textPrimary,
              ),
            ),
            Text(
              _activeEstimate == null
                  ? 'Manage and edit created quotation estimates'
                  : 'Design custom quotations, view live preview & download PDF',
              style: GoogleFonts.outfit(
                fontSize: 11,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
        actions: [
          if (_activeEstimate == null)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: FilledButton.icon(
                onPressed: _startNewEstimate,
                icon: const Icon(Icons.add_rounded, size: 16),
                label: Text(
                  'Create Estimate',
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            )
          else ...[
            TextButton.icon(
              onPressed: _isSaving ? null : () => _saveEstimate(goBack: true),
              icon: _isSaving
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppTheme.primaryColor,
                      ),
                    )
                  : const Icon(
                      Icons.save_rounded,
                      size: 16,
                      color: AppTheme.primaryColor,
                    ),
              label: Text(
                'Save Draft',
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: AppTheme.primaryColor,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: FilledButton.icon(
                onPressed: _isSaving ? null : _downloadPdf,
                icon: _isSaving
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.download_rounded, size: 16),
                label: Text(
                  _isSaving ? 'Processing...' : 'Download / Print',
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFC21820),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],
        ],
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(
            _activeEstimate != null && !isDesktop ? 48.0 : 1.0,
          ),
          child: _activeEstimate != null && !isDesktop
              ? Container(
                  color: Colors.white,
                  child: TabBar(
                    controller: _tabController,
                    indicatorColor: AppTheme.primaryColor,
                    labelColor: AppTheme.primaryColor,
                    unselectedLabelColor: AppTheme.textSecondary,
                    labelStyle: GoogleFonts.outfit(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                    tabs: const [
                      Tab(text: 'Editor Form'),
                      Tab(text: 'Visual Preview'),
                    ],
                  ),
                )
              : Container(height: 1, color: AppTheme.lightBorderColor),
        ),
      ),
      body: _activeEstimate == null
          ? _buildHistoryView()
          : (isDesktop ? _buildSplitScreen() : _buildTabbedScreen()),
    );
  }

  Widget _buildHistoryView() {
    if (_isLoadingHistory) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.primaryColor),
      );
    }

    final filtered = _savedEstimates.where((est) {
      final query = _searchQuery.toLowerCase();
      final name = (est['clientName'] ?? '').toString().toLowerCase();
      final no = (est['estimateNo'] ?? '').toString().toLowerCase();
      final phone = (est['clientPhone'] ?? '').toString().toLowerCase();
      return name.contains(query) || no.contains(query) || phone.contains(query);
    }).toList();

    return Column(
      children: [
        // Search Bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Container(
            height: 42,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.borderColor),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 8,
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
                    onChanged: (v) => setState(() => _searchQuery = v),
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Search by Customer, Estimate No, or Phone...',
                      hintStyle: GoogleFonts.outfit(
                        fontSize: 14,
                        color: AppTheme.textSecondary.withValues(alpha: 0.7),
                        fontWeight: FontWeight.w500,
                      ),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
                if (_searchQuery.isNotEmpty)
                  GestureDetector(
                    onTap: () {
                      _searchCtrl.clear();
                      setState(() => _searchQuery = '');
                    },
                    child: const Icon(
                      Icons.close_rounded,
                      size: 18,
                      color: AppTheme.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
        ),
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _searchQuery.isEmpty
                            ? Icons.description_outlined
                            : Icons.search_off_rounded,
                        size: 64,
                        color: Colors.grey.shade300,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _searchQuery.isEmpty
                            ? 'No estimate history found'
                            : 'No matches found for "$_searchQuery"',
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      if (_searchQuery.isEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Create a new estimate by clicking the button above',
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 24),
                        OutlinedButton.icon(
                          onPressed: _startNewEstimate,
                          icon: const Icon(Icons.add),
                          label: const Text('Create Estimate'),
                        ),
                      ],
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filtered.length,
                  itemBuilder: (_, i) {
                    final est = filtered[i];
                    final clientName = est['clientName'] ?? 'Unnamed Customer';
                    final estNo = est['estimateNo'] ?? 'No Number';
                    final estDate = est['estimateDate'] ?? '';
                    final total = est['grandTotal'] ?? 0.0;
                    final itemsCount = (est['items'] as List?)?.length ?? 0;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Material(
                          color: Colors.transparent,
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            leading: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color:
                                    const Color(0xFFC21820).withOpacity(0.08),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Center(
                                child: Icon(
                                  Icons.description_rounded,
                                  color: Color(0xFFC21820),
                                ),
                              ),
                            ),
                            title: Text(
                              clientName,
                              style: GoogleFonts.outfit(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            subtitle: Text(
                              'Est No: $estNo · $estDate · $itemsCount ${itemsCount == 1 ? 'item' : 'items'}',
                              style: GoogleFonts.outfit(
                                fontSize: 11,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '₹${total.toStringAsFixed(2)}',
                                  style: GoogleFonts.outfit(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                IconButton(
                                  icon: const Icon(
                                    Icons.edit_outlined,
                                    color: AppTheme.primaryColor,
                                  ),
                                  onPressed: () => _editEstimate(est),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete_outline_rounded,
                                    color: AppTheme.error,
                                  ),
                                  onPressed: () => _deleteFromHistory(est),
                                ),
                              ],
                            ),
                            onTap: () => _editEstimate(est),
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildSplitScreen() {
    return Row(
      children: [
        // Left Column: Form Editor
        Expanded(
          flex: 4,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: _buildFormEditor(),
          ),
        ),

        // Vertical Divider
        Container(width: 1, color: const Color(0xFFE5E7EB)),

        // Right Column: A4-scaled live preview
        Expanded(
          flex: 5,
          child: Container(
            color: const Color(0xFFECEFF1),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Center(child: _buildVisualPreview()),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTabbedScreen() {
    return TabBarView(
      controller: _tabController,
      children: [
        SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: _buildFormEditor(),
        ),
        Container(
          color: const Color(0xFFECEFF1),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: Center(child: _buildVisualPreview()),
          ),
        ),
      ],
    );
  }

  Widget _buildFormEditor() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section: Estimate Info
        _buildSectionHeader('1. Estimate Metadata'),
        Row(
          children: [
            Expanded(
              child: _buildField(
                'Estimate Number',
                _estimateNoCtrl,
                hint: 'e.g. EBS/25-26/EST/02689',
                prefixIcon: Icons.tag_rounded,
                readOnly: true,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildField(
                'Date',
                _estimateDateCtrl,
                hint: 'DD/MM/YYYY',
                prefixIcon: Icons.calendar_today_rounded,
                suffixIcon: IconButton(
                  icon: const Icon(
                    Icons.date_range_rounded,
                    size: 18,
                    color: AppTheme.primaryColor,
                  ),
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
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
                    if (picked != null) {
                      final day = picked.day.toString().padLeft(2, '0');
                      final month = picked.month.toString().padLeft(2, '0');
                      final year = picked.year;
                      setState(() {
                        _estimateDateCtrl.text = '$day/$month/$year';
                      });
                    }
                  },
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Section: Customer Info
        _buildSectionHeader('2. Customer / Client Info'),
        _buildField(
          'Customer Name',
          _clientNameCtrl,
          hint: 'e.g. Abraham Ali',
          prefixIcon: Icons.person_outline_rounded,
        ),
        const SizedBox(height: 12),
        _buildField(
          'Customer Address',
          _clientAddressCtrl,
          hint: 'Full delivery / billing address',
          maxLines: 2,
          prefixIcon: Icons.location_on_outlined,
        ),
        const SizedBox(height: 12),
        _buildField(
          'Customer Phone',
          _clientPhoneCtrl,
          hint: 'e.g. 9933617561',
          prefixIcon: Icons.phone_outlined,
        ),
        const SizedBox(height: 24),

        // Section: Company Info (Collapsible / Advanced)
        Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            title: Text(
              '3. Company Metadata (Advanced)',
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: AppTheme.textPrimary,
              ),
            ),
            subtitle: Text(
              'Edit sender corporate defaults',
              style: GoogleFonts.outfit(
                fontSize: 10,
                color: AppTheme.textSecondary,
              ),
            ),
            tilePadding: EdgeInsets.zero,
            children: [
              _buildField(
                'Company Name',
                _companyNameCtrl,
                prefixIcon: Icons.business_rounded,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildField(
                      'GSTIN',
                      _companyGstCtrl,
                      prefixIcon: Icons.receipt_long_rounded,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildField(
                      'State',
                      _companyStateCtrl,
                      prefixIcon: Icons.map_rounded,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildField(
                      'Phone',
                      _companyPhoneCtrl,
                      prefixIcon: Icons.phone_rounded,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildField(
                      'Email',
                      _companyEmailCtrl,
                      prefixIcon: Icons.email_outlined,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildField(
                'Address',
                _companyAddressCtrl,
                maxLines: 2,
                prefixIcon: Icons.home_work_outlined,
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // GST Toggle Section
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: _isGstEnabled
                ? AppTheme.primaryColor.withOpacity(0.05)
                : Colors.grey.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _isGstEnabled
                  ? AppTheme.primaryColor.withOpacity(0.2)
                  : Colors.grey.withOpacity(0.2),
            ),
          ),
          child: Row(
            children: [
              Icon(
                _isGstEnabled
                    ? Icons.receipt_long_rounded
                    : Icons.money_off_rounded,
                color: _isGstEnabled
                    ? AppTheme.primaryColor
                    : AppTheme.textSecondary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'GST Application',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    Text(
                      _isGstEnabled
                          ? 'GST (18%) will be added to the estimate'
                          : 'GST will NOT be added to this estimate',
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: _isGstEnabled,
                activeColor: AppTheme.primaryColor,
                onChanged: (val) {
                  setState(() {
                    _isGstEnabled = val;
                  });
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Section: Items Table
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildSectionHeader('4. Products / Items'),
            TextButton.icon(
              onPressed: () {
                setState(() {
                  _editingItems.add({
                    'name': '',
                    'quantity': 1.0,
                    'unit': 'liter',
                    'price': 0.0,
                    'gst': 18.0,
                    'amount': 0.0,
                  });
                });
              },
              icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
              label: Text(
                'Add Item Row',
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),

        // Items list editor
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _editingItems.length,
          itemBuilder: (_, idx) => _buildItemRowEditor(idx),
        ),

        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: GoogleFonts.outfit(
          fontWeight: FontWeight.bold,
          fontSize: 13,
          color: AppTheme.primaryColor,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildField(
    String label,
    TextEditingController ctrl, {
    String? hint,
    int maxLines = 1,
    IconData? prefixIcon,
    Widget? suffixIcon,
    VoidCallback? onTap,
    bool readOnly = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary.withOpacity(0.8),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.015),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: TextField(
            controller: ctrl,
            maxLines: maxLines,
            readOnly: readOnly,
            onTap: onTap,
            style: GoogleFonts.outfit(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppTheme.textPrimary,
            ),
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: GoogleFonts.outfit(
                fontSize: 12,
                color: Colors.grey.shade400,
              ),
              prefixIcon: prefixIcon != null
                  ? Icon(
                      prefixIcon,
                      size: 18,
                      color: AppTheme.primaryColor.withOpacity(0.7),
                    )
                  : null,
              suffixIcon:
                  suffixIcon ??
                  (ctrl.text.isNotEmpty && !readOnly
                      ? IconButton(
                          icon: const Icon(
                            Icons.cancel_rounded,
                            size: 16,
                            color: Colors.grey,
                          ),
                          onPressed: () {
                            ctrl.clear();
                            setState(() {});
                          },
                        )
                      : null),
              filled: true,
              fillColor: Colors.grey.shade50,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 16,
                vertical: maxLines > 1 ? 14 : 12,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.grey.shade200, width: 1.5),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(
                  color: AppTheme.primaryColor,
                  width: 1.8,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildItemRowEditor(int idx) {
    final item = _editingItems[idx];
    final controllers = _controllersCache.putIfAbsent(item, () {
      final name = TextEditingController(text: item['name'] ?? '')
        ..selection = TextSelection.collapsed(
          offset: (item['name'] ?? '').toString().length,
        );
      final price = TextEditingController(
        text: (item['price'] == null || item['price'] == 0.0)
            ? ''
            : item['price'].toString(),
      );
      final qty = TextEditingController(
        text: (item['quantity'] == null || item['quantity'] == 0.0)
            ? ''
            : item['quantity'].toString(),
      );
      final gst = TextEditingController(
        text: (item['gst'] == null || item['gst'] == 0.0)
            ? '18'
            : item['gst'].toString(),
      );
      return {'name': name, 'price': price, 'quantity': qty, 'gst': gst};
    });

    final nameCtrl = controllers['name']!;
    final priceCtrl = controllers['price']!;
    final qtyCtrl = controllers['quantity']!;
    final gstCtrl = controllers['gst']!;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Focus(
                  onFocusChange: (hasFocus) {
                    setState(() {
                      if (hasFocus) {
                        _focusedItemIdx = idx;
                      } else {
                        // Delay clearing to allow ListTile onTap to register
                        Future.delayed(const Duration(milliseconds: 200), () {
                          if (mounted && _focusedItemIdx == idx) {
                            setState(() {
                              _focusedItemIdx = null;
                            });
                          }
                        });
                      }
                    });
                  },
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: nameCtrl,
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Product / Item Name',
                          labelStyle: GoogleFonts.outfit(fontSize: 11),
                          hintText: 'Type item name...',
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                          suffixIcon: IconButton(
                            icon: const Icon(
                              Icons.search_rounded,
                              size: 18,
                              color: AppTheme.primaryColor,
                            ),
                            onPressed: () => _openProductSelectorDialog(
                              idx,
                              initialQuery: item['name'] ?? '',
                            ),
                          ),
                        ),
                        onChanged: (val) {
                          item['name'] = val;
                          setState(() {});
                        },
                      ),
                      if (item['name'].toString().isNotEmpty &&
                          _focusedItemIdx == idx)
                        _buildInlineSuggestions(idx, item['name'].toString()),
                    ],
                  ),
                ),
              ),
              if (_editingItems.length > 1) ...[
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(
                    Icons.delete_outline,
                    color: Colors.red,
                    size: 20,
                  ),
                  onPressed: () {
                    setState(() {
                      final item = _editingItems.removeAt(idx);
                      final ctrls = _controllersCache.remove(item);
                      if (ctrls != null) {
                        ctrls['name']?.dispose();
                        ctrls['price']?.dispose();
                        ctrls['quantity']?.dispose();
                      }
                    });
                  },
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              // Quantity
              Expanded(
                flex: 2,
                child: TextField(
                  controller: qtyCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  style: GoogleFonts.outfit(fontSize: 13),
                  decoration: InputDecoration(
                    labelText: 'Qty',
                    labelStyle: GoogleFonts.outfit(fontSize: 10),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  onChanged: (val) {
                    final double q = double.tryParse(val) ?? 0.0;
                    final double p = ((item['price'] ?? 0.0) as num).toDouble();
                    final double g = _isGstEnabled ? (((item['gst'] ?? 18.0) as num).toDouble()) : 0.0;
                    item['quantity'] = q;
                    item['amount'] = q * p * (1 + g / 100);
                    setState(() {});
                  },
                ),
              ),
              const SizedBox(width: 8),

              // Unit Selection
              Expanded(
                flex: 3,
                child: DropdownButtonFormField<String>(
                  value: (() {
                    final current = (item['unit'] ?? 'liter')
                        .toString()
                        .toLowerCase();
                    if (current == 'ltr') return 'liter';
                    if (current == 'gm') return 'g';
                    if (['kg', 'g', 'liter', 'ml', 'pcs'].contains(current)) {
                      return current;
                    }
                    return 'liter';
                  })(),
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    color: AppTheme.textPrimary,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Unit',
                    labelStyle: GoogleFonts.outfit(fontSize: 10),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'kg', child: Text('kg')),
                    DropdownMenuItem(value: 'g', child: Text('g')),
                    DropdownMenuItem(value: 'liter', child: Text('liter')),
                    DropdownMenuItem(value: 'ml', child: Text('ml')),
                    DropdownMenuItem(value: 'pcs', child: Text('pcs')),
                  ],
                  onChanged: (val) {
                    setState(() {
                      item['unit'] = val;
                    });
                  },
                ),
              ),
              const SizedBox(width: 8),

              // Price / Unit
              Expanded(
                flex: 3,
                child: TextField(
                  controller: priceCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  style: GoogleFonts.outfit(fontSize: 13),
                  decoration: InputDecoration(
                    labelText: 'Price/Unit',
                    labelStyle: GoogleFonts.outfit(fontSize: 10),
                    prefixText: '₹',
                    prefixStyle: GoogleFonts.outfit(fontSize: 12),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  onChanged: (val) {
                    final double p = double.tryParse(val) ?? 0.0;
                    final double q = ((item['quantity'] ?? 0.0) as num)
                        .toDouble();
                    final double g = _isGstEnabled ? (((item['gst'] ?? 18.0) as num).toDouble()) : 0.0;
                    item['price'] = p;
                    item['amount'] = q * p * (1 + g / 100);
                    setState(() {});
                  },
                ),
              ),
              const SizedBox(width: 8),

              // GST %
              if (_isGstEnabled) ...[
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: gstCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    style: GoogleFonts.outfit(fontSize: 13),
                    decoration: InputDecoration(
                      labelText: 'GST %',
                      labelStyle: GoogleFonts.outfit(fontSize: 10),
                      suffixText: '%',
                      suffixStyle: GoogleFonts.outfit(fontSize: 11),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 8,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    onChanged: (val) {
                      final double g = double.tryParse(val) ?? 0.0;
                      final double p =
                          ((item['price'] ?? 0.0) as num).toDouble();
                      final double q =
                          ((item['quantity'] ?? 0.0) as num).toDouble();
                      item['gst'] = g;
                      item['amount'] = q * p * (1 + g / 100);
                      setState(() {});
                    },
                  ),
                ),
                const SizedBox(width: 12),
              ],

              // Computed Row Total
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Amount',
                    style: GoogleFonts.outfit(
                      fontSize: 9,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Builder(
                    builder: (context) {
                      final double p =
                          ((item['price'] ?? 0.0) as num).toDouble();
                      final double q =
                          ((item['quantity'] ?? 0.0) as num).toDouble();
                      final double g = _isGstEnabled
                          ? (((item['gst'] ?? 18.0) as num).toDouble())
                          : 0.0;
                      final double amt = p * q * (1 + g / 100);
                      return Text(
                        '₹${amt.toStringAsFixed(2)}',
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: AppTheme.textPrimary,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Visual replica of the PDF layout
  Widget _buildVisualPreview() {
    final grandTotal = _calculateGrandTotal;
    final totalQty = _calculateTotalQty;

    return Container(
      width: 760,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Layered Header Section (Navy Pill is background, Red Banner overlaps on top)
          SizedBox(
            height: 150,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Layer 1: Navy Blue Container (starts at top, extends down)
                Positioned(
                  top: 0,
                  left: 0,
                  child: Container(
                    width: 420,
                    height: 150,
                    padding: const EdgeInsets.only(
                      left: 24,
                      right: 24,
                      bottom: 8,
                      top: 85,
                    ),
                    decoration: const BoxDecoration(
                      color: Color(0xFF1E293B),
                      borderRadius: BorderRadius.only(
                        bottomRight: Radius.circular(100),
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _companyNameCtrl.text,
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 2),
                        if (_isGstEnabled)
                          Text(
                            'GSTIN: ${_companyGstCtrl.text}',
                            style: GoogleFonts.outfit(
                              fontSize: 10,
                              color: Colors.grey.shade300,
                            ),
                          ),
                        Text(
                          'State: ${_companyStateCtrl.text}',
                          style: GoogleFonts.outfit(
                            fontSize: 10,
                            color: Colors.grey.shade300,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Layer 2: Red Banner Container (sits on top of the Navy block)
                Positioned(
                  top: 0,
                  right: 0,
                  width: 608,
                  child: Container(
                    height: 75,
                    decoration: const BoxDecoration(
                      color: Color(0xFFC21820),
                      borderRadius: BorderRadius.only(
                        topRight: Radius.circular(4),
                        bottomLeft: Radius.circular(100),
                      ),
                    ),
                    child: Row(
                      children: [
                        const SizedBox(width: 50),
                        _buildPreviewContactItem(
                          Icons.phone_rounded,
                          _companyPhoneCtrl.text,
                        ),
                        const SizedBox(width: 12),
                        Container(
                          height: 75,
                          width: 1,
                          color: Colors.white.withOpacity(0.3),
                        ),
                        const SizedBox(width: 12),
                        SizedBox(
                          width: 130,
                          child: _buildPreviewContactItem(
                            Icons.email_outlined,
                            _companyEmailCtrl.text.replaceFirst('@', '@\n'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          height: 75,
                          width: 1,
                          color: Colors.white.withOpacity(0.3),
                        ),
                        const SizedBox(width: 12),
                        SizedBox(
                          width: 150,
                          child: _buildPreviewContactItem(
                            Icons.location_on_outlined,
                            _companyAddressCtrl.text
                                .replaceFirst(
                                  'Arvind Vihar, ',
                                  'Arvind Vihar,\n',
                                )
                                .replaceFirst('Colony , ', 'Colony ,\n'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Layer 3: Overlapping White Logo Box (contained in Navy block/left corner)
                Positioned(
                  top: 15,
                  left: 24,
                  child: Container(
                    width: 110,
                    height: 70,
                    decoration: const BoxDecoration(color: Colors.transparent),
                    child: Image.asset(
                      'assets/images/logo_copy.png',
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => Center(
                        child: Text(
                          'EBS',
                          style: GoogleFonts.outfit(
                            color: const Color(0xFFC21820),
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left side: Customer Info
                    Expanded(
                      flex: 6,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Estimate For:',
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: const Color(0xFFC21820),
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _clientNameCtrl.text.isEmpty
                                ? '[Enter Customer Name]'
                                : _clientNameCtrl.text.toLowerCase(),
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.w800,
                              fontSize: 18,
                              color: Colors.black,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _clientAddressCtrl.text.isEmpty
                                ? '[Enter Customer Address]'
                                : _clientAddressCtrl.text,
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              color: AppTheme.textSecondary,
                              height: 1.3,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Contact No.: ${_clientPhoneCtrl.text}',
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 24),
                    // Right side: Estimate Info
                    Expanded(
                      flex: 4,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Estimate',
                            style: GoogleFonts.outfit(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.start,
                            children: [
                              Text(
                                'Estimate No.:   ',
                                style: GoogleFonts.outfit(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                              Text(
                                _estimateNoCtrl.text,
                                style: GoogleFonts.outfit(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.start,
                            children: [
                              Text(
                                'Date:   ',
                                style: GoogleFonts.outfit(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                              Text(
                                _estimateDateCtrl.text,
                                style: GoogleFonts.outfit(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Items Table header
                Container(
                  color: const Color(0xFFC21820),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 30,
                        child: Text(
                          '#',
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          'Item name',
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 50,
                        child: Text(
                          'Quantity',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 50,
                        child: Text(
                          'Unit',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 80,
                        child: Text(
                          'Price/ Unit',
                          textAlign: TextAlign.right,
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ),
                      if (_isGstEnabled)
                        SizedBox(
                          width: 60,
                          child: Text(
                            'GST',
                            textAlign: TextAlign.right,
                            style: GoogleFonts.outfit(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      SizedBox(
                        width: 90,
                        child: Text(
                          'Amount',
                          textAlign: TextAlign.right,
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Item Rows
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _editingItems.length,
                  itemBuilder: (_, i) {
                    final it = _editingItems[i];
                    final String name = it['name'].toString().isEmpty
                        ? '[Untitled Item]'
                        : it['name'].toString();
                    final price = (it['price'] ?? 0.0) as double;
                    final qty = (it['quantity'] ?? 0.0) as double;
                    final gst = (it['gst'] ?? 18.0) as double;
                    final amt = price * qty * (1 + gst / 100);
                    final isEven = i % 2 == 1;

                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: isEven ? const Color(0xFFFFF5F5) : Colors.white,
                        border: Border(
                          bottom: BorderSide(color: Colors.grey.shade100),
                        ),
                      ),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 30,
                            child: Text(
                              '${i + 1}',
                              style: GoogleFonts.outfit(
                                fontSize: 12,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              name,
                              style: GoogleFonts.outfit(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 50,
                            child: Text(
                              '${qty.toInt()}',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.outfit(
                                fontSize: 12,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 50,
                            child: Text(
                              it['unit'] ?? 'liter',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.outfit(
                                fontSize: 12,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 80,
                            child: Text(
                              '₹${price.toStringAsFixed(2)}',
                              textAlign: TextAlign.right,
                              style: GoogleFonts.outfit(
                                fontSize: 12,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                          ),
                          if (_isGstEnabled)
                            SizedBox(
                              width: 60,
                              child: Text(
                                '${gst.toStringAsFixed(0)}%',
                                textAlign: TextAlign.right,
                                style: GoogleFonts.outfit(
                                  fontSize: 12,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                            ),
                          SizedBox(
                            width: 90,
                            child: Text(
                              '₹${amt.toStringAsFixed(2)}',
                              textAlign: TextAlign.right,
                              style: GoogleFonts.outfit(
                                fontSize: 12,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),

                // Total quantity and amount row (Red)
                Container(
                  color: const Color(0xFFC21820),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      const SizedBox(width: 30),
                      Expanded(
                        child: Text(
                          'TOTAL',
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 50,
                        child: Text(
                          '$totalQty',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ),
                      const SizedBox(width: 50),
                      const SizedBox(width: 80),
                      if (_isGstEnabled) const SizedBox(width: 60),
                      SizedBox(
                        width: 90,
                        child: Text(
                          '₹${grandTotal.toStringAsFixed(2)}',
                          textAlign: TextAlign.right,
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Totals summary and Words layout
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Left side: Words
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Estimate Amount In Words',
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                              color: const Color(0xFFC21820),
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _previewNumberToWords(grandTotal),
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              color: AppTheme.textSecondary,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 24),

                    // Right side: Subtotal & Total boxes
                    SizedBox(
                      width: 260,
                      child: Table(
                        border: TableBorder.all(color: Colors.grey.shade200),
                        columnWidths: const {
                          0: FlexColumnWidth(5),
                          1: FlexColumnWidth(4),
                        },
                        children: [
                          TableRow(
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Text(
                                  _isGstEnabled
                                      ? 'Sub Total (Excl. GST)'
                                      : 'Total Amount',
                                  style: GoogleFonts.outfit(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Text(
                                  '₹${_calculateBaseSubtotal.toStringAsFixed(2)}',
                                  style: GoogleFonts.outfit(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.textPrimary,
                                  ),
                                  textAlign: TextAlign.right,
                                ),
                              ),
                            ],
                          ),
                          if (_isGstEnabled)
                            TableRow(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Text(
                                    'GST Total',
                                    style: GoogleFonts.outfit(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Text(
                                    '₹${_calculateGstTotal.toStringAsFixed(2)}',
                                    style: GoogleFonts.outfit(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.textPrimary,
                                    ),
                                    textAlign: TextAlign.right,
                                  ),
                                ),
                              ],
                            ),
                          TableRow(
                            decoration: const BoxDecoration(
                              color: Color(0xFFC21820),
                            ),
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Text(
                                  'Grand Total',
                                  style: GoogleFonts.outfit(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Text(
                                  '₹${grandTotal.toStringAsFixed(2)}',
                                  style: GoogleFonts.outfit(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                  textAlign: TextAlign.right,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 40),

                // Footer signature block
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const SizedBox(), // Empty left spacer
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          'For : ${_companyNameCtrl.text}',
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 10),
                        // Seal Stamp visual graphic (263x106px landscape)
                        Image.asset(
                          'assets/images/sign.png',
                          width: 200,
                          fit: BoxFit.fitWidth,
                          filterQuality: FilterQuality.high,
                          isAntiAlias: true,
                          errorBuilder: (context, error, stackTrace) {
                            return Image.asset(
                              'assets/images/logo.png',
                              width: 80,
                              height: 80,
                              fit: BoxFit.contain,
                              filterQuality: FilterQuality.high,
                            );
                          },
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Authorized Signatory',
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Bottom Accent bar with curve
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              Container(
                height: 16,
                decoration: const BoxDecoration(
                  color: Color(0xFFC21820),
                  borderRadius: BorderRadius.vertical(
                    bottom: Radius.circular(4),
                  ),
                ),
              ),
              Container(
                width: 160,
                height: 32,
                decoration: const BoxDecoration(
                  color: Color(0xFF1E293B),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(32),
                    bottomRight: Radius.circular(4),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewContactItem(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(icon, color: Colors.white, size: 13),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            text,
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontSize: 9,
              height: 1.2,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInlineSuggestions(int itemIdx, String query) {
    if (query.isEmpty || _availableProducts.isEmpty) return const SizedBox();

    final List<Map<String, dynamic>> suggestions = [];
    for (var p in _availableProducts) {
      final title = (p['title'] ?? p['name'] ?? '').toString();
      final vendor = (p['vendor'] ?? '').toString();
      final variants = p['variants'] as List? ?? [];

      if (title.toLowerCase().contains(query.toLowerCase()) ||
          vendor.toLowerCase().contains(query.toLowerCase())) {
        for (var v in variants) {
          suggestions.add({
            'product': p,
            'variant': v,
            'displayName': '$title - ${v['size']}',
            'price': ((v['price'] ?? 0.0) as num).toDouble(),
          });
        }
      } else {
        for (var v in variants) {
          final size = (v['size'] ?? '').toString().toLowerCase();
          if (size.contains(query.toLowerCase())) {
            suggestions.add({
              'product': p,
              'variant': v,
              'displayName': '$title - ${v['size']}',
              'price': ((v['price'] ?? 0.0) as num).toDouble(),
            });
          }
        }
      }
    }

    if (suggestions.isEmpty) return const SizedBox();

    return Container(
      margin: const EdgeInsets.only(top: 4),
      constraints: const BoxConstraints(maxHeight: 180),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: ListView.builder(
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          itemCount: suggestions.length.clamp(0, 6),
          itemBuilder: (context, sIdx) {
            final sugg = suggestions[sIdx];
            final p = sugg['product'] as Map;
            return ListTile(
              dense: true,
              visualDensity: VisualDensity.compact,
              title: Text(
                sugg['displayName'],
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: Text(
                p['vendor'] ?? '',
                style: GoogleFonts.outfit(fontSize: 10, color: Colors.grey),
              ),
              trailing: Text(
                '₹${sugg['price']}',
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryColor,
                ),
              ),
              onTap: () {
                setState(() {
                  final item = _editingItems[itemIdx];
                  final name = sugg['displayName'];
                  final price = sugg['price'];

                  item['name'] = name;
                  item['price'] = price;
                  item['unit'] = _parseUnitFromSize(
                    sugg['variant']?['size']?.toString() ?? '',
                  );
                  item['amount'] = price * (item['quantity'] ?? 0.0);

                  final ctrls = _controllersCache[item];
                  if (ctrls != null) {
                    ctrls['name']?.text = name;
                    ctrls['price']?.text = price == 0.0 ? '' : price.toString();
                  }

                  _focusedItemIdx = null;
                });
              },
            );
          },
        ),
      ),
    );
  }

  String _parseUnitFromSize(String size) {
    final sizeStr = size.toLowerCase().trim();
    if (sizeStr.contains('kg')) {
      return 'kg';
    } else if (sizeStr.contains('gm') ||
        sizeStr.endsWith(' g') ||
        sizeStr.contains(' g ')) {
      return 'g';
    } else if (sizeStr.contains('ml')) {
      return 'ml';
    } else if (sizeStr.contains('pcs') || sizeStr.contains('pc')) {
      return 'pcs';
    } else if (sizeStr.contains('ltr') ||
        sizeStr.contains('lit') ||
        sizeStr.contains('liter')) {
      return 'liter';
    }
    return 'liter'; // Default fallback
  }
}

class DashedCirclePainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final int dashCount;

  DashedCirclePainter({
    required this.color,
    this.strokeWidth = 1.5,
    this.dashCount = 24,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final double radius = size.width / 2;
    final Offset center = Offset(size.width / 2, size.height / 2);

    final double dashAngle = (2 * 3.141592653589793) / (dashCount * 2);

    for (int i = 0; i < dashCount; i++) {
      final double startAngle = i * 2 * dashAngle;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        dashAngle,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant DashedCirclePainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.dashCount != dashCount;
  }
}
