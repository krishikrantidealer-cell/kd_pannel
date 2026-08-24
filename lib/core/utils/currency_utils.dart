import 'dart:math';

/// Utility for exact, deterministic financial currency calculations, precision rounding, and formatting.
class CurrencyUtils {
  CurrencyUtils._();

  /// Safely round any floating-point number to exact 2 decimal places.
  /// Solves standard IEEE 754 precision drift (e.g. 499.99999999999994 -> 500.00).
  static double roundToCurrency(double value) {
    if (value.isNaN || value.isInfinite) return 0.0;
    return (value * 100).roundToDouble() / 100.0;
  }

  /// Parse any dynamic value (num, string, null) to double with 2 decimal precision.
  static double parse(dynamic value, {double defaultValue = 0.0}) {
    if (value == null) return defaultValue;
    if (value is num) return roundToCurrency(value.toDouble());
    if (value is String) {
      final cleaned = value.replaceAll(RegExp(r'[^0-9.-]'), '');
      final parsed = double.tryParse(cleaned);
      return parsed != null ? roundToCurrency(parsed) : defaultValue;
    }
    return defaultValue;
  }

  /// Calculate exact discount amount given subtotal and percentage discount.
  static double calculateDiscount({
    required double subtotal,
    required double discountPercentage,
    double maxDiscount = double.infinity,
  }) {
    if (subtotal <= 0 || discountPercentage <= 0) return 0.0;
    final discount = (subtotal * discountPercentage) / 100.0;
    final capped = min(discount, maxDiscount);
    return roundToCurrency(capped);
  }

  /// Calculate tax amount (GST) given taxable amount and tax rate percentage.
  static double calculateTax({
    required double taxableAmount,
    required double taxRatePercentage,
  }) {
    if (taxableAmount <= 0 || taxRatePercentage <= 0) return 0.0;
    final tax = (taxableAmount * taxRatePercentage) / 100.0;
    return roundToCurrency(tax);
  }

  /// Format amount in Indian Rupee format (e.g. ₹1,23,456.00).
  static String formatInr(dynamic amount, {bool showSymbol = true, bool includeDecimals = true}) {
    final val = parse(amount);
    final isNegative = val < 0;
    final absVal = val.abs();

    final parts = absVal.toStringAsFixed(2).split('.');
    final integerPart = parts[0];
    final decimalPart = parts[1];

    String formattedInt = '';
    if (integerPart.length <= 3) {
      formattedInt = integerPart;
    } else {
      final lastThree = integerPart.substring(integerPart.length - 3);
      final remaining = integerPart.substring(0, integerPart.length - 3);
      
      final buffer = StringBuffer();
      for (int i = 0; i < remaining.length; i++) {
        if (i > 0 && (remaining.length - i) % 2 == 0) {
          buffer.write(',');
        }
        buffer.write(remaining[i]);
      }
      buffer.write(',');
      buffer.write(lastThree);
      formattedInt = buffer.toString();
    }

    final sign = isNegative ? '-' : '';
    final symbol = showSymbol ? '₹' : '';
    final decimals = includeDecimals ? '.$decimalPart' : (decimalPart == '00' ? '' : '.$decimalPart');

    return '$sign$symbol$formattedInt$decimals';
  }
}
