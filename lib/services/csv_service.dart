import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:csv/csv.dart';
import 'package:excel/excel.dart' as xl;
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';

enum ExportFormat { csv, excel }

class ImportResult {
  final bool success;
  final bool cancelledByUser;
  final int count;
  final String? errorMessage;

  ImportResult._({
    required this.success,
    required this.cancelledByUser,
    required this.count,
    this.errorMessage,
  });

  factory ImportResult.success(int count) =>
      ImportResult._(success: true, cancelledByUser: false, count: count);

  factory ImportResult.error(String message) => ImportResult._(
    success: false,
    cancelledByUser: false,
    count: 0,
    errorMessage: message,
  );

  factory ImportResult.cancelled() =>
      ImportResult._(success: false, cancelledByUser: true, count: 0);
}

class CsvService {
  // ── 🔧 Column detection helpers ────────────────────────────────────
  static int _colFor(List<String> header, List<String> keywords) {
    for (var i = 0; i < header.length; i++) {
      final h = header[i].toLowerCase();
      if (keywords.any((k) => h.contains(k))) return i;
    }
    return -1;
  }

  static String _cell(List<dynamic> row, int col) {
    if (col == -1 || col >= row.length) return '';
    return row[col]?.toString().trim() ?? '';
  }

  static String _excelCellToString(dynamic cellValue) {
    if (cellValue == null) return '';
    try {
      final v = (cellValue as dynamic).value;
      if (v != null) return v.toString().trim();
    } catch (_) {
      // fall through to toString() below
    }
    return cellValue.toString().trim();
  }

  // ── 📄 Pick + parse — accepts BOTH .csv and .xlsx ──────────────────
  static Future<List<List<dynamic>>?> _pickAndParseSpreadsheet() async {
    final picked = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv', 'xlsx'],
      withData: true,
    );
    if (picked == null || picked.files.isEmpty) return null;

    final file = picked.files.first;
    final bytes = file.bytes;
    if (bytes == null) return null;

    final fileName = file.name.toLowerCase();

    if (fileName.endsWith('.xlsx')) {
      final excel = xl.Excel.decodeBytes(bytes);
      if (excel.tables.isEmpty) return [];
      final sheet = excel.tables[excel.tables.keys.first]!;
      return sheet.rows
          .map(
            (row) =>
                row.map((cell) => _excelCellToString(cell?.value)).toList(),
          )
          .toList();
    }

    final content = utf8.decode(bytes, allowMalformed: true);
    return csv.decode(content);
  }

  // ── 💾 Generate the file bytes/name based on the chosen format ─────
  static Future<String?> _saveRows(
    List<List<String>> rows,
    String baseFileName,
    ExportFormat format,
  ) async {
    if (format == ExportFormat.excel) {
      final excel = xl.Excel.createExcel();
      final sheetName = excel.tables.keys.isNotEmpty
          ? excel.tables.keys.first
          : 'Sheet1';
      final sheet = excel[sheetName];
      for (final row in rows) {
        sheet.appendRow(row.map((s) => xl.TextCellValue(s)).toList());
      }
      final bytes = excel.save();
      if (bytes == null) return null;
      return FilePicker.saveFile(
        dialogTitle: 'Save Export',
        fileName: '$baseFileName.xlsx',
        bytes: Uint8List.fromList(bytes),
      );
    }

    final csvString = csv.encode(rows);
    return FilePicker.saveFile(
      dialogTitle: 'Save Export',
      fileName: '$baseFileName.csv',
      bytes: Uint8List.fromList(utf8.encode(csvString)),
    );
  }

  // ── 📥 Import Student Data (.csv or .xlsx) ─────────────────────────
  static Future<ImportResult> importStudents() async {
    try {
      final rows = await _pickAndParseSpreadsheet();
      if (rows == null) return ImportResult.cancelled();
      if (rows.isEmpty) return ImportResult.error('The file is empty.');

      final header = rows.first.map((e) => e.toString().trim()).toList();
      final idCol = _colFor(header, ['student id']);
      final nameCol = _colFor(header, ['full name']);
      final emailCol = _colFor(header, ['email']);
      final yearCol = _colFor(header, ['year level', 'year']);
      final sectionCol = _colFor(header, ['section']);
      final typeCol = _colFor(header, ['student type']);
      final programCol = _colFor(header, ['program']);

      if (idCol == -1 || nameCol == -1) {
        return ImportResult.error(
          'The file is missing required columns (Student ID and Full Name).',
        );
      }

      var batch = FirebaseFirestore.instance.batch();
      int batchCount = 0;
      int imported = 0;

      for (var i = 1; i < rows.length; i++) {
        final row = rows[i];
        if (row.isEmpty || row.every((e) => e.toString().trim().isEmpty)) {
          continue;
        }

        final studentId = _cell(row, idCol);
        if (studentId.isEmpty) continue;

        final ref = FirebaseFirestore.instance
            .collection('students')
            .doc(studentId);
        final studentType = _cell(row, typeCol);

        batch.set(ref, {
          'fullName': _cell(row, nameCol),
          'email': _cell(row, emailCol),
          'year': _cell(row, yearCol),
          'section': _cell(row, sectionCol),
          'studentType': studentType.isEmpty ? 'Student' : studentType,
          'program': _cell(row, programCol),
        });
        imported++;
        batchCount++;

        if (batchCount == 450) {
          await batch.commit();
          batch = FirebaseFirestore.instance.batch();
          batchCount = 0;
        }
      }

      if (batchCount > 0) await batch.commit();
      return ImportResult.success(imported);
    } catch (e) {
      return ImportResult.error('Import failed: $e');
    }
  }

  // ── 📤 Export Student Data ─────────────────────────────────────────
  static Future<ImportResult> exportStudents({
    required ExportFormat format,
  }) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('students')
          .get();

      final rows = <List<String>>[
        [
          'Student ID',
          'Full Name',
          'Email',
          'Year Level',
          'Section',
          'Student Type',
          'Program',
        ],
      ];
      for (final doc in snapshot.docs) {
        final d = doc.data();
        rows.add([
          doc.id,
          (d['fullName'] ?? '').toString(),
          (d['email'] ?? '').toString(),
          (d['year'] ?? '').toString(),
          (d['section'] ?? '').toString(),
          (d['studentType'] ?? '').toString(),
          (d['program'] ?? '').toString(),
        ]);
      }

      final baseFileName =
          'students_export_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}';
      final savedPath = await _saveRows(rows, baseFileName, format);
      if (savedPath == null) return ImportResult.cancelled();
      return ImportResult.success(snapshot.docs.length);
    } catch (e) {
      return ImportResult.error('Export failed: $e');
    }
  }

  // ── 📥 Import Attendance Log (.csv or .xlsx) ───────────────────────
  static Future<ImportResult> importAttendance() async {
    try {
      final rows = await _pickAndParseSpreadsheet();
      if (rows == null) return ImportResult.cancelled();
      if (rows.isEmpty) return ImportResult.error('The file is empty.');

      final header = rows.first.map((e) => e.toString().trim()).toList();
      final idCol = _colFor(header, ['student id']);
      final nameCol = _colFor(header, ['full name']);
      final statusCol = _colFor(header, ['attendance status', 'status']);
      final programCol = _colFor(header, ['program']);
      final yearCol = _colFor(header, ['year']);
      final sectionCol = _colFor(header, ['section']);
      final dateCol = _colFor(header, ['date']);
      final timeCol = _colFor(header, ['time']);

      if (idCol == -1 || dateCol == -1 || statusCol == -1) {
        return ImportResult.error(
          'The file is missing required columns (Student ID, Date, and Attendance Status).',
        );
      }

      var batch = FirebaseFirestore.instance.batch();
      int batchCount = 0;
      int imported = 0;

      for (var i = 1; i < rows.length; i++) {
        final row = rows[i];
        if (row.isEmpty || row.every((e) => e.toString().trim().isEmpty)) {
          continue;
        }

        final studentId = _cell(row, idCol);
        final date = _cell(row, dateCol);
        if (studentId.isEmpty || date.isEmpty) continue;

        final time = _cell(row, timeCol).isEmpty
            ? '00:00'
            : _cell(row, timeCol);
        final status = _cell(row, statusCol).isEmpty
            ? 'Present'
            : _cell(row, statusCol);

        DateTime parsedTimestamp;
        try {
          parsedTimestamp = DateFormat('yyyy-MM-dd HH:mm').parse('$date $time');
        } catch (_) {
          parsedTimestamp = DateTime.tryParse(date) ?? DateTime.now();
        }

        final docId = '${studentId}_import_${date}_${time.replaceAll(':', '')}';
        final ref = FirebaseFirestore.instance
            .collection('attendance')
            .doc(docId);

        batch.set(ref, {
          'studentId': studentId,
          'fullName': _cell(row, nameCol),
          'attendanceStatus': status,
          'program': _cell(row, programCol),
          'year': _cell(row, yearCol),
          'section': _cell(row, sectionCol),
          'date': date,
          'time': time,
          'timestamp': Timestamp.fromDate(parsedTimestamp),
        });
        imported++;
        batchCount++;

        if (batchCount == 450) {
          await batch.commit();
          batch = FirebaseFirestore.instance.batch();
          batchCount = 0;
        }
      }

      if (batchCount > 0) await batch.commit();
      return ImportResult.success(imported);
    } catch (e) {
      return ImportResult.error('Import failed: $e');
    }
  }

  // ── 📤 Export Attendance Log ───────────────────────────────────────
  static Future<ImportResult> exportAttendance({
    required ExportFormat format,
  }) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('attendance')
          .orderBy('timestamp', descending: true)
          .get();

      final rows = <List<String>>[
        [
          'Student ID',
          'Full Name',
          'Attendance Status',
          'Program',
          'Year',
          'Section',
          'Date',
          'Time',
        ],
      ];
      for (final doc in snapshot.docs) {
        final d = doc.data();
        rows.add([
          (d['studentId'] ?? '').toString(),
          (d['fullName'] ?? '').toString(),
          (d['attendanceStatus'] ?? '').toString(),
          (d['program'] ?? '').toString(),
          (d['year'] ?? '').toString(),
          (d['section'] ?? '').toString(),
          (d['date'] ?? '').toString(),
          (d['time'] ?? '').toString(),
        ]);
      }

      final baseFileName =
          'attendance_export_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}';
      final savedPath = await _saveRows(rows, baseFileName, format);
      if (savedPath == null) return ImportResult.cancelled();
      return ImportResult.success(snapshot.docs.length);
    } catch (e) {
      return ImportResult.error('Export failed: $e');
    }
  }

  // ── 📤 Export Section Masterlist (with present/absent totals) ─────
  static Future<ImportResult> exportSectionMasterlist({
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> students,
    required String sectionLabel,
    required ExportFormat format,
  }) async {
    try {
      final studentIds = students.map((doc) => doc.id).toList();

      // ── I-tally ang Present/Late (parehong bibilangin bilang Present)
      // at Absent kada estudyante, gamit ang chunked whereIn queries ──
      final presentTally = <String, int>{};
      final absentTally = <String, int>{};

      for (var i = 0; i < studentIds.length; i += 30) {
        final chunk = studentIds.sublist(
          i,
          i + 30 > studentIds.length ? studentIds.length : i + 30,
        );
        final snap = await FirebaseFirestore.instance
            .collection('attendance')
            .where('studentId', whereIn: chunk)
            .get();

        for (final doc in snap.docs) {
          final d = doc.data();
          final id = (d['studentId'] ?? '').toString();
          final status = (d['attendanceStatus'] ?? '').toString();
          if (status == 'Present' || status == 'Late') {
            presentTally[id] = (presentTally[id] ?? 0) + 1;
          } else if (status == 'Absent') {
            absentTally[id] = (absentTally[id] ?? 0) + 1;
          }
        }
      }

      final rows = <List<String>>[
        [
          'Student ID',
          'Full Name',
          'Email',
          'Program',
          'Year',
          'Section',
          'Total Present',
          'Total Absent',
        ],
      ];

      for (final doc in students) {
        final d = doc.data();
        rows.add([
          doc.id,
          (d['fullName'] ?? '').toString(),
          (d['email'] ?? '').toString(),
          (d['program'] ?? '').toString(),
          (d['year'] ?? '').toString(),
          (d['section'] ?? '').toString(),
          '${presentTally[doc.id] ?? 0}',
          '${absentTally[doc.id] ?? 0}',
        ]);
      }

      final safeLabel = sectionLabel.replaceAll(RegExp(r'[^\w\-]+'), '_');
      final baseFileName =
          'masterlist_${safeLabel}_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}';
      final savedPath = await _saveRows(rows, baseFileName, format);
      if (savedPath == null) return ImportResult.cancelled();
      return ImportResult.success(students.length);
    } catch (e) {
      return ImportResult.error('Export failed: $e');
    }
  }
}
