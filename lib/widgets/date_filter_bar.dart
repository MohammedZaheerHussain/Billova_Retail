import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/date_filter.dart';

/// Reusable date filter bar used in Expenses, Bill History, etc.
class DateFilterBar extends StatelessWidget {
  final DateFilterType selected;
  final ValueChanged<DateFilterType> onChanged;
  final VoidCallback? onCustomTap;
  final DateTime? customStart;
  final DateTime? customEnd;

  const DateFilterBar({
    super.key,
    required this.selected,
    required this.onChanged,
    this.onCustomTap,
    this.customStart,
    this.customEnd,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: DateFilterType.values.map((type) {
          final isActive = type == selected;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _FilterChip(
              label: DateFilterHelper.filterLabel(type, customStart: customStart, customEnd: customEnd),
              icon: _iconFor(type),
              isActive: isActive,
              onTap: () {
                if (type == DateFilterType.custom && onCustomTap != null) {
                  onCustomTap!();
                } else {
                  onChanged(type);
                }
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  IconData _iconFor(DateFilterType type) {
    switch (type) {
      case DateFilterType.today: return Icons.today_rounded;
      case DateFilterType.yesterday: return Icons.history_rounded;
      case DateFilterType.thisWeek: return Icons.date_range_rounded;
      case DateFilterType.thisMonth: return Icons.calendar_month_rounded;
      case DateFilterType.lastMonth: return Icons.history_toggle_off_rounded;
      case DateFilterType.custom: return Icons.tune_rounded;
    }
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.icon,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: Duration(milliseconds: 200),
          padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isActive ? AppColors.primary.withValues(alpha: 0.15) : AppColors.surface(context),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isActive ? AppColors.primary : AppColors.cardBorder(context),
              width: isActive ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 15,
                color: isActive ? AppColors.accent : AppColors.textTertiary(context),
              ),
              SizedBox(width: 6),
              Text(
                label,
                style: AppTypography.labelSmall.copyWith(
                  color: isActive ? AppColors.accent : AppColors.textSecondary(context),
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
