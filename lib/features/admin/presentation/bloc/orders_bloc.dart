import 'dart:convert';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kd_pannel/core/network/api_client.dart';
import '../../data/models/order_model.dart';
import 'orders_event.dart';
import 'orders_state.dart';

class OrdersBloc extends Bloc<OrdersEvent, OrdersState> {
  OrdersBloc() : super(const OrdersState()) {
    on<FetchOrdersEvent>(_onFetchOrders);
    on<UpdateOrdersFilterEvent>(_onUpdateOrdersFilter);
    on<ClearOrdersMessageEvent>(_onClearOrdersMessage);
  }

  Future<void> _onFetchOrders(
    FetchOrdersEvent event,
    Emitter<OrdersState> emit,
  ) async {
    emit(state.copyWith(status: OrdersStatus.loading));
    try {
      final response = await ApiClient().get('/orders/admin/all');
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
    emit(state.copyWith(
      searchQuery: event.searchQuery,
      selectedOrderStatus: event.selectedOrderStatus,
      selectedPaymentStatus: event.selectedPaymentStatus,
      selectedPaymentMethod: event.selectedPaymentMethod,
      currentPage: event.currentPage,
      pageSize: event.pageSize,
    ));
  }

  void _onClearOrdersMessage(
    ClearOrdersMessageEvent event,
    Emitter<OrdersState> emit,
  ) {
    emit(state.copyWith(errorMessage: null));
  }
}
