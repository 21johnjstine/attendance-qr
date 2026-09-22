import 'package:flutter/material.dart';
import 'package:simpleattendancechecker/constants/app_sizing.dart';
import 'package:simpleattendancechecker/constants/color_palatte.dart';

class StatsChipsCard extends StatelessWidget {
  final String count;
  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const StatsChipsCard({
    super.key,
    required this.count,
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 130,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.sm,
        ),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected
              ? color.withValues(alpha: 0.15)
              : Colorpalatte.containercolor,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: selected ? Border.all(color: color, width: 2) : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          spacing: AppSpacing.sm,
          children: [
            Flexible(
              child: Text(
                count,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: AppFontSize.title,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ),

            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: AppFontSize.caption,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
