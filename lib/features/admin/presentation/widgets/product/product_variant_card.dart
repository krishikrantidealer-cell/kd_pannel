import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kd_pannel/app_theme.dart';
import 'package:kd_pannel/features/admin/presentation/widgets/product/product_form_helpers.dart';

class ProductVariantCard extends StatelessWidget {
  final int index;
  final Map<String, dynamic> variant;
  final bool isMobile;
  final int totalVariants;
  final VoidCallback onManageTiers;
  final VoidCallback onRemove;
  final VoidCallback onStateChanged;

  const ProductVariantCard({
    super.key,
    required this.index,
    required this.variant,
    required this.isMobile,
    required this.totalVariants,
    required this.onManageTiers,
    required this.onRemove,
    required this.onStateChanged,
  });

  @override
  Widget build(BuildContext context) {
    // All units are available for base packing regardless of pack size unit
    const List<String> basePackingUnits = ['lit', 'ml', 'kg', 'gm', 'pcs'];

    // Ensure basePackingUnit is set to a valid value
    if (!basePackingUnits.contains(variant['basePackingUnit'])) {
      variant['basePackingUnit'] = 'lit';
    }

    final String packSizeHint = switch (variant['packSizeUnit']) {
      'ml' => 'e.g. 250',
      'lit' => 'e.g. 1',
      'gm' => 'e.g. 500',
      'kg' => 'e.g. 1',
      'pcs' => 'e.g. 1',
      _ => 'e.g. 250',
    };

    final Widget packSizeValueField = buildProductFormField(
      label: 'Pack Size',
      hint: packSizeHint,
      controller: variant['packSizeVal'],
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
      ],
      validator: (val) {
        if (val == null || val.trim().isEmpty) return 'Required';
        final numVal = double.tryParse(val);
        if (numVal == null || numVal <= 0) return 'Invalid';
        return null;
      },
      isCompact: true,
    );

    final Widget packSizeUnitField = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Pack Unit',
          style: GoogleFonts.outfit(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          height: 32,
          width: double.infinity,
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.borderColor),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              value: [
                'ml',
                'lit',
                'gm',
                'kg',
                'pcs',
              ].contains(variant['packSizeUnit'])
                  ? variant['packSizeUnit']
                  : 'lit',
              onChanged: (val) {
                if (val != null) {
                  variant['packSizeUnit'] = val;
                  onStateChanged();
                  variant['recalculate']();
                }
              },
              dropdownColor: Colors.white,
              borderRadius: BorderRadius.circular(12),
              icon: const Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 16,
                color: AppTheme.textSecondary,
              ),
              items: const [
                DropdownMenuItem(value: 'ml', child: Text('ml')),
                DropdownMenuItem(value: 'lit', child: Text('lit')),
                DropdownMenuItem(value: 'gm', child: Text('gm')),
                DropdownMenuItem(value: 'kg', child: Text('kg')),
                DropdownMenuItem(value: 'pcs', child: Text('pcs')),
              ],
              style: GoogleFonts.outfit(
                fontSize: 13,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
        ),
      ],
    );

    final String basePackingHint = switch (variant['basePackingUnit']) {
      'ml' => 'e.g. 1000',
      'lit' => 'e.g. 10',
      'gm' => 'e.g. 1000',
      'kg' => 'e.g. 10',
      'pcs' => 'e.g. 10',
      _ => 'e.g. 10',
    };

    final Widget basePackingValueField = buildProductFormField(
      label: 'Base Packing',
      hint: basePackingHint,
      controller: variant['basePackingVal'],
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
      ],
      validator: (val) {
        if (val == null || val.trim().isEmpty) return 'Required';
        final numVal = double.tryParse(val);
        if (numVal == null || numVal <= 0) return 'Invalid';
        return null;
      },
      isCompact: true,
    );

    final Widget basePackingUnitField = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Base Unit',
          style: GoogleFonts.outfit(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          height: 32,
          width: double.infinity,
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.borderColor),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              value: variant['basePackingUnit'],
              onChanged: (val) {
                if (val != null) {
                  variant['basePackingUnit'] = val;
                  onStateChanged();
                  variant['recalculate']();
                }
              },
              dropdownColor: Colors.white,
              borderRadius: BorderRadius.circular(12),
              icon: const Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 16,
                color: AppTheme.textSecondary,
              ),
              items: basePackingUnits.map((u) {
                return DropdownMenuItem<String>(value: u, child: Text(u));
              }).toList(),
              style: GoogleFonts.outfit(
                fontSize: 13,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
        ),
      ],
    );

    final sizeFields = isMobile
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: packSizeValueField),
                  const SizedBox(width: 12),
                  Expanded(child: packSizeUnitField),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: basePackingValueField),
                  const SizedBox(width: 12),
                  Expanded(child: basePackingUnitField),
                ],
              ),
            ],
          )
        : Row(
            children: [
              Expanded(flex: 2, child: packSizeValueField),
              const SizedBox(width: 12),
              Expanded(flex: 2, child: packSizeUnitField),
              const SizedBox(width: 12),
              Expanded(flex: 2, child: basePackingValueField),
              const SizedBox(width: 12),
              Expanded(flex: 2, child: basePackingUnitField),
            ],
          );

    final String liveSuffix = getRateSuffix(
      variant['basePackingUnit'] as String? ?? 'lit',
    );

    final List<Widget> rateRowChildren = [
      Expanded(
        child: buildProductFormField(
          label: 'MRP Rate (₹$liveSuffix)',
          hint: 'e.g. 2400',
          controller: variant['compareRate'],
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
          ],
          validator: (val) {
            if (val == null || val.trim().isEmpty) return 'Required';
            final numVal = double.tryParse(val);
            if (numVal == null || numVal <= 0) return 'Must be > 0';
            return null;
          },
          prefixIcon: const Icon(
            Icons.currency_rupee_rounded,
            size: 14,
            color: AppTheme.textSecondary,
          ),
          isCompact: true,
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: buildProductFormField(
          label: 'Farmer Rate (₹$liveSuffix)',
          hint: 'e.g. 260',
          controller: variant['farmerRate'],
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
          ],
          validator: (val) {
            if (val == null || val.trim().isEmpty) return null;
            final numVal = double.tryParse(val);
            if (numVal == null || numVal <= 0) return 'Must be > 0';
            return null;
          },
          prefixIcon: const Icon(
            Icons.currency_rupee_rounded,
            size: 14,
            color: Color(0xFF059669),
          ),
          isCompact: true,
        ),
      ),
    ];

    final ratesMap = variant['rates'] as Map<String, TextEditingController>;
    final List<Widget> dynamicTierFields = [];
    final priceTiers = variant['priceTiers'] as List<Map<String, String>>;

    for (var tier in priceTiers) {
      final id = tier['id']!;
      final ctrl = ratesMap[id];
      if (ctrl != null) {
        final isPrimary = id == '1';
        dynamicTierFields.add(
          buildProductFormField(
            label: '${tier['name']} (₹$liveSuffix)',
            hint: isPrimary ? 'e.g. 950' : 'Optional',
            controller: ctrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
            ],
            validator: isPrimary
                ? (val) {
                    if (val == null || val.trim().isEmpty) return 'Required';
                    final numVal = double.tryParse(val);
                    if (numVal == null || numVal <= 0) return 'Must be > 0';
                    return null;
                  }
                : (val) {
                    if (val == null || val.trim().isEmpty) {
                      return null; // Optional
                    }
                    final numVal = double.tryParse(val);
                    if (numVal == null || numVal <= 0) return 'Must be > 0';
                    final t1Val = double.tryParse(
                      (variant['rates']
                                  as Map<String, TextEditingController>)['1']
                              ?.text
                              .trim() ??
                          '',
                    );
                    if (t1Val != null && numVal > t1Val) {
                      return '≤ Tier 1';
                    }
                    return null;
                  },
            prefixIcon: const Icon(
              Icons.currency_rupee_rounded,
              size: 14,
              color: AppTheme.textSecondary,
            ),
            isCompact: true,
          ),
        );
      }
    }

    final List<Widget> rateRows = [];
    rateRows.add(Row(children: rateRowChildren));

    for (int i = 0; i < dynamicTierFields.length; i += 2) {
      final List<Widget> rowItems = [];
      rowItems.add(Expanded(child: dynamicTierFields[i]));
      if (i + 1 < dynamicTierFields.length) {
        rowItems.add(const SizedBox(width: 12));
        rowItems.add(Expanded(child: dynamicTierFields[i + 1]));
      } else {
        rowItems.add(const SizedBox(width: 12));
        rowItems.add(const Spacer());
      }
      rateRows.add(const SizedBox(height: 10));
      rateRows.add(Row(children: rowItems));
    }

    final rateFields = Column(children: rateRows);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Container(
          decoration: const BoxDecoration(
            border: Border(
              left: BorderSide(color: AppTheme.primaryColor, width: 3),
            ),
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Text(
                        'Variant Option ${index + 1}',
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      TextButton.icon(
                        onPressed: onManageTiers,
                        icon: const Icon(Icons.settings_outlined, size: 16),
                        label: Text(
                          'Manage Tiers',
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: TextButton.styleFrom(
                          foregroundColor: AppTheme.primaryColor,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                      if (totalVariants > 1) ...[
                        const SizedBox(width: 12),
                        IconButton(
                          onPressed: onRemove,
                          icon: const Icon(
                            Icons.delete_outline_rounded,
                            size: 18,
                            color: AppTheme.error,
                          ),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          tooltip: 'Remove Variant',
                        ),
                      ],
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [sizeFields, const SizedBox(height: 16), rateFields],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
