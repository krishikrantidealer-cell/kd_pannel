import 'package:flutter/material.dart';
import 'package:kd_pannel/core/utils/currency_utils.dart';

/// Reusable Billing & Price Breakdown summary card for Order Creation.
class OrderBillingSummaryCard extends StatelessWidget {
  final double subtotal;
  final double discountAmount;
  final double deliveryFee;
  final double taxAmount;
  final double grandTotal;
  final String? appliedCouponCode;
  final VoidCallback? onRemoveCoupon;
  final VoidCallback? onApplyCouponPressed;

  const OrderBillingSummaryCard({
    super.key,
    required this.subtotal,
    required this.discountAmount,
    required this.deliveryFee,
    required this.taxAmount,
    required this.grandTotal,
    this.appliedCouponCode,
    this.onRemoveCoupon,
    this.onApplyCouponPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.receipt_long_rounded,
                  color: Color(0xFF10B981),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Price Summary',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(width: 0, height: 16),
          const Divider(height: 1),
          const SizedBox(height: 14),

          _buildRow('Item Subtotal', CurrencyUtils.formatInr(subtotal), theme),
          const SizedBox(height: 10),

          if (discountAmount > 0) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      'Discount',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF10B981),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (appliedCouponCode != null) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          appliedCouponCode!,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF10B981),
                          ),
                        ),
                      ),
                      if (onRemoveCoupon != null)
                        IconButton(
                          icon: const Icon(Icons.close, size: 14, color: Colors.redAccent),
                          onPressed: onRemoveCoupon,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          splashRadius: 12,
                        ),
                    ],
                  ],
                ),
                Text(
                  '-${CurrencyUtils.formatInr(discountAmount)}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF10B981),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],

          _buildRow(
            'Delivery Charges',
            deliveryFee == 0 ? 'FREE' : CurrencyUtils.formatInr(deliveryFee),
            theme,
            valueColor: deliveryFee == 0 ? const Color(0xFF10B981) : null,
          ),
          const SizedBox(height: 10),

          if (taxAmount > 0) ...[
            _buildRow('Estimated Tax (GST)', CurrencyUtils.formatInr(taxAmount), theme),
            const SizedBox(height: 10),
          ],

          const Divider(height: 20),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Grand Total',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  fontSize: 17,
                ),
              ),
              Text(
                CurrencyUtils.formatInr(grandTotal),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  fontSize: 19,
                  color: const Color(0xFF10B981),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRow(String label, String value, ThemeData theme, {Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.75),
          ),
        ),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}
