import 'package:flutter/material.dart';
import 'package:simpleattendancechecker/constants/app_sizing.dart';
import 'package:simpleattendancechecker/constants/color_palatte.dart';
import 'package:simpleattendancechecker/services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _isSigningIn = false;
  bool _isResettingPassword = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return 'Enter your email address.';

    final valid = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email);
    if (!valid) return 'Enter a valid email address.';

    return null;
  }

  String? _validatePassword(String? value) {
    if ((value ?? '').isEmpty) return 'Enter your password.';
    return null;
  }

  Future<void> _signIn() async {
    FocusManager.instance.primaryFocus?.unfocus();

    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSigningIn = true);

    try {
      await AuthService.signIn(
        email: _emailController.text,
        password: _passwordController.text,
      );
    } catch (e) {
      if (!mounted) return;
      await _showMessage(
        'Sign in failed',
        AuthService.firebaseAuthErrorMessage(e),
      );
    } finally {
      if (mounted) setState(() => _isSigningIn = false);
    }
  }

  Future<void> _forgotPassword() async {
    FocusManager.instance.primaryFocus?.unfocus();

    final email = _emailController.text.trim();
    final validation = _validateEmail(email);

    if (validation != null) {
      await _showMessage('Reset password', validation);
      return;
    }

    setState(() => _isResettingPassword = true);

    try {
      await AuthService.sendPasswordResetEmail(email);
      if (!mounted) return;
      await _showMessage(
        'Reset email sent',
        'A password reset link was sent to $email. Check your inbox and spam folder.',
      );
    } catch (e) {
      if (!mounted) return;
      await _showMessage(
        'Reset failed',
        AuthService.firebaseAuthErrorMessage(e),
      );
    } finally {
      if (mounted) setState(() => _isResettingPassword = false);
    }
  }

  Future<void> _showMessage(String title, String message) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colorpalatte.maincolor,
        title: Text(
          title,
          style: const TextStyle(
            fontFamily: 'K2D',
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon, color: Colorpalatte.mutedcolor),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: Colorpalatte.containercolor,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: 16,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: const BorderSide(
          color: Colorpalatte.secondary,
          width: 1.5,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: const BorderSide(color: Colorpalatte.errorcolor),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: const BorderSide(
          color: Colorpalatte.errorcolor,
          width: 1.5,
        ),
      ),
    );
  }

  Widget _circle({
    required double size,
    required Color color,
    required Alignment alignment,
  }) {
    return Align(
      alignment: alignment,
      child: Transform.translate(
        offset: Offset(
          alignment.x < 0 ? -size * .55 : size * .55,
          alignment.y < 0 ? -size * .12 : size * .12,
        ),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Scaffold(
      backgroundColor: Colorpalatte.maincolor,
      resizeToAvoidBottomInset: true,
      body: Stack(
        fit: StackFit.expand,
        children: [
          _circle(
            size: 180,
            color: Colorpalatte.accentcolor,
            alignment: const Alignment(-1.15, -0.92),
          ),
          _circle(
            size: 220,
            color: Colorpalatte.secondary,
            alignment: const Alignment(-0.95, -0.55),
          ),
          _circle(
            size: 190,
            color: Colorpalatte.secondary,
            alignment: const Alignment(1.08, -0.92),
          ),
          _circle(
            size: 230,
            color: Colorpalatte.accentcolor,
            alignment: const Alignment(1.12, -0.58),
          ),
          _circle(
            size: 170,
            color: Colorpalatte.accentcolor,
            alignment: const Alignment(-1.12, 0.96),
          ),
          _circle(
            size: 220,
            color: Colorpalatte.secondary,
            alignment: const Alignment(-0.86, 1.10),
          ),
          _circle(
            size: 170,
            color: Colorpalatte.secondary,
            alignment: const Alignment(1.08, 0.62),
          ),
          _circle(
            size: 135,
            color: Colorpalatte.accentcolor,
            alignment: const Alignment(1.18, 0.86),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.xl,
                  AppSpacing.lg,
                  AppSpacing.lg + bottomInset,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 430),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'LOGIN',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'K2D',
                            fontSize: 42,
                            fontWeight: FontWeight.w700,
                            color: Colorpalatte.secondary,
                            letterSpacing: 1.4,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        const Text(
                          'Email',
                          style: TextStyle(
                            fontFamily: 'K2D',
                            fontWeight: FontWeight.w600,
                            color: Colorpalatte.secondary,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        TextFormField(
                          controller: _emailController,
                          validator: _validateEmail,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          decoration: _inputDecoration(
                            hint: 'Enter your email',
                            icon: Icons.mail_outline_rounded,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        const Text(
                          'Password',
                          style: TextStyle(
                            fontFamily: 'K2D',
                            fontWeight: FontWeight.w600,
                            color: Colorpalatte.secondary,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        TextFormField(
                          controller: _passwordController,
                          validator: _validatePassword,
                          obscureText: _obscurePassword,
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) {
                            if (!_isSigningIn) _signIn();
                          },
                          decoration: _inputDecoration(
                            hint: 'Enter your password',
                            icon: Icons.lock_outline_rounded,
                            suffixIcon: IconButton(
                              tooltip: _obscurePassword
                                  ? 'Show password'
                                  : 'Hide password',
                              onPressed: () {
                                setState(
                                  () => _obscurePassword = !_obscurePassword,
                                );
                              },
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                color: Colorpalatte.mutedcolor,
                              ),
                            ),
                          ),
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed:
                                _isResettingPassword ? null : _forgotPassword,
                            style: TextButton.styleFrom(
                              foregroundColor: Colorpalatte.secondary,
                              padding: EdgeInsets.zero,
                            ),
                            child: _isResettingPassword
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Text(
                                    'Forgot Password?',
                                    style: TextStyle(
                                      fontFamily: 'K2D',
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        SizedBox(
                          height: 50,
                          child: ElevatedButton(
                            onPressed: _isSigningIn ? null : _signIn,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colorpalatte.secondary,
                              foregroundColor: Colorpalatte.maincolor,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(AppRadius.md),
                              ),
                            ),
                            child: _isSigningIn
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.2,
                                      color: Colorpalatte.maincolor,
                                    ),
                                  )
                                : const Text(
                                    'Sign in',
                                    style: TextStyle(
                                      fontFamily: 'K2D',
                                      fontSize: AppFontSize.body,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        const Text(
                          'Sign in with your Firebase email and password.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: AppFontSize.caption,
                            color: Colorpalatte.mutedcolor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
