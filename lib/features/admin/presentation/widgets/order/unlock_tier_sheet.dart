import 'package:flutter/material.dart';

class UnlockTierBottomSheet extends StatelessWidget {
  final String tierLabel;
  final double currentUnitPrice;
  final double tierPrice;
  final double packVolume;
  final String baseUnit;
  final int currentQty;
  final int requiredQty;
  final double savings;
  final VoidCallback onUpgrade;

  const UnlockTierBottomSheet({
    super.key,
    required this.tierLabel,
    required this.currentUnitPrice,
    required this.tierPrice,
    required this.packVolume,
    required this.baseUnit,
    required this.currentQty,
    required this.requiredQty,
    required this.savings,
    required this.onUpgrade,
  });

  static void show({
    required BuildContext context,
    required String tierLabel,
    required double currentUnitPrice,
    required double tierPrice,
    required double packVolume,
    required String baseUnit,
    required int currentQty,
    required int requiredQty,
    required double savings,
    required VoidCallback onUpgrade,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => UnlockTierBottomSheet(
        tierLabel: tierLabel,
        currentUnitPrice: currentUnitPrice,
        tierPrice: tierPrice,
        packVolume: packVolume,
        baseUnit: baseUnit,
        currentQty: currentQty,
        requiredQty: requiredQty,
        savings: savings,
        onUpgrade: onUpgrade,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final int diffQty = requiredQty - currentQty;
    final double currentVol = packVolume * currentQty;
    final double targetVol = packVolume * requiredQty;
    final String unitLabel = baseUnit.toLowerCase() == 'pcs'
        ? 'pcs'
        : baseUnit.toLowerCase() == 'kg'
        ? 'kg'
        : 'lit.';

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(
        24,
        16,
        24,
        24 + MediaQuery.of(context).padding.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF298E4D).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.lock_open_rounded,
                  color: Color(0xFF298E4D),
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Unlock $tierLabel Pricing!',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Get wholesale rates on bulk volume',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Price comparison card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFE8F5E9), Colors.white],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: const Color(0xFF298E4D).withValues(alpha: 0.15),
              ),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Current Price',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '₹${(currentUnitPrice / packVolume).toStringAsFixed(0)} / $unitLabel',
                          style: TextStyle(
                            fontSize: 15,
                            color: Colors.grey.shade700,
                            decoration: TextDecoration.lineThrough,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const Icon(
                      Icons.arrow_forward_rounded,
                      color: Color(0xFF298E4D),
                      size: 20,
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF298E4D),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'WHOLESALE RATE',
                            style: TextStyle(
                              fontSize: 8,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '₹${tierPrice.toStringAsFixed(0)} / $unitLabel',
                          style: const TextStyle(
                            fontSize: 20,
                            color: Color(0xFF298E4D),
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                if (savings > 0) ...[
                  const Divider(height: 24, thickness: 1),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.stars_rounded,
                        color: Colors.orange.shade700,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Total Bulk Savings: ₹${savings.toStringAsFixed(0)}!',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.orange.shade700,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Required Volume Progression',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 10),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LayoutBuilder(
              builder: (_, constraints) {
                final double fillPercent = targetVol > 0
                    ? (currentVol / targetVol).clamp(0.0, 1.0)
                    : 0.0;
                return Stack(
                  children: [
                    Container(
                      height: 8,
                      width: constraints.maxWidth,
                      color: Colors.grey.shade100,
                    ),
                    Container(
                      height: 8,
                      width: constraints.maxWidth * fillPercent,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF81C784), Color(0xFF298E4D)],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Current: ${currentVol % 1 == 0 ? currentVol.toInt() : currentVol.toStringAsFixed(1)} $unitLabel ($currentQty packs)',
                style: TextStyle(
                  fontSize: 10.5,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                'Target: ${threshold % 1 == 0 ? threshold.toInt() : threshold.toStringAsFixed(1)} $unitLabel ($requiredQty packs)',
                style: const TextStyle(
                  fontSize: 10.5,
                  color: Color(0xFF298E4D),
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Info box
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange.shade200, width: 0.5),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  color: Colors.orange.shade800,
                  size: 16,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    diffQty > 0
                        ? 'Adding $diffQty more pack${diffQty == 1 ? '' : 's'} unlocks ₹${(tierPrice - currentUnitPrice / packVolume).abs().toStringAsFixed(0)} discount per $unitLabel on ALL units!'
                        : 'You already have enough packs to unlock this tier!',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.orange.shade900,
                      fontWeight: FontWeight.bold,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: BorderSide(color: Colors.grey.shade300, width: 1.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    'KEEP CURRENT',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
              if (diffQty > 0) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      onUpgrade();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF298E4D),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      elevation: 3,
                      shadowColor: const Color(
                        0xFF298E4D,
                      ).withValues(alpha: 0.3),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(
                      'ADD $diffQty & SAVE',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  double get threshold => packVolume * requiredQty;
}
