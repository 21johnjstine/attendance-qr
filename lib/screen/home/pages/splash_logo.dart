import 'package:flutter/material.dart';
import 'package:simpleattendancechecker/constants/color_palatte.dart';
import 'package:simpleattendancechecker/screen/home/pages/home.dart';
import 'package:simpleattendancechecker/services/biometric_service.dart';

class SplashLogo extends StatefulWidget {
  const SplashLogo({super.key});

  @override
  State<SplashLogo> createState() => _SplashLogoState();
}

class _SplashLogoState extends State<SplashLogo>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  // ── 🎴 Logo animation ───────────────────────────
  late Animation<double> _logoFade;
  late Animation<double> _logoScale;

  // ── 🔴 Circle animation ───────────────────────────
  late Animation<double> _circleFade1;
  late Animation<double> _circleFade2;
  late Animation<double> _circleFade3;
  late Animation<double> _circleFade4;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _circleFade1 = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
    );
    _circleFade2 = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.1, 0.6, curve: Curves.easeOut),
    );
    _circleFade3 = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.2, 0.7, curve: Curves.easeOut),
    );
    _circleFade4 = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.3, 0.8, curve: Curves.easeOut),
    );

    _logoFade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.4, 1.0, curve: Curves.easeIn),
    );
    _logoScale = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.4, 1.0, curve: Curves.easeOutBack),
      ),
    );

    _controller.forward();

    // ── 🧭 Navigation delay ───────────────────────────
    Future.delayed(const Duration(milliseconds: 2000), () {
      if (mounted) _proceedToHome();
    });
  }

  // ── 🔐 I-check muna ang biometric bago pumasok sa Home ───────────────
  Future<void> _proceedToHome() async {
    final biometricEnabled = await BiometricService.isEnabled();
    bool proceed = true;

    if (biometricEnabled) {
      proceed = await BiometricService.authenticate();
    }

    if (!mounted) return;

    if (proceed) {
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (_, _, _) => const Home(),
          transitionsBuilder: (_, animation, _, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 500),
        ),
      );
    } else {
      _showAuthFailedDialog();
    }
  }

  void _showAuthFailedDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Authentication Failed'),
        content: const Text('A valid fingerprint is required to open the app.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _proceedToHome();
            },
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _circle({
    required double size,
    required Color color,
    required Animation<double> fade,
  }) {
    return FadeTransition(
      opacity: fade,
      child: ScaleTransition(
        scale: fade,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colorpalatte.maincolor,
      body: Stack(
        children: [
          // decoration 1
          Positioned(
            top: 170,
            right: 270,
            child: _circle(
              size: 140,
              color: Colorpalatte.secondary,
              fade: _circleFade1,
            ),
          ),
          Positioned(
            top: 100,
            right: 290,
            child: _circle(
              size: 140,
              color: Colorpalatte.accentcolor,
              fade: _circleFade1,
            ),
          ),

          // decoration 2
          Positioned(
            bottom: 640,
            left: 230,
            child: _circle(
              size: 220,
              color: Colorpalatte.accentcolor,
              fade: _circleFade2,
            ),
          ),
          Positioned(
            bottom: 560,
            left: 270,
            child: _circle(
              size: 220,
              color: Colorpalatte.secondary,
              fade: _circleFade2,
            ),
          ),

          // decoration 3
          Positioned(
            bottom: 100,
            left: 330,
            child: _circle(
              size: 100,
              color: Colorpalatte.accentcolor,
              fade: _circleFade3,
            ),
          ),
          Positioned(
            bottom: 150,
            left: 320,
            child: _circle(
              size: 100,
              color: Colorpalatte.secondary,
              fade: _circleFade3,
            ),
          ),

          // decoration 4
          Positioned(
            top: 620,
            right: 180,
            child: _circle(
              size: 300,
              color: Colorpalatte.secondary,
              fade: _circleFade4,
            ),
          ),
          Positioned(
            top: 510,
            right: 260,
            child: _circle(
              size: 300,
              color: Colorpalatte.accentcolor,
              fade: _circleFade4,
            ),
          ),

          // logo
          Center(
            child: FadeTransition(
              opacity: _logoFade,
              child: ScaleTransition(
                scale: _logoScale,
                child: Image(
                  image: const AssetImage('lib/assets/logo_name.png'),
                  height: 240,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
