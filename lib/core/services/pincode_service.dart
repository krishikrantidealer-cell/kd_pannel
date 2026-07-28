import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

class PincodeService {
  static final PincodeService _instance = PincodeService._internal();
  factory PincodeService() => _instance;
  PincodeService._internal();

  final String _baseUrl = 'https://api.postalpincode.in/pincode/';
  final String _storageKey = 'cached_pincodes_v1';
  Map<String, dynamic> _cache = {};
  bool _isInitialized = false;

  Future<void> init() async {
    if (_isInitialized) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_storageKey);
      if (saved != null) {
        _cache = jsonDecode(saved);
      }
      _isInitialized = true;
    } catch (e) {
      debugPrint('[PincodeService] Init error: $e');
    }
  }

  /// Returns {'district': '...', 'state': '...'} or null
  Map<String, String>? lookup(String pincode) {
    if (!_isInitialized) return null;
    final cleanPin = pincode.trim();
    if (_cache.containsKey(cleanPin)) {
      return Map<String, String>.from(_cache[cleanPin]);
    }
    return null;
  }

  /// Fetches and caches location for a pincode.
  /// Returns true if successfully resolved.
  Future<bool> resolve(String pincode) async {
    final cleanPin = pincode.trim();
    if (cleanPin.length != 6) return false;
    
    // Check cache again to avoid parallel inflight requests if needed
    if (_cache.containsKey(cleanPin)) return true;

    try {
      final response = await http.get(Uri.parse('$_baseUrl$cleanPin'));
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        if (data.isNotEmpty && data[0]['Status'] == 'Success') {
          final postOffices = data[0]['PostOffice'] as List;
          if (postOffices.isNotEmpty) {
            final entry = {
              'district': postOffices[0]['District'].toString(),
              'state': postOffices[0]['State'].toString(),
            };
            _cache[cleanPin] = entry;
            await _saveToDisk();
            return true;
          }
        }
      }
    } catch (e) {
      debugPrint('[PincodeService] API error for $cleanPin: $e');
    }
    return false;
  }

  Future<void> _saveToDisk() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_storageKey, jsonEncode(_cache));
    } catch (e) {
      debugPrint('[PincodeService] Save error: $e');
    }
  }
}
