// ---------------------------------------------------------------------------
// Order Data Models & Pricing Engine
// ---------------------------------------------------------------------------

class ParsedTier {
  final String id;
  final String name;
  final double? min;
  final double? max;
  final double rate;

  ParsedTier({
    required this.id,
    required this.name,
    this.min,
    this.max,
    required this.rate,
  });
}

Map<String, double?> parseTierRange(String name) {
  final regexParentheses = RegExp(r'\(([^)]+)\)');
  final match = regexParentheses.firstMatch(name);
  String content = '';
  if (match != null) {
    content = match.group(1)!;
  } else {
    content = name;
  }

  final clean = content.replaceAll(RegExp(r'[^0-9.\-+]'), '');

  if (clean.endsWith('+')) {
    final minStr = clean.substring(0, clean.length - 1);
    final min = double.tryParse(minStr);
    return {'min': min, 'max': null};
  } else if (clean.contains('-')) {
    final parts = clean.split('-');
    if (parts.length == 2) {
      final min = double.tryParse(parts[0]);
      final max = double.tryParse(parts[1]);
      return {'min': min, 'max': max};
    }
  }

  final numbers = RegExp(
    r'\d+(?:\.\d+)?',
  ).allMatches(clean).map((m) => double.tryParse(m.group(0) ?? '')).toList();
  if (numbers.isNotEmpty) {
    if (clean.contains('+') || numbers.length == 1) {
      return {'min': numbers.first, 'max': null};
    } else if (numbers.length >= 2) {
      return {'min': numbers[0], 'max': numbers[1]};
    }
  }

  return {'min': null, 'max': null};
}

double? parseRateValue(String? rateStr) {
  if (rateStr == null || rateStr.isEmpty) return null;
  final clean = rateStr.split('/').first.replaceAll(RegExp(r'[^0-9.]'), '');
  return double.tryParse(clean);
}

double getVariantPrice(
  Map<String, dynamic> variant,
  int quantity, {
  double? customPackVolume,
}) {
  final double packVolume =
      customPackVolume ?? ((variant['packVolume'] ?? 1) as num).toDouble();
  final double defaultPriceVal =
      ((variant['dealerPrice'] ?? variant['price'] ?? 0) as num).toDouble();
  final double fallbackPrice = variant['dealerPrice'] != null
      ? defaultPriceVal
      : defaultPriceVal * packVolume;

  final priceTiers = variant['priceTiers'] as List?;
  final rates = variant['rates'] as Map?;

  if (priceTiers == null ||
      priceTiers.isEmpty ||
      rates == null ||
      rates.isEmpty) {
    return fallbackPrice;
  }

  final double totalVolume = packVolume * quantity;

  final List<ParsedTier> parsedTiers = [];
  for (var tier in priceTiers) {
    if (tier is! Map) continue;
    final tierMap = Map<String, dynamic>.from(tier);
    final tierId = tierMap['id']?.toString() ?? '';
    final tierName = tierMap['name']?.toString() ?? '';

    final range = parseTierRange(tierName);

    final parsedInt = int.tryParse(tierId);
    final dynamic rawRate =
        rates[tierId] ?? (parsedInt != null ? rates[parsedInt] : null);
    final rateStr = rawRate?.toString();
    final rateVal = parseRateValue(rateStr);

    if (rateVal != null) {
      parsedTiers.add(
        ParsedTier(
          id: tierId,
          name: tierName,
          min: range['min'],
          max: range['max'],
          rate: rateVal,
        ),
      );
    }
  }

  if (parsedTiers.isEmpty) {
    return fallbackPrice;
  }

  // Sort by min descending (highest volume requirement first) to match backend logic
  parsedTiers.sort((a, b) {
    final aMin = a.min ?? 0.0;
    final bMin = b.min ?? 0.0;
    return bMin.compareTo(aMin);
  });

  for (var tier in parsedTiers) {
    final min = tier.min;
    if (min != null && totalVolume >= min) {
      return tier.rate * packVolume;
    }
  }

  return fallbackPrice;
}

class CartItem {
  final Map<String, dynamic> product;
  final Map<String, dynamic> variant;
  int quantity;
  double? priceOverride;
  double? customPackVolume;
  String? customBasePackingUnit;

  CartItem({
    required this.product,
    required this.variant,
    this.quantity = 1,
    this.priceOverride,
    this.customPackVolume,
    this.customBasePackingUnit,
  });

  double get effectivePackVolume =>
      customPackVolume ?? ((variant['packVolume'] ?? 1) as num).toDouble();

  String get effectiveBaseUnit {
    if (customBasePackingUnit != null && customBasePackingUnit!.isNotEmpty) {
      return customBasePackingUnit!;
    }
    return (variant['basePackingUnit'] ?? '').toString().trim();
  }

  bool get isCustomBasePack => customPackVolume != null;
  bool get isCustomPrice => priceOverride != null;

  double get lineTotal => price * quantity;

  double get price {
    if (priceOverride != null) {
      return priceOverride!;
    }
    return getVariantPrice(variant, quantity, customPackVolume: customPackVolume);
  }
}
