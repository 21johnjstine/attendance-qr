import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simpleattendancechecker/screen/auth/pages/login_screen.dart';

void main() {
  testWidgets('Login screen matches the email/password authentication flow',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: LoginScreen(),
      ),
    );

    expect(find.text('LOGIN'), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
    expect(find.text('Forgot Password?'), findsOneWidget);

    expect(find.text('Remember me'), findsNothing);
    expect(find.text('Or sign in with'), findsNothing);
  });
}
