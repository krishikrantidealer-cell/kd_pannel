/// Helper utilities for formatting numbers into compact units (k, M, B, etc.)
String formatUnits(num? value) {
  if (value == null) return '0';
  final double d = value.toDouble();
  final double abs = d.abs();
  final String sign = d < 0 ? '-' : '';

  if (abs >= 1000000000) {
    final double v = abs / 1000000000;
    final String formatted = v.toStringAsFixed(v.truncateToDouble() == v || (v * 10).truncateToDouble() == v * 10 ? (v.truncateToDouble() == v ? 0 : 1) : 1);
    return '$sign${formatted}B';
  } else if (abs >= 1000000) {
    final double v = abs / 1000000;
    final String formatted = v.toStringAsFixed(v.truncateToDouble() == v || (v * 10).truncateToDouble() == v * 10 ? (v.truncateToDouble() == v ? 0 : 1) : 1);
    return '$sign${formatted}M';
  } else if (abs >= 1000) {
    final double v = abs / 1000;
    final String formatted = v.toStringAsFixed(v.truncateToDouble() == v || (v * 10).truncateToDouble() == v * 10 ? (v.truncateToDouble() == v ? 0 : 1) : 1);
    return '$sign${formatted}k';
  } else {
    return (d == d.toInt() ? '$sign${d.toInt().abs()}' : '$sign${d.abs()}');
  }
}

/// Convenience alias for formatUnits
String formatCompactNumber(num? value) => formatUnits(value);
