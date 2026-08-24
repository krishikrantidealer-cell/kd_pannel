import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:kd_pannel/core/network/api_client.dart';
import 'package:kd_pannel/core/models/product_model.dart';
import 'package:kd_pannel/core/models/category_model.dart';

/// Repository for handling Product, Category, and Collection domain data.
class ProductRepository {
  static final ProductRepository _instance = ProductRepository._internal();
  factory ProductRepository() => _instance;
  ProductRepository._internal();

  final ApiClient _apiClient = ApiClient();

  List<Map<String, dynamic>>? _cachedProducts;
  List<ProductModel>? _cachedProductModels;
  List<Map<String, dynamic>>? _cachedCollections;
  List<CollectionModel>? _cachedCollectionModels;
  List<dynamic>? _cachedCategories;
  List<CategoryModel>? _cachedCategoryModels;
  DateTime? _productsCacheTime;
  DateTime? _categoriesCacheTime;
  DateTime? _collectionsCacheTime;

  static const Duration _cacheTtl = Duration(minutes: 5);

  bool _isCacheValid(DateTime? cacheTime) {
    if (cacheTime == null) return false;
    return DateTime.now().difference(cacheTime) < _cacheTtl;
  }

  void invalidateCache() {
    _cachedProducts = null;
    _cachedProductModels = null;
    _cachedCollections = null;
    _cachedCollectionModels = null;
    _cachedCategories = null;
    _cachedCategoryModels = null;
    _productsCacheTime = null;
    _categoriesCacheTime = null;
    _collectionsCacheTime = null;
    _apiClient.clearCache();
  }

  /// Get typed ProductModels.
  Future<List<ProductModel>> getProductModels({
    bool forceRefresh = false,
    String? search,
    String? category,
  }) async {
    if (!forceRefresh && _cachedProductModels != null && _isCacheValid(_productsCacheTime) && search == null && category == null) {
      return _cachedProductModels!;
    }
    final rawList = await getProducts(forceRefresh: forceRefresh, search: search, category: category);
    final models = rawList.map((p) => ProductModel.fromJson(p)).toList();
    if (search == null && category == null) {
      _cachedProductModels = models;
    }
    return models;
  }

  /// Get raw Products with optional search and category filters.
  Future<List<Map<String, dynamic>>> getProducts({
    bool forceRefresh = false,
    String? search,
    String? category,
  }) async {
    if (!forceRefresh && _cachedProducts != null && _isCacheValid(_productsCacheTime) && search == null && category == null) {
      return _cachedProducts!;
    }

    try {
      final response = await _apiClient.get('/products');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List list = data is List
            ? data
            : (data['products'] ?? data['data'] ?? []);
        final parsed = list
            .map((p) => Map<String, dynamic>.from(p as Map))
            .toList();

        if (search == null && category == null) {
          _cachedProducts = parsed;
          _productsCacheTime = DateTime.now();
        }

        List<Map<String, dynamic>> filtered = parsed;
        if (category != null && category != 'All' && category.isNotEmpty) {
          filtered = filtered.where((p) {
            final cats = p['categories'] as List? ?? [];
            return cats.any((c) => c.toString().toLowerCase() == category.toLowerCase());
          }).toList();
        }

        if (search != null && search.trim().isNotEmpty) {
          final q = search.trim().toLowerCase();
          filtered = filtered.where((p) {
            final title = (p['title'] ?? p['name'] ?? '').toString().toLowerCase();
            final vendor = (p['vendor'] ?? '').toString().toLowerCase();
            return title.contains(q) || vendor.contains(q);
          }).toList();
        }

        return filtered;
      }
    } catch (e) {
      debugPrint('[ProductRepository] getProducts error: $e');
    }

    return _cachedProducts ?? [];
  }

  /// Get typed CategoryModels.
  Future<List<CategoryModel>> getCategoryModels({bool forceRefresh = false}) async {
    if (!forceRefresh && _cachedCategoryModels != null && _isCacheValid(_categoriesCacheTime)) {
      return _cachedCategoryModels!;
    }
    final raw = await getCategories(forceRefresh: forceRefresh);
    final models = raw.map((c) => CategoryModel.fromJson(c)).toList();
    _cachedCategoryModels = models;
    return models;
  }

  /// Get raw Categories tree.
  Future<List<dynamic>> getCategories({bool forceRefresh = false}) async {
    if (!forceRefresh && _cachedCategories != null && _isCacheValid(_categoriesCacheTime)) {
      return _cachedCategories!;
    }

    try {
      final response = await _apiClient.get('/categories');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List list = data is List
            ? data
            : (data['categories'] ?? data['data'] ?? []);
        _cachedCategories = list;
        _categoriesCacheTime = DateTime.now();
        return _cachedCategories!;
      }
    } catch (e) {
      debugPrint('[ProductRepository] getCategories error: $e');
    }

    return _cachedCategories ?? [];
  }

  /// Get typed CollectionModels.
  Future<List<CollectionModel>> getCollectionModels({bool forceRefresh = false}) async {
    if (!forceRefresh && _cachedCollectionModels != null && _isCacheValid(_collectionsCacheTime)) {
      return _cachedCollectionModels!;
    }
    final raw = await getCollections(forceRefresh: forceRefresh);
    final models = raw.map((c) => CollectionModel.fromJson(c)).toList();
    _cachedCollectionModels = models;
    return models;
  }

  /// Get Marketing Collections.
  Future<List<Map<String, dynamic>>> getCollections({bool forceRefresh = false}) async {
    if (!forceRefresh && _cachedCollections != null && _isCacheValid(_collectionsCacheTime)) {
      return _cachedCollections!;
    }

    try {
      final response = await _apiClient.get('/collections');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List list = data is List
            ? data
            : (data['collections'] ?? data['data'] ?? []);
        _cachedCollections = list
            .map((c) => Map<String, dynamic>.from(c as Map))
            .toList();
        _collectionsCacheTime = DateTime.now();
        return _cachedCollections!;
      }
    } catch (e) {
      debugPrint('[ProductRepository] getCollections error: $e');
    }

    return _cachedCollections ?? [];
  }

  /// Delete a product by ID.
  Future<bool> deleteProduct(String id) async {
    try {
      final response = await _apiClient.delete('/products/$id');
      if (response.statusCode == 200 || response.statusCode == 204) {
        invalidateCache();
        return true;
      }
    } catch (e) {
      debugPrint('[ProductRepository] deleteProduct error: $e');
    }
    return false;
  }
}
