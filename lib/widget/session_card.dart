import 'package:flutter/material.dart';
import 'package:simpleattendancechecker/constants/app_sizing.dart';
import 'package:simpleattendancechecker/constants/color_palatte.dart';

class SessionCard extends StatelessWidget {
  final String daydate;
  final String sessions;
  final VoidCallback? onDoubleTap;
  const SessionCard({
    super.key,
    required this.daydate,
    required this.sessions,
    this.onDoubleTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onDoubleTap: onDoubleTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
        width: double.infinity,
        height: 90,
        decoration: BoxDecoration(
          color: Colorpalatte.containercolor,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Row(
          spacing: AppSpacing.md,
          children: [
            // ── 🗓️ Month and date ───────────────────────────
            Container(
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Colorpalatte.accentcolor,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),

              child: Center(
                child: Text(
                  daydate,
                  textAlign: TextAlign.start,
                  style: TextStyle(
                    fontSize: AppFontSize.body,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),

            // ── 🌐 Session Title ───────────────────────────
            Expanded(
              child: Text(
                sessions,
                style: TextStyle(
                  fontSize: AppFontSize.body,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),

            Center(
              child: Icon(
                Icons.edit_rounded,
                size: AppFontSize.display,
                color: Colorpalatte.accentcolor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
