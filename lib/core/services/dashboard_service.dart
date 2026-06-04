import 'dart:async';

/// A service that simulates real-world enterprise database queries with deliberate API latency.
/// This allows each dashboard widget to render individually in the background using FutureBuilders.
class DashboardService {
  // Simulating localized caches
  static final _salesDelay = const Duration(milliseconds: 1400);
  static final _ordersDelay = const Duration(milliseconds: 600);
  static final _dealersDelay = const Duration(milliseconds: 2000);
  static final _leadsDelay = const Duration(milliseconds: 1000);

  /// Standard simulated latency for Leads status categories
  static final _unassignedDelay = const Duration(milliseconds: 800);
  static final _assignedDelay = const Duration(milliseconds: 1200);
  static final _kycPendingDelay = const Duration(milliseconds: 1600);
  static final _kycConfirmDelay = const Duration(milliseconds: 1000);
  static final _orderPendingDelay = const Duration(milliseconds: 1500);
  static final _orderConfirmDelay = const Duration(milliseconds: 700);

  // --- Admin Dashboard Stats ---

  /// Maps a period string to a numeric multiplier for simulating different data.
  static double _periodMultiplier(String period) {
    switch (period) {
      case 'Today':
        return 0.05;
      case '1 Week':
      case 'Last 1 Week':
        return 0.22;
      case 'Last 2 Weeks':
        return 0.45;
      case 'Last 3 Weeks':
        return 0.65;
      case 'Last 1 Month':
        return 1.0;
      case 'Last 3 Months':
        return 2.8;
      case 'Last 6 Months':
        return 5.4;
      case 'This Month':
        return 1.0;
      default:
        return 1.0;
    }
  }

  Future<String> getRevenueToday({String period = 'Today'}) async {
    await Future.delayed(_salesDelay);
    final double base = 28400;
    final int val = (base * _periodMultiplier(period)).round();
    return '₹${_formatNumber(val)}';
  }

  Future<String> getOrderToday({String period = 'Today'}) async {
    await Future.delayed(_ordersDelay);
    final int base = 18;
    final int val = (base * _periodMultiplier(period)).round();
    return '$val';
  }

  Future<String> getActiveDealers({String period = 'Today'}) async {
    await Future.delayed(_dealersDelay);
    final int base = 842;
    final int val = (base + (10 * _periodMultiplier(period))).round();
    return '$val';
  }

  Future<String> getNewLeads({String period = 'Today'}) async {
    await Future.delayed(_leadsDelay);
    final int base = 15;
    final int val = (base * _periodMultiplier(period)).round();
    return '$val';
  }

  Future<String> getTransactingDeals({String period = 'Today'}) async {
    await Future.delayed(_salesDelay);
    final int base = 24;
    final int val = (base * _periodMultiplier(period)).round();
    return '$val';
  }

  Future<String> getEventsToday({String period = 'Today'}) async {
    await Future.delayed(_leadsDelay);
    final int base = 142;
    final int val = (base * _periodMultiplier(period)).round();
    return '$val';
  }

  static String _formatNumber(int n) {
    if (n >= 1000) {
      return '${(n / 1000).toStringAsFixed(n % 1000 == 0 ? 0 : 1)}k';
    }
    return '$n';
  }

  // --- Dealer Management Stats ---
  Future<String> getDealerTotalDealers() async {
    await Future.delayed(_dealersDelay);
    return '1,245';
  }

  Future<String> getDealerActiveDealers() async {
    await Future.delayed(_salesDelay);
    return '982';
  }

  Future<String> getDealerHighValueDealers() async {
    await Future.delayed(_leadsDelay);
    return '156';
  }

  Future<String> getDealerInactiveDealers() async {
    await Future.delayed(_ordersDelay);
    return '107';
  }

  // --- Leads Dashboard Stats ---
  Future<String> getLeadsUnassigned() async {
    await Future.delayed(_unassignedDelay);
    return '10';
  }

  Future<String> getLeadsAssigned() async {
    await Future.delayed(_assignedDelay);
    return '10';
  }

  Future<String> getLeadsKycPending() async {
    await Future.delayed(_kycPendingDelay);
    return '10';
  }

  Future<String> getLeadsKycConfirm() async {
    await Future.delayed(_kycConfirmDelay);
    return '10';
  }

  Future<String> getLeadsOrderPending() async {
    await Future.delayed(_orderPendingDelay);
    return '10';
  }

  Future<String> getLeadsOrderConfirm() async {
    await Future.delayed(_orderConfirmDelay);
    return '10';
  }
}
