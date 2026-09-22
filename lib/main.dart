import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:simpleattendancechecker/constants/app_sizing.dart';
import 'package:simpleattendancechecker/constants/color_palatte.dart';
import 'package:simpleattendancechecker/firebase_options.dart';
import 'package:simpleattendancechecker/screen/auth/pages/auth_gate.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
  } catch (e, stackTrace) {
    runApp(
      FirebaseStartupErrorApp(
        error: e,
        stackTrace: stackTrace,
      ),
    );
    return;
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Attendance Checker',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'K2D',
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colorpalatte.accentcolor,
          primary: Colorpalatte.secondary,
          surface: Colorpalatte.maincolor,
        ),
        scaffoldBackgroundColor: Colorpalatte.maincolor,
        textSelectionTheme: TextSelectionThemeData(
          cursorColor: Colorpalatte.secondary,
          selectionColor:
              Colorpalatte.secondary.withValues(alpha: 0.3),
          selectionHandleColor: Colorpalatte.secondary,
        ),
        chipTheme: ChipThemeData(
          checkmarkColor: Colorpalatte.maincolor,
          selectedColor: Colorpalatte.secondary,
          backgroundColor: Colorpalatte.containercolor,
          labelStyle: const TextStyle(
            fontFamily: 'K2D',
            fontWeight: FontWeight.w700,
          ),
          side: BorderSide.none,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
        ),
      ),
      home: const AuthGate(),
    );
  }
}

class FirebaseStartupErrorApp extends StatelessWidget {
  final Object error;
  final StackTrace stackTrace;

  const FirebaseStartupErrorApp({
    super.key,
    required this.error,
    required this.stackTrace,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Attendance Checker',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'K2D',
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colorpalatte.accentcolor,
          primary: Colorpalatte.secondary,
        ),
      ),
      home: Scaffold(
        backgroundColor: Colorpalatte.maincolor,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Container(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: Colorpalatte.containercolor,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.cloud_off_rounded,
                        color: Colorpalatte.errorcolor,
                        size: 48,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      const Text(
                        'Firebase initialization failed',
                        style: TextStyle(
                          fontFamily: 'K2D',
                          fontSize: AppFontSize.title,
                          fontWeight: FontWeight.w700,
                          color: Colorpalatte.secondary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      const Text(
                        'The application could not initialize Firebase. Check firebase_options.dart and the platform Firebase configuration.',
                        style: TextStyle(
                          color: Colorpalatte.mutedcolor,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        error.toString(),
                        style: const TextStyle(
                          fontSize: AppFontSize.caption,
                          color: Colorpalatte.errorcolor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
