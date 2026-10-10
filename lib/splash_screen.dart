import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:negoo_super_admin/admin_login.dart';
import 'package:negoo_super_admin/main.dart';
import 'package:negoo_super_admin/theme/app_theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminSplashScreen extends StatefulWidget {
  const AdminSplashScreen({super.key});

  @override
  State<AdminSplashScreen> createState() => _AdminSplashScreenState();
}

class _AdminSplashScreenState extends State<AdminSplashScreen>
    with SingleTickerProviderStateMixin {
  late final SupabaseClient _supabase;
  late AnimationController _pulseController;
  late Animation<double> _glowAnimation;

  int _stepIndex = 0;
  final List<String> _securitySteps = [
    "INITIALIZING CRYPTOGRAPHIC HANDSHAKE...",
    "BINDING SUPABASE REALTIME WEBSOCKET PIPELINE...",
    "VERIFYING EXECUTIVE ROLE CREDENTIALS...",
    "SECURITY PROTOCOL VALIDATED • ENTERING COMMAND...",
  ];

  Timer? _stepTimer;

  @override
  void initState() {
    super.initState();
    _supabase = Supabase.instance.client;

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _glowAnimation = Tween<double>(begin: 0.85, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Sequence through the verification steps
    _stepTimer = Timer.periodic(const Duration(milliseconds: 450), (timer) {
      if (mounted) {
        setState(() {
          if (_stepIndex < _securitySteps.length - 1) {
            _stepIndex++;
          }
        });
      }
    });

    _checkAuthentication();
  }

  @override
  void dispose() {
    _stepTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _checkAuthentication() async {
    // Provide a polished 2.0s hold to display executive boot sequences
    await Future.delayed(const Duration(milliseconds: 2000));

    if (!mounted) return;

    final session = _supabase.auth.currentSession;
    if (session != null) {
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 600),
          pageBuilder: (context, animation, secondaryAnimation) =>
              const AdminMainNavigationShell(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) =>
              FadeTransition(opacity: animation, child: child),
        ),
      );
    } else {
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 600),
          pageBuilder: (context, animation, secondaryAnimation) =>
              const AdminLoginScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) =>
              FadeTransition(opacity: animation, child: child),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Ambient luxury background glow
          Center(
            child: Container(
              width: 400,
              height: 400,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.goldPrimary.withValues(alpha: 0.08),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Animated Glowing Emblem
                AnimatedBuilder(
                  animation: _glowAnimation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _glowAnimation.value,
                      child: Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.surface,
                          border: Border.all(
                            color: AppColors.goldPrimary.withValues(alpha: 0.6),
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.goldPrimary.withValues(alpha: 0.25),
                              blurRadius: 28,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.shield_rounded,
                            size: 48,
                            color: AppColors.goldPrimary,
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 32),
                Text(
                  "NEGOO HQ",
                  style: GoogleFonts.cinzel(
                    color: AppColors.goldPrimary,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 6,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "CENTRAL EXECUTIVE CONTROL",
                  style: GoogleFonts.plusJakartaSans(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 2.5,
                  ),
                ),
                const SizedBox(height: 36),
                SizedBox(
                  width: 220,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: const LinearProgressIndicator(
                      color: AppColors.goldPrimary,
                      backgroundColor: Color(0x1AFFFFFF),
                      minHeight: 2.5,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: Text(
                    _securitySteps[_stepIndex],
                    key: ValueKey<int>(_stepIndex),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.jetBrainsMono(
                      color: AppColors.textMuted,
                      fontSize: 10,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            bottom: 24,
            left: 0,
            right: 0,
            child: Center(
              child: Text(
                "ENCRYPTED ENTERPRISE CONSOLE • V2.4 REALTIME",
                style: GoogleFonts.plusJakartaSans(
                  color: AppColors.textDisabled,
                  fontSize: 10,
                  letterSpacing: 1.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
