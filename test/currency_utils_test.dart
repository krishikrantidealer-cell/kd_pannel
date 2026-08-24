import 'package:flutter_test/flutter_test.dart';
import 'package:kd_pannel/core/utils/currency_utils.dart';

void main() {
  group('CurrencyUtils Tests', () {
    test('roundToCurrency rounds properly to 2 decimals', () {
      expect(CurrencyUtils.roundToCurrency(499.999999999), equals(500.00));
      expect(CurrencyUtils.roundToCurrency(123.456), equals(123.46));
      expect(CurrencyUtils.roundToCurrency(123.454), equals(123.45));
      expect(CurrencyUtils.roundToCurrency(0.0), equals(0.0));
      expect(CurrencyUtils.roundToCurrency(double.nan), equals(0.0));
    });

    test('parse extracts clean double with precision from strings or numbers', () {
      expect(CurrencyUtils.parse('₹1,250.50'), equals(1250.50));
      expect(CurrencyUtils.parse('  1000  '), equals(1000.00));
      expect(CurrencyUtils.parse(45.678), equals(45.68));
      expect(CurrencyUtils.parse(null, defaultValue: 10.0), equals(10.0));
    });

    test('calculateDiscount caps at maximum discount correctly', () {
      // 10% of 1000 is 100
      expect(
        CurrencyUtils.calculateDiscount(
          subtotal: 1000.0,
          discountPercentage: 10.0,
        ),
        equals(100.0),
      );

      // 50% of 1000 capped at 200 is 200
      expect(
        CurrencyUtils.calculateDiscount(
          subtotal: 1000.0,
          discountPercentage: 50.0,
          maxDiscount: 200.0,
        ),
        equals(200.0),
      );
    });

    test('calculateTax computes GST accurately', () {
      // 18% of 500 = 90
      expect(
        CurrencyUtils.calculateTax(
          taxableAmount: 500.0,
          taxRatePercentage: 18.0,
        ),
        equals(90.0),
      );
    });

    test('formatInr formats according to Indian numbering system', () {
      expect(CurrencyUtils.formatInr(123456.78), equals('₹1,23,456.78'));
      expect(CurrencyUtils.formatInr(500), equals('₹500.00'));
      expect(CurrencyUtils.formatInr(10000000), equals('₹1,00,00,000.00'));
      expect(CurrencyUtils.formatInr(1000, showSymbol: false), equals('1,000.00'));
    });
  });
}
