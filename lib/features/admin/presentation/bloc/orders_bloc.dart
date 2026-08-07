import 'dart:convert';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kd_pannel/core/network/api_client.dart';
import '../../data/models/order_model.dart';
import 'package:kd_pannel/features/admin/presentation/bloc/orders_event.dart';
import 'package:kd_pannel/features/admin/presentation/bloc/orders_state.dart';

class OrdersBloc extends Bloc<OrdersEvent, OrdersState> {
  OrdersBloc() : super(const OrdersState()) {
    on<FetchOrdersEvent>(_onFetchOrders);
    on<UpdateOrdersFilterEvent>(_onUpdateOrdersFilter);
    on<ClearOrdersMessageEvent>(_onClearOrdersMessage);
    on<ResetOrdersEvent>(_onResetOrders);
  }

  void _onResetOrders(ResetOrdersEvent event, Emitter<OrdersState> emit) {
    emit(const OrdersState());
  }

  Future<void> _onFetchOrders(
    FetchOrdersEvent event,
    Emitter<OrdersState> emit,
  ) async {
    if (state.status == OrdersStatus.loading) return;

    emit(state.copyWith(status: OrdersStatus.loading));
    try {
      String queryParams = '';
      if (state.selectedRange != null && state.selectedRange!.startDate != null) {
        final start = state.selectedRange!.startDate!.toUtc().toIso8601String();
        final end = (state.selectedRange!.endDate ?? state.selectedRange!.startDate!).toUtc().toIso8601String();
        queryParams = '?startDate=$start&endDate=$end';
      } else if (state.selectedTimeframe != 'All Time') {
        final now = DateTime.now();
        DateTime? startDate;
        switch (state.selectedTimeframe) {
          case 'Today': startDate = DateTime(now.year, now.month, now.day); break;
          case 'Last 1 Week': startDate = now.subtract(const Duration(days: 7)); break;
          case 'Last 1 Month': startDate = DateTime(now.year, now.month - 1, now.day); break;
          case 'Last 3 Months': startDate = DateTime(now.year, now.month - 3, now.day); break;
        }
        if (startDate != null) {
          queryParams = '?startDate=${startDate.toUtc().toIso8601String()}';
        }
      }

      final response = await ApiClient().get('/orders/admin/all$queryParams');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          final List rawOrders = data['orders'] ?? [];
          final List<OrderModel> parsedOrders =
              rawOrders.map((o) => OrderModel.fromJson(o)).toList();
          emit(state.copyWith(
            status: OrdersStatus.success,
            orders: parsedOrders,
          ));
          return;
        }
      }
      emit(state.copyWith(
        status: OrdersStatus.failure,
        errorMessage: 'Failed to load orders. Status code: ${response.statusCode}',
      ));
    } catch (e) {
      emit(state.copyWith(
        status: OrdersStatus.failure,
        errorMessage: 'Connection error: $e',
      ));
    }
  }

  void _onUpdateOrdersFilter(
    UpdateOrdersFilterEvent event,
    Emitter<OrdersState> emit,
  ) {
    if (event.resetRange) {
      emit(state.copyWithResetRange(
        searchQuery: event.searchQuery,
        selectedOrderStatus: event.selectedOrderStatus,
        selectedPaymentStatus: event.selectedPaymentStatus,
        selectedPaymentMethod: event.selectedPaymentMethod,
        selectedTimeframe: event.selectedTimeframe,
        currentPage: event.currentPage,
        pageSize: event.pageSize,
      ));
    } else {
      emit(state.copyWith(
        searchQuery: event.searchQuery,
        selectedOrderStatus: event.selectedOrderStatus,
        selectedPaymentStatus: event.selectedPaymentStatus,
        selectedPaymentMethod: event.selectedPaymentMethod,
        selectedTimeframe: event.selectedTimeframe,
        selectedRange: event.selectedRange,
        currentPage: event.currentPage,
        pageSize: event.pageSize,
      ));
    }

    // If timeframe or range changed, trigger a fresh fetch
    if (event.selectedTimeframe != null || event.selectedRange != null || event.resetRange) {
      add(const FetchOrdersEvent(forceRefresh: true));
    }
  }

  void _onClearOrdersMessage(
    ClearOrdersMessageEvent event,
    Emitter<OrdersState> emit,
  ) {
    emit(state.copyWith(errorMessage: null));
  }
}
