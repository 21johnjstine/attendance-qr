import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:simpleattendancechecker/constants/app_sizing.dart';
import 'package:simpleattendancechecker/constants/color_palatte.dart';
import 'package:simpleattendancechecker/widget/attendace_card.dart';

class StudentAnalyticsContent extends StatelessWidget {
  final String studentId;
  final String fullName;
  final bool showBackButton;
  final ScrollController? scrollController;

  const StudentAnalyticsContent({
    super.key,
    required this.studentId,
    required this.fullName,
    this.showBackButton = false,
    this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('attendance')
          .where('studentId', isEqualTo: studentId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Text(
                snapshot.error.toString().contains('permission-denied')
                    ? 'Firestore denied access to your attendance records.'
                    : 'Your attendance analytics could not be loaded.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colorpalatte.errorcolor),
              ),
            ),
          );
        }

        final docs = <QueryDocumentSnapshot<Map<String, dynamic>>>[
          ...(snapshot.data?.docs ??
              <QueryDocumentSnapshot<Map<String, dynamic>>>[]),
        ];
        docs.sort((a, b) => _timestampFor(b).compareTo(_timestampFor(a)));

        final present = docs.where((doc) {
          return doc.data()['attendanceStatus'] == 'Present';
        }).length;

        final late = docs.where((doc) {
          return doc.data()['attendanceStatus'] == 'Late';
        }).length;

        final absent = docs.where((doc) {
          return doc.data()['attendanceStatus'] == 'Absent';
        }).length;

        final ojt = docs.where((doc) {
          final status = doc.data()['attendanceStatus'];
          return status == 'OJT';
        }).length;

        final working = docs.where((doc) {
          return doc.data()['attendanceStatus'] == 'Working Student';
        }).length;

        // Present and Late are both counted as attended.
        // Absent is the only non-attended status.
        final attended = present + late;
        final overallDenominator = attended + absent;

        final overallPercent = overallDenominator == 0
            ? 0.0
            : (attended / overallDenominator) * 100;

        return ListView(
          controller: scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.xl,
          ),
          children: [
            if (showBackButton)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 16),
                  label: const Text('Back'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colorpalatte.secondary,
                    padding: EdgeInsets.zero,
                  ),
                ),
              ),
            Text(
              fullName,
              style: const TextStyle(
                fontFamily: 'K2D',
                fontSize: AppFontSize.title,
                fontWeight: FontWeight.w700,
                color: Colorpalatte.secondary,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            const Text(
              'Your attendance analytics',
              style: TextStyle(
                fontFamily: 'K2D',
                fontSize: AppFontSize.subtitle,
                color: Colorpalatte.mutedcolor,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            _overallCard(overallPercent),
            const SizedBox(height: AppSpacing.sm),
            _metricCard(
              icon: Icons.check_circle_rounded,
              label: 'Attended',
              count: attended,
              color: Colorpalatte.sucesscolor,
            ),
            const SizedBox(height: AppSpacing.sm),
            _metricCard(
              icon: Icons.access_time_rounded,
              label: 'Late',
              count: late,
              color: Colorpalatte.warningcolor,
            ),
            const SizedBox(height: AppSpacing.sm),
            _metricCard(
              icon: Icons.cancel_rounded,
              label: 'Absent',
              count: absent,
              color: Colorpalatte.errorcolor,
            ),
            if (ojt + working > 0) ...[
              const SizedBox(height: AppSpacing.sm),
              _metricCard(
                icon: Icons.work_outline_rounded,
                label: 'OJT / Work',
                count: ojt + working,
                color: Colorpalatte.ojtcolor,
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            const Text(
              'Attendance Log',
              style: TextStyle(
                fontFamily: 'K2D',
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: Colorpalatte.secondary,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            if (snapshot.connectionState == ConnectionState.waiting &&
                snapshot.data == null)
              const Padding(
                padding: EdgeInsets.all(AppSpacing.lg),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (docs.isEmpty)
              Container(
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: Colorpalatte.containercolor,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
                child: const Column(
                  children: [
                    Icon(
                      Icons.event_available_outlined,
                      size: 54,
                      color: Colorpalatte.mutedcolor,
                    ),
                    SizedBox(height: AppSpacing.sm),
                    Text(
                      'No attendance records yet.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'K2D',
                        fontSize: AppFontSize.subtitle,
                        fontWeight: FontWeight.w700,
                        color: Colorpalatte.secondary,
                      ),
                    ),
                  ],
                ),
              )
            else
              ...docs.map((doc) {
                final data = doc.data();
                final rawDate = (data['date'] ?? '').toString();
                var displayDate = rawDate;

                try {
                  displayDate = DateFormat(
                    'MMM dd, yyyy',
                  ).format(DateTime.parse(rawDate));
                } catch (_) {}

                return Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: AttendaceCard(
                    fullName: (data['fullName'] ?? fullName).toString(),
                    studentId: (data['studentId'] ?? studentId).toString(),
                    time: (data['time'] ?? '').toString(),
                    status: (data['attendanceStatus'] ?? '').toString(),
                    date: displayDate,
                    selfScanned: data['selfScanned'] == true,
                  ),
                );
              }),
          ],
        );
      },
    );
  }

  Widget _overallCard(double overallPercent) {
    final value = overallPercent.clamp(0.0, 100.0) / 100;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: Colorpalatte.secondary,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${overallPercent.round()}%',
                  style: const TextStyle(
                    fontFamily: 'K2D',
                    fontSize: 42,
                    height: 1,
                    fontWeight: FontWeight.w700,
                    color: Colorpalatte.maincolor,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                const Text(
                  'Overall Attendance',
                  style: TextStyle(
                    fontFamily: 'K2D',
                    fontSize: AppFontSize.body,
                    fontWeight: FontWeight.w700,
                    color: Colorpalatte.maincolor,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 108,
            height: 108,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 104,
                  height: 104,
                  child: CircularProgressIndicator(
                    value: value,
                    strokeWidth: 10,
                    backgroundColor: Colorpalatte.mutedcolor.withValues(
                      alpha: .25,
                    ),
                    color: Colorpalatte.sucesscolor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _metricCard({
    required IconData icon,
    required String label,
    required int count,
    required Color color,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: Colorpalatte.containercolor,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 27),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontFamily: 'K2D',
                fontSize: AppFontSize.body,
                fontWeight: FontWeight.w500,
                color: Colorpalatte.secondary,
              ),
            ),
          ),
          Text(
            '$count',
            style: TextStyle(
              fontFamily: 'K2D',
              fontSize: AppFontSize.title,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  static DateTime _timestampFor(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final timestamp = doc.data()['timestamp'];
    if (timestamp is Timestamp) return timestamp.toDate();

    final date = (doc.data()['date'] ?? '').toString();
    final time = (doc.data()['time'] ?? '00:00').toString();

    try {
      return DateTime.parse('$date $time');
    } catch (_) {
      return DateTime.fromMillisecondsSinceEpoch(0);
    }
  }
}
