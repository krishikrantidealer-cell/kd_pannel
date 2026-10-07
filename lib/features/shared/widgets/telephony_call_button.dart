import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kd_pannel/core/auth/auth_service.dart';
import 'package:kd_pannel/core/services/telephony_audio_service.dart';
import 'package:kd_pannel/core/utils/navigation_service.dart';
import 'package:kd_pannel/features/admin/presentation/bloc/call_logs_bloc.dart';
import 'package:kd_pannel/features/admin/presentation/bloc/call_logs_event.dart';

enum TelephonyButtonVariant {
  filled,
  outlined,
  iconOnly,
  chip,
}

/// Centralized DRY Telephony Helper & Call Dispatcher
class TelephonyHelper {
  static String sanitizePhone(String rawPhone) {
    String cleaned = rawPhone.replaceAll(RegExp(r'\D'), '');
    if (cleaned.startsWith('91') && cleaned.length > 10) {
      cleaned = cleaned.substring(2);
    }
    while (cleaned.startsWith('0')) {
      cleaned = cleaned.substring(1);
    }
    return cleaned;
  }

  static void initiateCall(
    BuildContext? context, {
    required String customerPhone,
    String? customerName,
    String callMode = 'click2call',
  }) {
    final clean = sanitizePhone(customerPhone);
    final targetContext = (context != null && context.mounted)
        ? context
        : NavigationService.navigatorKey.currentContext;

    if (clean.length < 10) {
      if (targetContext != null && targetContext.mounted) {
        ScaffoldMessenger.of(targetContext).showSnackBar(
          SnackBar(
            content: Text('Invalid phone number: $customerPhone'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
      return;
    }

    if (targetContext != null) {
      targetContext.read<CallLogsBloc>().add(TriggerOutboundCallEvent(
        clean,
        customerName: customerName,
        callMode: 'click2call',
      ));
    }
  }

  static void showDialpad(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => const QuickDialpadDialog(),
    );
  }
}

/// Universal Reusable Outbound Calling Button (DRY Component)
class TelephonyCallButton extends StatelessWidget {
  final String customerPhone;
  final String? customerName;
  final TelephonyButtonVariant variant;
  final Color? color;
  final String label;
  final double iconSize;

  const TelephonyCallButton({
    super.key,
    required this.customerPhone,
    this.customerName,
    this.variant = TelephonyButtonVariant.filled,
    this.color,
    this.label = 'Call',
    this.iconSize = 16,
  });

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}

/// Universal In-App Quick Dialpad Dialog
class QuickDialpadDialog extends StatefulWidget {
  final String? initialPhone;
  final String? initialName;

  const QuickDialpadDialog({
    super.key,
    this.initialPhone,
    this.initialName,
  });

  @override
  State<QuickDialpadDialog> createState() => _QuickDialpadDialogState();
}

class _QuickDialpadDialogState extends State<QuickDialpadDialog> {
  late TextEditingController _phoneController;
  late TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    _phoneController = TextEditingController(text: widget.initialPhone ?? '');
    _nameController = TextEditingController(text: widget.initialName ?? '');
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _appendDigit(String digit) {
    TelephonyAudioService().playDtmfTone(digit);
    setState(() {
      _phoneController.text = _phoneController.text + digit;
    });
  }

  void _backspace() {
    TelephonyAudioService().playDtmfTone('backspace');
    if (_phoneController.text.isNotEmpty) {
      setState(() {
        _phoneController.text = _phoneController.text.substring(0, _phoneController.text.length - 1);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF0F172A),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFF334155), width: 1.2),
      ),
      child: Container(
        width: 340,
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF008069).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.dialpad_rounded, color: Color(0xFF10B981), size: 20),
                ),
                const SizedBox(width: 10),
                Text(
                  'Quick Telephony Dialer',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Color(0xFF94A3B8), size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Number Display Input
            TextField(
              controller: _phoneController,
              autofocus: true,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF38BDF8),
                letterSpacing: 1.5,
              ),
              keyboardType: TextInputType.phone,
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                hintText: 'Enter phone number',
                hintStyle: GoogleFonts.plusJakartaSans(color: const Color(0xFF64748B), fontSize: 14),
                filled: true,
                fillColor: const Color(0xFF1E293B),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.backspace_rounded, color: Color(0xFF94A3B8), size: 18),
                  onPressed: _backspace,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFF334155)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFF38BDF8), width: 1.5),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
            const SizedBox(height: 16),

            // Numpad Grid
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.5,
              children: [
                ...['1', '2', '3', '4', '5', '6', '7', '8', '9', '*', '0', '#'].map(
                  (digit) => InkWell(
                    onTap: () => _appendDigit(digit),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF334155)),
                      ),
                      child: Text(
                        digit,
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Unified 1-Click Call Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.call_rounded, size: 18),
                label: Text(
                  'Call Customer',
                  style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF008069),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () {
                  final phone = _phoneController.text.trim();
                  if (phone.isNotEmpty) {
                    Navigator.of(context).pop();
                    TelephonyHelper.initiateCall(
                      context,
                      customerPhone: phone,
                      customerName: _nameController.text.trim(),
                      callMode: 'click2call',
                    );
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
