import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

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

/// Formats a conversation list timestamp just like official WhatsApp:
/// - Today: 'hh:mm a' (e.g. '10:45 AM')
/// - Yesterday: 'Yesterday'
/// - Within last 6 days: Day name (e.g. 'Monday', 'Tuesday')
/// - Older: 'dd/MM/yyyy' (e.g. '14/10/2026')
String formatWhatsAppConversationTime(dynamic rawDate) {
  if (rawDate == null) return '';
  DateTime? dt;
  if (rawDate is DateTime) {
    dt = rawDate.toLocal();
  } else {
    dt = DateTime.tryParse(rawDate.toString())?.toLocal();
  }
  if (dt == null) return '';

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final target = DateTime(dt.year, dt.month, dt.day);
  final diff = today.difference(target).inDays;

  if (diff <= 0) {
    return DateFormat('hh:mm a').format(dt);
  } else if (diff == 1) {
    return 'Yesterday';
  } else if (diff < 7) {
    return DateFormat('EEEE').format(dt);
  } else {
    return DateFormat('dd/MM/yyyy').format(dt);
  }
}

/// Formats a chat date divider label just like official WhatsApp:
/// - Today: 'TODAY'
/// - Yesterday: 'YESTERDAY'
/// - Older this year: 'd MMMM' (e.g. '12 OCTOBER')
/// - Older previous years: 'd MMMM yyyy' (e.g. '12 OCTOBER 2025')
String formatWhatsAppDateDivider(dynamic rawDate) {
  if (rawDate == null) return '';
  DateTime? dt;
  if (rawDate is DateTime) {
    dt = rawDate.toLocal();
  } else {
    dt = DateTime.tryParse(rawDate.toString())?.toLocal();
  }
  if (dt == null) return '';

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final target = DateTime(dt.year, dt.month, dt.day);
  final diff = today.difference(target).inDays;

  if (diff <= 0) {
    return 'TODAY';
  } else if (diff == 1) {
    return 'YESTERDAY';
  } else if (dt.year == now.year) {
    return DateFormat('d MMMM').format(dt).toUpperCase();
  } else {
    return DateFormat('d MMMM yyyy').format(dt).toUpperCase();
  }
}

/// Renders the official WhatsApp pill date divider between messages
Widget buildWhatsAppDateDivider(dynamic rawDate) {
  final label = formatWhatsAppDateDivider(rawDate);
  if (label.isEmpty) return const SizedBox.shrink();

  return Center(
    child: Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Text(
        label,
        style: GoogleFonts.outfit(
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF54656F),
          letterSpacing: 0.3,
        ),
      ),
    ),
  );
}
