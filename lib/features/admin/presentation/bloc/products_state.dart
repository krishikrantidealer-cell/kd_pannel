import 'package:equatable/equatable.dart';

enum ProductsStatus { initial, loading, success, failure }

class ProductsState extends Equatable {
  final ProductsStatus status;
  final List<Map<String, dynamic>> allProducts;
  final List<Map<String, dynamic>> filteredProducts;
  final List<Map<String, dynamic>> collections;
  final List<dynamic> categories;
  final String searchQuery;
  final String selectedCategory;
  final String? errorMessage;

  const ProductsState({
    this.status = ProductsStatus.initial,
    this.allProducts = const [],
    this.filteredProducts = const [],
    this.collections = const [],
    this.categories = const [],
    this.searchQuery = '',
    this.selectedCategory = '',
    this.errorMessage,
  });

  ProductsState copyWith({
    ProductsStatus? status,
    List<Map<String, dynamic>>? allProducts,
    List<Map<String, dynamic>>? filteredProducts,
    List<Map<String, dynamic>>? collections,
    List<dynamic>? categories,
    String? searchQuery,
    String? selectedCategory,
    String? errorMessage,
  }) {
    return ProductsState(
      status: status ?? this.status,
      allProducts: allProducts ?? this.allProducts,
      filteredProducts: filteredProducts ?? this.filteredProducts,
      collections: collections ?? this.collections,
      categories: categories ?? this.categories,
      searchQuery: searchQuery ?? this.searchQuery,
      selectedCategory: selectedCategory ?? this.selectedCategory,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [
        status,
        allProducts,
        filteredProducts,
        collections,
        categories,
        searchQuery,
        selectedCategory,
        errorMessage,
      ];
}
