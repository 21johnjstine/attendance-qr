import 'package:flutter/material.dart';
import 'package:simpleattendancechecker/constants/app_sizing.dart';
import 'package:simpleattendancechecker/constants/color_palatte.dart';
import 'package:simpleattendancechecker/screen/recordlist/functions/student_analytics_content.dart';

class StudentAnalyticsSheet {
  static Future<void> show(
    BuildContext context, {
    required String studentId,
    required String fullName,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colorpalatte.maincolor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.lg),
        ),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.85,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (context, scrollController) {
            return StudentAnalyticsContent(
              studentId: studentId,
              fullName: fullName,
              showBackButton: true,
              scrollController: scrollController,
            );
          },
        );
      },
    );
  }
}
