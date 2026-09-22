import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:curved_navigation_bar/curved_navigation_bar.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:simpleattendancechecker/constants/color_palatte.dart';
import 'package:simpleattendancechecker/screen/dashboard/pages/dashboard.dart';
import 'package:simpleattendancechecker/screen/recordlist/pages/record_list.dart';
import 'package:simpleattendancechecker/screen/scanner/pages/scanner.dart';
import 'package:simpleattendancechecker/widget/custom_appbar.dart';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  // ── 🛠️ Method functions ───────────────────────────
  int _selectedIndex = 1;
  DateTime _selectedDate = DateTime.now();

  // ── 🔄 Pull-to-refresh — works regardless of which tab is active ──────
  Future<void> _onRefresh() async {
    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
    try {
      await FirebaseFirestore.instance
          .collection('attendance')
          .where('date', isEqualTo: dateStr)
          .get(const GetOptions(source: Source.server));
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    //
    final List<Widget> pages = [
      Scanner(isActive: _selectedIndex == 0),
      Dashboard(
        selectedDate: _selectedDate,
        onDateChanged: (date) => setState(() => _selectedDate = date),
      ),
      RecordList(isActive: _selectedIndex == 2),
    ];

    // ── 🏗️ Main structure ───────────────────────────
    return Scaffold(
      backgroundColor: Colorpalatte.maincolor,
      appBar: const CustomAppbar(),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _onRefresh,
          child: IndexedStack(index: _selectedIndex, children: pages),
        ),
      ),
      bottomNavigationBar: CurvedNavigationBar(
        index: _selectedIndex,
        backgroundColor: Colorpalatte.maincolor,
        color: Colorpalatte.secondary,
        animationDuration: const Duration(milliseconds: 400),
        onTap: (index) => setState(() => _selectedIndex = index),
        items: [
          Icon(
            Icons.qr_code_scanner_rounded,
            color: Colorpalatte.maincolor,
            size: 30,
          ),
          Icon(Icons.home_rounded, color: Colorpalatte.maincolor, size: 30),
          Icon(Icons.list_alt_rounded, color: Colorpalatte.maincolor, size: 30),
        ],
      ),
    );
  }
}
