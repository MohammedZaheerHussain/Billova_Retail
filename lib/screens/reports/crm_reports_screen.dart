import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';

class CrmReportsScreen extends StatefulWidget {
  const CrmReportsScreen({super.key});

  @override
  State<CrmReportsScreen> createState() => _CrmReportsScreenState();
}

class _CrmReportsScreenState extends State<CrmReportsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.analytics_rounded, size: 64, color: AppColors.accent.withValues(alpha: 0.3)),
            const SizedBox(height: 16),
            Text('CRM Reports', style: AppTypography.h2.copyWith(color: AppColors.textPrimary(context))),
            const SizedBox(height: 8),
            Text('Coming soon...', style: AppTypography.bodyMedium.copyWith(color: AppColors.textTertiary(context))),
          ],
        ),
      ),
    );
  }
}
