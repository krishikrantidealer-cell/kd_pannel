import 'dart:convert';
import 'package:kd_pannel/core/network/api_client.dart';

class AttributionRepository {
  Future<Map<String, dynamic>> fetchReport({
    required String startDate,
    required String endDate,
    required String channel,
    required bool liveOnly,
  }) async {
    final res = await ApiClient().get(
      '/attribution/report?startDate=$startDate&endDate=$endDate&channel=$channel&liveOnly=$liveOnly',
    );
    if (res.statusCode != 200) {
      throw Exception('Failed to load attribution report (${res.statusCode})');
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    if (data['success'] != true) {
      throw Exception(data['message'] ?? 'Attribution report request failed');
    }
    return data;
  }

  Future<Map<String, dynamic>> syncMetaSpend({
    required String startDate,
    required String endDate,
  }) async {
    final res = await ApiClient().post('/attribution/sync-spend', {
      'startDate': startDate,
      'endDate': endDate,
    });
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode >= 400 && data['skipped'] != true) {
      throw Exception(data['message'] ?? 'Meta spend sync failed');
    }
    return data;
  }
}
