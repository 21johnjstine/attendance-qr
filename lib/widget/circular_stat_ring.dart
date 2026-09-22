import 'package:flutter/material.dart';

/// Reusable circular progress ring with a percentage label sa gitna.
/// Ginagamit ng Analytics popup para sa Overall/Present/Late/Absent stats.
class CircularStatRing extends StatelessWidget {
  final double percent;
  final Color color;
  final double size;
  final double strokeWidth;
  final TextStyle? textStyle;

  const CircularStatRing({
    super.key,
    required this.percent,
    required this.color,
    this.size = 60,
    this.strokeWidth = 6,
    this.textStyle,
  });

  @override
  Widget build(BuildContext context) {
    final clamped = percent.clamp(0, 100).toDouble();
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              value: clamped / 100,
              strokeWidth: strokeWidth,
              backgroundColor: color.withOpacity(0.15),
              valueColor: AlwaysStoppedAnimation<Color>(color),
              strokeCap: StrokeCap.round,
            ),
          ),
          Text(
            '${clamped.round()}%',
            style:
                textStyle ??
                TextStyle(
                  fontFamily: 'K2D',
                  fontWeight: FontWeight.w700,
                  fontSize: size * 0.28,
                  color: color,
                ),
          ),
        ],
      ),
    );
  }
}
