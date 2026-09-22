import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:simpleattendancechecker/constants/app_sizing.dart';
import 'package:simpleattendancechecker/constants/color_palatte.dart';
import 'package:simpleattendancechecker/constants/shadow_card.dart';
import 'package:simpleattendancechecker/screen/recordlist/functions/student_analytics_sheet.dart';
import 'package:simpleattendancechecker/services/csv_service.dart';
import 'package:simpleattendancechecker/widget/date_time_card.dart';
import 'package:simpleattendancechecker/widget/searchbar_card.dart';

class SectionStudentList extends StatefulWidget {
  final String program;
  final String year;
  final String section;
  final String sectionLabel;
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> students;
  final VoidCallback onBack;

  const SectionStudentList({
    super.key,
    required this.program,
    required this.year,
    required this.section,
    required this.sectionLabel,
    required this.students,
    required this.onBack,
  });

  @override
  State<SectionStudentList> createState() => _SectionStudentListState();
}

class _SectionStudentListState extends State<SectionStudentList> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _sortAscending = true;
  bool _isExporting = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ALERTDIALOG EXPORTING FUNCTION {#d46,69}
  Future<void> _handleExport() async {
    final format = await showDialog<ExportFormat>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colorpalatte.maincolor,
        title: const Text('Choose Export Format'),
        content: const Text('Select the file format you want to export to.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, ExportFormat.csv),
            child: const Text('CSV (.csv)'),
          ),

          TextButton(
            onPressed: () => Navigator.pop(context, ExportFormat.excel),
            child: const Text('Excel (.xlsx)'),
          ),
        ],
      ),
    );

    if (format == null) return;

    setState(() => _isExporting = true);

    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: AppSpacing.md),
            const Expanded(child: Text('Exporting section masterlist...')),
          ],
        ),
      ),
    );

    final result = await CsvService.exportSectionMasterlist(
      students: widget.students,
      sectionLabel: widget.sectionLabel,
      format: format,
    );

    if (!mounted) return;
    Navigator.pop(context);
    setState(() => _isExporting = false);

    if (result.cancelledByUser) return;
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(result.success ? 'Success' : 'Error'),
        content: Text(
          result.success
              ? '${result.count} student record(s) exported successfully.'
              : (result.errorMessage ?? 'Something went wrong.'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // SEARCHBOX AND FILTERING FUNCTION {#7b7,14}
    final filtered =
        widget.students.where((doc) {
          final d = doc.data();
          final name = (d['fullName'] ?? '').toString().toLowerCase();
          final id = doc.id.toLowerCase();
          final query = _searchQuery.toLowerCase();
          return query.isEmpty || name.contains(query) || id.contains(query);
        }).toList()..sort((a, b) {
          final nameA = (a.data()['fullName'] ?? '').toString();
          final nameB = (b.data()['fullName'] ?? '').toString();
          return _sortAscending
              ? nameA.compareTo(nameB)
              : nameB.compareTo(nameA);
        });

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Column(
        spacing: AppSpacing.sm,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 🧩 SECTION LIST ───────────────────────────
          Row(
            children: [
              IconButton(
                onPressed: widget.onBack,
                icon: const Icon(Icons.arrow_back_ios_new_rounded),
                color: Colorpalatte.secondary,
              ),
              Expanded(
                child: Text(
                  widget.sectionLabel,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'K2D',
                    fontSize: AppFontSize.title,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),

          // ── 🗓️ CALENDAR ───────────────────────────
          DateTimeCard(
            selectedDate: DateTime.now(),
            studentCount: widget.students.length,
            tappable: false,
          ),

          Row(
            spacing: AppSpacing.xs,
            children: [
              // ── 🔍 SEARCH BAR ───────────────────────────
              // SEARCHBAR {#a39,7}
              Expanded(
                child: SearchbarCard(
                  controller: _searchController,
                  onChanged: (value) => setState(() => _searchQuery = value),
                  showPadShad: false,
                ),
              ),

              // ── 🔽 FILTER FUNCTION ───────────────────────────
              // FILTERING A-Z {#82e,17}
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
                  onPressed: () =>
                      setState(() => _sortAscending = !_sortAscending),
                ),
              ),

              // ── 📤 EXPORTING FUNCTION ───────────────────────────
              // EXPORT BUTTON {#852,13}
              ElevatedButton.icon(
                onPressed: _isExporting ? null : _handleExport,
                icon: const Icon(Icons.ios_share_rounded, size: 18),
                label: const Text('Export'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colorpalatte.secondary,
                  foregroundColor: Colorpalatte.maincolor,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                ),
              ),
            ],
          ),

          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Text(
                      'No matching students.',
                      style: TextStyle(color: Colorpalatte.mutedcolor),
                    ),
                  )
                : ListView.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: AppSpacing.xm),
                    itemBuilder: (context, index) {
                      final doc = filtered[index];
                      final d = doc.data();
                      final studentId = doc.id;
                      final fullName = (d['fullName'] ?? '').toString();

                      return InkWell(
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        onTap: () => StudentAnalyticsSheet.show(
                          context,
                          studentId: studentId,
                          fullName: fullName,
                        ),
                        child: Container(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          decoration: BoxDecoration(
                            boxShadow: ShadowCard.card,
                            color: Colorpalatte.containercolor,
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      studentId,
                                      style: TextStyle(
                                        fontFamily: 'K2D',
                                        fontWeight: FontWeight.w700,
                                        fontSize: AppFontSize.body,
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
                              Icon(
                                Icons.chevron_right_rounded,
                                color: Colorpalatte.mutedcolor,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
