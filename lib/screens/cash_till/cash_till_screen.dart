import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/formatters.dart';
import '../../providers/cash_till_provider.dart';

class CashTillScreen extends StatefulWidget {
  const CashTillScreen({super.key});

  @override
  State<CashTillScreen> createState() => _CashTillScreenState();
}

class _CashTillScreenState extends State<CashTillScreen> {
  final _openingCashCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<CashTillProvider>();
      provider.loadToday();
    });
  }

  @override
  void dispose() {
    _openingCashCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<CashTillProvider>(
      builder: (context, provider, _) {
        final till = provider.today;

        if (till != null) {
          _openingCashCtrl.text = till.openingCash.toStringAsFixed(0);
        }

        return Scaffold(
          backgroundColor: Colors.transparent,
          body: SingleChildScrollView(
            padding: EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('Daily Cash Till',
                        style: AppTypography.h1.copyWith(color: AppColors.textPrimary(context))),
                    const Spacer(),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        Formatters.date(DateTime.now()),
                        style: AppTypography.mono.copyWith(color: AppColors.accent, fontSize: 13),
                      ),
                    ),
                    SizedBox(width: 8),
                    IconButton(
                      onPressed: () => provider.refresh(),
                      icon: Icon(Icons.refresh_rounded, color: AppColors.textSecondary(context)),
                      tooltip: 'Refresh',
                    ),
                  ],
                ),
                SizedBox(height: 24),

                if (provider.isLoading)
                  Center(child: CircularProgressIndicator(color: AppColors.accent))
                else if (till == null)
                  Center(
                    child: Text('Unable to load cash till',
                        style: AppTypography.bodyMedium.copyWith(color: AppColors.textTertiary(context))),
                  )
                else ...[
                  // ─── Opening Cash ───
                  _card(
                    icon: Icons.account_balance_wallet_rounded,
                    iconGradient: AppColors.primaryGradient,
                    title: 'Opening Cash',
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _openingCashCtrl,
                            keyboardType: TextInputType.number,
                            style: AppTypography.monoLarge.copyWith(color: AppColors.textPrimary(context)),
                            decoration: InputDecoration(
                              prefixText: '₹ ',
                              prefixStyle: AppTypography.monoLarge.copyWith(color: AppColors.textTertiary(context)),
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
                            ),
                          ),
                        ),
                        SizedBox(width: 12),
                        ElevatedButton(
                          onPressed: () async {
                            final amount = double.tryParse(_openingCashCtrl.text) ?? 0;
                            final success = await provider.setOpeningCash(amount);
                            if (success && context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Opening cash updated'),
                                  backgroundColor: AppColors.card(context),
                                ),
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('Save', style: TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ─── Summary Cards ───
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isWide = constraints.maxWidth > 700;
                      final cards = [
                        _summaryCard(
                          'Cash In (Sales)',
                          Formatters.currency(till.cashIn),
                          Icons.arrow_downward_rounded,
                          AppColors.success,
                          AppColors.successBg,
                        ),
                        _summaryCard(
                          'Cash Out (Expenses)',
                          Formatters.currency(till.cashOut),
                          Icons.arrow_upward_rounded,
                          AppColors.error,
                          AppColors.errorBg,
                        ),
                        _summaryCard(
                          'Net Flow',
                          Formatters.currency(till.netFlow),
                          till.netFlow >= 0 ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                          till.netFlow >= 0 ? AppColors.success : AppColors.error,
                          till.netFlow >= 0 ? AppColors.successBg : AppColors.errorBg,
                        ),
                      ];

                      if (isWide) {
                        return Row(
                          children: cards
                              .map((c) => Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: c)))
                              .toList(),
                        );
                      }
                      return Column(children: cards.map((c) => Padding(padding: const EdgeInsets.only(bottom: 12), child: c)).toList());
                    },
                  ),
                  const SizedBox(height: 16),

                  // ─── Closing Balance ───
                  Container(
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
                      children: [
                        Text(
                          'Closing Balance',
                          style: AppTypography.labelLarge.copyWith(
                            color: Colors.white.withValues(alpha: 0.8),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          Formatters.currency(till.closingBalance),
                          style: AppTypography.monoLarge.copyWith(
                            color: Colors.white,
                            fontSize: 36,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Opening ₹${till.openingCash.toStringAsFixed(0)} + Sales ₹${till.cashIn.toStringAsFixed(0)} − Expenses ₹${till.cashOut.toStringAsFixed(0)}',
                          style: AppTypography.labelSmall.copyWith(
                            color: Colors.white.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _card({
    required IconData icon,
    required LinearGradient iconGradient,
    required String title,
    required Widget child,
  }) {
    return Container(
      padding: EdgeInsets.all(20),
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
                  gradient: iconGradient,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: Colors.white),
              ),
              SizedBox(width: 12),
              Text(title, style: AppTypography.h4.copyWith(color: AppColors.textPrimary(context))),
            ],
          ),
          SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _summaryCard(String title, String value, IconData icon, Color color, Color bgColor) {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardBorder(context)),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppTypography.labelSmall.copyWith(color: AppColors.textTertiary(context))),
              const SizedBox(height: 4),
              Text(value, style: AppTypography.mono.copyWith(color: color, fontWeight: FontWeight.w700, fontSize: 16)),
            ],
          ),
        ],
      ),
    );
  }
}
