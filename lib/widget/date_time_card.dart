import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:simpleattendancechecker/constants/app_sizing.dart';
import 'package:simpleattendancechecker/constants/color_palatte.dart';

class DateTimeCard extends StatefulWidget {
  final DateTime selectedDate;
  final ValueChanged<DateTime>? onDateChanged;
  final int? studentCount;
  final bool tappable;

  const DateTimeCard({
    super.key,
    required this.selectedDate,
    this.onDateChanged,
    this.studentCount,
    this.tappable = true,
  });

  @override
  State<DateTimeCard> createState() => _DateTimeCardState();
}

class _DateTimeCardState extends State<DateTimeCard> {
  // ── 🛠️ State variables ───────────────────────────
  Timer? _timer;
  DateTime _now = DateTime.now();

  // ── 🛠️ Methods / Functions ───────────────────────────
  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: widget.selectedDate,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Colorpalatte.secondary, // header bg, selected date bg
              onPrimary:
                  Colorpalatte.maincolor, // text sa loob ng selected date
              surface: Colorpalatte.containercolor, // background ng buong dialog
              onSurface:
                  Colorpalatte.secondary, // default text color ng calendar
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor:
                    Colorpalatte.secondary, // "CANCEL"/"OK" buttons
              ),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) widget.onDateChanged!(picked);
  }

  // ── 🎨 Flutter override ───────────────────────────
  @override
  void initState() {
    super.initState();
    if (widget.studentCount == null) {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => _now = DateTime.now());
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // ── 🎴 UI Build ───────────────────────────
  @override
  Widget build(BuildContext context) {
    // ── 🛠️ Local functions ───────────────────────────
    // DATE FORMATTING {#b32,6}
    final dateStr = DateFormat('yyyy-MM-dd').format(widget.selectedDate);
    final isToday = dateStr == DateFormat('yyyy-MM-dd').format(DateTime.now());
    final formattedDate = DateFormat(
      'MMMM dd, yyyy',
    ).format(widget.selectedDate);
    final formattedTime = DateFormat('hh:mm a').format(_now);

    // TAPPABLE & STUDENTS LOGIC {#8ca,3}
    final String rightLabel = widget.studentCount != null
        ? '${widget.studentCount} Students'
        : (isToday ? formattedTime : 'Tap to change date');

    final content = Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xm),
      width: double.infinity,
      height: 40,
      decoration: BoxDecoration(
        color: Colorpalatte.secondary,
        borderRadius: BorderRadius.circular(AppRadius.xm),
      ),
      child: Row(
        spacing: AppSpacing.xs,
        children: [
          Image.asset('lib/assets/png/calendar.png', width: 20, height: 20),

          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  formattedDate,
                  style: TextStyle(
                    color: Colorpalatte.maincolor,
                    fontFamily: 'K2D',
                    fontSize: AppFontSize.body,
                    fontWeight: FontWeight.w700,
                  ),
                ),

                Text(
                  rightLabel,
                  style: TextStyle(
                    color: Colorpalatte.maincolor,
                    fontFamily: 'K2D',
                    fontSize: AppFontSize.body,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    // ── 🎨 UI Structures ───────────────────────────
    return widget.tappable
        ? GestureDetector(onTap: _pickDate, child: content)
        : content;
  }
}
