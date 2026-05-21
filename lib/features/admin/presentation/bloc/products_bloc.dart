import 'dart:convert';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'products_event.dart';
import 'products_state.dart';
import 'package:kd_pannel/core/network/api_client.dart';
import 'package:kd_pannel/core/utils/local_cache_helper.dart';

class ProductsBloc extends Bloc<ProductsEvent, ProductsState> {
  ProductsBloc() : super(const ProductsState()) {
    on<LoadProductsEvent>(_onLoadProducts);
    on<SearchProductsEvent>(_onSearchProducts);
    on<FilterProductsByCategoryEvent>(_onFilterProductsByCategory);
    on<DeleteProductEvent>(_onDeleteProduct);
  }

  List<Map<String, dynamic>> _applyFilter({
    required List<Map<String, dynamic>> products,
    required String query,
    required String category,
  }) {
    return products.where((prod) {
      final name = prod['name']?.toString() ?? '';
      final vendor = prod['vendor']?.toString() ?? '';
      final variants = prod['variants'] as List? ?? [];

      final matchesSearch = name.toLowerCase().contains(query.toLowerCase()) ||
          vendor.toLowerCase().contains(query.toLowerCase()) ||
          variants.any((v) =>
              (v['packSize']?.toString() ?? '')
                  .toLowerCase()
                  .contains(query.toLowerCase()));

      final matchesCategory = category.isEmpty ||
          category.toLowerCase() == 'all' ||
          (prod['category']?.toString().toLowerCase().trim() ==
              category.toLowerCase().trim());

      return matchesSearch && matchesCategory;
    }).toList();
  }

  Future<void> _onLoadProducts(
    LoadProductsEvent event,
    Emitter<ProductsState> emit,
  ) async {
    final client = ApiClient();

    // 1. Check memory cache first for instant UI response (unless force refresh)
    if (!event.forceRefresh &&
        client.cachedProducts != null &&
        client.cachedCollections != null &&
        client.cachedCategories != null) {
      final products = client.cachedProducts!;
      emit(state.copyWith(
        status: ProductsStatus.success,
        allProducts: products,
        filteredProducts: _applyFilter(
          products: products,
          query: state.searchQuery,
          category: state.selectedCategory,
        ),
        collections: client.cachedCollections!,
        categories: client.cachedCategories!,
      ));
      return;
    }

    emit(state.copyWith(status: ProductsStatus.loading));

    // 2. Try loading from local storage cache first to show cached data instantly
    if (!event.forceRefresh) {
      final localProducts = await LocalCacheHelper.getCachedProducts();
      final localCollections = await LocalCacheHelper.getCachedCollections();
      final localCategories = await LocalCacheHelper.getCachedCategories();

      if (localProducts != null || localCollections != null || localCategories != null) {
        final products = localProducts ?? [];
        emit(state.copyWith(
          status: ProductsStatus.success,
          allProducts: products,
          filteredProducts: _applyFilter(
            products: products,
            query: state.searchQuery,
            category: state.selectedCategory,
          ),
          collections: localCollections ?? [],
          categories: localCategories ?? [],
        ));
      }
    }

    // 3. Fetch fresh data from backend
    try {
      final results = await Future.wait([
        client.get('/products?limit=1000'),
        client.get('/collections?all=true'),
        client.get('/products/categories'),
      ]);

      final productsRes = results[0];
      final collectionsRes = results[1];
      final categoriesRes = results[2];

      List<Map<String, dynamic>> freshProducts = state.allProducts;
      List<Map<String, dynamic>> freshCollections = state.collections;
      List<dynamic> freshCategories = state.categories;

      // Parse categories
      if (categoriesRes.statusCode == 200) {
        final data = jsonDecode(categoriesRes.body);
        if (data['success'] == true && data['categories'] is List) {
          freshCategories = data['categories'] as List<dynamic>;
          client.cachedCategories = freshCategories;
          LocalCacheHelper.saveCachedCategories(freshCategories);
        }
      }

      // Parse products
      if (productsRes.statusCode == 200) {
        final data = jsonDecode(productsRes.body);
        if (data['success'] == true && data['products'] is List) {
          final List rawProducts = data['products'];
          final List<Map<String, dynamic>> preparedProducts = [];
          for (var p in rawProducts) {
            final String minPriceStr = p['minPrice'] != null ? '₹${p['minPrice']}' : '₹0';
            final String maxPriceStr = p['maxPrice'] != null ? '₹${p['maxPrice']}' : '₹0';
            final String priceRange = p['minPrice'] == p['maxPrice'] ? minPriceStr : '$minPriceStr - $maxPriceStr';
            final bool inStock = p['availabilityStatus'] != 'Out of Stock';

            // Category name
            String categoryName = 'N/A';
            if (p['categoryId'] != null && p['categoryId'] is Map) {
              categoryName = p['categoryId']['name'] ?? 'N/A';
            }

            // Subcategory name
            String subCategoryName = 'N/A';
            if (p['subCategoryId'] != null &&
                p['categoryId'] != null &&
                p['categoryId'] is Map &&
                p['categoryId']['subCategories'] is List) {
              final List subs = p['categoryId']['subCategories'];
              final matchingSub = subs.firstWhere(
                (s) => s['_id'] == p['subCategoryId'],
                orElse: () => null,
              );
              if (matchingSub != null) {
                subCategoryName = matchingSub['name'] ?? 'N/A';
              }
            }

            preparedProducts.add({
              'id': p['_id'],
              'sku': p['_id']
                  .toString()
                  .substring(
                    p['_id'].toString().length >= 6 ? p['_id'].toString().length - 6 : 0,
                  )
                  .toUpperCase(),
              'name': p['title'] ?? '',
              'category': categoryName,
              'subCategory': subCategoryName,
              'vendor': p['brandName'] ?? p['vendor'] ?? 'N/A',
              'price': priceRange,
              'inStock': inStock,
              'variants': p['variants'] ?? [],
              'images': p['images'] ?? [],
              'thumbnail': p['thumbnail'],
              'thumbnailBytes': null,
              'assignedCollections': p['assignedCollections'] ?? [],
              'description': p['description'] ?? '',
              'specifications': p['specifications'] ?? {},
              'tags': p['tags'] ?? [],
              'mediumImages': p['mediumImages'] ?? [],
              'originalImages': p['originalImages'] ?? [],
              'isFeatured': p['isFeatured'] ?? false,
            });
          }
          freshProducts = preparedProducts;
          client.cachedProducts = freshProducts;
          LocalCacheHelper.saveCachedProducts(freshProducts);
        }
      }

      // Parse collections
      if (collectionsRes.statusCode == 200) {
        final data = jsonDecode(collectionsRes.body);
        if (data['success'] == true && data['collections'] is List) {
          final List rawCollections = data['collections'];
          final List<Map<String, dynamic>> preparedCollections = [];
          for (var c in rawCollections) {
            final String parentId = c['_id'] ?? c['id'] ?? '';
            final List subList = c['subCollections'] as List? ?? [];
            preparedCollections.add({
              'id': parentId,
              'name': c['name'] ?? '',
              'slug': c['slug'] ?? '',
              'isActive': c['isActive'] ?? true,
              'subCollections': subList
                  .map(
                    (sub) => {
                      'id': sub['_id'] ?? sub['id'] ?? '',
                      'parentId': parentId,
                      'name': sub['name'] ?? '',
                      'slug': sub['slug'] ?? '',
                      'isActive': sub['isActive'] ?? true,
                    },
                  )
                  .toList(),
            });
          }
          freshCollections = preparedCollections;
          client.cachedCollections = freshCollections;
          LocalCacheHelper.saveCachedCollections(freshCollections);
        }
      }

      emit(state.copyWith(
        status: ProductsStatus.success,
        allProducts: freshProducts,
        filteredProducts: _applyFilter(
          products: freshProducts,
          query: state.searchQuery,
          category: state.selectedCategory,
        ),
        collections: freshCollections,
        categories: freshCategories,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: ProductsStatus.failure,
        errorMessage: e.toString(),
      ));
    }
  }

  void _onSearchProducts(
    SearchProductsEvent event,
    Emitter<ProductsState> emit,
  ) {
    emit(state.copyWith(
      searchQuery: event.query,
      filteredProducts: _applyFilter(
        products: state.allProducts,
        query: event.query,
        category: state.selectedCategory,
      ),
    ));
  }

  void _onFilterProductsByCategory(
    FilterProductsByCategoryEvent event,
    Emitter<ProductsState> emit,
  ) {
    emit(state.copyWith(
      selectedCategory: event.categoryName,
      filteredProducts: _applyFilter(
        products: state.allProducts,
        query: state.searchQuery,
        category: event.categoryName,
      ),
    ));
  }

  Future<void> _onDeleteProduct(
    DeleteProductEvent event,
    Emitter<ProductsState> emit,
  ) async {
    try {
      final response = await ApiClient().delete('/products/${event.productId}');
      if (response.statusCode == 200) {
        final updatedProducts = state.allProducts
            .where((p) => (p['id'] ?? p['_id'] ?? '').toString() != event.productId)
            .toList();

        // Update caches
        ApiClient().cachedProducts = updatedProducts;
        LocalCacheHelper.saveCachedProducts(updatedProducts);

        emit(state.copyWith(
          allProducts: updatedProducts,
          filteredProducts: _applyFilter(
            products: updatedProducts,
            query: state.searchQuery,
            category: state.selectedCategory,
          ),
        ));
      } else {
        emit(state.copyWith(
          errorMessage: 'Failed to delete product (Status ${response.statusCode})',
        ));
      }
    } catch (e) {
      emit(state.copyWith(errorMessage: e.toString()));
    }
  }
}
