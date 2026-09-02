class DistrictDemandData {
  final String _rawDistrictName;
  final String _rawStateName;
  final String primaryCrop;
  final String category;
  final String subCategory;
  final int registeredDealers; // users registered with this district address
  final int activeBuyers; // unique users who placed ≥1 order from this district
  final int activeDealers; // = registeredDealers (kept for compatibility)
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

  // Canonical names trimmed
  String get districtName => _rawDistrictName.trim();
  String get stateName => _rawStateName.trim();

  int get activeFarmers => activeDealers;
}

String formatHeatmapCurrency(double rupees) {
  if (rupees >= 100000) {
    return '₹${(rupees / 100000).toStringAsFixed(2)} Lakh';
  } else if (rupees >= 1000) {
    return '₹${(rupees / 1000).toStringAsFixed(1)}k';
  } else {
    return '₹${rupees.toStringAsFixed(0)}';
  }
}
