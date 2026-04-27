import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';

class LoansChitsScreen extends StatefulWidget {
  const LoansChitsScreen({super.key});

  @override
  State<LoansChitsScreen> createState() => _LoansChitsScreenState();
}

class _LoansChitsScreenState extends State<LoansChitsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.account_balance_rounded, size: 64, color: AppColors.accent.withValues(alpha: 0.3)),
            const SizedBox(height: 16),
            Text('Loans & Chits', style: AppTypography.h2.copyWith(color: AppColors.textPrimary(context))),
            const SizedBox(height: 8),
            Text('Coming soon...', style: AppTypography.bodyMedium.copyWith(color: AppColors.textTertiary(context))),
          ],
        ),
      ),
    );
  }
}
