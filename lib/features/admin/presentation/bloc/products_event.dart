import 'package:equatable/equatable.dart';

abstract class ProductsEvent extends Equatable {
  const ProductsEvent();

  @override
  List<Object?> get props => [];
}

class LoadProductsEvent extends ProductsEvent {
  final bool forceRefresh;
  const LoadProductsEvent({this.forceRefresh = false});

  @override
  List<Object?> get props => [forceRefresh];
}

class SearchProductsEvent extends ProductsEvent {
  final String query;
  const SearchProductsEvent(this.query);

  @override
  List<Object?> get props => [query];
}

class FilterProductsByCategoryEvent extends ProductsEvent {
  final String categoryName;
  const FilterProductsByCategoryEvent(this.categoryName);

  @override
  List<Object?> get props => [categoryName];
}

class DeleteProductEvent extends ProductsEvent {
  final String productId;
  const DeleteProductEvent(this.productId);

  @override
  List<Object?> get props => [productId];
}

class ToggleProductAvailabilityEvent extends ProductsEvent {
  final String productId;
  final bool newInStock;
  const ToggleProductAvailabilityEvent(this.productId, this.newInStock);

  @override
  List<Object?> get props => [productId, newInStock];
}
