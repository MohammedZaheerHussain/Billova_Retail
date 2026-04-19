import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../providers/staff_provider.dart';

class StaffLoginScreen extends StatefulWidget {
  final VoidCallback onLogin;
  const StaffLoginScreen({super.key, required this.onLogin});

  @override
  State<StaffLoginScreen> createState() => _StaffLoginScreenState();
}

class _StaffLoginScreenState extends State<StaffLoginScreen> {
  final _usernameCtrl = TextEditingController();
  final _pinCtrl = TextEditingController();
  String _error = '';
  bool _isLoading = false;

  Future<void> _login() async {
    if (_usernameCtrl.text.trim().isEmpty || _pinCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Enter username and PIN');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = '';
    });

    final provider = context.read<StaffProvider>();
    final result = await provider.loginStaff(
      _usernameCtrl.text.trim(),
      _pinCtrl.text.trim(),
    );

    setState(() => _isLoading = false);

    if (result == null) {
      // Success
      widget.onLogin();
    } else {
      setState(() => _error = result);
    }
  }

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _pinCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldDark,
      body: Center(
        child: Container(
          width: 380,
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: AppColors.cardDark,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.cardBorderDark),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.15),
                blurRadius: 40,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Logo
              Container(
                width: 60, height: 60,
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.person_rounded, color: Colors.white, size: 30),
              ),
              const SizedBox(height: 16),
              Text('Staff Login', style: AppTypography.h2.copyWith(color: AppColors.textPrimaryDark)),
              const SizedBox(height: 4),
              Text('Enter your credentials to continue',
                  style: AppTypography.labelSmall.copyWith(color: AppColors.textTertiaryDark)),
              const SizedBox(height: 28),

              // Username
              TextField(
                controller: _usernameCtrl,
                style: const TextStyle(color: AppColors.textPrimaryDark),
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: 'Username',
                  hintText: 'e.g. john',
                  labelStyle: const TextStyle(color: AppColors.textSecondaryDark, fontSize: 13),
                  hintStyle: const TextStyle(color: AppColors.textTertiaryDark),
                  prefixIcon: const Icon(Icons.person_outline_rounded, color: AppColors.textTertiaryDark),
                  filled: true,
                  fillColor: AppColors.surfaceDark,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.cardBorderDark),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.cardBorderDark),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // PIN
              TextField(
                controller: _pinCtrl,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 6,
                style: const TextStyle(color: AppColors.textPrimaryDark, letterSpacing: 8),
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _login(),
                decoration: InputDecoration(
                  labelText: 'PIN',
                  hintText: '••••',
                  counterText: '',
                  labelStyle: const TextStyle(color: AppColors.textSecondaryDark, fontSize: 13),
                  hintStyle: const TextStyle(color: AppColors.textTertiaryDark),
                  prefixIcon: const Icon(Icons.lock_outline_rounded, color: AppColors.textTertiaryDark),
                  filled: true,
                  fillColor: AppColors.surfaceDark,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.cardBorderDark),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.cardBorderDark),
                  ),
                ),
              ),
              const SizedBox(height: 8),

              if (_error.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(_error,
                      style: AppTypography.labelSmall.copyWith(color: AppColors.error),
                      textAlign: TextAlign.center),
                ),

              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _login,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isLoading
                      ? const SizedBox(width: 20, height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text('Login', style: AppTypography.button.copyWith(color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
