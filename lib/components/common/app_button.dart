import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final Color? color;
  final bool loading;
  final bool outlined;

  const AppButton({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.color,
    this.loading = false,
    this.outlined = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? const Color(0xFF00F2FE);
    final disabled = onTap == null || loading;

    if (outlined) {
      return SizedBox(
        width: double.infinity,
        height: 52,
        child: OutlinedButton.icon(
          onPressed: disabled ? null : onTap,
          style: OutlinedButton.styleFrom(
            foregroundColor: c,
            side: BorderSide(color: c.withOpacity(0.5)),
            shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          icon: loading
              ? SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: c),
          )
              : (icon != null ? Icon(icon, size: 18) : const SizedBox.shrink()),
          label: Text(label,
              style: GoogleFonts.inter(
                  fontWeight: FontWeight.w900, fontSize: 14)),
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton.icon(
        onPressed: disabled ? null : onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: c,
          foregroundColor: const Color(0xFF0B132B),
          disabledBackgroundColor: Colors.white.withOpacity(0.05),
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
        ),
        icon: loading
            ? const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
              strokeWidth: 2, color: Color(0xFF0B132B)),
        )
            : (icon != null ? Icon(icon, size: 18) : const SizedBox.shrink()),
        label: Text(label,
            style: GoogleFonts.inter(
                fontWeight: FontWeight.w900, fontSize: 14)),
      ),
    );
  }
}