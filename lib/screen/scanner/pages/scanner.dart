import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:simpleattendancechecker/constants/app_sizing.dart';
import 'package:simpleattendancechecker/constants/color_palatte.dart';
import 'package:simpleattendancechecker/screen/scanner/functions/scanned_qr_sheet.dart';
import 'package:simpleattendancechecker/screen/scanner/functions/scanner_overlay_painter.dart';
import 'package:simpleattendancechecker/services/attendance_service.dart';
import 'package:simpleattendancechecker/services/biometric_service.dart';

class Scanner extends StatefulWidget {
  final bool isActive;

  const Scanner({super.key, required this.isActive});

  @override
  State<Scanner> createState() => _ScannerState();
}

class _ScannerState extends State<Scanner> {
  late final MobileScannerController controller;
  final TextEditingController _manualIdController = TextEditingController();
  final FocusNode _manualIdFocusNode = FocusNode();

  int _selectedTab = 0;
  bool _isProcessing = false;
  bool _lateMode = false;
  bool _isMarkingAbsent = false;

  String? _selectedClassId;
  String? _generatedPayload;
  AttendanceSessionClass? _generatedClass;
  DateTime? _generatedExpiresAt;
  String? _generatedSessionId;
  Timer? _sessionTimer;
  int _remainingSessionSeconds = 0;
  bool _isGenerating = false;
  bool _isFinalizingSession = false;
  int _presentWindowMinutes = 20;

  late Future<List<AttendanceSessionClass>> _classesFuture;

  @override
  void initState() {
    super.initState();

    // On Flutter Web, use ZXing WASM for more reliable
    // QR detection on Safari/iOS and other mobile browsers.
    if (kIsWeb) {
      MobileScannerPlatform.instance.setWebBarcodeReader(
        WebBarcodeReader.zxingWasm,
      );
    }

    controller = MobileScannerController(
      formats: [BarcodeFormat.qrCode],
      autoStart: false,
    );

    _manualIdController.addListener(_onManualIdChanged);
    _classesFuture = AttendanceService.loadTeacherClasses();
    _restoreActiveSession();
  }

  Future<void> _restoreActiveSession() async {
    try {
      final activeSession = await AttendanceService.loadActiveTeacherSession();

      if (!mounted || activeSession == null) return;

      final classes = await _classesFuture;
      if (!mounted) return;

      AttendanceSessionClass? matchedClass;
      for (final item in classes) {
        if (item.classId == activeSession.payload.classId) {
          matchedClass = item;
          break;
        }
      }

      final restoredClass = matchedClass ?? activeSession.asClass();

      setState(() {
        _generatedPayload = activeSession.payload.toJson();
        _generatedClass = restoredClass;
        _generatedExpiresAt = activeSession.expiresAt;
        _generatedSessionId = activeSession.payload.sessionId;
        _selectedClassId = activeSession.payload.classId;
        _presentWindowMinutes = activeSession.presentWindowMinutes;
      });

      _startSessionTimer(
        activeSession.expiresAt,
        activeSession.payload.sessionId,
      );
    } catch (_) {
      // No restorable active session. The Generate QR tab can create one.
    }
  }

  @override
  void didUpdateWidget(covariant Scanner oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.isActive == oldWidget.isActive) return;

    if (!widget.isActive) {
      controller.stop();
      return;
    }

    if (_selectedTab == 0) {
      controller.start();
    }
  }

  @override
  void dispose() {
    _sessionTimer?.cancel();
    controller.dispose();
    _manualIdController.dispose();
    _manualIdFocusNode.dispose();
    super.dispose();
  }

  void _onManualIdChanged() {
    final value = _manualIdController.text.trim();
    if (value.length == 14 && !_isProcessing) {
      _manualIdController.clear();
      _handleStudentScan(value);
    }
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_isProcessing || !widget.isActive || _selectedTab != 0) return;

    String? rawValue;
    for (final barcode in capture.barcodes) {
      final value = barcode.rawValue?.trim();
      if (value != null && value.isNotEmpty) {
        rawValue = value;
        break;
      }
    }
    if (rawValue == null || rawValue.isEmpty) return;

    _isProcessing = true;

    await _handleStudentScan(rawValue);

    if (mounted) {
      _isProcessing = false;
    }
  }

  Future<void> _handleStudentScan(String rawValue) async {
    try {
      final studentId = _extractPersonalStudentId(rawValue);

      if (studentId == null) {
        await _showInfoDialog(
          'Session QR Detected',
          'This is a teacher session QR. The teacher scanner accepts personal student QR codes or manual Student IDs.',
        );
        return;
      }

      final studentDoc = await FirebaseFirestore.instance
          .collection('students')
          .doc(studentId)
          .get();

      if (!mounted) return;

      if (!studentDoc.exists) {
        await _showInfoDialog(
          'Student ID Not Found',
          'No record was found for Student ID "$studentId". Please check the QR code or contact the administrator.',
        );
        return;
      }

      final data = studentDoc.data()!;
      final fullName = (data['fullName'] ?? 'Unknown student').toString();
      final program = (data['program'] ?? '').toString();
      final year = (data['year'] ?? '').toString();
      final section = (data['section'] ?? '').toString();
      final email = (data['email'] ?? '').toString();
      final studentType = (data['studentType'] ?? 'Student').toString();

      final now = DateTime.now();
      final todayStr = DateFormat('yyyy-MM-dd').format(now);

      final existing = await FirebaseFirestore.instance
          .collection('attendance')
          .where('studentId', isEqualTo: studentId)
          .where('date', isEqualTo: todayStr)
          .limit(1)
          .get();

      if (!mounted) return;

      if (existing.docs.isNotEmpty) {
        await _showInfoDialog(
          'Already Logged',
          '$fullName has already been recorded for attendance today.',
        );
        return;
      }

      final status = studentType != 'Student'
          ? studentType
          : (_lateMode ? 'Late' : 'Present');

      final yearDigits = RegExp(r'^\d+').firstMatch(year)?.group(0) ?? '';
      final yearSection = '$yearDigits-$section';

      await ScannedQrSheet.show(
        context,
        {
          'studentId': studentId,
          'name': fullName,
          'program': program,
          'year': year,
          'section': section,
          'yearSection': yearSection,
          'email': email,
          'studentType': studentType,
          'status': status,
          'dateToday': '${now.month}/${now.day}/${now.year}',
          'timeRecorded':
              '${now.hour}:${now.minute.toString().padLeft(2, '0')}',
        },
        onConfirm: () async {
          final docId =
              '${studentId}_${DateFormat('yyyyMMdd_HHmmss').format(now)}';

          await FirebaseFirestore.instance
              .collection('attendance')
              .doc(docId)
              .set({
                'studentId': studentId,
                'fullName': fullName,
                'attendanceStatus': status,
                'program': program,
                'year': year,
                'section': section,
                'date': todayStr,
                'time': DateFormat('HH:mm').format(now),
                'timestamp': Timestamp.fromDate(now),
                'selfScanned': false,
                'scanMethod': 'teacher_personal_qr',
              });
        },
      );

      if (mounted && widget.isActive) {
        try {
          await controller.stop();
          await controller.start();
        } catch (_) {}
      }
    } on FirebaseException catch (e) {
      if (!mounted) return;

      final message = e.code == 'permission-denied'
          ? 'Firestore denied access to this student record.'
          : e.message ?? 'The scan could not be processed.';

      await _showInfoDialog('Error occurred', message);
    } catch (e) {
      if (!mounted) return;
      await _showInfoDialog(
        'Error occurred',
        'The scan could not be processed: $e',
      );
    } finally {
      _isProcessing = false;
    }
  }

  String? _extractPersonalStudentId(String rawValue) {
    final trimmed = rawValue.trim();

    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is Map) {
        final map = Map<String, dynamic>.from(decoded);
        final type = map['type']?.toString();

        if (type == 'attendance_session') {
          return null;
        }

        if (type == 'student_identity') {
          final id = map['studentId']?.toString().trim();
          if (id != null && id.isNotEmpty) return id;
        }

        return null;
      }
    } catch (_) {
      // Existing personal student QR codes are raw student IDs.
    }

    if (trimmed.isEmpty) return null;
    return trimmed;
  }

  Future<void> _markAbsentees() async {
    List<QueryDocumentSnapshot<Map<String, dynamic>>> allStudents;

    try {
      final snap = await FirebaseFirestore.instance
          .collection('students')
          .get();
      allStudents = snap.docs;
    } catch (e) {
      if (!mounted) return;
      await _showInfoDialog(
        'Error occurred',
        'Could not retrieve the student list: $e',
      );
      return;
    }

    if (!mounted) return;

    const allStudentsOption = 'All Students (All Programs/Sections)';

    final sections = <String>{};
    for (final doc in allStudents) {
      final label = _studentSectionLabel(doc.data());
      if (label.isNotEmpty) sections.add(label);
    }

    final sortedSections = <String>[
      allStudentsOption,
      ...sections.toList()..sort(),
    ];

    String? selectedSection;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Colorpalatte.maincolor,
              title: const Text('Mark as Absent'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Select the Program - Year & Section, or mark all students:',
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  DropdownButtonFormField<String>(
                    initialValue: selectedSection,
                    isExpanded: true,
                    hint: const Text('Select an option'),
                    items: sortedSections
                        .map(
                          (s) => DropdownMenuItem(
                            value: s,
                            child: Text(s, overflow: TextOverflow.ellipsis),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setDialogState(() => selectedSection = v),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: selectedSection == null
                      ? null
                      : () => Navigator.pop(context, true),
                  child: const Text('Confirm'),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed != true || selectedSection == null) return;

    final isAllStudents = selectedSection == allStudentsOption;

    final verified = await BiometricService.authenticate();
    if (!mounted) return;

    if (!verified) {
      await _showInfoDialog(
        'Not Confirmed',
        'Mark as Absent was cancelled because biometric verification failed.',
      );
      return;
    }

    setState(() => _isMarkingAbsent = true);

    try {
      final now = DateTime.now();
      final todayStr = DateFormat('yyyy-MM-dd').format(now);

      final attendanceToday = await FirebaseFirestore.instance
          .collection('attendance')
          .where('date', isEqualTo: todayStr)
          .get();

      final loggedIds = attendanceToday.docs
          .map((doc) => doc.data()['studentId'])
          .whereType<String>()
          .toSet();

      final batch = FirebaseFirestore.instance.batch();
      var markedCount = 0;

      for (final doc in allStudents) {
        final data = doc.data();
        final label = _studentSectionLabel(data);

        if (!isAllStudents && label != selectedSection) {
          continue;
        }

        final studentId = doc.id;
        if (loggedIds.contains(studentId)) continue;

        final studentType = (data['studentType'] ?? 'Student').toString();
        final status = (studentType == 'OJT' || studentType == 'Working Student')
            ? studentType
            : 'Absent';

        final docId =
            '${studentId}_${DateFormat('yyyyMMdd_HHmmss').format(now)}';
        final ref = FirebaseFirestore.instance
            .collection('attendance')
            .doc(docId);

        batch.set(ref, {
          'studentId': studentId,
          'fullName': data['fullName'] ?? '',
          'attendanceStatus': status,
          'program': data['program'] ?? '',
          'year': data['year'] ?? '',
          'section': data['section'] ?? '',
          'date': todayStr,
          'time': DateFormat('HH:mm').format(now),
          'timestamp': Timestamp.fromDate(now),
          'selfScanned': false,
          'scanMethod': 'teacher_mark_absent',
        });

        markedCount++;
      }

      if (markedCount > 0) {
        await batch.commit();
      }

      if (!mounted) return;

      final scopeLabel = isAllStudents ? 'all students' : '"$selectedSection"';

      await _showInfoDialog(
        'Done',
        markedCount > 0
            ? '$markedCount student(s) from $scopeLabel were logged.'
            : 'No unlogged students remain for $scopeLabel today.',
      );
    } on FirebaseException catch (e) {
      if (!mounted) return;

      await _showInfoDialog(
        'Error occurred',
        e.code == 'permission-denied'
            ? 'Firestore denied the attendance write.'
            : e.message ?? 'Could not process the request.',
      );
    } catch (e) {
      if (!mounted) return;
      await _showInfoDialog('Error occurred', 'Could not process: $e');
    } finally {
      if (mounted) {
        setState(() => _isMarkingAbsent = false);
      }
    }
  }

  String _studentSectionLabel(Map<String, dynamic> data) {
    final program = (data['program'] ?? '').toString();
    final year = (data['year'] ?? '').toString();
    final section = (data['section'] ?? '').toString();
    final yearDigits = RegExp(r'^\d+').firstMatch(year)?.group(0) ?? '';

    if (program.isEmpty && yearDigits.isEmpty && section.isEmpty) {
      return '';
    }

    return '$program $yearDigits-$section'.trim();
  }

  Future<void> _showInfoDialog(String title, String message) {
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colorpalatte.maincolor,
        title: Text(title, style: const TextStyle(fontFamily: 'K2D')),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _selectTab(int tab) {
    if (_selectedTab == tab) return;

    setState(() => _selectedTab = tab);

    if (!widget.isActive) return;

    if (tab == 0) {
      controller.start();
    } else {
      controller.stop();
    }
  }

  Future<void> _generateSessionQr() async {
    final selectedId = _selectedClassId;
    if (selectedId == null) {
      await _showInfoDialog(
        'Select a class',
        'Choose a class/section before generating the attendance session QR.',
      );
      return;
    }

    AttendanceSessionClass? selectedClass;
    try {
      final classes = await _classesFuture;
      for (final item in classes) {
        if (item.classId == selectedId) {
          selectedClass = item;
          break;
        }
      }
    } catch (e) {
      if (!mounted) return;
      await _showInfoDialog(
        'Unable to load classes',
        'The class list could not be loaded: $e',
      );
      return;
    }

    final resolvedClass = selectedClass;
    if (resolvedClass == null) {
      if (!mounted) return;
      await _showInfoDialog(
        'Class unavailable',
        'The selected class no longer exists in the student list.',
      );
      return;
    }

    setState(() => _isGenerating = true);

    try {
      final payload = await AttendanceService.createSession(
        selectedClass: resolvedClass,
        presentWindowMinutes: _presentWindowMinutes,
      );

      final parsed = jsonDecode(payload) as Map<String, dynamic>;
      final sessionId = parsed['sessionId']?.toString();
      final expiresAtRaw = parsed['expiresAt']?.toString();
      final parsedExpiresAt = expiresAtRaw == null
          ? null
          : DateTime.tryParse(expiresAtRaw);
      final expiresAt = parsedExpiresAt ?? DateTime.now().add(
        Duration(
          minutes: _presentWindowMinutes +
              AttendanceService.lateWindowMinutes,
        ),
      );

      if (!mounted) return;

      _sessionTimer?.cancel();
      setState(() {
        _generatedPayload = payload;
        _generatedClass = resolvedClass;
        _generatedExpiresAt = expiresAt;
        _generatedSessionId = sessionId;
        _selectedClassId = selectedId;
        _remainingSessionSeconds = expiresAt
            .difference(DateTime.now())
            .inSeconds
            .clamp(0, 86400)
            .toInt();
      });

      if (sessionId != null) {
        _startSessionTimer(expiresAt, sessionId);
      }

      await _showInfoDialog(
        'QR Generated',
        'Present window: $_presentWindowMinutes minutes. ' +
            'Late window: additional ${AttendanceService.lateWindowMinutes} minutes. ' +
            'Session ends at ${DateFormat('hh:mm a').format(expiresAt)}.',
      );
    } on AttendanceServiceException catch (e) {
      if (!mounted) return;
      await _showInfoDialog('Could not generate QR', e.message);
    } on FirebaseException catch (e) {
      if (!mounted) return;
      await _showInfoDialog(
        'Could not generate QR',
        e.code == 'permission-denied'
            ? 'Session for this class already exists for today.'
            : e.message ?? 'The session could not be created.',
      );
    } catch (e) {
      if (!mounted) return;
      await _showInfoDialog(
        'Could not generate QR',
        'The attendance session could not be created: $e',
      );
    } finally {
      if (mounted) {
        setState(() => _isGenerating = false);
      }
    }
  }

  void _startSessionTimer(DateTime expiresAt, String sessionId) {
    _sessionTimer?.cancel();

    void tick() {
      if (!mounted) return;

      final seconds = expiresAt.difference(DateTime.now()).inSeconds;
      if (seconds <= 0) {
        _sessionTimer?.cancel();
        setState(() => _remainingSessionSeconds = 0);
        _finalizeSessionIfExpired(sessionId);
        return;
      }

      setState(() => _remainingSessionSeconds = seconds);
    }

    tick();
    _sessionTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => tick(),
    );
  }

  Future<void> _finalizeSessionIfExpired(String sessionId) async {
    if (_isFinalizingSession) return;
    _isFinalizingSession = true;

    try {
      await AttendanceService.finalizeSessionAttendance(sessionId);
      if (mounted) {
        setState(() {});
      }
    } catch (_) {
      // The scheduled Firebase function is the server-side fallback when
      // the teacher app cannot finalize the session itself.
    } finally {
      _isFinalizingSession = false;
    }
  }

  String _formatRemaining(int seconds) {
    final safe = seconds < 0 ? 0 : seconds;
    final hours = safe ~/ 3600;
    final minutes = (safe % 3600) ~/ 60;
    final secs = safe % 60;

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    }

    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  Widget _buildTabs() {
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
            child: _tabButton(
              label: 'Scan QR',
              icon: Icons.qr_code_scanner_rounded,
              selected: _selectedTab == 0,
              onTap: () => _selectTab(0),
            ),
          ),
          Expanded(
            child: _tabButton(
              label: 'Generate QR',
              icon: Icons.qr_code_2_rounded,
              selected: _selectedTab == 1,
              onTap: () => _selectTab(1),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tabButton({
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
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
              label,
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

  Widget _buildScanTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Container(
            width: MediaQuery.widthOf(context) * 0.85,
            height: MediaQuery.heightOf(context) * 0.4,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              gradient: const LinearGradient(
                colors: [Colorpalatte.ojtcolor, Colorpalatte.secondary],
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final size = Size(
                    constraints.maxWidth,
                    constraints.maxHeight,
                  );
                  final cutoutSize = size.shortestSide * 0.6;
                  final scanWindow = Rect.fromCenter(
                    center: Offset(size.width / 2, size.height / 2),
                    width: cutoutSize,
                    height: cutoutSize,
                  );

                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      MobileScanner(
                        controller: controller,
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
        const Center(
          child: Text(
            'Point your camera at a personal Student QR code to scan',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'K2D',
              fontSize: AppFontSize.subtitle,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: Colorpalatte.containercolor,
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ValueListenableBuilder(
                    valueListenable: controller,
                    builder: (context, state, _) {
                      final torchOn = state.torchState == TorchState.on;

                      return Row(
                        children: [
                          IconButton(
                            onPressed: () => controller.toggleTorch(),
                            icon: Icon(
                              torchOn
                                  ? Icons.bolt_rounded
                                  : Icons.bolt_outlined,
                            ),
                            color: torchOn
                                ? Colorpalatte.accentcolor
                                : Colorpalatte.mutedcolor,
                            style: IconButton.styleFrom(
                              backgroundColor: Colorpalatte.maincolor,
                              shape: const CircleBorder(),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          const Text(
                            'Flash',
                            style: TextStyle(
                              fontFamily: 'K2D',
                              fontSize: AppFontSize.caption,
                              color: Colorpalatte.mutedcolor,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  Row(
                    children: [
                      Text(
                        'Late Mode',
                        style: TextStyle(
                          fontFamily: 'K2D',
                          fontSize: AppFontSize.caption,
                          fontWeight: _lateMode
                              ? FontWeight.w700
                              : FontWeight.w400,
                          color: _lateMode
                              ? Colorpalatte.errorcolor
                              : Colorpalatte.mutedcolor,
                        ),
                      ),
                      Switch(
                        value: _lateMode,
                        activeThumbColor: Colorpalatte.errorcolor,
                        onChanged: (v) => setState(() => _lateMode = v),
                      ),
                    ],
                  ),
                ],
              ),
              const Divider(height: AppSpacing.lg),
              TextField(
                controller: _manualIdController,
                focusNode: _manualIdFocusNode,
                maxLength: 14,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  counterText: '',
                  hintText: '06-1234-567890',
                  prefixIcon: const Icon(Icons.badge_outlined),
                  filled: true,
                  fillColor: Colorpalatte.maincolor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              ElevatedButton.icon(
                onPressed: _isMarkingAbsent ? null : _markAbsentees,
                icon: _isMarkingAbsent
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colorpalatte.errorcolor,
                        ),
                      )
                    : const Icon(
                        Icons.person_off_rounded,
                        color: Colorpalatte.errorcolor,
                      ),
                label: Text(
                  _isMarkingAbsent ? 'Marking...' : 'Mark as Absent',
                  style: const TextStyle(color: Colorpalatte.errorcolor),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colorpalatte.errorcolor.withValues(
                    alpha: 0.1,
                  ),
                  foregroundColor: Colorpalatte.errorcolor,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    side: const BorderSide(color: Colorpalatte.errorcolor),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGeneratorTab() {
    return FutureBuilder<List<AttendanceSessionClass>>(
      future: _classesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return _GeneratorMessage(
            icon: Icons.error_outline_rounded,
            color: Colorpalatte.errorcolor,
            title: 'Class list unavailable',
            message:
                'The teacher class list could not be loaded. Check Firestore permissions and your connection.',
            onRetry: () {
              setState(() {
                _classesFuture = AttendanceService.loadTeacherClasses();
              });
            },
          );
        }

        final classes = snapshot.data ?? [];

        if (classes.isEmpty) {
          return const _GeneratorMessage(
            icon: Icons.groups_2_outlined,
            color: Colorpalatte.mutedcolor,
            title: 'No classes found',
            message:
                'Add students with program, year, and section information before generating a session QR.',
          );
        }

        AttendanceSessionClass? selected;
        for (final item in classes) {
          if (item.classId == _selectedClassId) {
            selected = item;
            break;
          }
        }

        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Generate Session QR',
                style: TextStyle(
                  fontFamily: 'K2D',
                  fontSize: AppFontSize.title,
                  fontWeight: FontWeight.w700,
                  color: Colorpalatte.secondary,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              const Text(
                'Create one temporary attendance QR for a specific class/session. The QR contains a random session ID and must be validated against Firestore.',
                style: TextStyle(
                  fontSize: AppFontSize.caption,
                  color: Colorpalatte.mutedcolor,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              DropdownButtonFormField<String>(
                initialValue: _selectedClassId,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: 'Class / Section',
                  filled: true,
                  fillColor: Colorpalatte.containercolor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    borderSide: BorderSide.none,
                  ),
                ),
                items: classes
                    .map(
                      (item) => DropdownMenuItem(
                        value: item.classId,
                        child: Text(
                          '${item.label}  •  ${item.studentCount} students',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedClassId = value;
                    _sessionTimer?.cancel();
                    _generatedPayload = null;
                    _generatedClass = null;
                    _generatedExpiresAt = null;
                    _generatedSessionId = null;
                    _remainingSessionSeconds = 0;
                  });
                },
              ),
              const SizedBox(height: AppSpacing.sm),
              DropdownButtonFormField<int>(
                initialValue: _presentWindowMinutes,
                decoration: InputDecoration(
                  labelText: 'Present window',
                  filled: true,
                  fillColor: Colorpalatte.containercolor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    borderSide: BorderSide.none,
                  ),
                ),
                items: const [
                  DropdownMenuItem(value: 10, child: Text('10 minutes')),
                  DropdownMenuItem(value: 20, child: Text('20 minutes')),
                  DropdownMenuItem(value: 30, child: Text('30 minutes')),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _presentWindowMinutes = value);
                },
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'After the present window, students have an additional ${AttendanceService.lateWindowMinutes} minutes to be marked Late. After that, the session closes and remaining students are automatically finalized.',
                style: const TextStyle(
                  fontSize: AppFontSize.caption,
                  color: Colorpalatte.mutedcolor,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _isGenerating ? null : _generateSessionQr,
                  icon: _isGenerating
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colorpalatte.maincolor,
                          ),
                        )
                      : const Icon(Icons.qr_code_2_rounded),
                  label: Text(
                    _isGenerating ? 'Generating...' : 'Generate QR Code',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colorpalatte.secondary,
                    foregroundColor: Colorpalatte.maincolor,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              if (_generatedPayload != null &&
                  _generatedClass != null &&
                  _generatedExpiresAt != null)
                _buildGeneratedQrCard(selected: selected ?? _generatedClass!)
              else
                _buildGeneratorPlaceholder(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildGeneratorPlaceholder() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xl,
      ),
      decoration: BoxDecoration(
        color: Colorpalatte.containercolor,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: const Column(
        children: [
          Icon(
            Icons.qr_code_2_rounded,
            size: 72,
            color: Colorpalatte.mutedcolor,
          ),
          SizedBox(height: AppSpacing.sm),
          Text(
            'No active session QR',
            style: TextStyle(
              fontFamily: 'K2D',
              fontSize: AppFontSize.subtitle,
              fontWeight: FontWeight.w700,
              color: Colorpalatte.secondary,
            ),
          ),
          SizedBox(height: AppSpacing.xs),
          Text(
            'Select a class and generate a QR code.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: AppFontSize.caption,
              color: Colorpalatte.mutedcolor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGeneratedQrCard({required AttendanceSessionClass selected}) {
    final expiresAt = _generatedExpiresAt!;
    final expired = !expiresAt.isAfter(DateTime.now());
    final presentUntil = expiresAt.subtract(
      const Duration(minutes: AttendanceService.lateWindowMinutes),
    );
    final remaining = _remainingSessionSeconds;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colorpalatte.containercolor,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      expired ? 'Session Ended' : 'Active Session',
                      style: const TextStyle(
                        fontFamily: 'K2D',
                        fontSize: AppFontSize.subtitle,
                        fontWeight: FontWeight.w700,
                        color: Colorpalatte.secondary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      selected.label,
                      style: const TextStyle(
                        fontSize: AppFontSize.caption,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                expired ? Icons.timer_off_rounded : Icons.timer_rounded,
                color: expired
                    ? Colorpalatte.errorcolor
                    : Colorpalatte.accentcolor,
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                expired ? 'Expired' : _formatRemaining(remaining),
                style: TextStyle(
                  fontFamily: 'K2D',
                  fontSize: AppFontSize.caption,
                  fontWeight: FontWeight.w700,
                  color: expired
                      ? Colorpalatte.errorcolor
                      : Colorpalatte.secondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: _sessionWindowChip(
                  'Present',
                  DateFormat('hh:mm a').format(presentUntil),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: _sessionWindowChip(
                  'Late',
                  DateFormat('hh:mm a').format(expiresAt),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: Colorpalatte.maincolor,
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            child: QrImageView(
              data: _generatedPayload!,
              size: MediaQuery.widthOf(context) * .64,
              backgroundColor: Colorpalatte.maincolor,
              errorCorrectionLevel: QrErrorCorrectLevel.M,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            expired
                ? 'This QR is no longer valid. Remaining students have been finalized automatically.'
                : 'Ask students to scan this QR. The first ${_presentWindowMinutes} minutes are Present, followed by ${AttendanceService.lateWindowMinutes} minutes for Late.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: AppFontSize.caption,
              color: expired
                  ? Colorpalatte.errorcolor
                  : Colorpalatte.mutedcolor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sessionWindowChip(String label, String time) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: Colorpalatte.maincolor,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'K2D',
              fontSize: AppFontSize.caption,
              fontWeight: FontWeight.w700,
              color: Colorpalatte.secondary,
            ),
          ),
          Text(
            'until $time',
            style: const TextStyle(
              fontSize: 11,
              color: Colorpalatte.mutedcolor,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.xl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Attendance Scanner',
            style: TextStyle(
              fontFamily: 'K2D',
              fontSize: AppFontSize.display,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          _buildTabs(),
          const SizedBox(height: AppSpacing.md),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: _selectedTab == 0
                ? KeyedSubtree(
                    key: const ValueKey('scan'),
                    child: _buildScanTab(),
                  )
                : KeyedSubtree(
                    key: const ValueKey('generate'),
                    child: _buildGeneratorTab(),
                  ),
          ),
        ],
      ),
    );
  }
}

class _GeneratorMessage extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String message;
  final VoidCallback? onRetry;

  const _GeneratorMessage({
    required this.icon,
    required this.color,
    required this.title,
    required this.message,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: Colorpalatte.containercolor,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        children: [
          Icon(icon, size: 56, color: color),
          const SizedBox(height: AppSpacing.sm),
          Text(
            title,
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
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: AppFontSize.caption,
              color: Colorpalatte.mutedcolor,
              height: 1.35,
            ),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: AppSpacing.md),
            ElevatedButton(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colorpalatte.secondary,
                foregroundColor: Colorpalatte.maincolor,
              ),
              child: const Text('Retry'),
            ),
          ],
        ],
      ),
    );
  }
}
