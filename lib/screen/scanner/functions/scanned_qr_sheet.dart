import 'package:flutter/material.dart';
import 'package:simpleattendancechecker/constants/app_sizing.dart';
import 'package:simpleattendancechecker/constants/color_palatte.dart';

class ScannedQrSheet {
  static Future<void> show(
    BuildContext context,
    Map<String, String> data, {
    required Future<void> Function() onConfirm,
  }) {
    return showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colorpalatte.maincolor,
      builder: (BuildContext context) {
        bool isSaving = false;

        return StatefulBuilder(
          builder: (context, setState) {
            return Padding(
              padding: const EdgeInsets.all(30),
              
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  spacing: AppSpacing.xm,
                  children: [
                    Center(
                      child: Text(
                        'Welcome',
                        style: TextStyle(
                          color: Colorpalatte.accentcolor,
                          fontFamily: 'K2D',
                          fontSize: AppFontSize.title,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),

                    Center(
                      child: Text(
                        'Confirm attendance details below.',
                        style: TextStyle(
                          fontSize: AppFontSize.subtitle,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Student Information:',
                          style: TextStyle(
                            fontFamily: 'K2D',
                            fontSize: AppFontSize.body,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        Text(
                          data['timeRecorded'] ?? '',
                          style: TextStyle(
                            fontFamily: 'K2D',
                            fontSize: AppFontSize.body,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),

                    Container(
                      padding: EdgeInsets.all(AppSpacing.md),
                      width: double.infinity,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        color: Colorpalatte.containercolor,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            data['name'] ?? 'Unknown student',
                            style: TextStyle(
                              fontSize: AppFontSize.body,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                data['studentId'] ?? 'Unknown student ID',
                                style: TextStyle(
                                  fontSize: AppFontSize.body,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                              Text(
                                '${data['program'] ?? ''} - ${data['yearSection'] ?? ''}',
                                style: TextStyle(
                                  fontSize: AppFontSize.body,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    Align(
                      alignment: AlignmentGeometry.centerLeft,
                      child: Text(
                        'Date and Status',
                        style: TextStyle(
                          fontSize: AppFontSize.body,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),

                    Container(
                      padding: EdgeInsets.all(AppSpacing.md),
                      width: double.infinity,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        color: Colorpalatte.containercolor,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            data['dateToday'] ?? '',
                            style: TextStyle(
                              fontSize: AppFontSize.body,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                          Text(
                            data['status'] ?? '',
                            style: TextStyle(
                              fontSize: AppFontSize.body,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: AppSpacing.xm),
                    
                    Row(
                      spacing: AppSpacing.xm,
                      children: [
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colorpalatte.mutedcolor,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadiusGeometry.circular(
                                  AppRadius.md,
                                ),
                              ),
                            ),
                            onPressed: isSaving
                                ? null
                                : () => Navigator.pop(context),
                            child: const Text(
                              'Cancel',
                              style: TextStyle(
                                color: Colorpalatte.maincolor,
                                fontSize: AppFontSize.caption,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),

                        Expanded(
                          flex: 3,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colorpalatte.secondary,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadiusGeometry.circular(
                                  AppRadius.md,
                                ),
                              ),
                            ),
                            onPressed: isSaving
                                ? null
                                : () async {
                                    setState(() => isSaving = true);
                                    try {
                                      await onConfirm();
                                    } finally {
                                      if (context.mounted) {
                                        Navigator.pop(context);
                                      }
                                    }
                                  },
                            child: isSaving
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colorpalatte.maincolor,
                                    ),
                                  )
                                : const Text(
                                    'Scan new student',
                                    style: TextStyle(
                                      color: Colorpalatte.maincolor,
                                      fontSize: AppFontSize.caption,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
