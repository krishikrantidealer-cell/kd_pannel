import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kd_pannel/app_theme.dart';

class DistrictDemandData {
  final String _rawDistrictName;
  final String _rawStateName;
  final String primaryCrop;
  final String category;
  final String subCategory;
  final int registeredDealers; // users registered with this district address
  final int activeBuyers;      // unique users who placed ≥1 order from this district
  final int activeDealers;     // = registeredDealers (kept for compatibility)
  final double searchVolumeIndex;
  final double conversionRate;
  final double grossRevenueRupees;
  final int orderCount;
  final Map<String, double>? categoryBreakdown;
  final Map<String, double>? subCategoryBreakdown;
  final Map<String, double>? productBreakdown;

  const DistrictDemandData({
    required String districtName,
    required String stateName,
    required this.primaryCrop,
    this.category = 'General Products',
    this.subCategory = '',
    required this.activeDealers,
    this.registeredDealers = 0,
    this.activeBuyers = 0,
    required this.searchVolumeIndex,
    required this.conversionRate,
    required this.grossRevenueRupees,
    this.orderCount = 0,
    this.categoryBreakdown,
    this.subCategoryBreakdown,
    this.productBreakdown,
  })  : _rawDistrictName = districtName,
        _rawStateName = stateName;

  // Backend already returns canonical English names — just trim whitespace
  String get districtName => _rawDistrictName.trim();
  String get stateName => _rawStateName.trim();

  int get activeFarmers => activeDealers;
}

String _formatCurrency(double rupees) {
  if (rupees >= 100000) {
    return '₹${(rupees / 100000).toStringAsFixed(2)} Lakh';
  } else if (rupees >= 1000) {
    return '₹${(rupees / 1000).toStringAsFixed(1)}k';
  } else {
    return '₹${rupees.toStringAsFixed(0)}';
  }
}



class AgriHeatmapWidget extends StatefulWidget {
  final List<DistrictDemandData> districts;
  final bool isLoading;

  const AgriHeatmapWidget({
    super.key,
    required this.districts,
    this.isLoading = false,
  });

  @override
  State<AgriHeatmapWidget> createState() => _AgriHeatmapWidgetState();
}

class _AgriHeatmapWidgetState extends State<AgriHeatmapWidget> {
  String _selectedState = 'All';
  String _selectedDistrict = 'All';
  String _selectedCategory = 'All';
  String _selectedSubCategory = 'All';
  String _selectedProduct = 'All';
  String _searchQuery = '';

  // Breakdown View Mode: 'None', 'Product', 'Category', 'SubCategory'
  String _breakdownMode = 'None';

  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _resetFilters() {
    setState(() {
      _selectedState = 'All';
      _selectedDistrict = 'All';
      _selectedCategory = 'All';
      _selectedSubCategory = 'All';
      _selectedProduct = 'All';
      _searchQuery = '';
      _breakdownMode = 'None';
      _searchController.clear();
    });
  }

  Map<String, double> _getEffectiveCategoryBreakdown(DistrictDemandData district) {
    if (district.categoryBreakdown != null && district.categoryBreakdown!.isNotEmpty) {
      return district.categoryBreakdown!;
    }
    return {district.category: district.grossRevenueRupees};
  }

  Map<String, double> _getEffectiveProductBreakdown(DistrictDemandData district) {
    if (district.productBreakdown != null && district.productBreakdown!.isNotEmpty) {
      return district.productBreakdown!;
    }
    return {district.primaryCrop: district.grossRevenueRupees};
  }

  Map<String, double> _getEffectiveSubCategoryBreakdown(DistrictDemandData district) {
    if (district.subCategoryBreakdown != null && district.subCategoryBreakdown!.isNotEmpty) {
      return district.subCategoryBreakdown!;
    }
    if (district.subCategory.isNotEmpty) {
      return {district.subCategory: district.grossRevenueRupees};
    }
    return {district.category: district.grossRevenueRupees};
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isLoading) {
      return Container(
        height: 300,
        decoration: BoxDecoration(
          color: AppTheme.cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.borderColor.withOpacity(0.6)),
        ),
        child: const Center(
          child: CircularProgressIndicator(color: AppTheme.primaryColor),
        ),
      );
    }

    if (widget.districts.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(36),
        decoration: BoxDecoration(
          color: AppTheme.cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: AppTheme.cardShadow,
          border: Border.all(color: AppTheme.borderColor.withOpacity(0.6)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.location_off_rounded, size: 36, color: AppTheme.primaryColor),
            ),
            const SizedBox(height: 14),
            Text(
              'No Order Locations Recorded Yet',
              style: GoogleFonts.outfit(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'The regional heatmap populates automatically as orders are placed across dealer districts.',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    // 1. Available States — fully normalized dedup
    final Map<String, String> stateDedup = {}; 
    for (final d in widget.districts) {
      String raw = d.stateName.trim();
      if (raw.isEmpty || raw.toLowerCase() == 'unknown') continue;
      
      // A. Standardize Casing immediately (Fixes "Madhya pradesh" vs "Madhya Pradesh")
      raw = raw.split(' ').map((w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}' : '').join(' ');

      // B. Create a "Fuzzy Key" (Strips everything but letters, merges Andra/Andhra)
      String fuzzyKey = raw.toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');
      if (fuzzyKey.contains('andra')) fuzzyKey = 'andhrapradesh'; // Fixes "Andra" typo
      if (fuzzyKey.contains('madhya')) fuzzyKey = 'madhyapradesh'; // Fixes "Madhyaperdesh" typo

      // C. Preservation: Only store the first version found (which will be Title Cased)
      if (!stateDedup.containsKey(fuzzyKey)) {
        stateDedup[fuzzyKey] = raw;
      }
    }
    final List<String> availableStates = ['All', ...stateDedup.values.toList()..sort()];
    if (!availableStates.contains(_selectedState)) {
      _selectedState = 'All';
    }

    // 2. Filter by State (space-stripped, case-insensitive match)
    String _stateKey(String s) => s.toLowerCase().replaceAll(RegExp(r'\s+'), '');
    final List<DistrictDemandData> stateFilteredDistricts = _selectedState == 'All'
        ? widget.districts
        : widget.districts
            .where((d) => _stateKey(d.stateName) == _stateKey(_selectedState))
            .toList();

    // 3. Available Districts — case-insensitive dedup (backend returns canonical names)
    final Map<String, String> districtDedup = {};
    for (final d in stateFilteredDistricts) {
      final raw = d.districtName;
      if (raw.isEmpty || raw.toLowerCase() == 'unknown') continue;
      final key = raw.toLowerCase().replaceAll(RegExp(r'\s+'), '');
      districtDedup[key] ??= raw
          .split(' ')
          .map((w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}' : '')
          .where((w) => w.isNotEmpty)
          .join(' ');
    }
    final List<String> availableDistricts = ['All', ...districtDedup.values.toList()..sort()];
    if (!availableDistricts.contains(_selectedDistrict)) {
      _selectedDistrict = 'All';
    }

    // 4. Available Database Categories
    final Set<String> categorySet = widget.districts
        .map((d) => d.category.trim())
        .where((c) => c.isNotEmpty)
        .toSet();
    for (final d in widget.districts) {
      if (d.categoryBreakdown != null) {
        categorySet.addAll(d.categoryBreakdown!.keys);
      }
    }
    final List<String> availableCategories = ['All', ...categorySet.toList()..sort()];
    if (!availableCategories.contains(_selectedCategory)) {
      _selectedCategory = 'All';
    }

    // 5. Available Database SubCategories
    final Set<String> subCategorySet = widget.districts
        .map((d) => d.subCategory.trim())
        .where((sc) => sc.isNotEmpty)
        .toSet();
    for (final d in widget.districts) {
      if (d.subCategoryBreakdown != null) {
        subCategorySet.addAll(d.subCategoryBreakdown!.keys);
      }
    }
    final List<String> availableSubCategories = ['All', ...subCategorySet.toList()..sort()];
    if (!availableSubCategories.contains(_selectedSubCategory)) {
      _selectedSubCategory = 'All';
    }

    // 6. Available Database Products
    final Set<String> productSet = {};
    for (final d in widget.districts) {
      if (d.productBreakdown != null) {
        productSet.addAll(d.productBreakdown!.keys);
      }
    }
    final List<String> availableProducts = ['All', ...productSet.toList()..sort()];
    if (!availableProducts.contains(_selectedProduct)) {
      _selectedProduct = 'All';
    }

    // 7. Filter Districts by State, District, Category, SubCategory, Product & Search Query
    final List<DistrictDemandData> filteredDistricts = stateFilteredDistricts.where((d) {
      final matchesDistrict = _selectedDistrict == 'All' ||
          d.districtName.toLowerCase() == _selectedDistrict.toLowerCase();

      final catBreakdown = _getEffectiveCategoryBreakdown(d);
      final matchesCategory = _selectedCategory == 'All' ||
          d.category.toLowerCase() == _selectedCategory.toLowerCase() ||
          catBreakdown.keys.any((k) => k.toLowerCase() == _selectedCategory.toLowerCase());

      final matchesSubCategory = _selectedSubCategory == 'All' ||
          d.subCategory.toLowerCase() == _selectedSubCategory.toLowerCase() ||
          (d.subCategoryBreakdown != null &&
              d.subCategoryBreakdown!.keys.any((k) => k.toLowerCase() == _selectedSubCategory.toLowerCase()));

      final prodBreakdown = _getEffectiveProductBreakdown(d);
      final matchesProduct = _selectedProduct == 'All' ||
          prodBreakdown.keys.any((p) => p.toLowerCase() == _selectedProduct.toLowerCase());

      final matchesSearch = _searchQuery.isEmpty ||
          d.districtName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          d.stateName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          d.primaryCrop.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          d.category.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          prodBreakdown.keys.any((p) => p.toLowerCase().contains(_searchQuery.toLowerCase()));

      return matchesDistrict && matchesCategory && matchesSubCategory && matchesProduct && matchesSearch;
    }).toList();

    // Aggregated Metrics
    double totalRevenue = 0.0;
    for (final d in filteredDistricts) {
      if (_selectedProduct != 'All') {
        final pBreakdown = _getEffectiveProductBreakdown(d);
        final key = pBreakdown.keys.firstWhere(
          (k) => k.toLowerCase() == _selectedProduct.toLowerCase(),
          orElse: () => '',
        );
        totalRevenue += key.isNotEmpty ? (pBreakdown[key] ?? 0.0) : d.grossRevenueRupees;
      } else if (_selectedCategory != 'All') {
        final catBreakdown = _getEffectiveCategoryBreakdown(d);
        final matchKey = catBreakdown.keys.firstWhere(
          (k) => k.toLowerCase() == _selectedCategory.toLowerCase(),
          orElse: () => '',
        );
        totalRevenue += matchKey.isNotEmpty ? (catBreakdown[matchKey] ?? 0.0) : d.grossRevenueRupees;
      } else {
        totalRevenue += d.grossRevenueRupees;
      }
    }

    final int totalDealers = filteredDistricts.fold(0, (sum, d) => sum + d.activeDealers);
    final double avgConversionRate = filteredDistricts.isNotEmpty
        ? filteredDistricts.fold(0.0, (sum, d) => sum + d.conversionRate) / filteredDistricts.length
        : 0.0;

    final bool hasActiveFilters = _selectedState != 'All' ||
        _selectedDistrict != 'All' ||
        _selectedCategory != 'All' ||
        _selectedSubCategory != 'All' ||
        _selectedProduct != 'All' ||
        _searchQuery.isNotEmpty ||
        _breakdownMode != 'None';

    return Container(
      clipBehavior: Clip.antiAlias,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: AppTheme.borderColor.withOpacity(0.8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Executive Title Header & Segmented Controls
          LayoutBuilder(
            builder: (context, constraints) {
              final isDesktop = constraints.maxWidth > 850;
              return Flex(
                direction: isDesktop ? Axis.horizontal : Axis.vertical,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: isDesktop ? CrossAxisAlignment.center : CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF2E7D32), Color(0xFF1B5E20)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF2E7D32).withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.analytics_rounded, size: 22, color: Colors.white),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Dealer District & Product Intelligence',
                            style: GoogleFonts.outfit(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.textPrimary,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Real Database Categorised & Product-Wise Demand Heatmap',
                            style: GoogleFonts.outfit(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  SizedBox(height: isDesktop ? 0 : 12),

                  // Segmented Breakdown Mode Selector
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: AppTheme.backgroundColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.borderColor),
                    ),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildModeSegmentTab('None', '📊 Overview'),
                          _buildModeSegmentTab('Product', '📦 Product Breakdown'),
                          _buildModeSegmentTab('Category', '🏷️ Category'),
                          _buildModeSegmentTab('SubCategory', '📁 SubCategory'),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 20),

          // Filters Bar Container
          LayoutBuilder(
            builder: (context, constraints) {
              final isDesktop = constraints.maxWidth > 950;
              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.backgroundColor.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.borderColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Flex(
                      direction: isDesktop ? Axis.horizontal : Axis.vertical,
                      crossAxisAlignment: isDesktop ? CrossAxisAlignment.center : CrossAxisAlignment.start,
                      children: [
                        // 1. State Dropdown
                        Expanded(
                          flex: isDesktop ? 2 : 0,
                          child: _buildFilterDropdownColumn(
                            label: 'STATE',
                            value: _selectedState,
                            icon: Icons.map_rounded,
                            items: availableStates,
                            activeColor: AppTheme.primaryColor,
                            onChanged: (val) {
                              if (val != null) {
                                setState(() {
                                  _selectedState = val;
                                  _selectedDistrict = 'All';
                                });
                              }
                            },
                          ),
                        ),
                        SizedBox(width: isDesktop ? 10 : 0, height: isDesktop ? 0 : 10),

                        // 2. District Dropdown
                        Expanded(
                          flex: isDesktop ? 2 : 0,
                          child: _buildFilterDropdownColumn(
                            label: 'DISTRICT',
                            value: _selectedDistrict,
                            icon: Icons.location_city_rounded,
                            items: availableDistricts,
                            activeColor: const Color(0xFF0288D1),
                            onChanged: (val) {
                              if (val != null) {
                                setState(() {
                                  _selectedDistrict = val;
                                });
                              }
                            },
                          ),
                        ),
                        SizedBox(width: isDesktop ? 10 : 0, height: isDesktop ? 0 : 10),

                        // 3. Category Dropdown
                        Expanded(
                          flex: isDesktop ? 3 : 0,
                          child: _buildFilterDropdownColumn(
                            label: 'CATEGORY',
                            value: _selectedCategory,
                            icon: Icons.category_rounded,
                            items: availableCategories,
                            activeColor: const Color(0xFF7B1FA2),
                            onChanged: (val) {
                              if (val != null) {
                                setState(() {
                                  _selectedCategory = val;
                                });
                              }
                            },
                          ),
                        ),
                        SizedBox(width: isDesktop ? 10 : 0, height: isDesktop ? 0 : 10),

                        // 4. Product Dropdown
                        if (availableProducts.length > 1) ...[
                          Expanded(
                            flex: isDesktop ? 3 : 0,
                            child: _buildFilterDropdownColumn(
                              label: 'PRODUCT',
                              value: _selectedProduct,
                              icon: Icons.inventory_2_rounded,
                              items: availableProducts,
                              activeColor: const Color(0xFFE65100),
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() {
                                    _selectedProduct = val;
                                  });
                                }
                              },
                            ),
                          ),
                          SizedBox(width: isDesktop ? 10 : 0, height: isDesktop ? 0 : 10),
                        ],

                        // 5. Search Bar
                        Expanded(
                          flex: isDesktop ? 3 : 0,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'SEARCH',
                                style: GoogleFonts.outfit(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.textSecondary,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                height: 42,
                                decoration: BoxDecoration(
                                  color: AppTheme.cardColor,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: _searchQuery.isNotEmpty ? AppTheme.primaryColor : AppTheme.borderColor,
                                    width: _searchQuery.isNotEmpty ? 1.5 : 1.0,
                                  ),
                                ),
                                child: TextField(
                                  controller: _searchController,
                                  style: GoogleFonts.outfit(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.textPrimary,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: 'Search district, product...',
                                    hintStyle: GoogleFonts.outfit(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.textSecondary,
                                    ),
                                    prefixIcon: const Icon(Icons.search_rounded, size: 18, color: AppTheme.textSecondary),
                                    suffixIcon: _searchQuery.isNotEmpty
                                        ? IconButton(
                                            icon: const Icon(Icons.close_rounded, size: 16),
                                            onPressed: () {
                                              setState(() {
                                                _searchQuery = '';
                                                _searchController.clear();
                                              });
                                            },
                                          )
                                        : null,
                                    border: InputBorder.none,
                                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                                  ),
                                  onChanged: (val) {
                                    setState(() {
                                      _searchQuery = val.trim();
                                    });
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Reset Button
                        if (hasActiveFilters) ...[
                          SizedBox(width: isDesktop ? 10 : 0, height: isDesktop ? 0 : 10),
                          Padding(
                            padding: const EdgeInsets.only(top: 14),
                            child: InkWell(
                              onTap: _resetFilters,
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                height: 42,
                                padding: const EdgeInsets.symmetric(horizontal: 14),
                                decoration: BoxDecoration(
                                  color: Colors.red.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: Colors.red.withOpacity(0.3)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.refresh_rounded, size: 16, color: Colors.red),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Reset',
                                      style: GoogleFonts.outfit(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.red,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),

                    // Quick Category Pills
                    if (availableCategories.length > 2) ...[
                      const SizedBox(height: 12),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            Text(
                              'DATABASE CATEGORIES: ',
                              style: GoogleFonts.outfit(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.textSecondary,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(width: 8),
                            ...availableCategories.where((c) => c != 'All').map((catName) {
                              final isSelected = _selectedCategory.toLowerCase() == catName.toLowerCase();
                              return Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: InkWell(
                                  onTap: () {
                                    setState(() {
                                      _selectedCategory = isSelected ? 'All' : catName;
                                    });
                                  },
                                  borderRadius: BorderRadius.circular(20),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? AppTheme.primaryColor
                                          : AppTheme.primaryColor.withOpacity(0.08),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: isSelected
                                            ? AppTheme.primaryColor
                                            : AppTheme.primaryColor.withOpacity(0.3),
                                      ),
                                    ),
                                    child: Text(
                                      catName,
                                      style: GoogleFonts.outfit(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w800,
                                        color: isSelected ? Colors.white : AppTheme.primaryColor,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 16),

          // Executive Summary Metric Ribbon
          Container(
            clipBehavior: Clip.antiAlias,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.primaryColor.withOpacity(0.08),
                  const Color(0xFF0288D1).withOpacity(0.08),
                ],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.primaryColor.withOpacity(0.2)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      'Districts Displayed: ',
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    Text(
                      '${filteredDistricts.length}',
                      style: GoogleFonts.outfit(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                    Text(
                      ' / ${widget.districts.length}',
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    if (_selectedProduct != 'All') ...[
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE65100),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '📦 $_selectedProduct',
                          style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white),
                        ),
                      ),
                    ] else if (_selectedCategory != 'All') ...[
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0288D1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '🏷️ $_selectedCategory',
                          style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white),
                        ),
                      ),
                    ],
                  ],
                ),
                Row(
                  children: [
                    Text(
                      _selectedProduct != 'All'
                          ? 'PRODUCT REVENUE: '
                          : (_selectedCategory == 'All' ? 'TOTAL REVENUE: ' : 'CATEGORY REVENUE: '),
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textSecondary,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      _formatCurrency(totalRevenue),
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.success,
                      ),
                    ),
                    const SizedBox(width: 18),
                    Container(
                      width: 1,
                      height: 20,
                      color: AppTheme.borderColor,
                    ),
                    const SizedBox(width: 18),
                    Text(
                      'ACTIVE DEALERS: ',
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textSecondary,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      '$totalDealers',
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 18),
                    Container(
                      width: 1,
                      height: 20,
                      color: AppTheme.borderColor,
                    ),
                    const SizedBox(width: 18),
                    Text(
                      'AVG CONVERSION: ',
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textSecondary,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      '${avgConversionRate.toStringAsFixed(1)}%',
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF7B1FA2),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // District Intelligence Cards Grid
          if (filteredDistricts.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppTheme.backgroundColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.borderColor),
              ),
              child: Column(
                children: [
                  const Icon(Icons.search_off_rounded, size: 44, color: AppTheme.textSecondary),
                  const SizedBox(height: 12),
                  Text(
                    'No dealer districts match your filter criteria',
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Try modifying your Product, Category, State, or District selection.',
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _resetFilters,
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('Reset All Filters'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      textStyle: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w800),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 700;
                return Wrap(
                  spacing: 14,
                  runSpacing: 14,
                  children: filteredDistricts.map((district) {
                    final double width = isWide
                        ? (constraints.maxWidth - 28) / 3
                        : (constraints.maxWidth - 14) / 2;

                    final bool isHighDemand = district.searchVolumeIndex > 75;
                    final bool isMedDemand = district.searchVolumeIndex > 50;

                    final List<Color> topGradient = isHighDemand
                        ? [const Color(0xFFFF5722), const Color(0xFFF4511E)]
                        : (isMedDemand
                            ? [const Color(0xFFFF9800), const Color(0xFFFB8C00)]
                            : [const Color(0xFF2E7D32), const Color(0xFF43A047)]);

                    final Color convColor = district.conversionRate >= 50.0
                        ? const Color(0xFF2E7D32)
                        : (district.conversionRate >= 25.0
                            ? const Color(0xFF0288D1)
                            : const Color(0xFFE65100));

                    final Map<String, double> activeBreakdownMap = _breakdownMode == 'Product'
                        ? _getEffectiveProductBreakdown(district)
                        : (_breakdownMode == 'SubCategory'
                            ? _getEffectiveSubCategoryBreakdown(district)
                            : _getEffectiveCategoryBreakdown(district));

                    return Container(
                      width: width,
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        color: AppTheme.backgroundColor,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.03),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                        border: Border.all(color: AppTheme.borderColor),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // High-Impact Demand Gradient Strip - Submerged 100% Flush
                          Container(
                            height: 4,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(colors: topGradient),
                            ),
                          ),

                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // District Name & Volume Index Pill
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        district.districtName,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.outfit(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w800,
                                          color: AppTheme.textPrimary,
                                          letterSpacing: -0.2,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: topGradient.first.withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: topGradient.first.withOpacity(0.3)),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            isHighDemand
                                                ? Icons.local_fire_department_rounded
                                                : (isMedDemand ? Icons.trending_up_rounded : Icons.check_circle_rounded),
                                            size: 13,
                                            color: topGradient.first,
                                          ),
                                          const SizedBox(width: 3),
                                          Text(
                                            '${district.searchVolumeIndex.toInt()} Index',
                                            style: GoogleFonts.outfit(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w800,
                                              color: topGradient.first,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),

                                // State & Main Category Badge
                                Row(
                                  children: [
                                    const Icon(Icons.location_on_rounded, size: 13, color: AppTheme.textSecondary),
                                    const SizedBox(width: 3),
                                    Text(
                                      district.stateName,
                                      style: GoogleFonts.outfit(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: AppTheme.textSecondary,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '•',
                                      style: GoogleFonts.outfit(
                                        fontSize: 12,
                                        color: AppTheme.textSecondary,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: AppTheme.primaryColor.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(5),
                                        ),
                                        child: Text(
                                          district.category,
                                          overflow: TextOverflow.ellipsis,
                                          style: GoogleFonts.outfit(
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.w800,
                                            color: AppTheme.primaryColor,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 14),

                                // Breakdown View Mode or Standard Metrics
                                if (_breakdownMode != 'None') ...[
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: AppTheme.cardColor,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: AppTheme.borderColor),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _breakdownMode == 'Product'
                                              ? '📦 TOP PRODUCT DEMAND SHARE'
                                              : (_breakdownMode == 'SubCategory'
                                                  ? '📁 SUBCATEGORY REVENUE SHARE'
                                                  : '🏷️ CATEGORY REVENUE SHARE'),
                                          style: GoogleFonts.outfit(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w800,
                                            color: AppTheme.textSecondary,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        ...activeBreakdownMap.entries.map((entry) {
                                          final total = district.grossRevenueRupees > 0 ? district.grossRevenueRupees : 1;
                                          final pct = ((entry.value / total) * 100).clamp(5.0, 100.0);
                                          final color = _breakdownMode == 'Product'
                                              ? const Color(0xFFE65100)
                                              : (_breakdownMode == 'SubCategory'
                                                  ? const Color(0xFF7B1FA2)
                                                  : AppTheme.primaryColor);

                                          return Padding(
                                            padding: const EdgeInsets.only(bottom: 6),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                  children: [
                                                    Expanded(
                                                      child: Text(
                                                        entry.key,
                                                        overflow: TextOverflow.ellipsis,
                                                        style: GoogleFonts.outfit(
                                                          fontSize: 11.5,
                                                          fontWeight: FontWeight.w700,
                                                          color: AppTheme.textPrimary,
                                                        ),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 6),
                                                    Text(
                                                      _formatCurrency(entry.value),
                                                      style: GoogleFonts.outfit(
                                                        fontSize: 11.5,
                                                        fontWeight: FontWeight.w800,
                                                        color: color,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 3),
                                                ClipRRect(
                                                  borderRadius: BorderRadius.circular(3),
                                                  child: LinearProgressIndicator(
                                                    value: pct / 100,
                                                    minHeight: 5,
                                                    backgroundColor: color.withOpacity(0.12),
                                                    valueColor: AlwaysStoppedAnimation<Color>(color),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                        }).toList(),
                                      ],
                                    ),
                                  ),
                                ] else ...[
                                  // Standard Overview Metrics Block
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: AppTheme.cardColor,
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
                                              _selectedProduct != 'All'
                                                  ? 'PRODUCT REVENUE'
                                                  : (_selectedCategory == 'All' ? 'TOTAL REVENUE' : 'CATEGORY REVENUE'),
                                              style: GoogleFonts.outfit(
                                                fontSize: 9.5,
                                                fontWeight: FontWeight.w800,
                                                color: AppTheme.textSecondary,
                                                letterSpacing: 0.5,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              _formatCurrency(
                                                _selectedProduct != 'All'
                                                    ? (_getEffectiveProductBreakdown(district)[_selectedProduct] ?? district.grossRevenueRupees)
                                                    : (_selectedCategory == 'All'
                                                        ? district.grossRevenueRupees
                                                        : (_getEffectiveCategoryBreakdown(district)[_selectedCategory] ?? district.grossRevenueRupees)),
                                              ),
                                              style: GoogleFonts.outfit(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w800,
                                                color: AppTheme.primaryColor,
                                              ),
                                            ),
                                          ],
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: Colors.blue.withOpacity(0.08),
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(color: Colors.blue.withOpacity(0.2)),
                                          ),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.end,
                                            children: [
                                              Text(
                                                'ACTIVE DEALERS',
                                                style: GoogleFonts.outfit(
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.w800,
                                                  color: Colors.blue.shade800,
                                                  letterSpacing: 0.5,
                                                ),
                                              ),
                                              const SizedBox(height: 1),
                                              Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  const Icon(Icons.storefront_rounded, size: 13, color: Colors.blue),
                                                  const SizedBox(width: 3),
                                                  Text(
                                                    '${district.activeDealers}',
                                                    style: GoogleFonts.outfit(
                                                      fontSize: 14,
                                                      fontWeight: FontWeight.w800,
                                                      color: Colors.blue.shade900,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 10),
                                // Dealer Conversion Rate Micro-Gauge Bar
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                                  decoration: BoxDecoration(
                                    color: convColor.withOpacity(0.06),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: convColor.withOpacity(0.2)),
                                  ),
                                  child: Column(
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Row(
                                            children: [
                                              Icon(Icons.stars_rounded, size: 14, color: convColor),
                                              const SizedBox(width: 4),
                                              Text(
                                                'Dealer Order Conversion',
                                                style: GoogleFonts.outfit(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w700,
                                                  color: AppTheme.textSecondary,
                                                ),
                                              ),
                                            ],
                                          ),
                                          Text(
                                            '${district.conversionRate.toStringAsFixed(1)}%',
                                            style: GoogleFonts.outfit(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w800,
                                              color: convColor,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(3),
                                        child: LinearProgressIndicator(
                                          value: (district.conversionRate / 100).clamp(0.02, 1.0),
                                          minHeight: 4,
                                          backgroundColor: convColor.withOpacity(0.12),
                                          valueColor: AlwaysStoppedAnimation<Color>(convColor),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                );
              },
            ),
        ],
      ),
    );
  }

  // Segment Tab Helper
  Widget _buildModeSegmentTab(String modeKey, String label) {
    final isSelected = _breakdownMode == modeKey;
    return InkWell(
      onTap: () {
        setState(() {
          _breakdownMode = modeKey;
        });
      },
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryColor : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppTheme.primaryColor.withOpacity(0.3),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: isSelected ? Colors.white : AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }

  // Dropdown Column Helper
  Widget _buildFilterDropdownColumn({
    required String label,
    required String value,
    required IconData icon,
    required List<String> items,
    required Color activeColor,
    required ValueChanged<String?> onChanged,
  }) {
    final isFiltered = value != 'All';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: AppTheme.textSecondary,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          height: 42,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: AppTheme.cardColor,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isFiltered ? activeColor : AppTheme.borderColor,
              width: isFiltered ? 1.5 : 1.0,
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
              style: GoogleFonts.outfit(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
              onChanged: onChanged,
              items: items.map((itemVal) {
                return DropdownMenuItem<String>(
                  value: itemVal,
                  child: Row(
                    children: [
                      Icon(
                        icon,
                        size: 14,
                        color: itemVal == 'All' ? AppTheme.textSecondary : activeColor,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          itemVal == 'All' ? 'All ${label.toLowerCase()}s' : itemVal,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.outfit(
                            fontWeight: itemVal == 'All' ? FontWeight.w600 : FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }
}
