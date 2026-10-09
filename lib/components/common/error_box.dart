import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/theme_controller.dart';

class ErrorBox extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  final String retryLabel;

  const ErrorBox({
    super.key,
    required this.message,
    this.onRetry,
    this.retryLabel = 'Retry',
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark ||
        ThemeController.instance.isDarkMode;

    final boxBg = isDark ? const Color(0xFF2C0F12) : const Color(0xFFFDE8E8);
    final borderCol = isDark
        ? const Color(0xFFFF453A).withValues(alpha: 0.35)
        : const Color(0xFFFF3B30).withValues(alpha: 0.3);
    final iconCol = isDark ? const Color(0xFFFF453A) : const Color(0xFFD70015);
    final textCol = isDark ? const Color(0xFFFF8080) : const Color(0xFF99000D);
    final retryCol = isDark ? const Color(0xFFFF453A) : const Color(0xFFD70015);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: boxBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderCol),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.error_outline, color: iconCol, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: GoogleFonts.inter(
                    color: textCol,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onRetry,
                icon: Icon(Icons.refresh, size: 16, color: retryCol),
                label: Text(
                  retryLabel,
                  style: GoogleFonts.inter(
                    color: retryCol,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
