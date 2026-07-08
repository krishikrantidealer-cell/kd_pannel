import 'package:equatable/equatable.dart';
import 'package:syncfusion_flutter_datepicker/datepicker.dart';

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
  final String? selectedTimeframe;
  final PickerDateRange? selectedRange;
  final bool resetRange;
  final int? currentPage;
  final int? pageSize;

  const UpdateOrdersFilterEvent({
    this.searchQuery,
    this.selectedOrderStatus,
    this.selectedPaymentStatus,
    this.selectedPaymentMethod,
    this.selectedTimeframe,
    this.selectedRange,
    this.resetRange = false,
    this.currentPage,
    this.pageSize,
  });

  @override
  List<Object?> get props => [
        searchQuery,
        selectedOrderStatus,
        selectedPaymentStatus,
        selectedPaymentMethod,
        selectedTimeframe,
        selectedRange,
        resetRange,
        currentPage,
        pageSize,
      ];
}

class ClearOrdersMessageEvent extends OrdersEvent {
  const ClearOrdersMessageEvent();
}

class ResetOrdersEvent extends OrdersEvent {
  const ResetOrdersEvent();
}
