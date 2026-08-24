import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:kd_pannel/core/network/api_client.dart';

void main() {
  group('ApiClient Error Normalization Tests', () {
    test('normalizes JSON response errors', () {
      final response = http.Response('{"success": false, "message": "Invalid credentials"}', 401);
      final error = ApiClient.normalizeError(response);
      expect(error, equals('Invalid credentials'));
    });

    test('normalizes HTML error pages during cold start/gateway timeout', () {
      final response = http.Response('<!DOCTYPE html><html><body>502 Bad Gateway</body></html>', 502);
      final error = ApiClient.normalizeError(response);
      expect(error, contains('Server error (502)'));
    });

    test('normalizes Dart exceptions cleanly without prefix', () {
      final exception = Exception('Dealer not found');
      final error = ApiClient.normalizeError(exception);
      expect(error, equals('Dealer not found'));
    });

    test('handles null with fallback message', () {
      final error = ApiClient.normalizeError(null, fallback: 'Default fallback');
      expect(error, equals('Default fallback'));
    });
  });
}
