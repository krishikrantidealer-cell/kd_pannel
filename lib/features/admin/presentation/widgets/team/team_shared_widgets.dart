import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kd_pannel/app_theme.dart';

Widget buildTableHeaderCell(String text, {bool alignRight = false}) {
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    child: Align(
      alignment: alignRight ? Alignment.centerRight : Alignment.centerLeft,
      child: Text(
        text.toUpperCase(),
        style: GoogleFonts.outfit(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.0,
          color: const Color(0xFF64748B),
        ),
      ),
    ),
  );
}

Widget buildTableCell(String text) {
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    child: Text(
      text,
      style: GoogleFonts.outfit(
        fontSize: 13,
        color: AppTheme.textBody,
        fontWeight: FontWeight.w500,
      ),
    ),
  );
}

Widget buildMiniBadge(String text, Color color) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(4),
    ),
    child: Text(
      text,
      style: GoogleFonts.outfit(
        fontSize: 10.5,
        fontWeight: FontWeight.bold,
        color: color,
      ),
    ),
  );
}

Widget buildBadge(String countText, Color baseColor) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: baseColor.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: baseColor.withValues(alpha: 0.18), width: 1),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(shape: BoxShape.circle, color: baseColor),
        ),
        const SizedBox(width: 6),
        Text(
          countText,
          style: GoogleFonts.outfit(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: baseColor,
          ),
        ),
      ],
    ),
  );
}

Widget buildRowActionButton({
  required IconData icon,
  required String tooltip,
  required Color color,
  required VoidCallback onPressed,
}) {
  return Tooltip(
    message: tooltip,
    textStyle: GoogleFonts.outfit(fontSize: 11, color: Colors.white),
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            color: Colors.white,
          ),
          child: Icon(icon, size: 16, color: color),
        ),
      ),
    ),
  );
}

Widget buildSummaryCard(
  String title,
  String value,
  IconData icon,
  Color color,
) {
  return Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppTheme.borderColor),
    ),
    child: Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 20, color: color),
        ),
        const SizedBox(width: 14),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: GoogleFonts.outfit(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              title,
              style: GoogleFonts.outfit(
                fontSize: 12,
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

InputDecoration buildInputDecoration(
  String label,
  IconData icon, {
  Widget? suffixIcon,
}) {
  return InputDecoration(
    labelText: label,
    labelStyle: GoogleFonts.outfit(
      color: AppTheme.textSecondary,
      fontSize: 13,
      fontWeight: FontWeight.w500,
    ),
    prefixIcon: Icon(icon, size: 18, color: AppTheme.primaryColor),
    suffixIcon: suffixIcon,
    filled: true,
    fillColor: const Color(0xFFF9FAFB),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppTheme.borderColor, width: 1),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppTheme.primaryColor, width: 1.5),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppTheme.error, width: 1),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppTheme.error, width: 1.5),
    ),
  );
}

Widget buildPaginationControls({
  required int currentPage,
  required int total,
  required int pageSize,
  required ValueChanged<int> onPageChanged,
}) {
  final int totalPages = (total / pageSize).ceil();
  final int displayPages = totalPages > 0 ? totalPages : 1;

  List<Widget> pageButtons = [];

  if (displayPages <= 5) {
    for (int i = 1; i <= displayPages; i++) {
      pageButtons.add(
        PageNumberButton(
          page: i,
          isActive: currentPage == i,
          onTap: () => onPageChanged(i),
        ),
      );
      if (i < displayPages) {
        pageButtons.add(const SizedBox(width: 8));
      }
    }
  } else {
    pageButtons.add(
      PageNumberButton(
        page: 1,
        isActive: currentPage == 1,
        onTap: () => onPageChanged(1),
      ),
    );
    pageButtons.add(const SizedBox(width: 8));

    if (currentPage > 3) {
      pageButtons.add(
        Text(
          '...',
          style: GoogleFonts.outfit(
            color: AppTheme.textSecondary,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
      pageButtons.add(const SizedBox(width: 8));
    }

    final start = (currentPage - 1).clamp(2, displayPages - 1);
    final end = (currentPage + 1).clamp(2, displayPages - 1);

    for (int i = start; i <= end; i++) {
      if (i > 1 && i < displayPages) {
        pageButtons.add(
          PageNumberButton(
            page: i,
            isActive: currentPage == i,
            onTap: () => onPageChanged(i),
          ),
        );
        pageButtons.add(const SizedBox(width: 8));
      }
    }

    if (currentPage < displayPages - 2) {
      pageButtons.add(
        Text(
          '...',
          style: GoogleFonts.outfit(
            color: AppTheme.textSecondary,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
      pageButtons.add(const SizedBox(width: 8));
    }

    pageButtons.add(
      PageNumberButton(
        page: displayPages,
        isActive: currentPage == displayPages,
        onTap: () => onPageChanged(displayPages),
      ),
    );
  }

  return Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      PaginationButton(
        onTap: currentPage > 1 ? () => onPageChanged(currentPage - 1) : null,
        icon: Icons.chevron_left,
        isDisabled: currentPage <= 1,
      ),
      const SizedBox(width: 12),
      ...pageButtons,
      const SizedBox(width: 12),
      PaginationButton(
        onTap: currentPage < displayPages
            ? () => onPageChanged(currentPage + 1)
            : null,
        icon: Icons.chevron_right,
        isDisabled: currentPage >= displayPages,
      ),
    ],
  );
}

class PageNumberButton extends StatefulWidget {
  final int page;
  final bool isActive;
  final VoidCallback? onTap;

  const PageNumberButton({
    super.key,
    required this.page,
    required this.isActive,
    this.onTap,
  });

  @override
  State<PageNumberButton> createState() => _PageNumberButtonState();
}

class _PageNumberButtonState extends State<PageNumberButton> {
  bool isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: widget.onTap != null
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => isHovered = true),
      onExit: (_) => setState(() => isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: widget.isActive
                ? AppTheme.primaryColor
                : (isHovered ? const Color(0xFFF3F4F6) : Colors.white),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: widget.isActive
                  ? AppTheme.primaryColor
                  : AppTheme.borderColor,
            ),
          ),
          child: Text(
            '${widget.page}',
            style: GoogleFonts.outfit(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: widget.isActive ? Colors.white : AppTheme.textBody,
            ),
          ),
        ),
      ),
    );
  }
}

class PaginationButton extends StatefulWidget {
  final VoidCallback? onTap;
  final IconData icon;
  final bool isDisabled;

  const PaginationButton({
    super.key,
    required this.onTap,
    required this.icon,
    this.isDisabled = false,
  });

  @override
  State<PaginationButton> createState() => _PaginationButtonState();
}

class _PaginationButtonState extends State<PaginationButton> {
  bool isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: widget.isDisabled
          ? SystemMouseCursors.basic
          : SystemMouseCursors.click,
      onEnter: (_) => setState(() => isHovered = true),
      onExit: (_) => setState(() => isHovered = false),
      child: GestureDetector(
        onTap: widget.isDisabled ? null : widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: widget.isDisabled
                ? Colors.white
                : (isHovered ? const Color(0xFFF3F4F6) : Colors.white),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: AppTheme.borderColor),
          ),
          child: Icon(
            widget.icon,
            size: 18,
            color: widget.isDisabled
                ? const Color(0xFFD1D5DB)
                : AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }
}
