import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../providers/auth_provider.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeIn;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _fadeIn = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0, 0.6, curve: Curves.easeOut)),
    );

    _scale = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0, 0.6, curve: Curves.easeOutBack)),
    );

    _controller.forward();
    _checkSession();
  }

  Future<void> _checkSession() async {
    try {
      // Wait for animation to play
      await Future.delayed(const Duration(milliseconds: 2000));

      if (!mounted) return;

      final auth = context.read<AuthProvider>();
      await auth.checkSession().timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          debugPrint('⚠️ Splash session check timed out — falling back to login');
        },
      );

      if (!mounted) return;

      if (auth.isAuthenticated) {
        Navigator.pushReplacementNamed(context, '/home');
      } else {
        Navigator.pushReplacementNamed(context, '/login');
      }
    } catch (e) {
      debugPrint('⚠️ Session check error in SplashScreen: $e');
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/login');
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldDark,
      body: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Opacity(
              opacity: _fadeIn.value,
              child: Transform.scale(
                scale: _scale.value,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ─── Logo / Icon ───
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.4),
                            blurRadius: 30,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.receipt_long_rounded,
                        size: 48,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 32),

                    // ─── App Name ───
                    ShaderMask(
                      shaderCallback: (bounds) =>
                          AppColors.primaryGradient.createShader(bounds),
                      child: Text(
                        'SKYWALK',
                        style: AppTypography.displayLarge.copyWith(
                          color: Colors.white,
                          letterSpacing: 8,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'BILLING',
                      style: AppTypography.labelLarge.copyWith(
                        color: AppColors.textSecondaryDark,
                        letterSpacing: 12,
                        fontSize: 13,
                      ),
                    ),

                    const SizedBox(height: 48),

                    // ─── Loading Indicator ───
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppColors.accent.withValues(alpha: 0.6),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
