import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:simpleattendancechecker/constants/app_sizing.dart';
import 'package:simpleattendancechecker/constants/color_palatte.dart';
import 'package:simpleattendancechecker/screen/auth/pages/login_screen.dart';
import 'package:simpleattendancechecker/screen/home/pages/home.dart';
import 'package:simpleattendancechecker/screen/student/pages/student_home.dart';
import 'package:simpleattendancechecker/services/auth_service.dart';
import 'package:simpleattendancechecker/services/biometric_service.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: AuthService.authStateChanges(),
      builder: (context, authSnapshot) {
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const _LoadingScreen();
        }

        if (authSnapshot.hasError) {
          return const _ErrorScreen(
            title: 'Authentication unavailable',
            message: 'The Firebase Authentication state could not be loaded.',
          );
        }

        final user = authSnapshot.data;
        if (user == null) return const LoginScreen();

        return _RoleGate(user: user);
      },
    );
  }
}

class _RoleGate extends StatefulWidget {
  final User user;

  const _RoleGate({required this.user});

  @override
  State<_RoleGate> createState() => _RoleGateState();
}

class _RoleGateState extends State<_RoleGate> {
  late Future<String?> _roleFuture;

  @override
  void initState() {
    super.initState();
    _roleFuture = AuthService.getRole(widget.user);
  }

  void _retry() {
    setState(() => _roleFuture = AuthService.getRole(widget.user));
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: _roleFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _LoadingScreen(message: 'Loading your account...');
        }

        if (snapshot.hasError) {
          return _ErrorScreen(
            title: 'Unable to load account role',
            message: _friendlyRoleError(snapshot.error),
            onRetry: _retry,
            showSignOut: true,
          );
        }

        switch (snapshot.data) {
          case 'teacher':
            return const _TeacherGate();
          case 'student':
            return const _StudentGate();
          default:
            return _ErrorScreen(
              title: 'Account role missing',
              message:
                  'Your Firebase account is authenticated, but users/${widget.user.uid} does not contain a valid teacher or student role.',
              onRetry: _retry,
              showSignOut: true,
            );
        }
      },
    );
  }

  String _friendlyRoleError(Object? error) {
    final text = error?.toString().toLowerCase() ?? '';
    if (text.contains('permission-denied')) {
      return 'Firestore denied access to your users profile. Check the users/{uid} read rule.';
    }
    if (text.contains('network')) {
      return 'A network error occurred while loading your profile.';
    }
    return 'Your account role could not be loaded. Please try again.';
  }
}

class _TeacherGate extends StatefulWidget {
  const _TeacherGate();

  @override
  State<_TeacherGate> createState() => _TeacherGateState();
}

class _TeacherGateState extends State<_TeacherGate> {
  late Future<bool> _future;

  @override
  void initState() {
    super.initState();
    _future = _authenticateIfEnabled();
  }

  Future<bool> _authenticateIfEnabled() async {
    final enabled = await BiometricService.isEnabled();
    if (!enabled) return true;

    final supported = await BiometricService.isDeviceSupported();
    if (!supported) return false;

    return BiometricService.authenticate();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _LoadingScreen(message: 'Verifying your account...');
        }

        if (snapshot.data != true) {
          return _ErrorScreen(
            title: 'Verification required',
            message:
                'Biometric verification is enabled for the teacher account. Verify again or sign out.',
            onRetry: () {
              setState(() => _future = _authenticateIfEnabled());
            },
            showSignOut: true,
          );
        }

        return const Home();
      },
    );
  }
}

class _StudentGate extends StatefulWidget {
  const _StudentGate();

  @override
  State<_StudentGate> createState() => _StudentGateState();
}

class _StudentGateState extends State<_StudentGate> {
  late Future<StudentProfile> _future;

  @override
  void initState() {
    super.initState();
    final user = AuthService.currentUser;
    _future = user == null
        ? Future<StudentProfile>.error(
            const AuthProfileException('No authenticated user was found.'),
          )
        : AuthService.getStudentProfile(user);
  }

  void _retry() {
    final user = AuthService.currentUser;
    setState(() {
      _future = user == null
          ? Future<StudentProfile>.error(
              const AuthProfileException('No authenticated user was found.'),
            )
          : AuthService.getStudentProfile(user);
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<StudentProfile>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _LoadingScreen(message: 'Loading student profile...');
        }

        if (snapshot.hasError || snapshot.data == null) {
          final error = snapshot.error;
          return _ErrorScreen(
            title: 'Student profile unavailable',
            message: error is AuthProfileException
                ? error.message
                : 'Your student profile could not be loaded from Firestore.',
            onRetry: _retry,
            showSignOut: true,
          );
        }

        return StudentHome(profile: snapshot.data!);
      },
    );
  }
}

class _LoadingScreen extends StatelessWidget {
  final String message;

  const _LoadingScreen({this.message = 'Checking your account...'});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colorpalatte.maincolor,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 70,
              height: 70,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colorpalatte.secondary,
                  width: 2,
                ),
              ),
              child: ClipOval(
                child: Image.asset(
                  'lib/assets/logo.png',
                  fit: BoxFit.contain,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            const CircularProgressIndicator(
              color: Colorpalatte.secondary,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              message,
              style: const TextStyle(
                color: Colorpalatte.mutedcolor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorScreen extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback? onRetry;
  final bool showSignOut;

  const _ErrorScreen({
    required this.title,
    required this.message,
    this.onRetry,
    this.showSignOut = false,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colorpalatte.maincolor,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
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
                      Icons.error_outline_rounded,
                      color: Colorpalatte.errorcolor,
                      size: 44,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      title,
                      style: const TextStyle(
                        fontFamily: 'K2D',
                        fontSize: AppFontSize.title,
                        fontWeight: FontWeight.w700,
                        color: Colorpalatte.secondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      message,
                      style: const TextStyle(
                        color: Colorpalatte.mutedcolor,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (showSignOut)
                          TextButton(
                            onPressed: () => AuthService.signOut(),
                            child: const Text('Sign out'),
                          ),
                        if (onRetry != null)
                          ElevatedButton(
                            onPressed: onRetry,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colorpalatte.secondary,
                              foregroundColor: Colorpalatte.maincolor,
                            ),
                            child: const Text('Try again'),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
