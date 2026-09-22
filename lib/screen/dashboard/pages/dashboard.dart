import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:simpleattendancechecker/constants/app_sizing.dart';
import 'package:simpleattendancechecker/constants/color_palatte.dart';
import 'package:simpleattendancechecker/widget/attendace_card.dart';
import 'package:simpleattendancechecker/widget/date_time_card.dart';
import 'package:simpleattendancechecker/widget/searchbar_card.dart';
import 'package:simpleattendancechecker/widget/section_card.dart';
import 'package:simpleattendancechecker/widget/stats_chips_card.dart';

class Dashboard extends StatefulWidget {
  final DateTime selectedDate;
  final ValueChanged<DateTime> onDateChanged;

  const Dashboard({
    super.key,
    required this.selectedDate,
    required this.onDateChanged,
  });

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  // ── 🛠️ State variables ───────────────────────────
  String _searchQuery = '';
  String _selectedSection = 'All';
  String? _selectedStatus;
  bool _sortAscending = true;

  bool _isOffline = false;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;

  // ── 🛠️ Methods / Functions ───────────────────────────
  String _sectionLabel(Map<String, dynamic> d) {
    final program = (d['program'] ?? '').toString();
    final year = (d['year'] ?? '').toString();
    final section = (d['section'] ?? '').toString();
    final yearDigits = RegExp(r'^\d+').firstMatch(year)?.group(0) ?? '';
    if (program.isEmpty && yearDigits.isEmpty && section.isEmpty) return '';
    return '$program $yearDigits-$section'.trim();
  }

  // ── 🎨 Flutter override ───────────────────────────
  @override
  void initState() {
    super.initState();

    Connectivity().checkConnectivity().then((result) {
      if (mounted) {
        setState(
          () => _isOffline = result.every((r) => r == ConnectivityResult.none),
        );
      }
    });
    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
      final offline =
          results.isEmpty || results.every((r) => r == ConnectivityResult.none);
      if (offline != _isOffline) {
        setState(() => _isOffline = offline);
      }
    });
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    super.dispose();
  }

  // ── Helper widgets ───────────────────────────
  void _toggleStatus(String value) {
    setState(() => _selectedStatus = _selectedStatus == value ? null : value);
  }

  // ── 🎴 UI Build ───────────────────────────
  @override
  Widget build(BuildContext context) {
    // ── 🛠️ Local functions ───────────────────────────
    final dateStr = DateFormat('yyyy-MM-dd').format(widget.selectedDate);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('attendance')
          .where('date', isEqualTo: dateStr)
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Center(
              child: Text(
                'An error occurred while fetching data:\n${snapshot.error}',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colorpalatte.errorcolor),
              ),
            ),
          );
        }

        // Function of stats card {#89b,85}
        final docs = snapshot.data?.docs ?? [];

        final sections = <String>{'All'};
        for (final doc in docs) {
          final label = _sectionLabel(doc.data());
          if (label.isNotEmpty) sections.add(label);
        }

        final sectionDocs = docs.where((doc) {
          return _selectedSection == 'All' ||
              _sectionLabel(doc.data()) == _selectedSection;
        }).toList();

        final presentCount = sectionDocs
            .where((d) => d.data()['attendanceStatus'] == 'Present')
            .length;
        final lateCount = sectionDocs
            .where((d) => d.data()['attendanceStatus'] == 'Late')
            .length;
        final absentCount = sectionDocs
            .where((d) => d.data()['attendanceStatus'] == 'Absent')
            .length;
        final ojtCount = sectionDocs
            .where((d) => d.data()['attendanceStatus'] == 'OJT')
            .length;
        final workingCount = sectionDocs
            .where((d) => d.data()['attendanceStatus'] == 'Working Student')
            .length;

        final filteredDocs =
            sectionDocs.where((doc) {
              final d = doc.data();
              final name = (d['fullName'] ?? '').toString().toLowerCase();
              final id = (d['studentId'] ?? '').toString().toLowerCase();
              final query = _searchQuery.toLowerCase();
              final matchesSearch =
                  query.isEmpty || name.contains(query) || id.contains(query);
              final matchesStatus =
                  _selectedStatus == null ||
                  d['attendanceStatus'] == _selectedStatus;
              return matchesSearch && matchesStatus;
            }).toList()..sort((a, b) {
              final nameA = (a.data()['fullName'] ?? '').toString();
              final nameB = (b.data()['fullName'] ?? '').toString();
              return _sortAscending
                  ? nameA.compareTo(nameB)
                  : nameB.compareTo(nameA);
            });

        final statsItems = [
          (
            count: presentCount,
            label: 'Present',
            status: 'Present',
            color: Colorpalatte.sucesscolor,
          ),
          (
            count: lateCount,
            label: 'Late',
            status: 'Late',
            color: Colorpalatte.warningcolor,
          ),
          (
            count: absentCount,
            label: 'Absent',
            status: 'Absent',
            color: Colorpalatte.errorcolor,
          ),
          (
            count: ojtCount,
            label: 'OJT',
            status: 'OJT',
            color: Colorpalatte.ojtcolor,
          ),
          (
            count: workingCount,
            label: 'Working',
            status: 'Working Student',
            color: Colorpalatte.infocolor,
          ),
        ];

        final sectionList = sections.toList();

        // ── 🎨 UI Structures ───────────────────────────

        return CustomScrollView(
          slivers: [
            // ── 📌 Sticky header ───────────────────────────
            PinnedHeaderSliver(
              child: Material(
                color: Colorpalatte.maincolor,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),

                  child: Column(
                    spacing: AppSpacing.sm,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── 🗨️ Overview title ───────────────────────────
                      Text(
                        'Overview',
                        style: TextStyle(
                          fontFamily: 'K2D',
                          fontSize: AppFontSize.display,
                          fontWeight: FontWeight.w700,
                        ),
                      ),

                      // ── ⌛ Date and timer ───────────────────────────
                      DateTimeCard(
                        selectedDate: widget.selectedDate,
                        onDateChanged: widget.onDateChanged,
                      ),

                      // ── 📊 Attendance stats ───────────────────────────
                      SizedBox(
                        height: 70,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: statsItems.length,
                          separatorBuilder: (context, index) {
                            return const SizedBox(width: AppSpacing.sm);
                          },
                          itemBuilder: (context, index) {
                            final item = statsItems[index];

                            return StatsChipsCard(
                              count: '${item.count}',
                              label: item.label,
                              color: item.color,
                              selected: _selectedStatus == item.status,
                              onTap: () => _toggleStatus(item.status),
                            );
                          },
                        ),
                      ),

                      // ── 🗂️ Section filter ───────────────────────────
                      Text(
                        'Sections',
                        style: TextStyle(
                          fontFamily: 'K2D',
                          fontSize: AppFontSize.title,
                          fontWeight: FontWeight.w700,
                        ),
                      ),

                      // ── 🗂️ Section filter ───────────────────────────
                      SizedBox(
                        height: 40,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: sectionList.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(width: AppSpacing.xs),
                          itemBuilder: (context, index) {
                            final s = sectionList[index];
                            return SectionCard(
                              label: s,
                              selected: s == _selectedSection,
                              onTap: () => setState(() => _selectedSection = s),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Offline warning {#313,39}
            // ── ⚠️ Offline mode warning ───────────────────────────
            if (_isOffline)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    AppSpacing.sm,
                    AppSpacing.md,
                    0,
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.xs,
                      horizontal: AppSpacing.sm,
                    ),
                    decoration: BoxDecoration(
                      color: Colorpalatte.warningcolor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.cloud_off_rounded,
                          size: 16,
                          color: Colorpalatte.secondary,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Text(
                          'Offline mode — showing local data',
                          style: TextStyle(
                            fontSize: AppFontSize.caption,
                            color: Colorpalatte.secondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // Attendance and Search Bar {#5c4,67}
            // ── 📌 Attendance section list ───────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.sm,
                  AppSpacing.md,
                  AppSpacing.xs,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Attendance',
                          style: TextStyle(
                            fontFamily: 'K2D',
                            fontSize: AppFontSize.title,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          '${filteredDocs.length} scanned',
                          style: TextStyle(
                            fontFamily: 'K2D',
                            fontSize: AppFontSize.caption,
                            color: Colorpalatte.mutedcolor,
                          ),
                        ),
                      ],
                    ),

                    Row(
                      children: [
                        Expanded(
                          child: SearchbarCard(
                            onChanged: (value) =>
                                setState(() => _searchQuery = value),
                          ),
                        ),

                        Container(
                          decoration: BoxDecoration(
                            color: Colorpalatte.containercolor,
                            borderRadius: BorderRadius.circular(AppRadius.md),
                          ),
                          child: IconButton(
                            tooltip: _sortAscending ? 'A-Z' : 'Z-A',
                            icon: Icon(
                              _sortAscending
                                  ? Icons.arrow_upward_rounded
                                  : Icons.arrow_downward_rounded,
                              color: Colorpalatte.secondary,
                            ),
                            onPressed: () => setState(
                              () => _sortAscending = !_sortAscending,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            if (snapshot.connectionState == ConnectionState.waiting &&
                docs.isEmpty)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (filteredDocs.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: Text('No matching records.')),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  0,
                  AppSpacing.md,
                  AppSpacing.md,
                ),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      if (index.isOdd) {
                        return const SizedBox(height: AppSpacing.xm);
                      }
                      final d = filteredDocs[index ~/ 2].data();
                      return AttendaceCard(
                        fullName: d['fullName'] ?? '',
                        studentId: d['studentId'] ?? '',
                        time: d['time'] ?? '',
                        status: d['attendanceStatus'] ?? '',
                      );
                    },
                    childCount: filteredDocs.isEmpty
                        ? 0
                        : filteredDocs.length * 2 - 1,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
