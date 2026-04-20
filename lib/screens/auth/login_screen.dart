import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../providers/auth_provider.dart';
import '../../providers/staff_provider.dart';
import '../../widgets/animated_login_background.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();

  // Animation controller for floating icons overlay
  late final AnimationController _floatIconController;

  // Admin fields
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  // Staff fields
  final _usernameController = TextEditingController();
  final _pinController = TextEditingController();
  bool _obscurePin = true;

  // Tab state: 0 = Admin, 1 = Staff
  int _loginMode = 0;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _floatIconController = AnimationController(
      duration: const Duration(seconds: 20),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _floatIconController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _usernameController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _submitAdmin() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);

    final auth = context.read<AuthProvider>();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    final success = await auth.signIn(email, password);

    if (success && mounted) {
      Navigator.pushReplacementNamed(context, '/home');
    }

    if (mounted) setState(() => _isSubmitting = false);
  }

  Future<void> _submitStaff() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);

    final auth = context.read<AuthProvider>();
    final staff = context.read<StaffProvider>();
    final username = _usernameController.text.trim();
    final pin = _pinController.text.trim();

    // Silently try to recover Supabase session (for data sync)
    // This NEVER blocks staff login — staff works independently
    if (!auth.isAuthenticated) {
      try {
        await auth.checkSession();
      } catch (_) {
        debugPrint('⚠️ No Supabase session — staff will use local data');
      }
    }

    // Validate staff credentials against local staff table
    final error = await staff.loginStaff(username, pin);
    if (error != null) {
      auth.setError(error);
      if (mounted) setState(() => _isSubmitting = false);
      return;
    }

    // Mark auth as staff session
    await auth.staffLogin();

    if (mounted) {
      Navigator.pushReplacementNamed(context, '/home');
    }
    if (mounted) setState(() => _isSubmitting = false);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFF060612),
      body: Stack(
        children: [
          // Animated background
          const Positioned.fill(
            child: AnimatedLoginBackground(),
          ),

          // Floating billing icons overlay
          AnimatedBuilder(
            animation: _floatIconController,
            builder: (context, _) => FloatingIconsOverlay(
              progress: _floatIconController.value,
            ),
          ),

          // Login form (centered, glassmorphism card)
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                // ─── Logo ───
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.3),
                        blurRadius: 24,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.receipt_long_rounded,
                    size: 40,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 24),

                ShaderMask(
                  shaderCallback: (bounds) =>
                      AppColors.primaryGradient.createShader(bounds),
                  child: Text(
                    'SKYWALK',
                    style: AppTypography.h1.copyWith(
                      color: Colors.white,
                      letterSpacing: 6,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _loginMode == 0 ? 'Admin Login' : 'Staff Login',
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textSecondaryDark,
                  ),
                ),

                const SizedBox(height: 28),

                // ─── Login Mode Toggle ───
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceDark,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.cardBorderDark),
                  ),
                  child: Row(
                    children: [
                      _modeTab(0, '👑  Admin', Icons.admin_panel_settings_rounded),
                      _modeTab(1, '👨‍💼  Staff', Icons.badge_rounded),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // ─── Form Card (glassmorphism) ───
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.cardDark.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppColors.cardBorderDark.withValues(alpha: 0.5),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.08),
                        blurRadius: 40,
                        spreadRadius: 2,
                      ),
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_loginMode == 0) ...[
                          // ─── ADMIN: Email + Password ───
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            style: const TextStyle(color: AppColors.textPrimaryDark),
                            decoration: _inputDecoration(
                              label: 'Email',
                              icon: Icons.email_outlined,
                            ),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) return 'Enter your email';
                              if (!v.contains('@')) return 'Enter a valid email';
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            style: const TextStyle(color: AppColors.textPrimaryDark),
                            decoration: _inputDecoration(
                              label: 'Password',
                              icon: Icons.lock_outlined,
                              suffix: IconButton(
                                icon: Icon(
                                  _obscurePassword ? Icons.visibility_off : Icons.visibility,
                                  color: AppColors.textTertiaryDark,
                                ),
                                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                              ),
                            ),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) return 'Enter your password';
                              if (v.length < 6) return 'Password must be at least 6 characters';
                              return null;
                            },
                          ),
                        ] else ...[
                          // ─── STAFF: Username + PIN ───
                          TextFormField(
                            controller: _usernameController,
                            style: const TextStyle(color: AppColors.textPrimaryDark),
                            decoration: _inputDecoration(
                              label: 'Username',
                              icon: Icons.person_outline_rounded,
                            ),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) return 'Enter your username';
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _pinController,
                            obscureText: _obscurePin,
                            keyboardType: TextInputType.number,
                            maxLength: 6,
                            style: TextStyle(
                              color: AppColors.textPrimaryDark,
                              letterSpacing: _obscurePin ? 8 : 4,
                              fontSize: 18,
                            ),
                            decoration: _inputDecoration(
                              label: 'PIN',
                              icon: Icons.pin_rounded,
                              suffix: IconButton(
                                icon: Icon(
                                  _obscurePin ? Icons.visibility_off : Icons.visibility,
                                  color: AppColors.textTertiaryDark,
                                ),
                                onPressed: () => setState(() => _obscurePin = !_obscurePin),
                              ),
                            ),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) return 'Enter your PIN';
                              if (v.length < 4) return 'PIN must be 4-6 digits';
                              return null;
                            },
                          ),
                        ],

                        // Error Message
                        if (auth.errorMessage.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.errorBg,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.error_outline, color: AppColors.error, size: 18),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    auth.errorMessage,
                                    style: AppTypography.bodySmall.copyWith(color: AppColors.error),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        const SizedBox(height: 24),

                        // Submit Button
                        SizedBox(
                          height: 52,
                          child: ElevatedButton(
                            onPressed: _isSubmitting
                                ? null
                                : (_loginMode == 0 ? _submitAdmin : _submitStaff),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _loginMode == 0
                                  ? AppColors.primary
                                  : AppColors.accent,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              elevation: 0,
                            ),
                            child: _isSubmitting
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Text(
                                    _loginMode == 0 ? 'Sign In' : 'Clock In & Start',
                                    style: AppTypography.button.copyWith(
                                      color: Colors.white,
                                      fontSize: 15,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // ─── Staff hint ───
                if (_loginMode == 1)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.infoBg,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.info.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline_rounded, color: AppColors.info, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Enter the username and PIN provided by your admin. You will be automatically clocked in.',
                            style: AppTypography.bodySmall.copyWith(
                              color: AppColors.info,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      ],
    ),
    );
  }

  Widget _modeTab(int index, String label, IconData icon) {
    final isActive = _loginMode == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() => _loginMode = index);
          context.read<AuthProvider>().clearError();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isActive
                ? (index == 0 ? AppColors.primary : AppColors.accent).withValues(alpha: 0.15)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: isActive
                ? Border.all(color: index == 0 ? AppColors.primary : AppColors.accent, width: 1.5)
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18,
                  color: isActive
                      ? (index == 0 ? AppColors.primary : AppColors.accent)
                      : AppColors.textTertiaryDark),
              const SizedBox(width: 8),
              Text(
                label,
                style: AppTypography.labelMedium.copyWith(
                  color: isActive
                      ? (index == 0 ? AppColors.primary : AppColors.accent)
                      : AppColors.textTertiaryDark,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
    Widget? suffix,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: AppColors.textSecondaryDark),
      prefixIcon: Icon(icon, color: AppColors.textTertiaryDark),
      suffixIcon: suffix,
      filled: true,
      fillColor: AppColors.surfaceDark,
      counterText: '',
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.cardBorderDark),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.cardBorderDark),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: _loginMode == 0 ? AppColors.primary : AppColors.accent),
      ),
    );
  }
}
