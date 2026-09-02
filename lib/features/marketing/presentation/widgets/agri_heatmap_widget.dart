import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kd_pannel/app_theme.dart';
import 'package:kd_pannel/features/marketing/data/india_state_districts.dart';
import 'package:kd_pannel/features/marketing/domain/models/district_demand_data.dart';
import 'package:kd_pannel/features/marketing/presentation/widgets/heatmap/agri_heatmap_filter_bar.dart';
import 'package:kd_pannel/features/marketing/presentation/widgets/heatmap/agri_heatmap_metric_ribbon.dart';
import 'package:kd_pannel/features/marketing/presentation/widgets/heatmap/agri_heatmap_shimmer.dart';
import 'package:kd_pannel/features/marketing/presentation/widgets/heatmap/district_intelligence_card.dart';

// Re-export model for backwards-compatibility
export 'package:kd_pannel/features/marketing/domain/models/district_demand_data.dart';

class AgriHeatmapWidget extends StatefulWidget {
  final List<DistrictDemandData> districts;
  final bool isLoading;

  static const Map<String, List<String>> _stateDistricts = kIndiaStateDistricts;

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
  String _selectedProduct = 'All';
  String _selectedActivityFilter = 'All';
  String _searchQuery = '';
  String _breakdownMode = 'None'; // 'None', 'Product', 'Category', 'SubCategory'

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
      _selectedProduct = 'All';
      _selectedActivityFilter = 'All';
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

  String _normalize(String input) => input.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

  @override
  Widget build(BuildContext context) {
    // 0. High-Fidelity Loading State
    if (widget.isLoading) {
      return const AgriHeatmapShimmer();
    }

    // 0. Empty State
    if (widget.districts.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(36),
        decoration: BoxDecoration(
          color: AppTheme.cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: AppTheme.cardShadow,
          border: Border.all(color: AppTheme.borderColor.withValues(alpha: 0.6)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.location_off_rounded,
                size: 36,
                color: AppTheme.primaryColor,
              ),
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

    // 1. Available States & Counts
    final List<String> availableStates = [
      'All',
      ...AgriHeatmapWidget._stateDistricts.keys.toList()..sort(),
    ];
    if (!availableStates.contains(_selectedState)) {
      _selectedState = 'All';
    }

    final Map<String, int> stateOrderCounts = {};
    final Map<String, int> stateDealerCounts = {};
    int unmatchedOrders = 0;
    final Set<String> unmatchedStateNames = {};

    for (final d in widget.districts) {
      final dataStateKey = _normalize(d.stateName);
      final dealerCount = d.registeredDealers > 0 ? d.registeredDealers : d.activeDealers;

      final matchedState = availableStates.firstWhere((s) {
        if (s == 'All') return false;
        final staticStateKey = _normalize(s);
        if (dataStateKey == staticStateKey) return true;

        final sKey = staticStateKey.replaceAll('and', '').replaceAll('islands', '').replaceAll('ut', '').replaceAll('nct', '');
        final dKey = dataStateKey.replaceAll('and', '').replaceAll('islands', '').replaceAll('ut', '').replaceAll('nct', '');

        if (sKey == dKey && sKey.length > 3) return true;
        if (sKey.contains(dKey) && dKey.length > 4) return true;
        if (dKey.contains(sKey) && sKey.length > 4) return true;

        if (staticStateKey == 'andhrapradesh' && (dataStateKey == 'ap' || dataStateKey == 'andrapradesh')) return true;
        if (staticStateKey == 'uttarpradesh' && (dataStateKey == 'up' || dataStateKey == 'uttarpradesh')) return true;
        if (staticStateKey == 'madhyapradesh' && (dataStateKey == 'mp' || dataStateKey == 'madhyapradesh')) return true;
        if (staticStateKey == 'maharashtra' && (dataStateKey == 'mh' || dataStateKey == 'maha')) return true;
        if (staticStateKey == 'gujarat' && (dataStateKey == 'gj' || dataStateKey == 'gujrat')) return true;
        if (staticStateKey == 'rajasthan' && (dataStateKey == 'rj' || dataStateKey == 'rajs')) return true;
        if (staticStateKey == 'westbengal' && (dataStateKey == 'wb' || dataStateKey == 'bengal')) return true;
        if (staticStateKey == 'tamilnadu' && (dataStateKey == 'tn' || dataStateKey == 'tamil')) return true;
        if (staticStateKey == 'karnataka' && (dataStateKey == 'ka' || dataStateKey == 'karnatak')) return true;
        if (staticStateKey == 'telangana' && (dataStateKey == 'tg' || dataStateKey == 'ts' || dataStateKey == 'telengana')) return true;
        if (staticStateKey == 'jammukashmir' && (dataStateKey == 'jk' || dataStateKey == 'jammu' || dataStateKey == 'jammukashmir')) return true;
        if (staticStateKey == 'uttarakhand' && (dataStateKey == 'uk' || dataStateKey == 'uttaranchal' || dataStateKey == 'uttarkhand')) return true;
        if (staticStateKey == 'odisha' && (dataStateKey == 'orissa' || dataStateKey == 'odisa')) return true;
        if (staticStateKey == 'puducherryut' && (dataStateKey == 'pondicherry' || dataStateKey == 'puduchery')) return true;
        if (staticStateKey == 'lakshadweeput' && (dataStateKey == 'laccadive' || dataStateKey == 'lakshadweep')) return true;

        return false;
      }, orElse: () => '');

      if (matchedState.isNotEmpty) {
        stateOrderCounts[matchedState] = (stateOrderCounts[matchedState] ?? 0) + d.orderCount;
        stateDealerCounts[matchedState] = (stateDealerCounts[matchedState] ?? 0) + dealerCount;
      } else {
        unmatchedOrders += d.orderCount;
        if (d.stateName.isNotEmpty) unmatchedStateNames.add(d.stateName);
      }
    }

    if (unmatchedOrders > 0) {
      final label = 'Other (${unmatchedStateNames.take(2).join(", ")})';
      stateOrderCounts[label] = unmatchedOrders;
      if (!availableStates.contains(label)) {
        availableStates.add(label);
      }
    }

    availableStates.retainWhere(
      (s) => s == 'All' || (stateOrderCounts[s] ?? 0) > 0 || (stateDealerCounts[s] ?? 0) > 0,
    );
    final String safeState = availableStates.contains(_selectedState) ? _selectedState : 'All';
    final int grandTotalOrders = widget.districts.fold(0, (sum, d) => sum + d.orderCount);

    // 2. Filter by State
    final List<DistrictDemandData> stateFilteredDistricts = safeState == 'All'
        ? widget.districts
        : widget.districts.where((d) {
            final dataStateKey = _normalize(d.stateName);
            final selectedStateKey = _normalize(safeState);
            if (dataStateKey == selectedStateKey) return true;
            if (selectedStateKey == 'uttarpradesh' && dataStateKey == 'up') return true;
            if (selectedStateKey == 'madhyapradesh' && dataStateKey == 'mp') return true;
            return false;
          }).toList();

    // 3. Available Districts & Counts
    final List<String> availableDistricts = ['All'];
    if (safeState != 'All') {
      availableDistricts.addAll(AgriHeatmapWidget._stateDistricts[safeState] ?? []);
    } else {
      final Set<String> distSet = widget.districts
          .where(
            (d) => (d.orderCount > 0 || d.registeredDealers > 0) && d.districtName.isNotEmpty && d.districtName.toLowerCase() != 'unknown',
          )
          .map((d) => d.districtName)
          .toSet();
      availableDistricts.addAll(distSet.toList()..sort());
    }

    final Map<String, int> districtOrderCounts = {};
    final Map<String, int> districtDealerCounts = {};
    for (final d in stateFilteredDistricts) {
      final dataDistKey = _normalize(d.districtName);
      final dealerCount = d.registeredDealers > 0 ? d.registeredDealers : d.activeDealers;
      final matchedDist = availableDistricts.firstWhere((dist) {
        if (dist == 'All') return false;
        final staticDistKey = _normalize(dist);
        return dataDistKey.contains(staticDistKey) || staticDistKey.contains(dataDistKey);
      }, orElse: () => '');
      if (matchedDist.isNotEmpty) {
        districtOrderCounts[matchedDist] = (districtOrderCounts[matchedDist] ?? 0) + d.orderCount;
        districtDealerCounts[matchedDist] = (districtDealerCounts[matchedDist] ?? 0) + dealerCount;
      } else if ((d.orderCount > 0 || dealerCount > 0) && d.districtName.isNotEmpty) {
        districtOrderCounts[d.districtName] = (districtOrderCounts[d.districtName] ?? 0) + d.orderCount;
        districtDealerCounts[d.districtName] = (districtDealerCounts[d.districtName] ?? 0) + dealerCount;
        if (!availableDistricts.contains(d.districtName)) {
          availableDistricts.add(d.districtName);
        }
      }
    }

    availableDistricts.retainWhere(
      (d) => d == 'All' || (districtOrderCounts[d] ?? 0) > 0 || (districtDealerCounts[d] ?? 0) > 0,
    );
    final String safeDistrict = availableDistricts.contains(_selectedDistrict) ? _selectedDistrict : 'All';

    // 4. Activity Filter Dealer Counts
    int activeDealersTotal = 0;
    int untappedDealersTotal = 0;
    for (final d in widget.districts) {
      final reg = d.registeredDealers > 0 ? d.registeredDealers : d.activeDealers;
      final buyers = d.activeBuyers;
      activeDealersTotal += buyers;
      if (reg > buyers) {
        untappedDealersTotal += (reg - buyers);
      }
    }
    final int allDealersCountTotal = activeDealersTotal + untappedDealersTotal;

    final String optAll = 'All ($allDealersCountTotal Dealers)';
    final String optActive = 'Active Only ($activeDealersTotal Dealers)';
    final String optUntapped = 'Untapped Only ($untappedDealersTotal Dealers)';
    final List<String> activityOptions = [optAll, optActive, optUntapped];

    final String activeFilterValue = activityOptions.firstWhere(
      (opt) => opt.startsWith(_selectedActivityFilter),
      orElse: () => optAll,
    );

    final int stateFilteredTotalOrders = districtOrderCounts.values.fold(0, (sum, val) => sum + val);

    // 5. Available Categories & Products
    final Set<String> categorySet = widget.districts.map((d) => d.category.trim()).where((c) => c.isNotEmpty).toSet();
    for (final d in widget.districts) {
      if (d.categoryBreakdown != null) {
        categorySet.addAll(d.categoryBreakdown!.keys);
      }
    }
    final List<String> availableCategories = ['All', ...categorySet.toList()..sort()];
    final String safeCategory = availableCategories.contains(_selectedCategory) ? _selectedCategory : 'All';

    final Set<String> productSet = {};
    for (final d in widget.districts) {
      if (d.productBreakdown != null) {
        productSet.addAll(d.productBreakdown!.keys);
      }
    }
    final List<String> availableProducts = ['All', ...productSet.toList()..sort()];
    final String safeProduct = availableProducts.contains(_selectedProduct) ? _selectedProduct : 'All';

    // 6. Filter Districts
    final List<DistrictDemandData> filteredDistricts = stateFilteredDistricts.where((d) {
      final matchesDistrict = safeDistrict == 'All' || _normalize(d.districtName) == _normalize(safeDistrict);

      final catBreakdown = _getEffectiveCategoryBreakdown(d);
      final matchesCategory = safeCategory == 'All' ||
          d.category.toLowerCase() == safeCategory.toLowerCase() ||
          catBreakdown.keys.any((k) => k.toLowerCase() == safeCategory.toLowerCase());

      final prodBreakdown = _getEffectiveProductBreakdown(d);
      final matchesProduct = safeProduct == 'All' ||
          prodBreakdown.keys.any((p) => p.toLowerCase() == safeProduct.toLowerCase());

      final matchesSearch = _searchQuery.isEmpty ||
          d.districtName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          d.stateName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          d.primaryCrop.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          d.category.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          prodBreakdown.keys.any((p) => p.toLowerCase().contains(_searchQuery.toLowerCase()));

      final matchesActivity = _selectedActivityFilter.startsWith('All') ||
          (_selectedActivityFilter.startsWith('Active Only') && (d.orderCount > 0 || d.activeBuyers > 0)) ||
          (_selectedActivityFilter.startsWith('Untapped Only') && (d.orderCount == 0 || d.registeredDealers > d.activeBuyers));

      return matchesDistrict && matchesCategory && matchesProduct && matchesSearch && matchesActivity;
    }).toList();

    // 7. Aggregated Metrics
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

    final int totalDealers = filteredDistricts.fold(0, (sum, d) {
      final reg = d.registeredDealers > 0 ? d.registeredDealers : d.activeDealers;
      if (_selectedActivityFilter.startsWith('Untapped Only')) {
        return sum + (reg - d.activeBuyers).clamp(0, 999999);
      } else if (_selectedActivityFilter.startsWith('Active Only')) {
        return sum + d.activeBuyers;
      }
      return sum + (d.activeBuyers > 0 ? d.activeBuyers : d.activeDealers);
    });

    final int totalRegisteredDealers = filteredDistricts.fold(
      0,
      (sum, d) => sum + (d.registeredDealers > 0 ? d.registeredDealers : d.activeDealers),
    );
    final int totalOrders = filteredDistricts.fold(0, (sum, d) => sum + d.orderCount);
    final double avgConversionRate = filteredDistricts.isNotEmpty
        ? filteredDistricts.fold(0.0, (sum, d) => sum + d.conversionRate) / filteredDistricts.length
        : 0.0;

    final bool hasActiveFilters = _selectedState != 'All' ||
        _selectedDistrict != 'All' ||
        _selectedCategory != 'All' ||
        _selectedProduct != 'All' ||
        _selectedActivityFilter != 'All' ||
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
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(color: AppTheme.borderColor.withValues(alpha: 0.8)),
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
                                color: const Color(0xFF2E7D32).withValues(alpha: 0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.analytics_rounded,
                            size: 22,
                            color: Colors.white,
                          ),
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
                            _buildModeSegmentTab('None', 'Overview', Icons.bar_chart_rounded),
                            _buildModeSegmentTab('Product', 'Product Breakdown', Icons.inventory_2_rounded),
                            _buildModeSegmentTab('Category', 'Category', Icons.label_rounded),
                            _buildModeSegmentTab('SubCategory', 'SubCategory', Icons.folder_rounded),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 20),

            // Filters Bar Component
            AgriHeatmapFilterBar(
              activeFilterValue: activeFilterValue,
              activityOptions: activityOptions,
              onActivityChanged: (val) {
                if (val != null) {
                  setState(() {
                    if (val.startsWith('Active Only')) {
                      _selectedActivityFilter = 'Active Only';
                    } else if (val.startsWith('Untapped Only')) {
                      _selectedActivityFilter = 'Untapped Only';
                    } else {
                      _selectedActivityFilter = 'All';
                    }
                  });
                }
              },
              safeState: safeState,
              availableStates: availableStates,
              stateOrderCounts: stateOrderCounts,
              grandTotalOrders: grandTotalOrders,
              onStateChanged: (val) {
                if (val != null) {
                  setState(() {
                    _selectedState = val;
                    _selectedDistrict = 'All';
                  });
                }
              },
              safeDistrict: safeDistrict,
              availableDistricts: availableDistricts,
              districtOrderCounts: districtOrderCounts,
              stateFilteredTotalOrders: stateFilteredTotalOrders,
              onDistrictChanged: (val) {
                if (val != null) {
                  setState(() {
                    _selectedDistrict = val;
                  });
                }
              },
              safeCategory: safeCategory,
              availableCategories: availableCategories,
              onCategoryChanged: (cat) {
                setState(() {
                  _selectedCategory = cat ?? 'All';
                });
              },
              safeProduct: safeProduct,
              availableProducts: availableProducts,
              onProductChanged: (prod) {
                if (prod != null) {
                  setState(() {
                    _selectedProduct = prod;
                  });
                }
              },
              searchController: _searchController,
              searchQuery: _searchQuery,
              onSearchChanged: (val) {
                setState(() {
                  _searchQuery = val.trim();
                });
              },
              onClearSearch: () {
                setState(() {
                  _searchQuery = '';
                  _searchController.clear();
                });
              },
              hasActiveFilters: hasActiveFilters,
              onResetFilters: _resetFilters,
            ),
            const SizedBox(height: 16),

            // Executive Summary Metric Ribbon
            AgriHeatmapMetricRibbon(
              displayedDistrictsCount: filteredDistricts.length,
              totalDistrictsCount: widget.districts.length,
              selectedProduct: _selectedProduct,
              selectedCategory: _selectedCategory,
              totalRevenue: totalRevenue,
              totalDealers: totalDealers,
              totalRegisteredDealers: totalRegisteredDealers,
              totalOrders: totalOrders,
              avgConversionRate: avgConversionRate,
              selectedActivityFilter: _selectedActivityFilter,
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
                    const Icon(
                      Icons.search_off_rounded,
                      size: 44,
                      color: AppTheme.textSecondary,
                    ),
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
                        textStyle: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth > 700;
                  final double width = isWide
                      ? (constraints.maxWidth - 28) / 3
                      : (constraints.maxWidth - 14) / 2;

                  return Wrap(
                    spacing: 14,
                    runSpacing: 14,
                    children: filteredDistricts.map((district) {
                      return DistrictIntelligenceCard(
                        district: district,
                        width: width,
                        breakdownMode: _breakdownMode,
                        selectedProduct: _selectedProduct,
                        selectedCategory: _selectedCategory,
                        selectedActivityFilter: _selectedActivityFilter,
                        getEffectiveProductBreakdown: _getEffectiveProductBreakdown,
                        getEffectiveCategoryBreakdown: _getEffectiveCategoryBreakdown,
                        getEffectiveSubCategoryBreakdown: _getEffectiveSubCategoryBreakdown,
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
  Widget _buildModeSegmentTab(String modeKey, String label, IconData icon) {
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
                    color: AppTheme.primaryColor.withValues(alpha: 0.3),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected ? Colors.white : AppTheme.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? Colors.white : AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
