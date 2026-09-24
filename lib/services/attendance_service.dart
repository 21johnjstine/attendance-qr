import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:simpleattendancechecker/services/auth_service.dart';

class SessionQrPayload {
  final int version;
  final String type;
  final String sessionId;
  final String date;
  final String classId;

  const SessionQrPayload({
    required this.version,
    required this.type,
    required this.sessionId,
    required this.date,
    required this.classId,
  });

  String toJson() => jsonEncode({
    'version': version,
    'type': type,
    'sessionId': sessionId,
    'date': date,
    'classId': classId,
  });

  static SessionQrPayload parse(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      throw const FormatException('QR payload is not a JSON object.');
    }

    final map = Map<String, dynamic>.from(decoded);
    final version = map['version'];
    final type = map['type'];
    final sessionId = map['sessionId'];
    final date = map['date'];
    final classId = map['classId'];

    if (version is! num ||
        type is! String ||
        sessionId is! String ||
        date is! String ||
        classId is! String) {
      throw const FormatException('QR payload is missing required fields.');
    }

    if (type != 'attendance_session') {
      throw const FormatException('This QR code is not an attendance session.');
    }

    if (sessionId.trim().isEmpty ||
        date.trim().isEmpty ||
        classId.trim().isEmpty) {
      throw const FormatException('QR payload contains empty session fields.');
    }

    return SessionQrPayload(
      version: version.toInt(),
      type: type,
      sessionId: sessionId.trim(),
      date: date.trim(),
      classId: classId.trim(),
    );
  }
}

class AttendanceSessionClass {
  final String classId;
  final String program;
  final String year;
  final String section;
  final int studentCount;

  const AttendanceSessionClass({
    required this.classId,
    required this.program,
    required this.year,
    required this.section,
    required this.studentCount,
  });

  String get label {
    final yearDigits = RegExp(r'^\d+').firstMatch(year)?.group(0) ?? year;
    return '$program $yearDigits-$section';
  }

  AttendanceSessionClass copyWith({int? studentCount}) {
    return AttendanceSessionClass(
      classId: classId,
      program: program,
      year: year,
      section: section,
      studentCount: studentCount ?? this.studentCount,
    );
  }
}

class ActiveAttendanceSession {
  final SessionQrPayload payload;
  final DateTime expiresAt;
  final String program;
  final String year;
  final String section;
  final int presentWindowMinutes;
  final DateTime createdAt;

  const ActiveAttendanceSession({
    required this.payload,
    required this.expiresAt,
    required this.program,
    required this.year,
    required this.section,
    required this.presentWindowMinutes,
    required this.createdAt,
  });

  AttendanceSessionClass asClass({int studentCount = 0}) {
    return AttendanceSessionClass(
      classId: payload.classId,
      program: program,
      year: year,
      section: section,
      studentCount: studentCount,
    );
  }
}

class AttendanceSession {
  final SessionQrPayload payload;
  final DateTime createdAt;
  final DateTime expiresAt;
  final String program;
  final String year;
  final String section;
  final int presentWindowMinutes;
  final int lateWindowMinutes;
  final String createdBy;

  const AttendanceSession({
    required this.payload,
    required this.createdAt,
    required this.expiresAt,
    required this.program,
    required this.year,
    required this.section,
    required this.presentWindowMinutes,
    required this.lateWindowMinutes,
    required this.createdBy,
  });
}

class AttendanceWriteResult {
  final bool success;
  final String message;
  final String? status;
  final AttendanceSession? session;

  const AttendanceWriteResult({
    required this.success,
    required this.message,
    this.status,
    this.session,
  });

  factory AttendanceWriteResult.success({
    required String message,
    required String status,
    required AttendanceSession session,
  }) {
    return AttendanceWriteResult(
      success: true,
      message: message,
      status: status,
      session: session,
    );
  }

  factory AttendanceWriteResult.failure(String message) {
    return AttendanceWriteResult(success: false, message: message);
  }
}

class AttendanceServiceException implements Exception {
  final String message;

  const AttendanceServiceException(this.message);

  @override
  String toString() => message;
}

class AttendanceService {
  AttendanceService._();

  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static String dateString(DateTime date) =>
      DateFormat('yyyy-MM-dd').format(date);

  static String _today() => dateString(DateTime.now());

  static String _yearDigits(String year) =>
      RegExp(r'^\d+').firstMatch(year)?.group(0) ?? '';

  static Future<List<AttendanceSessionClass>> loadTeacherClasses() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw const AttendanceServiceException(
        'You must be signed in to load classes.',
      );
    }

    if (await AuthService.getRole(user) != 'teacher') {
      throw const AttendanceServiceException(
        'Only teacher accounts can load classes.',
      );
    }

    final snapshot = await _firestore.collection('students').get();
    final groups = <String, AttendanceSessionClass>{};

    for (final doc in snapshot.docs) {
      final data = doc.data();
      final program = (data['program'] ?? '').toString().trim();
      final year = (data['year'] ?? '').toString().trim();
      final section = (data['section'] ?? '').toString().trim();
      final yearDigits = _yearDigits(year);

      if (program.isEmpty || yearDigits.isEmpty || section.isEmpty) continue;

      final classId = '$program|$yearDigits|$section';
      final existing = groups[classId];
      if (existing == null) {
        groups[classId] = AttendanceSessionClass(
          classId: classId,
          program: program,
          year: year,
          section: section,
          studentCount: 1,
        );
      } else {
        groups[classId] = existing.copyWith(
          studentCount: existing.studentCount + 1,
        );
      }
    }

    final result = groups.values.toList()
      ..sort((a, b) {
        final programCompare = a.program.compareTo(b.program);
        if (programCompare != 0) return programCompare;
        final yearCompare = _yearDigits(a.year).compareTo(_yearDigits(b.year));
        if (yearCompare != 0) return yearCompare;
        return a.section.compareTo(b.section);
      });

    return result;
  }

  static const int lateWindowMinutes = 30;
  static const List<int> allowedPresentWindows = [10, 20, 30];

  static Future<String> createSession({
    required AttendanceSessionClass selectedClass,
    required int presentWindowMinutes,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw const AttendanceServiceException(
        'You must be signed in to generate a session QR.',
      );
    }

    if (await AuthService.getRole(user) != 'teacher') {
      throw const AttendanceServiceException(
        'Only teacher accounts can generate session QR codes.',
      );
    }

    if (!allowedPresentWindows.contains(presentWindowMinutes)) {
      throw const AttendanceServiceException(
        'Present window must be 10, 20, or 30 minutes.',
      );
    }

    final now = DateTime.now();
    final date = dateString(now);
    final sessionRef = _firestore.collection('sessions').doc();
    final expiresAt = now.add(
      Duration(minutes: presentWindowMinutes + lateWindowMinutes),
    );

    final batch = _firestore.batch();

    final payload = SessionQrPayload(
      version: 2,
      type: 'attendance_session',
      sessionId: sessionRef.id,
      date: date,
      classId: selectedClass.classId,
    );

    final today = dateString(DateTime.now());

    final existingSessions = await _firestore
        .collection('sessions')
        .where('createdBy', isEqualTo: user.uid)
        .where('date', isEqualTo: today)
        .where('classId', isEqualTo: selectedClass.classId)
        .limit(1)
        .get();

    if (existingSessions.docs.isNotEmpty) {
      throw Exception('A session for this class already exists for today.');
    }

    batch.set(sessionRef, {
      'version': 2,
      'type': 'attendance_session',
      'sessionId': sessionRef.id,
      'date': date,
      'classId': selectedClass.classId,
      'program': selectedClass.program,
      'year': selectedClass.year,
      'section': selectedClass.section,
      'presentWindowMinutes': presentWindowMinutes,
      'lateWindowMinutes': lateWindowMinutes,
      'createdBy': user.uid,
      'createdAt': FieldValue.serverTimestamp(),
      'expiresAt': Timestamp.fromDate(expiresAt),
      'active': true,
    });

    await batch.commit();

    // Extra fields are for the teacher UI. Student QR parsing only uses the
    // standard payload fields above and reads timing from Firestore.
    return jsonEncode({
      ...jsonDecode(payload.toJson()) as Map<String, dynamic>,
      'presentWindowMinutes': presentWindowMinutes,
      'lateWindowMinutes': lateWindowMinutes,
      'createdAt': now.toIso8601String(),
      'expiresAt': expiresAt.toIso8601String(),
    });
  }

  static Future<ActiveAttendanceSession?> loadActiveTeacherSession() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    if (await AuthService.getRole(user) != 'teacher') return null;

    final snapshot = await _firestore
        .collection('sessions')
        .where('createdBy', isEqualTo: user.uid)
        .get();

    final now = DateTime.now();
    ActiveAttendanceSession? latest;

    for (final doc in snapshot.docs) {
      final data = doc.data();
      if (data['active'] != true) continue;

      final expiresAtValue = data['expiresAt'];
      if (expiresAtValue is! Timestamp) continue;
      final expiresAt = expiresAtValue.toDate();
      if (!expiresAt.isAfter(now)) continue;

      final date = (data['date'] ?? '').toString();
      final classId = (data['classId'] ?? '').toString();
      final sessionId = (data['sessionId'] ?? doc.id).toString();
      final type = (data['type'] ?? '').toString();
      final version = data['version'];
      final presentWindow = (data['presentWindowMinutes'] as num?)?.toInt();
      final lateWindow = (data['lateWindowMinutes'] as num?)?.toInt();

      if (presentWindow == null ||
          lateWindow == null ||
          type != 'attendance_session' ||
          (version is num ? version.toInt() : 1) != 2 ||
          date != _today() ||
          classId.isEmpty ||
          sessionId.isEmpty ||
          !allowedPresentWindows.contains(presentWindow) ||
          lateWindow != lateWindowMinutes) {
        continue;
      }

      final program = (data['program'] ?? '').toString().trim();
      final year = (data['year'] ?? '').toString().trim();
      final section = (data['section'] ?? '').toString().trim();

      if (program.isEmpty || year.isEmpty || section.isEmpty) continue;

      final createdAtValue = data['createdAt'];
      final createdAt = createdAtValue is Timestamp
          ? createdAtValue.toDate()
          : expiresAt.subtract(
              Duration(minutes: presentWindow + lateWindowMinutes),
            );

      final candidate = ActiveAttendanceSession(
        payload: SessionQrPayload(
          version: 2,
          type: type,
          sessionId: sessionId,
          date: date,
          classId: classId,
        ),
        expiresAt: expiresAt,
        program: program,
        year: year,
        section: section,
        presentWindowMinutes: presentWindow,
        createdAt: createdAt,
      );

      if (latest == null || candidate.createdAt.isAfter(latest.createdAt)) {
        latest = candidate;
      }
    }

    return latest;
  }

  static Future<AttendanceSession> validateSession(
    SessionQrPayload payload,
    StudentProfile profile,
  ) async {
    if (payload.version != 2) {
      throw const AttendanceServiceException(
        'This QR code uses an unsupported version. Please generate a new session QR.',
      );
    }

    final snapshot = await _firestore
        .collection('sessions')
        .doc(payload.sessionId)
        .get();

    if (!snapshot.exists) {
      throw const AttendanceServiceException(
        'This attendance session no longer exists.',
      );
    }

    final data = snapshot.data()!;
    final type = (data['type'] ?? '').toString();
    final storedSessionId = (data['sessionId'] ?? snapshot.id).toString();
    final storedDate = (data['date'] ?? '').toString();
    final storedClassId = (data['classId'] ?? '').toString();

    if (type != 'attendance_session') {
      throw const AttendanceServiceException(
        'This QR code does not point to a valid attendance session.',
      );
    }

    if (storedSessionId != payload.sessionId ||
        storedDate != payload.date ||
        storedClassId != payload.classId) {
      throw const AttendanceServiceException(
        'The QR payload does not match the attendance session record.',
      );
    }

    if (storedDate != _today()) {
      throw const AttendanceServiceException(
        'This attendance QR belongs to another date and has expired.',
      );
    }

    if (storedClassId != profile.classId) {
      throw AttendanceServiceException(
        'This session is for $storedClassId, but your account belongs to ${profile.classId}.',
      );
    }

    if (data['active'] != true) {
      throw const AttendanceServiceException(
        'This attendance session is no longer active.',
      );
    }

    final createdAtValue = data['createdAt'];
    final expiresAtValue = data['expiresAt'];
    if (createdAtValue is! Timestamp || expiresAtValue is! Timestamp) {
      throw const AttendanceServiceException(
        'This attendance session has invalid timing information.',
      );
    }

    final presentWindow = (data['presentWindowMinutes'] as num?)?.toInt();
    final lateWindow = (data['lateWindowMinutes'] as num?)?.toInt();

    if (presentWindow == null ||
        lateWindow == null ||
        !allowedPresentWindows.contains(presentWindow) ||
        lateWindow != lateWindowMinutes) {
      throw const AttendanceServiceException(
        'This attendance session has invalid timing settings.',
      );
    }

    final expiresAt = expiresAtValue.toDate();
    if (!expiresAt.isAfter(DateTime.now())) {
      throw const AttendanceServiceException(
        'This attendance QR has expired. Ask the teacher for a new QR code.',
      );
    }

    final createdBy = (data['createdBy'] ?? '').toString();
    final program = (data['program'] ?? '').toString();
    final year = (data['year'] ?? '').toString();
    final section = (data['section'] ?? '').toString();

    if (createdBy.isEmpty ||
        program.isEmpty ||
        year.isEmpty ||
        section.isEmpty) {
      throw const AttendanceServiceException(
        'The session record is incomplete.',
      );
    }

    return AttendanceSession(
      payload: payload,
      createdAt: createdAtValue.toDate(),
      expiresAt: expiresAt,
      program: program,
      year: year,
      section: section,
      presentWindowMinutes: presentWindow,
      lateWindowMinutes: lateWindow,
      createdBy: createdBy,
    );
  }

  static String _sessionStatusForStudent({
    required StudentProfile profile,
    required AttendanceSession session,
    required DateTime now,
  }) {
    final studentType = profile.studentType.trim();

    if (studentType == 'OJT' || studentType == 'Working Student') {
      return studentType;
    }

    final presentDeadline = session.createdAt.add(
      Duration(minutes: session.presentWindowMinutes),
    );

    return now.isBefore(presentDeadline) ? 'Present' : 'Late';
  }

  static Future<AttendanceWriteResult> recordStudentSessionAttendance({
    required String rawPayload,
    required StudentProfile profile,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      return AttendanceWriteResult.failure(
        'Your Firebase session is no longer active. Please sign in again.',
      );
    }

    try {
      if (await AuthService.getRole(user) != 'student') {
        return AttendanceWriteResult.failure(
          'Only student accounts can use the student session scanner.',
        );
      }

      final payload = SessionQrPayload.parse(rawPayload);
      final session = await validateSession(payload, profile);
      final today = _today();

      // Keep the existing daily attendance behavior: once a student has an
      // attendance record for today, another scan does not create a duplicate.
      final existing = await _firestore
          .collection('attendance')
          .where('studentId', isEqualTo: profile.studentId)
          .get();

      final alreadyRecordedToday = existing.docs.any(
        (doc) => doc.data()['date']?.toString() == today,
      );

      if (alreadyRecordedToday) {
        return AttendanceWriteResult.failure(
          'Your attendance has already been recorded for today.',
        );
      }

      final now = DateTime.now();
      final attendanceId = '${profile.studentId}_$today';
      final ref = _firestore.collection('attendance').doc(attendanceId);
      final status = _sessionStatusForStudent(
        profile: profile,
        session: session,
        now: now,
      );

      await ref.set({
        'studentId': profile.studentId,
        'fullName': profile.fullName,
        'attendanceStatus': status,
        'program': profile.program,
        'year': profile.year,
        'section': profile.section,
        'date': today,
        'time': DateFormat('HH:mm').format(now),
        'timestamp': FieldValue.serverTimestamp(),
        'selfScanned': true,
        'sessionId': session.payload.sessionId,
        'classId': session.payload.classId,
        'scanMethod': 'student_session_qr',
        'authUid': user.uid,
      });

      return AttendanceWriteResult.success(
        message: 'Attendance recorded successfully.',
        status: status,
        session: session,
      );
    } on FormatException {
      return AttendanceWriteResult.failure(
        'This is not a valid attendance session QR code.',
      );
    } on AttendanceServiceException catch (e) {
      return AttendanceWriteResult.failure(e.message);
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        return AttendanceWriteResult.failure(
          'Invalid QR or QR is expired. Please scan a valid active session QR code.',
        );
      }
      if (e.code == 'unavailable' || e.code == 'deadline-exceeded') {
        return AttendanceWriteResult.failure(
          'The network connection is unavailable. Please try again.',
        );
      }
      return AttendanceWriteResult.failure(
        e.message ?? 'The attendance request failed.',
      );
    } catch (_) {
      return AttendanceWriteResult.failure(
        'The attendance request could not be completed.',
      );
    }
  }

  static Future<int> finalizeSessionAttendance(String sessionId) async {
    final user = _auth.currentUser;
    if (user == null || await AuthService.getRole(user) != 'teacher') {
      throw const AttendanceServiceException(
        'Only teacher accounts can finalize attendance sessions.',
      );
    }

    final sessionRef = _firestore.collection('sessions').doc(sessionId);
    final sessionSnap = await sessionRef.get();
    if (!sessionSnap.exists) {
      throw const AttendanceServiceException(
        'The attendance session could not be found.',
      );
    }

    final data = sessionSnap.data()!;
    if (data['createdBy'] != user.uid) {
      throw const AttendanceServiceException(
        'You are not allowed to finalize this attendance session.',
      );
    }

    if (data['active'] != true) return 0;

    final expiresAtValue = data['expiresAt'];
    if (expiresAtValue is! Timestamp ||
        expiresAtValue.toDate().isAfter(DateTime.now())) {
      throw const AttendanceServiceException('The session is still active.');
    }

    final date = (data['date'] ?? '').toString();
    final program = (data['program'] ?? '').toString();
    final year = (data['year'] ?? '').toString();
    final section = (data['section'] ?? '').toString();

    if (date.isEmpty || program.isEmpty || year.isEmpty || section.isEmpty) {
      throw const AttendanceServiceException(
        'The attendance session is incomplete.',
      );
    }

    final studentsSnap = await _firestore.collection('students').get();
    final attendanceSnap = await _firestore
        .collection('attendance')
        .where('date', isEqualTo: date)
        .get();

    final loggedIds = attendanceSnap.docs
        .map((doc) => doc.data()['studentId'])
        .whereType<String>()
        .toSet();

    final candidates = studentsSnap.docs.where((doc) {
      final student = doc.data();
      return student['program']?.toString() == program &&
          student['year']?.toString() == year &&
          student['section']?.toString() == section;
    }).toList();

    final pending = <Map<String, dynamic>>[];
    for (final doc in candidates) {
      final student = doc.data();
      final studentId = doc.id;
      if (loggedIds.contains(studentId)) continue;

      final studentType = (student['studentType'] ?? 'Student').toString();
      final status = (studentType == 'OJT' || studentType == 'Working Student')
          ? studentType
          : 'Absent';

      final attendanceId = '${studentId}_$sessionId';
      pending.add({
        'ref': _firestore.collection('attendance').doc(attendanceId),
        'data': {
          'studentId': studentId,
          'fullName': student['fullName'] ?? '',
          'attendanceStatus': status,
          'program': student['program'] ?? '',
          'year': student['year'] ?? '',
          'section': student['section'] ?? '',
          'date': date,
          'time': DateFormat('HH:mm').format(DateTime.now()),
          'timestamp': FieldValue.serverTimestamp(),
          'selfScanned': false,
          'sessionId': sessionId,
          'classId': data['classId'] ?? '',
          'scanMethod': 'session_auto_finalize',
        },
      });
    }

    const chunkSize = 400;
    for (var start = 0; start < pending.length; start += chunkSize) {
      final batch = _firestore.batch();
      final end = (start + chunkSize < pending.length)
          ? start + chunkSize
          : pending.length;

      for (var i = start; i < end; i++) {
        final item = pending[i];
        batch.set(
          item['ref'] as DocumentReference<Map<String, dynamic>>,
          item['data'] as Map<String, dynamic>,
        );
      }

      batch.update(sessionRef, {
        'active': false,
        'finalizedAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();
    }

    if (pending.isEmpty) {
      await sessionRef.update({
        'active': false,
        'finalizedAt': FieldValue.serverTimestamp(),
      });
    }

    return pending.length;
  }
}
