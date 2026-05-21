import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class LocalCacheHelper {
  static const String _keyProducts = 'kd_cached_products';
  static const String _keyCollections = 'kd_cached_collections';
  static const String _keyCategories = 'kd_cached_categories';

  static Future<void> saveCachedProducts(List<Map<String, dynamic>> products) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyProducts, jsonEncode(products));
    } catch (e) {
      print('Error caching products locally: $e');
    }
  }

  static Future<List<Map<String, dynamic>>?> getCachedProducts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final dataStr = prefs.getString(_keyProducts);
      if (dataStr != null) {
        final List decoded = jsonDecode(dataStr);
        return decoded.map((item) => Map<String, dynamic>.from(item)).toList();
      }
    } catch (e) {
      print('Error reading cached products: $e');
    }
    return null;
  }

  static Future<void> saveCachedCollections(List<Map<String, dynamic>> collections) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyCollections, jsonEncode(collections));
    } catch (e) {
      print('Error caching collections locally: $e');
    }
  }

  static Future<List<Map<String, dynamic>>?> getCachedCollections() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final dataStr = prefs.getString(_keyCollections);
      if (dataStr != null) {
        final List decoded = jsonDecode(dataStr);
        return decoded.map((item) => Map<String, dynamic>.from(item)).toList();
      }
    } catch (e) {
      print('Error reading cached collections: $e');
    }
    return null;
  }

  static Future<void> saveCachedCategories(List<dynamic> categories) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyCategories, jsonEncode(categories));
    } catch (e) {
      print('Error caching categories locally: $e');
    }
  }

  static Future<List<dynamic>?> getCachedCategories() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final dataStr = prefs.getString(_keyCategories);
      if (dataStr != null) {
        return jsonDecode(dataStr) as List;
      }
    } catch (e) {
      print('Error reading cached categories: $e');
    }
    return null;
  }

  static Future<void> clearAllCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyProducts);
      await prefs.remove(_keyCollections);
      await prefs.remove(_keyCategories);
    } catch (e) {
      print('Error clearing local cache: $e');
    }
  }
}
