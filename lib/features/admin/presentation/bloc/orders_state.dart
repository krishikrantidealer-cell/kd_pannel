import 'package:equatable/equatable.dart';
import 'package:syncfusion_flutter_datepicker/datepicker.dart';
import '../../data/models/order_model.dart';

enum OrdersStatus { initial, loading, success, failure }

class OrdersState extends Equatable {
  final OrdersStatus status;
  final List<OrderModel> orders;
  
  // Filtering and pagination states
  final String searchQuery;
  final String selectedOrderStatus;
  final String selectedPaymentStatus;
  final String selectedPaymentMethod;
  final String selectedOrderSource;
  final String selectedTimeframe;
  final PickerDateRange? selectedRange;
  final int currentPage;
  final int pageSize;
  
  // Error handling
  final String? errorMessage;

  const OrdersState({
    this.status = OrdersStatus.initial,
    this.orders = const [],
    this.searchQuery = '',
    this.selectedOrderStatus = 'All Statuses',
    this.selectedPaymentStatus = 'All Payments',
    this.selectedPaymentMethod = 'All Methods',
    this.selectedOrderSource = 'All Sources',
    this.selectedTimeframe = 'All Time',
    this.selectedRange,
    this.currentPage = 1,
    this.pageSize = 10,
    this.errorMessage,
  });

  OrdersState copyWith({
    OrdersStatus? status,
    List<OrderModel>? orders,
    String? searchQuery,
    String? selectedOrderStatus,
    String? selectedPaymentStatus,
    String? selectedPaymentMethod,
    String? selectedOrderSource,
    String? selectedTimeframe,
    PickerDateRange? selectedRange,
    int? currentPage,
    int? pageSize,
    String? errorMessage,
  }) {
    return OrdersState(
      status: status ?? this.status,
      orders: orders ?? this.orders,
      searchQuery: searchQuery ?? this.searchQuery,
      selectedOrderStatus: selectedOrderStatus ?? this.selectedOrderStatus,
      selectedPaymentStatus: selectedPaymentStatus ?? this.selectedPaymentStatus,
      selectedPaymentMethod: selectedPaymentMethod ?? this.selectedPaymentMethod,
      selectedOrderSource: selectedOrderSource ?? this.selectedOrderSource,
      selectedTimeframe: selectedTimeframe ?? this.selectedTimeframe,
      selectedRange: selectedRange ?? this.selectedRange,
      currentPage: currentPage ?? this.currentPage,
      pageSize: pageSize ?? this.pageSize,
      errorMessage: errorMessage, // Reset if not explicitly set
    );
  }

  OrdersState copyWithResetRange({
    OrdersStatus? status,
    List<OrderModel>? orders,
    String? searchQuery,
    String? selectedOrderStatus,
    String? selectedPaymentStatus,
    String? selectedPaymentMethod,
    String? selectedOrderSource,
    String? selectedTimeframe,
    int? currentPage,
    int? pageSize,
    String? errorMessage,
  }) {
    return OrdersState(
      status: status ?? this.status,
      orders: orders ?? this.orders,
      searchQuery: searchQuery ?? this.searchQuery,
      selectedOrderStatus: selectedOrderStatus ?? this.selectedOrderStatus,
      selectedPaymentStatus: selectedPaymentStatus ?? this.selectedPaymentStatus,
      selectedPaymentMethod: selectedPaymentMethod ?? this.selectedPaymentMethod,
      selectedOrderSource: selectedOrderSource ?? this.selectedOrderSource,
      selectedTimeframe: selectedTimeframe ?? this.selectedTimeframe,
      selectedRange: null,
      currentPage: currentPage ?? this.currentPage,
      pageSize: pageSize ?? this.pageSize,
      errorMessage: errorMessage,
    );
  }

  // Helper method to keep previous error message if needed
  OrdersState copyWithKeepError({
    OrdersStatus? status,
    List<OrderModel>? orders,
    String? searchQuery,
    String? selectedOrderStatus,
    String? selectedPaymentStatus,
    String? selectedPaymentMethod,
    String? selectedOrderSource,
    int? currentPage,
    int? pageSize,
    String? errorMessage,
  }) {
    return OrdersState(
      status: status ?? this.status,
      orders: orders ?? this.orders,
      searchQuery: searchQuery ?? this.searchQuery,
      selectedOrderStatus: selectedOrderStatus ?? this.selectedOrderStatus,
      selectedPaymentStatus: selectedPaymentStatus ?? this.selectedPaymentStatus,
      selectedPaymentMethod: selectedPaymentMethod ?? this.selectedPaymentMethod,
      selectedOrderSource: selectedOrderSource ?? this.selectedOrderSource,
      currentPage: currentPage ?? this.currentPage,
      pageSize: pageSize ?? this.pageSize,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [
        status,
        orders,
        searchQuery,
        selectedOrderStatus,
        selectedPaymentStatus,
        selectedPaymentMethod,
        selectedOrderSource,
        selectedTimeframe,
        selectedRange,
        currentPage,
        pageSize,
        errorMessage,
      ];
}
