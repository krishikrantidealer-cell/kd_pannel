import 'package:equatable/equatable.dart';

abstract class OrdersEvent extends Equatable {
  const OrdersEvent();

  @override
  List<Object?> get props => [];
}

class FetchOrdersEvent extends OrdersEvent {
  final bool forceRefresh;
  const FetchOrdersEvent({this.forceRefresh = false});

  @override
  List<Object?> get props => [forceRefresh];
}

class UpdateOrdersFilterEvent extends OrdersEvent {
  final String? searchQuery;
  final String? selectedOrderStatus;
  final String? selectedPaymentStatus;
  final String? selectedPaymentMethod;
  final int? currentPage;
  final int? pageSize;

  const UpdateOrdersFilterEvent({
    this.searchQuery,
    this.selectedOrderStatus,
    this.selectedPaymentStatus,
    this.selectedPaymentMethod,
    this.currentPage,
    this.pageSize,
  });

  @override
  List<Object?> get props => [
        searchQuery,
        selectedOrderStatus,
        selectedPaymentStatus,
        selectedPaymentMethod,
        currentPage,
        pageSize,
      ];
}

class ClearOrdersMessageEvent extends OrdersEvent {
  const ClearOrdersMessageEvent();
}
