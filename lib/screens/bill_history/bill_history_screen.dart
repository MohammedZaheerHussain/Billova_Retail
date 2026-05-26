import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/date_filter.dart';
import '../../data/models/sale_model.dart';
import '../../providers/sales_provider.dart';
import '../../widgets/date_filter_bar.dart';
import 'bill_detail_screen.dart';

class BillHistoryScreen extends StatelessWidget {
  const BillHistoryScreen({super.key});

  Future<void> _pickCustomRange(BuildContext context, SalesProvider provider) async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: now,
      initialDateRange: DateTimeRange(
        start: provider.customStart ?? now.subtract(Duration(days: 7)),
        end: provider.customEnd ?? now,
      ),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.dark(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              surface: AppColors.card(context),
              onSurface: AppColors.textPrimary(context),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      provider.setFilter(
        DateFilterType.custom,
        customStart: picked.start,
        customEnd: picked.end,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SalesProvider>(
      builder: (context, provider, _) {
        final grouped = provider.groupedSales;
        final groupKeys = grouped.keys.toList();

        return Scaffold(
          backgroundColor: Colors.transparent,
          body: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ─── Header ───
                Row(
                  children: [
                    Text('Bill History',
                        style: AppTypography.h1.copyWith(color: AppColors.textPrimary(context))),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        '${provider.filteredCount} bills',
                        style: AppTypography.mono.copyWith(color: AppColors.accent, fontSize: 13),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // ─── Date Filter Bar ───
                DateFilterBar(
                  selected: provider.filterType,
                  onChanged: (type) => provider.setFilter(type),
                  onCustomTap: () => _pickCustomRange(context, provider),
                ),
                const SizedBox(height: 12),

                // ─── Payment Mode Filter ───
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: ['All', 'Cash', 'UPI', 'Card', 'Udhar'].map((mode) {
                      final isActive = provider.paymentFilter == mode;
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: GestureDetector(
                          onTap: () => provider.setPaymentFilter(mode),
                          child: Container(
                            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: isActive
                                  ? _paymentColor(context, mode).withValues(alpha: 0.15)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isActive
                                    ? _paymentColor(context, mode)
                                    : AppColors.cardBorder(context),
                              ),
                            ),
                            child: Text(
                              mode,
                              style: AppTypography.labelSmall.copyWith(
                                color: isActive ? _paymentColor(context, mode) : AppColors.textTertiary(context),
                                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 16),

                // ─── Summary Cards ───
                Row(
                  children: [
                    _summaryCard(context,
                      icon: Icons.receipt_long_rounded,
                      label: '${DateFilterHelper.filterLabel(provider.filterType)} Sales',
                      value: Formatters.currency(provider.filteredTotal),
                      color: AppColors.success,
                      bgColor: AppColors.successBg,
                    ),
                    const SizedBox(width: 12),
                    _summaryCard(context,
                      icon: Icons.shopping_bag_rounded,
                      label: 'Bills',
                      value: '${provider.filteredCount}',
                      color: AppColors.accent,
                      bgColor: AppColors.infoBg,
                    ),
                    const SizedBox(width: 12),
                    _summaryCard(context,
                      icon: Icons.inventory_2_rounded,
                      label: 'Items Sold',
                      value: '${provider.filteredItemCount}',
                      color: AppColors.warning,
                      bgColor: AppColors.warningBg,
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // ─── Error ───
                if (provider.error.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.errorBg,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline, color: AppColors.error, size: 18),
                        const SizedBox(width: 8),
                        Text(provider.error,
                            style: AppTypography.bodySmall.copyWith(color: AppColors.error)),
                      ],
                    ),
                  ),

                // ─── Grouped List ───
                Expanded(
                  child: provider.isLoading
                      ? Center(child: CircularProgressIndicator(color: AppColors.accent))
                      : provider.sales.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.receipt_long_outlined,
                                      size: 64,
                                      color: AppColors.textTertiary(context).withValues(alpha: 0.3)),
                                  SizedBox(height: 16),
                                  Text('No bills for ${DateFilterHelper.filterLabel(provider.filterType).toLowerCase()}',
                                      style: AppTypography.h3
                                          .copyWith(color: AppColors.textSecondary(context))),
                                  SizedBox(height: 8),
                                  Text('Complete a sale to see it here',
                                      style: AppTypography.bodyMedium
                                          .copyWith(color: AppColors.textTertiary(context))),
                                ],
                              ),
                            )
                          : ListView(
                              children: _buildGroupedItems(context, grouped, groupKeys, provider),
                            ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _summaryCard(BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required Color bgColor,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(height: 6),
            Text(value,
                style: AppTypography.mono.copyWith(
                    color: color, fontWeight: FontWeight.w700, fontSize: 16)),
            const SizedBox(height: 2),
            Text(label,
                style: AppTypography.labelSmall.copyWith(color: color.withValues(alpha: 0.7))),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildGroupedItems(
      BuildContext context, Map<String, List<SaleModel>> grouped, List<String> keys, SalesProvider provider) {
    final widgets = <Widget>[];
    for (final dateLabel in keys) {
      final items = grouped[dateLabel]!;
      final dayTotal = items.fold<double>(0, (sum, s) => sum + s.total.roundToDouble());

      // Date group header
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 6),
          child: Row(
            children: [
              Icon(Icons.calendar_today_rounded, size: 14, color: AppColors.accent),
              SizedBox(width: 8),
              Text(
                dateLabel,
                style: AppTypography.labelMedium.copyWith(
                  color: AppColors.accent,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(width: 6),
              Text(
                '(${items.length} bill${items.length != 1 ? 's' : ''})',
                style: AppTypography.labelSmall.copyWith(color: AppColors.textTertiary(context)),
              ),
              SizedBox(width: 8),
              Expanded(child: Container(height: 1, color: AppColors.cardBorder(context))),
              const SizedBox(width: 8),
              Text(
                Formatters.currency(dayTotal),
                style: AppTypography.monoSmall.copyWith(
                    color: AppColors.success, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      );

      // Bill cards for this date
      for (final sale in items) {
        widgets.add(_billCard(context, sale, provider));
      }
    }
    return widgets;
  }

  Widget _billCard(BuildContext context, SaleModel sale, SalesProvider provider) {
    return Container(
      margin: EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardBorder(context)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _showBillDetail(context, sale),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Icon
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.receipt_rounded, color: AppColors.accent, size: 22),
                ),
                SizedBox(width: 14),

                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            sale.invoiceNumber,
                            style: AppTypography.mono
                                .copyWith(color: AppColors.textPrimary(context), fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: _paymentColor(context, sale.paymentMode).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              sale.paymentMode,
                              style: AppTypography.labelSmall.copyWith(
                                color: _paymentColor(context, sale.paymentMode),
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 4),
                      Text(
                        sale.customerName.isNotEmpty ? sale.customerName : 'Walk-in Customer',
                        style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary(context)),
                      ),
                      Text(
                        '${sale.totalItems} items • ${Formatters.time(sale.createdAt)}',
                        style: AppTypography.labelSmall.copyWith(color: AppColors.textTertiary(context)),
                      ),
                    ],
                  ),
                ),

                // Amount
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      Formatters.currency(sale.total.roundToDouble()),
                      style: AppTypography.mono.copyWith(
                        color: AppColors.success,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    if (sale.discount > 0)
                      Text(
                        '-${Formatters.currency(sale.discount.roundToDouble())}',
                        style: AppTypography.monoSmall.copyWith(color: AppColors.error),
                      ),
                    if (sale.dueAmount > 0)
                      Text(
                        'Due: ${Formatters.currency(sale.dueAmount.roundToDouble())}',
                        style: AppTypography.monoSmall.copyWith(color: AppColors.warning, fontWeight: FontWeight.w600),
                      ),
                  ],
                ),
                SizedBox(width: 8),
                Icon(Icons.chevron_right_rounded, color: AppColors.textTertiary(context), size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _paymentColor(BuildContext context, String mode) {
    switch (mode.toLowerCase()) {
      case 'cash':
        return AppColors.success;
      case 'upi':
        return AppColors.info;
      case 'card':
        return AppColors.accent;
      case 'udhar':
        return AppColors.warning;
      case 'partial':
        return const Color(0xFFFFA726); // Amber for partial payment
      case 'credit':
        return AppColors.warning;
      case 'split':
        return const Color(0xFF9C27B0); // Purple for split payments
      case 'all':
        return AppColors.textSecondary(context);
      default:
        return AppColors.textSecondary(context);
    }
  }

  void _showBillDetail(BuildContext context, SaleModel sale) {
    showDialog(
      context: context,
      builder: (ctx) => BillDetailDialog(sale: sale),
    );
  }
}
