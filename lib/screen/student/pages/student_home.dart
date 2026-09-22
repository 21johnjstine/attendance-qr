import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:curved_navigation_bar/curved_navigation_bar.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:simpleattendancechecker/constants/app_sizing.dart';
import 'package:simpleattendancechecker/constants/color_palatte.dart';
import 'package:simpleattendancechecker/screen/recordlist/functions/student_analytics_content.dart';
import 'package:simpleattendancechecker/screen/scanner/functions/scanner_overlay_painter.dart';
import 'package:simpleattendancechecker/services/attendance_service.dart';
import 'package:simpleattendancechecker/services/auth_service.dart';

class StudentHome extends StatefulWidget {
  final StudentProfile profile;

  const StudentHome({super.key, required this.profile});

  @override
  State<StudentHome> createState() => _StudentHomeState();
}

class _StudentHomeState extends State<StudentHome> {
  int _selectedIndex = 1;

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      _StudentQrHub(profile: widget.profile, isActive: _selectedIndex == 0),
      _StudentDashboard(profile: widget.profile),
      StudentAnalyticsContent(
        studentId: widget.profile.studentId,
        fullName: widget.profile.fullName,
      ),
    ];

    return Scaffold(
      backgroundColor: Colorpalatte.maincolor,
      appBar: const _StudentAppBar(),
      body: SafeArea(
        child: IndexedStack(index: _selectedIndex, children: pages),
      ),
      bottomNavigationBar: CurvedNavigationBar(
        index: _selectedIndex,
        backgroundColor: Colorpalatte.maincolor,
        color: Colorpalatte.secondary,
        animationDuration: const Duration(milliseconds: 400),
        onTap: (index) => setState(() => _selectedIndex = index),
        items: const [
          Icon(
            Icons.qr_code_2_rounded,
            color: Colorpalatte.maincolor,
            size: 30,
          ),
          Icon(Icons.home_rounded, color: Colorpalatte.maincolor, size: 30),
          Icon(
            Icons.analytics_rounded,
            color: Colorpalatte.maincolor,
            size: 30,
          ),
        ],
      ),
    );
  }
}

class _StudentAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _StudentAppBar();

  @override
  Size get preferredSize => const Size.fromHeight(90);

  Future<void> _signOut(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colorpalatte.maincolor,
        title: const Text(
          'Sign out?',
          style: TextStyle(fontFamily: 'K2D', fontWeight: FontWeight.w700),
        ),
        content: const Text(
          'You will return to the login screen after signing out.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await AuthService.signOut();
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        color: Colorpalatte.maincolor,
        child: Row(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colorpalatte.secondary, width: 2),
              ),
              padding: const EdgeInsets.all(4),
              child: ClipOval(
                child: Image.asset('lib/assets/logo.png', fit: BoxFit.contain),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            const Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Welcome to',
                    style: TextStyle(
                      fontFamily: 'K2D',
                      fontSize: AppFontSize.caption,
                      color: Colorpalatte.mutedcolor,
                    ),
                  ),
                  Text(
                    'Attendance Checker',
                    style: TextStyle(
                      fontFamily: 'K2D',
                      fontSize: AppFontSize.subtitle,
                      fontWeight: FontWeight.w700,
                      color: Colorpalatte.secondary,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: Colorpalatte.containercolor,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: PopupMenuButton<String>(
                color: Colorpalatte.maincolor,
                icon: const Icon(
                  Icons.person_outline_rounded,
                  color: Colorpalatte.secondary,
                ),
                onSelected: (value) {
                  if (value == 'sign_out') _signOut(context);
                },
                itemBuilder: (context) => const [
                  PopupMenuItem<String>(
                    value: 'sign_out',
                    child: Row(
                      children: [
                        Icon(Icons.logout_rounded),
                        SizedBox(width: AppSpacing.xs),
                        Text('Sign out'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StudentDashboard extends StatelessWidget {
  final StudentProfile profile;

  const _StudentDashboard({required this.profile});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('attendance')
          .where('studentId', isEqualTo: profile.studentId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Text(
                snapshot.error.toString().contains('permission-denied')
                    ? 'Firestore denied access to your attendance records.'
                    : 'Your attendance could not be loaded.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colorpalatte.errorcolor),
              ),
            ),
          );
        }

        final docs =
            snapshot.data?.docs ??
            <QueryDocumentSnapshot<Map<String, dynamic>>>[];

        final present = docs
            .where((d) => d.data()['attendanceStatus'] == 'Present')
            .length;

        final late = docs
            .where((d) => d.data()['attendanceStatus'] == 'Late')
            .length;

        final absent = docs
            .where((d) => d.data()['attendanceStatus'] == 'Absent')
            .length;

        final attended = present + late;

        final denominator = attended + absent;

        final overall = denominator == 0 ? 0.0 : (attended / denominator) * 100;

        return RefreshIndicator(
          onRefresh: () async {
            await Future<void>.delayed(const Duration(milliseconds: 250));
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.xl,
            ),
            children: [
              const Text(
                'Home',
                style: TextStyle(
                  fontFamily: 'K2D',
                  fontSize: AppFontSize.display,
                  fontWeight: FontWeight.w700,
                  color: Colorpalatte.secondary,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              const Text(
                'Your attendance at a glance.',
                style: TextStyle(
                  fontSize: AppFontSize.caption,
                  color: Colorpalatte.mutedcolor,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: Colorpalatte.secondary,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 54,
                      height: 54,
                      decoration: const BoxDecoration(
                        color: Colorpalatte.accentcolor,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.school_rounded,
                        color: Colorpalatte.secondary,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            profile.fullName,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: 'K2D',
                              fontSize: AppFontSize.subtitle,
                              fontWeight: FontWeight.w700,
                              color: Colorpalatte.maincolor,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${profile.studentId}  •  ${profile.program} ${profile.yearDigits}-${profile.section}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: AppFontSize.caption,
                              color: Colorpalatte.maincolor.withValues(
                                alpha: .8,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: _HomeStat(
                      label: 'Overall',
                      value: '${overall.round()}%',
                      color: Colorpalatte.secondary,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: _HomeStat(
                      label: 'Attended',
                      value: '$attended',
                      color: Colorpalatte.sucesscolor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: _HomeStat(
                      label: 'Late',
                      value: '$late',
                      color: Colorpalatte.warningcolor,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: _HomeStat(
                      label: 'Absent',
                      value: '$absent',
                      color: Colorpalatte.errorcolor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: Colorpalatte.containercolor,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      color: Colorpalatte.secondary,
                    ),
                    SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        'Use QR to show your personal code or scan your teacher\'s active session QR.',
                        style: TextStyle(
                          fontSize: AppFontSize.caption,
                          color: Colorpalatte.mutedcolor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _HomeStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _HomeStat({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: Colorpalatte.containercolor,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border(bottom: BorderSide(color: color, width: 3)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontFamily: 'K2D',
              fontSize: AppFontSize.title,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: AppFontSize.caption,
              color: Colorpalatte.mutedcolor,
            ),
          ),
        ],
      ),
    );
  }
}

class _StudentQrHub extends StatefulWidget {
  final StudentProfile profile;
  final bool isActive;

  const _StudentQrHub({required this.profile, required this.isActive});

  @override
  State<_StudentQrHub> createState() => _StudentQrHubState();
}

class _StudentQrHubState extends State<_StudentQrHub> {
  late final MobileScannerController _controller;
  int _selectedTab = 0;
  bool _processing = false;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      formats: const [BarcodeFormat.qrCode],
      autoStart: widget.isActive,
    );
  }

  @override
  void didUpdateWidget(covariant _StudentQrHub oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive == oldWidget.isActive) return;

    if (!widget.isActive || _selectedTab != 0) {
      _controller.stop();
    } else {
      _controller.start();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _selectTab(int index) {
    if (_selectedTab == index) return;

    setState(() => _selectedTab = index);
    if (!widget.isActive) return;

    if (index == 0) {
      _controller.start();
    } else {
      _controller.stop();
    }
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_processing || !widget.isActive || _selectedTab != 0) return;

    String? rawValue;
    for (final barcode in capture.barcodes) {
      final value = barcode.rawValue?.trim();
      if (value != null && value.isNotEmpty) {
        rawValue = value;
        break;
      }
    }

    if (rawValue == null) return;

    setState(() => _processing = true);

    final result = await AttendanceService.recordStudentSessionAttendance(
      rawPayload: rawValue,
      profile: widget.profile,
    );

    if (!mounted) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colorpalatte.maincolor,
        title: Row(
          children: [
            Icon(
              result.success
                  ? Icons.check_circle_rounded
                  : Icons.error_outline_rounded,
              color: result.success
                  ? Colorpalatte.sucesscolor
                  : Colorpalatte.errorcolor,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                result.success ? 'Attendance Recorded' : 'Scan Failed',
                style: const TextStyle(
                  fontFamily: 'K2D',
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        content: Text(result.message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('OK'),
          ),
        ],
      ),
    );

    if (mounted) setState(() => _processing = false);
  }

  @override
  Widget build(BuildContext context) {
    return IndexedStack(
      index: _selectedTab,
      children: [_buildScanTab(context), _buildMyQrTab(context)],
    );
  }

  Widget _buildTabBar() {
    return Container(
      height: 50,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colorpalatte.containercolor,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          Expanded(
            child: _TabButton(
              title: 'Scan QR',
              icon: Icons.qr_code_scanner_rounded,
              selected: _selectedTab == 0,
              onTap: () => _selectTab(0),
            ),
          ),
          Expanded(
            child: _TabButton(
              title: 'My QR Code',
              icon: Icons.qr_code_2_rounded,
              selected: _selectedTab == 1,
              onTap: () => _selectTab(1),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScanTab(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.xl,
      ),
      children: [
        _buildTabBar(),
        const SizedBox(height: AppSpacing.md),
        const Text(
          'Scan for Attendance',
          style: TextStyle(
            fontFamily: 'K2D',
            fontSize: AppFontSize.display,
            fontWeight: FontWeight.w700,
            color: Colorpalatte.secondary,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        const Text(
          'Point your camera at your teacher\'s Session QR.',
          style: TextStyle(
            fontSize: AppFontSize.caption,
            color: Colorpalatte.mutedcolor,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Center(
          child: Container(
            width: MediaQuery.of(context).size.width * .86,
            height: MediaQuery.of(context).size.height * .44,
            decoration: BoxDecoration(
              color: Colorpalatte.secondary,
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final size = Size(
                    constraints.maxWidth,
                    constraints.maxHeight,
                  );
                  final cutout = size.shortestSide * .60;
                  final scanWindow = Rect.fromCenter(
                    center: Offset(size.width / 2, size.height / 2),
                    width: cutout,
                    height: cutout,
                  );

                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      MobileScanner(
                        controller: _controller,
                        onDetect: _onDetect,
                        fit: BoxFit.cover,
                      ),
                      CustomPaint(
                        size: size,
                        painter: ScannerOverlayPainter(
                          scanWindow: scanWindow,
                          borderColor: Colorpalatte.accentcolor,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        const Text(
          'Point your camera at the Session QR to scan',
          textAlign: TextAlign.center,
          style: TextStyle(fontFamily: 'K2D', fontSize: AppFontSize.subtitle),
        ),
        const SizedBox(height: AppSpacing.sm),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          decoration: BoxDecoration(
            color: Colorpalatte.containercolor,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Row(
            children: [
              ValueListenableBuilder(
                valueListenable: _controller,
                builder: (context, state, _) {
                  final torchOn = state.torchState == TorchState.on;
                  return IconButton(
                    onPressed: _controller.toggleTorch,
                    icon: Icon(
                      torchOn
                          ? Icons.flash_on_rounded
                          : Icons.flash_off_rounded,
                    ),
                    color: torchOn
                        ? Colorpalatte.accentcolor
                        : Colorpalatte.mutedcolor,
                  );
                },
              ),
              const Text(
                'Flash',
                style: TextStyle(
                  fontFamily: 'K2D',
                  fontSize: AppFontSize.caption,
                  color: Colorpalatte.mutedcolor,
                ),
              ),
              const Spacer(),
              if (_processing)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              const SizedBox(width: AppSpacing.sm),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMyQrTab(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.xl,
      ),
      children: [
        _buildTabBar(),
        const SizedBox(height: AppSpacing.md),
        const Text(
          'My QR Code',
          style: TextStyle(
            fontFamily: 'K2D',
            fontSize: AppFontSize.display,
            fontWeight: FontWeight.w700,
            color: Colorpalatte.secondary,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        const Text(
          'Your personal QR represents your student identity. It is not a daily attendance QR.',
          style: TextStyle(
            fontSize: AppFontSize.caption,
            color: Colorpalatte.mutedcolor,
            height: 1.4,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: Colorpalatte.containercolor,
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: Colorpalatte.maincolor,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
                child: QrImageView(
                  data: widget.profile.studentId,
                  size: MediaQuery.of(context).size.width * .68,
                  backgroundColor: Colorpalatte.maincolor,
                  errorCorrectionLevel: QrErrorCorrectLevel.M,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                widget.profile.fullName,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'K2D',
                  fontSize: AppFontSize.subtitle,
                  fontWeight: FontWeight.w700,
                  color: Colorpalatte.secondary,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                widget.profile.studentId,
                style: const TextStyle(
                  fontFamily: 'K2D',
                  fontWeight: FontWeight.w700,
                  color: Colorpalatte.secondary,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '${widget.profile.program} • ${widget.profile.year} • Section ${widget.profile.section}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: AppFontSize.caption,
                  color: Colorpalatte.mutedcolor,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TabButton extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _TabButton({
    required this.title,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? Colorpalatte.secondary : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 19,
              color: selected ? Colorpalatte.maincolor : Colorpalatte.secondary,
            ),
            const SizedBox(width: AppSpacing.xs),
            Text(
              title,
              style: TextStyle(
                fontFamily: 'K2D',
                fontSize: AppFontSize.caption,
                fontWeight: FontWeight.w700,
                color: selected
                    ? Colorpalatte.maincolor
                    : Colorpalatte.secondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
