import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kd_pannel/app_theme.dart';

class AgriHeatmapFilterBar extends StatelessWidget {
  final String activeFilterValue;
  final List<String> activityOptions;
  final ValueChanged<String?> onActivityChanged;

  final String safeState;
  final List<String> availableStates;
  final Map<String, int> stateOrderCounts;
  final int grandTotalOrders;
  final ValueChanged<String?> onStateChanged;

  final String safeDistrict;
  final List<String> availableDistricts;
  final Map<String, int> districtOrderCounts;
  final int stateFilteredTotalOrders;
  final ValueChanged<String?> onDistrictChanged;

  final String safeCategory;
  final List<String> availableCategories;
  final ValueChanged<String?> onCategoryChanged;

  final String safeProduct;
  final List<String> availableProducts;
  final ValueChanged<String?> onProductChanged;

  final TextEditingController searchController;
  final String searchQuery;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onClearSearch;

  final bool hasActiveFilters;
  final VoidCallback onResetFilters;

  const AgriHeatmapFilterBar({
    super.key,
    required this.activeFilterValue,
    required this.activityOptions,
    required this.onActivityChanged,
    required this.safeState,
    required this.availableStates,
    required this.stateOrderCounts,
    required this.grandTotalOrders,
    required this.onStateChanged,
    required this.safeDistrict,
    required this.availableDistricts,
    required this.districtOrderCounts,
    required this.stateFilteredTotalOrders,
    required this.onDistrictChanged,
    required this.safeCategory,
    required this.availableCategories,
    required this.onCategoryChanged,
    required this.safeProduct,
    required this.availableProducts,
    required this.onProductChanged,
    required this.searchController,
    required this.searchQuery,
    required this.onSearchChanged,
    required this.onClearSearch,
    required this.hasActiveFilters,
    required this.onResetFilters,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth > 950;
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.backgroundColor.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Flex(
                direction: isDesktop ? Axis.horizontal : Axis.vertical,
                crossAxisAlignment: isDesktop
                    ? CrossAxisAlignment.center
                    : CrossAxisAlignment.start,
                children: [
                  // 0. Activity Filter Dropdown
                  Expanded(
                    flex: isDesktop ? 2 : 0,
                    child: _buildFilterDropdownColumn(
                      label: 'ACTIVITY',
                      value: activeFilterValue,
                      icon: Icons.filter_alt_rounded,
                      items: activityOptions,
                      activeColor: const Color(0xFF00897B),
                      onChanged: onActivityChanged,
                    ),
                  ),
                  SizedBox(
                    width: isDesktop ? 10 : 0,
                    height: isDesktop ? 0 : 10,
                  ),

                  // 1. State Dropdown
                  Expanded(
                    flex: isDesktop ? 2 : 0,
                    child: _buildFilterDropdownColumn(
                      label: 'STATE',
                      value: safeState,
                      icon: Icons.map_rounded,
                      items: availableStates,
                      itemCounts: stateOrderCounts,
                      totalCount: grandTotalOrders,
                      activeColor: AppTheme.primaryColor,
                      onChanged: onStateChanged,
                    ),
                  ),
                  SizedBox(
                    width: isDesktop ? 10 : 0,
                    height: isDesktop ? 0 : 10,
                  ),

                  // 2. District Dropdown
                  Expanded(
                    flex: isDesktop ? 2 : 0,
                    child: _buildFilterDropdownColumn(
                      label: 'DISTRICT',
                      value: safeDistrict,
                      icon: Icons.location_city_rounded,
                      items: availableDistricts,
                      itemCounts: districtOrderCounts,
                      totalCount: stateFilteredTotalOrders,
                      activeColor: const Color(0xFF0288D1),
                      onChanged: onDistrictChanged,
                    ),
                  ),
                  SizedBox(
                    width: isDesktop ? 10 : 0,
                    height: isDesktop ? 0 : 10,
                  ),

                  // 3. Category Dropdown
                  Expanded(
                    flex: isDesktop ? 3 : 0,
                    child: _buildFilterDropdownColumn(
                      label: 'CATEGORY',
                      value: safeCategory,
                      icon: Icons.category_rounded,
                      items: availableCategories,
                      activeColor: const Color(0xFF7B1FA2),
                      onChanged: onCategoryChanged,
                    ),
                  ),
                  SizedBox(
                    width: isDesktop ? 10 : 0,
                    height: isDesktop ? 0 : 10,
                  ),

                  // 4. Product Dropdown
                  if (availableProducts.length > 1) ...[
                    Expanded(
                      flex: isDesktop ? 3 : 0,
                      child: _buildFilterDropdownColumn(
                        label: 'PRODUCT',
                        value: safeProduct,
                        icon: Icons.inventory_2_rounded,
                        items: availableProducts,
                        activeColor: const Color(0xFFE65100),
                        onChanged: onProductChanged,
                      ),
                    ),
                    SizedBox(
                      width: isDesktop ? 10 : 0,
                      height: isDesktop ? 0 : 10,
                    ),
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
                              color: searchQuery.isNotEmpty
                                  ? AppTheme.primaryColor
                                  : AppTheme.borderColor,
                              width: searchQuery.isNotEmpty ? 1.5 : 1.0,
                            ),
                          ),
                          child: TextField(
                            controller: searchController,
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
                              prefixIcon: const Icon(
                                Icons.search_rounded,
                                size: 18,
                                color: AppTheme.textSecondary,
                              ),
                              suffixIcon: searchQuery.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(
                                        Icons.close_rounded,
                                        size: 16,
                                      ),
                                      onPressed: onClearSearch,
                                    )
                                  : null,
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 10,
                              ),
                            ),
                            onChanged: onSearchChanged,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Reset Button
                  if (hasActiveFilters) ...[
                    SizedBox(
                      width: isDesktop ? 10 : 0,
                      height: isDesktop ? 0 : 10,
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 14),
                      child: InkWell(
                        onTap: onResetFilters,
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          height: 42,
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: Colors.red.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.refresh_rounded,
                                size: 16,
                                color: Colors.red,
                              ),
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
                      ...availableCategories
                          .where((c) => c != 'All')
                          .map((catName) {
                        final isSelected =
                            safeCategory.toLowerCase() == catName.toLowerCase();
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: InkWell(
                            onTap: () {
                              onCategoryChanged(isSelected ? 'All' : catName);
                            },
                            borderRadius: BorderRadius.circular(20),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppTheme.primaryColor
                                    : AppTheme.primaryColor.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isSelected
                                      ? AppTheme.primaryColor
                                      : AppTheme.primaryColor.withValues(alpha: 0.3),
                                ),
                              ),
                              child: Text(
                                catName,
                                style: GoogleFonts.outfit(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w800,
                                  color: isSelected
                                      ? Colors.white
                                      : AppTheme.primaryColor,
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildFilterDropdownColumn({
    required String label,
    required String value,
    required IconData icon,
    required List<String> items,
    Map<String, int>? itemCounts,
    int? totalCount,
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
                final count = itemVal == 'All'
                    ? totalCount
                    : (itemCounts != null ? (itemCounts[itemVal] ?? 0) : null);
                return DropdownMenuItem<String>(
                  value: itemVal,
                  child: Row(
                    children: [
                      Icon(
                        icon,
                        size: 14,
                        color: itemVal == 'All'
                            ? AppTheme.textSecondary
                            : activeColor,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          itemVal == 'All'
                              ? 'All ${label.toLowerCase().endsWith('y') ? label.toLowerCase().substring(0, label.length - 1) + 'ies' : label.toLowerCase() + 's'}'
                              : itemVal,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.outfit(
                            fontWeight: itemVal == 'All'
                                ? FontWeight.w600
                                : FontWeight.w800,
                          ),
                        ),
                      ),
                      if (count != null)
                        Padding(
                          padding: const EdgeInsets.only(left: 4),
                          child: Text(
                            '($count)',
                            style: GoogleFonts.outfit(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: itemVal == 'All'
                                  ? AppTheme.textSecondary
                                  : activeColor.withValues(alpha: 0.8),
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
