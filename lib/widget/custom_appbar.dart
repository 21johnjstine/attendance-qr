import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:simpleattendancechecker/constants/app_sizing.dart';
import 'package:simpleattendancechecker/constants/color_palatte.dart';
import 'package:simpleattendancechecker/constants/shadow_card.dart';
import 'package:simpleattendancechecker/services/biometric_service.dart';
import 'package:simpleattendancechecker/services/csv_service.dart';

class CustomAppbar extends StatefulWidget implements PreferredSizeWidget {
  const CustomAppbar({super.key});

  @override
  State<CustomAppbar> createState() => _CustomAppbarState();

  @override
  Size get preferredSize => const Size.fromHeight(90);
}

class _CustomAppbarState extends State<CustomAppbar> {
  bool _fingerprintEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadPreference();
  }

  Future<void> _loadPreference() async {
    final enabled = await BiometricService.isEnabled();
    if (mounted) setState(() => _fingerprintEnabled = enabled);
  }

  Future<void> _toggleFingerprint() async {
    if (!_fingerprintEnabled) {
      final supported = await BiometricService.isDeviceSupported();
      if (!supported) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No biometrics are set up on this device.'),
            ),
          );
        }
        return;
      }
    }
    final newValue = !_fingerprintEnabled;
    await BiometricService.setEnabled(newValue);
    if (mounted) setState(() => _fingerprintEnabled = newValue);
  }

  Future<void> _handleSignOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colorpalatte.maincolor,
        title: const Text(
          'Sign out?',
          style: TextStyle(
            fontFamily: 'K2D',
            fontWeight: FontWeight.w700,
          ),
        ),
        content: const Text(
          'You will return to the login screen after signing out.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await FirebaseAuth.instance.signOut();
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? 'Could not sign out.')),
      );
    }
  }

  void _showLoadingDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: AppSpacing.md),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
  }

  Future<void> _showResultDialog(
    ImportResult result, {
    required String Function(int) successMessage,
  }) async {
    if (!mounted) return;
    Navigator.pop(context); // close the loading dialog
    if (result.cancelledByUser) return;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(result.success ? 'Success' : 'Error'),
        content: Text(
          result.success
              ? successMessage(result.count)
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

  Future<ExportFormat?> _askExportFormat() {
    return showDialog<ExportFormat>(
      context: context,
      builder: (context) => AlertDialog(
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
  }

  Future<void> _handleImportStudents() async {
    _showLoadingDialog('Importing student data...');
    final result = await CsvService.importStudents();
    await _showResultDialog(
      result,
      successMessage: (n) => '$n student record(s) imported successfully.',
    );
  }

  Future<void> _handleExportStudents() async {
    final format = await _askExportFormat();
    if (format == null) return;
    _showLoadingDialog('Exporting student data...');
    final result = await CsvService.exportStudents(format: format);
    await _showResultDialog(
      result,
      successMessage: (n) => '$n student record(s) exported successfully.',
    );
  }

  Future<void> _handleImportAttendance() async {
    _showLoadingDialog('Importing attendance log...');
    final result = await CsvService.importAttendance();
    await _showResultDialog(
      result,
      successMessage: (n) => '$n attendance record(s) imported successfully.',
    );
  }

  Future<void> _handleExportAttendance() async {
    final format = await _askExportFormat();
    if (format == null) return;
    _showLoadingDialog('Exporting attendance log...');
    final result = await CsvService.exportAttendance(format: format);
    await _showResultDialog(
      result,
      successMessage: (n) => '$n attendance record(s) exported successfully.',
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
        width: double.infinity,
        height: MediaQuery.heightOf(context) * 0.08,
        decoration: BoxDecoration(color: Colorpalatte.maincolor),
        child: Row(
          spacing: 10,
          children: [
            Container(
              width: MediaQuery.widthOf(context) * 0.11,
              height: MediaQuery.heightOf(context) * 0.11,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colorpalatte.secondary, width: 2),
              ),
              child: ClipOval(
                child: Image(
                  image: AssetImage('lib/assets/logo.png'),
                  fit: BoxFit.scaleDown,
                ),
              ),
            ),
            const Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Welcome to',
                    style: TextStyle(
                      fontFamily: 'K2D',
                      fontSize: AppFontSize.body,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  Text(
                    'Attendance Checker',
                    style: TextStyle(
                      fontFamily: 'K2D',
                      fontSize: AppFontSize.subtitle,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: MediaQuery.widthOf(context) * 0.09,
              height: MediaQuery.heightOf(context) * 0.04,
              decoration: BoxDecoration(
                color: Colorpalatte.containercolor,
                borderRadius: BorderRadius.circular(AppRadius.sm),
                boxShadow: ShadowCard.card
              ),
              child: PopupMenuButton<String>(
                color: Colorpalatte.maincolor,
                padding: EdgeInsets.zero,
                icon: const Icon(Icons.settings_rounded),
                onSelected: (value) {
                  switch (value) {
                    case 'fingerprint':
                      _toggleFingerprint();
                      break;
                    case 'import_students':
                      _handleImportStudents();
                      break;
                    case 'export_students':
                      _handleExportStudents();
                      break;
                    case 'import_attendance':
                      _handleImportAttendance();
                      break;
                    case 'export_attendance':
                      _handleExportAttendance();
                      break;
                    case 'sign_out':
                      _handleSignOut();
                      break;
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'fingerprint',
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Enable Fingerprint'),
                        Icon(
                          _fingerprintEnabled
                              ? Icons.check_box
                              : Icons.check_box_outline_blank,
                          color: Colorpalatte.secondary,
                        ),
                      ],
                    ),
                  ),
                  const PopupMenuDivider(),
                  const PopupMenuItem(
                    value: 'import_students',
                    child: Row(
                      children: [
                        Icon(Icons.file_upload_outlined),
                        SizedBox(width: AppSpacing.xs),
                        Text('Import Student Data'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'export_students',
                    child: Row(
                      children: [
                        Icon(Icons.file_download_outlined),
                        SizedBox(width: AppSpacing.xs),
                        Text('Export Student Data'),
                      ],
                    ),
                  ),
                  const PopupMenuDivider(),
                  const PopupMenuItem(
                    value: 'import_attendance',
                    child: Row(
                      children: [
                        Icon(Icons.file_upload_outlined),
                        SizedBox(width: AppSpacing.xs),
                        Text('Import Attendance Log'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'export_attendance',
                    child: Row(
                      children: [
                        Icon(Icons.file_download_outlined),
                        SizedBox(width: AppSpacing.xs),
                        Text('Export Attendance Log'),
                      ],
                    ),
                  ),
                  const PopupMenuDivider(),
                  const PopupMenuItem(
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
