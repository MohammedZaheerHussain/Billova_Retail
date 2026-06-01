import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/formatters.dart';
import '../../providers/cash_till_provider.dart';

/// Professional retail cash reconciliation screen.
///
/// Separates physical shop cash (Cash) from digital collections (UPI/Card).
/// Owner can verify physical cash drawer against system-calculated expected amount.
class CashTillScreen extends StatefulWidget {
  const CashTillScreen({super.key});

  @override
  State<CashTillScreen> createState() => _CashTillScreenState();
}

class _CashTillScreenState extends State<CashTillScreen> {
  final _openingCashCtrl = TextEditingController();
  final _closingCashCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CashTillProvider>().loadToday();
    });
  }

  @override
  void dispose() {
    _openingCashCtrl.dispose();
    _closingCashCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<CashTillProvider>(
      builder: (context, provider, _) {
        final till = provider.today;

        if (till != null) {
          // Only set text if user isn't actively editing
          if (!_openingCashCtrl.text.contains('.') || _openingCashCtrl.text.isEmpty) {
            _openingCashCtrl.text = till.openingCash.toStringAsFixed(0);
          }
          if (till.isCashCounted && _closingCashCtrl.text.isEmpty) {
            _closingCashCtrl.text = till.actualClosingCash.toStringAsFixed(0);
          }
        }

        return Scaffold(
          backgroundColor: Colors.transparent,
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ─── Header ───
                Row(
                  children: [
                    Text('Daily Cash Till',
                        style: AppTypography.h1.copyWith(color: AppColors.textPrimary(context))),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        Formatters.date(DateTime.now()),
                        style: AppTypography.mono.copyWith(color: AppColors.accent, fontSize: 13),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: () => provider.refresh(),
                      icon: Icon(Icons.refresh_rounded, color: AppColors.textSecondary(context)),
                      tooltip: 'Refresh',
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                if (provider.isLoading)
                  const Center(child: CircularProgressIndicator(color: AppColors.accent))
                else if (till == null)
                  Center(
                    child: Text('Unable to load cash till',
                        style: AppTypography.bodyMedium.copyWith(color: AppColors.textTertiary(context))),
                  )
                else ...[
                  // ═══════════════════════════════════════════════════
                  // SECTION 1 — Opening Cash Balance
                  // ═══════════════════════════════════════════════════
                  _sectionCard(
                    icon: Icons.account_balance_wallet_rounded,
                    gradient: AppColors.primaryGradient,
                    title: 'Opening Cash',
                    subtitle: 'Physical cash available when shop opens',
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _openingCashCtrl,
                            keyboardType: TextInputType.number,
                            style: AppTypography.monoLarge.copyWith(
                                color: AppColors.textPrimary(context), fontSize: 20),
                            decoration: _inputDecoration('₹ '),
                          ),
                        ),
                        const SizedBox(width: 12),
                        _actionButton('Save', Icons.save_rounded, AppColors.primary, () async {
                          final amount = double.tryParse(_openingCashCtrl.text) ?? 0;
                          final success = await provider.setOpeningCash(amount);
                          if (success && context.mounted) {
                            _showSnack('Opening cash updated ✓');
                          }
                        }),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ═══════════════════════════════════════════════════
                  // SECTION 2 — Sales Breakdown (Cash / UPI / Card)
                  // ═══════════════════════════════════════════════════
                  _sectionHeader('Sales Breakdown', Icons.point_of_sale_rounded),
                  const SizedBox(height: 10),
                  _responsiveGrid([
                    _metricCard(
                      'Cash Sales',
                      till.cashSales,
                      Icons.money_rounded,
                      AppColors.success,
                      AppColors.successBg,
                      subtitle: 'Physical cash in shop',
                    ),
                    _metricCard(
                      'UPI Sales',
                      till.upiSales,
                      Icons.qr_code_rounded,
                      const Color(0xFF8B5CF6), // Purple for UPI
                      const Color(0x1A8B5CF6),
                      subtitle: 'Goes to bank account',
                    ),
                    _metricCard(
                      'Card Sales',
                      till.cardSales,
                      Icons.credit_card_rounded,
                      const Color(0xFF3B82F6), // Blue for card
                      const Color(0x1A3B82F6),
                      subtitle: 'Goes to merchant account',
                    ),
                  ]),
                  const SizedBox(height: 20),

                  // ═══════════════════════════════════════════════════
                  // SECTION 3 — Expense Breakdown (Cash / Digital)
                  // ═══════════════════════════════════════════════════
                  _sectionHeader('Expense Breakdown', Icons.receipt_long_rounded),
                  const SizedBox(height: 10),
                  _responsiveGrid([
                    _metricCard(
                      'Cash Expenses',
                      till.cashExpenses,
                      Icons.money_off_rounded,
                      AppColors.error,
                      AppColors.errorBg,
                      subtitle: 'Paid from shop cash',
                    ),
                    _metricCard(
                      'UPI/Bank Expenses',
                      till.digitalExpenses,
                      Icons.account_balance_rounded,
                      AppColors.warning,
                      AppColors.warningBg,
                      subtitle: 'Paid digitally',
                    ),
                  ]),
                  const SizedBox(height: 20),

                  // ═══════════════════════════════════════════════════
                  // SECTION 4 — Expected Physical Cash (MOST IMPORTANT)
                  // ═══════════════════════════════════════════════════
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: AppColors.successGradient,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.success.withValues(alpha: 0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.inventory_2_rounded, color: Colors.white, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'Expected Physical Cash in Shop',
                              style: AppTypography.labelLarge.copyWith(
                                color: Colors.white.withValues(alpha: 0.9),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          Formatters.currency(till.expectedCash),
                          style: AppTypography.monoLarge.copyWith(
                            color: Colors.white,
                            fontSize: 36,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Opening ₹${till.openingCash.toStringAsFixed(0)}  +  Cash Sales ₹${till.cashSales.toStringAsFixed(0)}  −  Cash Expenses ₹${till.cashExpenses.toStringAsFixed(0)}${till.cashRefunds > 0 ? '  −  Refunds ₹${till.cashRefunds.toStringAsFixed(0)}' : ''}',
                            style: AppTypography.labelSmall.copyWith(
                              color: Colors.white.withValues(alpha: 0.8),
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ═══════════════════════════════════════════════════
                  // SECTION 5 — Digital / Bank Collection
                  // ═══════════════════════════════════════════════════
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.card(context),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFF8B5CF6).withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0x1A8B5CF6),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.account_balance_rounded,
                                  size: 18, color: Color(0xFF8B5CF6)),
                            ),
                            const SizedBox(width: 12),
                            Text('Digital / Bank Collection',
                                style: AppTypography.h4.copyWith(color: AppColors.textPrimary(context))),
                            const Spacer(),
                            Text(
                              Formatters.currency(till.digitalCollection),
                              style: AppTypography.monoLarge.copyWith(
                                color: const Color(0xFF8B5CF6),
                                fontSize: 22,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _detailRow('UPI Sales', till.upiSales, '+', const Color(0xFF8B5CF6)),
                        _detailRow('Card Sales', till.cardSales, '+', const Color(0xFF3B82F6)),
                        if (till.digitalExpenses > 0)
                          _detailRow('Digital Expenses', till.digitalExpenses, '−', AppColors.error),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ═══════════════════════════════════════════════════
                  // SECTION 6 — Closing Cash Verification
                  // ═══════════════════════════════════════════════════
                  _sectionCard(
                    icon: Icons.calculate_rounded,
                    gradient: AppColors.warningGradient,
                    title: 'Cash Drawer Verification',
                    subtitle: 'Count physical cash and enter below',
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _closingCashCtrl,
                                keyboardType: TextInputType.number,
                                style: AppTypography.monoLarge.copyWith(
                                    color: AppColors.textPrimary(context), fontSize: 20),
                                decoration: _inputDecoration('₹ ',
                                    hint: 'Actual cash counted'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            _actionButton('Verify', Icons.check_circle_rounded,
                                AppColors.warning, () async {
                              final amount = double.tryParse(_closingCashCtrl.text) ?? 0;
                              final success = await provider.setActualClosingCash(amount);
                              if (success && context.mounted) {
                                _showSnack('Cash verification recorded ✓');
                              }
                            }),
                          ],
                        ),
                        if (till.isCashCounted) ...[
                          const SizedBox(height: 16),
                          _cashVerificationResult(till),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ═══════════════════════════════════════════════════
                  // SECTION 7 — Daily Reconciliation Summary
                  // ═══════════════════════════════════════════════════
                  _reconciliationSummary(till),
                  const SizedBox(height: 32),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  // ─── Cash Verification Result ───
  Widget _cashVerificationResult(dynamic till) {
    final diff = till.cashDifference as double;
    final isMatch = diff.abs() < 1;
    final isMinor = diff.abs() < 50;

    Color statusColor;
    String statusText;
    IconData statusIcon;

    if (isMatch) {
      statusColor = AppColors.success;
      statusText = 'Perfect Match ✓';
      statusIcon = Icons.check_circle_rounded;
    } else if (isMinor) {
      statusColor = AppColors.warning;
      statusText = 'Minor Difference';
      statusIcon = Icons.warning_rounded;
    } else {
      statusColor = AppColors.error;
      statusText = 'Cash Mismatch Detected';
      statusIcon = Icons.error_rounded;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(statusIcon, color: statusColor, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(statusText,
                    style: AppTypography.labelLarge.copyWith(color: statusColor)),
                const SizedBox(height: 2),
                Text(
                  'Expected: ${Formatters.currency(till.expectedCash)}  •  Actual: ${Formatters.currency(till.actualClosingCash)}',
                  style: AppTypography.labelSmall.copyWith(
                      color: AppColors.textTertiary(context)),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'Difference',
                style: AppTypography.labelSmall.copyWith(color: AppColors.textTertiary(context)),
              ),
              Text(
                '${diff >= 0 ? '+' : ''}${Formatters.currency(diff)}',
                style: AppTypography.mono.copyWith(
                  color: statusColor,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Reconciliation Summary Card ───
  Widget _reconciliationSummary(dynamic till) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.summarize_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text(
                'Daily Reconciliation Summary',
                style: AppTypography.h4.copyWith(color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Cash Section
          _summaryLine('Opening Cash', till.openingCash, Colors.white),
          _summaryLine('+ Cash Sales', till.cashSales, const Color(0xFF86EFAC)),
          _summaryLine('− Cash Expenses', till.cashExpenses, const Color(0xFFFCA5A5)),
          if (till.cashRefunds > 0)
            _summaryLine('− Cash Refunds', till.cashRefunds, const Color(0xFFFCA5A5)),
          const Divider(color: Colors.white24, height: 20),
          _summaryLine('= Expected Closing Cash', till.expectedCash, Colors.white, bold: true),

          if (till.isCashCounted) ...[
            const SizedBox(height: 4),
            _summaryLine('Actual Counted Cash', till.actualClosingCash, Colors.white),
            _summaryLine(
              'Difference',
              till.cashDifference,
              till.cashDifference.abs() < 1
                  ? const Color(0xFF86EFAC)
                  : (till.cashDifference.abs() < 50
                      ? const Color(0xFFFDE68A)
                      : const Color(0xFFFCA5A5)),
              bold: true,
            ),
          ],

          const Divider(color: Colors.white24, height: 24),

          // Digital Section
          _summaryLine('UPI Collection', till.upiSales, const Color(0xFFC4B5FD)),
          _summaryLine('Card Collection', till.cardSales, const Color(0xFF93C5FD)),
          if (till.digitalExpenses > 0)
            _summaryLine('− Digital Expenses', till.digitalExpenses, const Color(0xFFFCA5A5)),
          const Divider(color: Colors.white24, height: 20),
          _summaryLine('= Net Digital Balance', till.digitalCollection, Colors.white, bold: true),

          const Divider(color: Colors.white24, height: 24),

          // Grand Total
          _summaryLine('Total Day Collection', till.totalSales, Colors.white, bold: true, large: true),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // REUSABLE WIDGETS
  // ═══════════════════════════════════════════════════════════

  Widget _sectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.accent),
        const SizedBox(width: 8),
        Text(title, style: AppTypography.h3.copyWith(color: AppColors.textPrimary(context))),
      ],
    );
  }

  Widget _sectionCard({
    required IconData icon,
    required LinearGradient gradient,
    required String title,
    String? subtitle,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: gradient,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTypography.h4.copyWith(color: AppColors.textPrimary(context))),
                  if (subtitle != null)
                    Text(subtitle,
                        style: AppTypography.labelSmall.copyWith(color: AppColors.textTertiary(context))),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _metricCard(String title, double value, IconData icon, Color color, Color bgColor,
      {String? subtitle}) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardBorder(context)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: AppTypography.labelSmall.copyWith(color: AppColors.textTertiary(context))),
                const SizedBox(height: 2),
                Text(Formatters.currency(value),
                    style: AppTypography.mono.copyWith(
                        color: color, fontWeight: FontWeight.w700, fontSize: 16)),
                if (subtitle != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(subtitle,
                        style: TextStyle(fontSize: 9, color: AppColors.textTertiary(context))),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _responsiveGrid(List<Widget> cards) {
    return LayoutBuilder(builder: (context, constraints) {
      final isWide = constraints.maxWidth > 700;
      if (isWide) {
        return Row(
          children: cards
              .map((c) => Expanded(
                  child: Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: c)))
              .toList(),
        );
      }
      return Column(
          children:
              cards.map((c) => Padding(padding: const EdgeInsets.only(bottom: 10), child: c)).toList());
    });
  }

  Widget _detailRow(String label, double value, String sign, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text('$sign  ', style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 13)),
          Text(label, style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary(context))),
          const Spacer(),
          Text(Formatters.currency(value),
              style: AppTypography.monoSmall.copyWith(color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _summaryLine(String label, double value, Color color,
      {bool bold = false, bool large = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                color: color.withValues(alpha: bold ? 1.0 : 0.8),
                fontSize: large ? 14 : 12,
                fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
              )),
          Text(
            Formatters.currency(value),
            style: AppTypography.monoSmall.copyWith(
              color: color,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
              fontSize: large ? 18 : 13,
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String prefix, {String? hint}) {
    return InputDecoration(
      prefixText: prefix,
      prefixStyle: AppTypography.monoLarge.copyWith(
          color: AppColors.textTertiary(context), fontSize: 20),
      hintText: hint,
      hintStyle: TextStyle(color: AppColors.textTertiary(context), fontSize: 14),
      filled: true,
      fillColor: AppColors.surface(context),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppColors.cardBorder(context)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppColors.cardBorder(context)),
      ),
    );
  }

  Widget _actionButton(String label, IconData icon, Color color, VoidCallback onPressed) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppColors.card(context)),
    );
  }
}
