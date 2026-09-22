import 'package:flutter/material.dart';
import 'package:simpleattendancechecker/constants/app_sizing.dart';
import 'package:simpleattendancechecker/constants/color_palatte.dart';
import 'package:simpleattendancechecker/constants/shadow_card.dart';

class AttendaceCard extends StatelessWidget {
  final String fullName;
  final String studentId;
  final String time;
  final String status;
  final String? date;
  final bool selfScanned;

  const AttendaceCard({
    super.key,
    required this.fullName,
    required this.studentId,
    required this.time,
    required this.status,
    this.date,
    this.selfScanned = false,
  });

  Color get _statusColor {
    switch (status) {
      case 'Present':
        return Colorpalatte.sucesscolor;
      case 'Late':
        return Colorpalatte.warningcolor;
      case 'Absent':
        return Colorpalatte.errorcolor;
      case 'OJT':
        return Colorpalatte.ojtcolor;
      case 'Working Student':
        return Colorpalatte.infocolor;
      default:
        return Colorpalatte.mutedcolor;
    }
  }

  bool get _attendanceWhileOjtWorking {
    final isOjtorWorking = status == 'OJT' || status == 'Working Student';
    return isOjtorWorking && selfScanned;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(AppSpacing.md),
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colorpalatte.containercolor,
        boxShadow: ShadowCard.card,

        borderRadius: BorderRadius.circular(AppRadius.xm),
      ),
      child: Row(
        spacing: AppSpacing.xm,
        children: [
          _buildStatusDot(),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  studentId,
                  style: TextStyle(
                    fontFamily: 'K2D',
                    fontSize: AppFontSize.body,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  fullName,
                  style: TextStyle(
                    fontFamily: 'K2D',
                    fontSize: AppFontSize.caption,
                    color: Colorpalatte.mutedcolor,
                  ),
                ),
              ],
            ),
          ),

          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                date != null ? '$date  •  $time' : time,
                style: TextStyle(fontFamily: 'K2D', fontSize: AppFontSize.body),
              ),
              Text(
                status,
                style: TextStyle(
                  fontFamily: 'K2D',
                  fontSize: AppFontSize.caption,
                  fontWeight: FontWeight.w700,
                  color: _statusColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusDot() {
    if (_attendanceWhileOjtWorking) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colorpalatte.sucesscolor,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _statusColor,
            ),
          ),
        ],
      );
    }

    return Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(shape: BoxShape.circle, color: _statusColor),
    );
  }
}
