import 'package:flutter_test/flutter_test.dart';
import 'package:kd_pannel/features/admin/presentation/bloc/orders_state.dart';
import 'package:kd_pannel/features/admin/data/models/order_model.dart';

void main() {
  group('OrdersState Tests', () {
    test('default state has correct initial values', () {
      const state = OrdersState();
      expect(state.status, equals(OrdersStatus.initial));
      expect(state.orders, isEmpty);
      expect(state.searchQuery, isEmpty);
      expect(state.selectedOrderStatus, equals('All Statuses'));
      expect(state.selectedPaymentStatus, equals('All Payments'));
      expect(state.selectedTimeframe, equals('All Time'));
      expect(state.currentPage, equals(1));
    });

    test('copyWith updates state correctly', () {
      const state = OrdersState();
      final sampleOrder = OrderModel.fromJson({
        '_id': 'ORD-101',
        'orderId': 'ORD-101',
        'user': {'name': 'Ramesh Kumar', 'phone': '9876543210', 'role': 'dealer'},
        'orderStatus': 'PENDING',
        'totalAmount': 1500.0,
        'placedAt': DateTime.now().toIso8601String(),
      });

      final updated = state.copyWith(
        status: OrdersStatus.success,
        orders: [sampleOrder],
        searchQuery: 'ORD-101',
        selectedOrderStatus: 'PENDING',
      );

      expect(updated.status, equals(OrdersStatus.success));
      expect(updated.orders.length, equals(1));
      expect(updated.orders.first.id, equals('ORD-101'));
      expect(updated.searchQuery, equals('ORD-101'));
      expect(updated.selectedOrderStatus, equals('PENDING'));
    });

    test('copyWithResetRange clears date range correctly', () {
      const state = OrdersState(selectedTimeframe: 'custom');
      final updated = state.copyWithResetRange(
        selectedTimeframe: 'All Time',
        searchQuery: 'query',
      );

      expect(updated.selectedRange, isNull);
      expect(updated.selectedTimeframe, equals('All Time'));
      expect(updated.searchQuery, equals('query'));
    });
  });
}
