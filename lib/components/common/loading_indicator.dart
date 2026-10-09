import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class LoadingIndicator extends StatelessWidget {
  final Color? color;
  final double size;
  final String? label;

  const LoadingIndicator({
    super.key,
    this.color,
    this.size = 36,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? const Color(0xFF00F2FE);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              color: c,
              strokeWidth: 3,
            ),
          ),
          if (label != null) ...[
            const SizedBox(height: 14),
            Text(label!,
                style: GoogleFonts.inter(
                    color: Colors.white54,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
          ],
        ],
      ),
    );
  }
}