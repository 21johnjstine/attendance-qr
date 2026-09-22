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
    final yearDigits =
        RegExp(r'^\d+').firstMatch(year)?.group(0) ?? year;
    return '$program $yearDigits-$section';
  }

  AttendanceSessionClass copyWith({
    int? studentCount,
  }) {
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
  final String status;
  final DateTime createdAt;

  const ActiveAttendanceSession({
    required this.payload,
    required this.expiresAt,
    required this.program,
    required this.year,
    required this.section,
    required this.status,
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
  final DateTime expiresAt;
  final String program;
  final String year;
  final String section;
  final String defaultStatus;
  final String createdBy;

  const AttendanceSession({
    required this.payload,
    required this.expiresAt,
    required this.program,
    required this.year,
    required this.section,
    required this.defaultStatus,
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
    return AttendanceWriteResult(
      success: false,
      message: message,
    );
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

  static Future<String> createSession({
    required AttendanceSessionClass selectedClass,
    required int validityMinutes,
    required String status,
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

    if (validityMinutes <= 0) {
      throw const AttendanceServiceException(
        'Session validity must be greater than zero minutes.',
      );
    }

    final normalizedStatus = status == 'Late' ? 'Late' : 'Present';
    final now = DateTime.now();
    final date = dateString(now);
    final sessionRef = _firestore.collection('sessions').doc();
    final expiresAt = now.add(Duration(minutes: validityMinutes));

    // There should be one active session per teacher. Older active sessions
    // are deactivated, but the new session gets its own random ID.
    final previous = await _firestore
        .collection('sessions')
        .where('createdBy', isEqualTo: user.uid)
        .get();

    final batch = _firestore.batch();
    for (final doc in previous.docs) {
      final data = doc.data();
      if (data['active'] == true) {
        batch.update(doc.reference, {
          'active': false,
          'deactivatedAt': FieldValue.serverTimestamp(),
        });
      }
    }

    final payload = SessionQrPayload(
      version: 1,
      type: 'attendance_session',
      sessionId: sessionRef.id,
      date: date,
      classId: selectedClass.classId,
    );

    batch.set(sessionRef, {
      'version': 1,
      'type': 'attendance_session',
      'sessionId': sessionRef.id,
      'date': date,
      'classId': selectedClass.classId,
      'program': selectedClass.program,
      'year': selectedClass.year,
      'section': selectedClass.section,
      'defaultStatus': normalizedStatus,
      'createdBy': user.uid,
      'createdAt': FieldValue.serverTimestamp(),
      'expiresAt': Timestamp.fromDate(expiresAt),
      'active': true,
    });

    await batch.commit();
    return payload.toJson();
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

      if (type != 'attendance_session' ||
          (version is num ? version.toInt() : 1) != 1 ||
          date != _today() ||
          classId.isEmpty ||
          sessionId.isEmpty) {
        continue;
      }

      final program = (data['program'] ?? '').toString().trim();
      final year = (data['year'] ?? '').toString().trim();
      final section = (data['section'] ?? '').toString().trim();

      if (program.isEmpty || year.isEmpty || section.isEmpty) continue;

      final createdAtValue = data['createdAt'];
      final createdAt = createdAtValue is Timestamp
          ? createdAtValue.toDate()
          : expiresAt.subtract(const Duration(minutes: 15));

      final candidate = ActiveAttendanceSession(
        payload: SessionQrPayload(
          version: version is num ? version.toInt() : 1,
          type: type,
          sessionId: sessionId,
          date: date,
          classId: classId,
        ),
        expiresAt: expiresAt,
        program: program,
        year: year,
        section: section,
        status: (data['defaultStatus'] ?? 'Present').toString() == 'Late'
            ? 'Late'
            : 'Present',
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
    if (payload.version != 1) {
      throw const AttendanceServiceException(
        'This QR code uses an unsupported version.',
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

    final expiresAtValue = data['expiresAt'];
    if (expiresAtValue is! Timestamp) {
      throw const AttendanceServiceException(
        'This attendance session has no valid expiration time.',
      );
    }

    if (!expiresAtValue.toDate().isAfter(DateTime.now())) {
      throw const AttendanceServiceException(
        'This attendance QR has expired. Ask the teacher for a new QR code.',
      );
    }

    final createdBy = (data['createdBy'] ?? '').toString();
    final program = (data['program'] ?? '').toString();
    final year = (data['year'] ?? '').toString();
    final section = (data['section'] ?? '').toString();
    final defaultStatus = (data['defaultStatus'] ?? 'Present').toString();

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
      expiresAt: expiresAtValue.toDate(),
      program: program,
      year: year,
      section: section,
      defaultStatus: defaultStatus == 'Late' ? 'Late' : 'Present',
      createdBy: createdBy,
    );
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

      // Read this student's records only and detect any attendance already
      // recorded today, including a record created by the teacher scanner.
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
      final status = session.defaultStatus;

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
}
