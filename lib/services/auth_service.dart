import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class StudentProfile {
  final String studentId;
  final String fullName;
  final String email;
  final String program;
  final String year;
  final String section;
  final String studentType;

  const StudentProfile({
    required this.studentId,
    required this.fullName,
    required this.email,
    required this.program,
    required this.year,
    required this.section,
    required this.studentType,
  });

  String get yearDigits =>
      RegExp(r'^\d+').firstMatch(year)?.group(0) ?? '';

  String get classId => '$program|$yearDigits|$section';

  factory StudentProfile.fromDocument(
    String studentId,
    Map<String, dynamic> data,
  ) {
    return StudentProfile(
      studentId: studentId,
      fullName: (data['fullName'] ?? '').toString().trim(),
      email: (data['email'] ?? '').toString().trim(),
      program: (data['program'] ?? '').toString().trim(),
      year: (data['year'] ?? '').toString().trim(),
      section: (data['section'] ?? '').toString().trim(),
      studentType: (data['studentType'] ?? 'Student').toString().trim(),
    );
  }
}

class AuthProfileException implements Exception {
  final String message;

  const AuthProfileException(this.message);

  @override
  String toString() => message;
}

class AuthService {
  AuthService._();

  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static Stream<User?> authStateChanges() => _auth.authStateChanges();

  static User? get currentUser => _auth.currentUser;

  static Future<UserCredential> signIn({
    required String email,
    required String password,
  }) async {
    return _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  static Future<void> sendPasswordResetEmail(String email) {
    return _auth.sendPasswordResetEmail(email: email.trim());
  }

  static Future<void> signOut() => _auth.signOut();

  static Future<String?> getRole(User user) async {
    final snapshot = await _firestore
        .collection('users')
        .doc(user.uid)
        .get();

    if (!snapshot.exists) return null;

    final role = snapshot.data()?['role'];
    if (role is! String) return null;

    final normalized = role.trim().toLowerCase();
    if (normalized != 'teacher' && normalized != 'student') {
      return null;
    }

    return normalized;
  }

  static Future<StudentProfile> getStudentProfile(User user) async {
    final userSnapshot = await _firestore
        .collection('users')
        .doc(user.uid)
        .get();

    if (!userSnapshot.exists) {
      throw const AuthProfileException(
        'Your account profile was not found in Firestore.',
      );
    }

    final userData = userSnapshot.data() ?? <String, dynamic>{};
    final storedStudentId = (userData['studentId'] ?? '').toString().trim();

    DocumentSnapshot<Map<String, dynamic>>? studentSnapshot;

    if (storedStudentId.isNotEmpty) {
      studentSnapshot = await _firestore
          .collection('students')
          .doc(storedStudentId)
          .get();
    }

    if (studentSnapshot == null || !studentSnapshot.exists) {
      final email = user.email?.trim();
      if (email == null || email.isEmpty) {
        throw const AuthProfileException(
          'The authenticated account has no email address to match with a student profile.',
        );
      }

      final query = await _firestore
          .collection('students')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        studentSnapshot = query.docs.first;
      }
    }

    if (studentSnapshot == null || !studentSnapshot.exists) {
      throw const AuthProfileException(
        'No student profile matches this Firebase account. Add the studentId field to users/{uid} or make sure students.email matches the Firebase Auth email.',
      );
    }

    final profile = StudentProfile.fromDocument(
      studentSnapshot.id,
      studentSnapshot.data() ?? <String, dynamic>{},
    );

    if (profile.studentId.isEmpty) {
      throw const AuthProfileException(
        'The student profile has no student ID.',
      );
    }

    if (profile.fullName.isEmpty) {
      throw const AuthProfileException(
        'The student profile is missing the full name.',
      );
    }

    if (profile.program.isEmpty ||
        profile.year.isEmpty ||
        profile.section.isEmpty) {
      throw const AuthProfileException(
        'The student profile is missing program, year, or section information.',
      );
    }

    return profile;
  }

  static String firebaseAuthErrorMessage(Object error) {
    if (error is! FirebaseAuthException) {
      return 'Something went wrong. Please try again.';
    }

    switch (error.code) {
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'invalid-credential':
      case 'wrong-password':
      case 'user-not-found':
        return 'The email or password is incorrect.';
      case 'user-disabled':
        return 'This Firebase account has been disabled.';
      case 'too-many-requests':
        return 'Too many login attempts. Please wait a while and try again.';
      case 'network-request-failed':
        return 'A network error occurred. Check your internet connection and try again.';
      case 'operation-not-allowed':
        return 'Email/password sign-in is not enabled in Firebase Authentication.';
      default:
        return error.message?.isNotEmpty == true
            ? error.message!
            : 'Authentication failed. Please try again.';
    }
  }
}
