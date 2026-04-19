import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/date_filter.dart';
import '../../core/constants.dart';
import '../../data/models/expense_model.dart';
import '../../providers/expense_provider.dart';
import '../../providers/cash_till_provider.dart';
import '../../widgets/date_filter_bar.dart';

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key});

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  String _selectedCategory = 'General';

  void _addExpense() async {
    final amount = double.tryParse(_amountCtrl.text.trim());
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid amount'), backgroundColor: AppColors.error),
      );
      return;
    }

    final provider = context.read<ExpenseProvider>();
    final success = await provider.addExpense(
      amount: amount,
      note: _noteCtrl.text.trim(),
      category: _selectedCategory,
    );

    if (success && mounted) {
      _amountCtrl.clear();
      _noteCtrl.clear();
      setState(() => _selectedCategory = 'General');
      context.read<CashTillProvider>().refresh();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Expense added'), backgroundColor: AppColors.cardDark),
      );
    }
  }

  Future<void> _pickCustomRange(ExpenseProvider provider) async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: now,
      initialDateRange: DateTimeRange(
        start: provider.customStart ?? now.subtract(const Duration(days: 7)),
        end: provider.customEnd ?? now,
      ),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              surface: AppColors.cardDark,
              onSurface: AppColors.textPrimaryDark,
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
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ExpenseProvider>(
      builder: (context, provider, _) {
        final grouped = provider.groupedExpenses;
        final groupKeys = grouped.keys.toList();

        return Scaffold(
          backgroundColor: Colors.transparent,
          body: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ─── Header ───
                Row(
                  children: [
                    Text('Expenses', style: AppTypography.h1.copyWith(color: AppColors.textPrimaryDark)),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.errorBg,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        '${provider.expenseCount} expenses',
                        style: AppTypography.mono.copyWith(color: AppColors.error, fontSize: 13),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // ─── Date Filter Bar ───
                DateFilterBar(
                  selected: provider.filterType,
                  onChanged: (type) => provider.setFilter(type),
                  onCustomTap: () => _pickCustomRange(provider),
                ),
                const SizedBox(height: 16),

                // ─── Add Expense Card ───
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.cardDark,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.cardBorderDark),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              gradient: AppColors.errorGradient,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.add_rounded, color: Colors.white, size: 18),
                          ),
                          const SizedBox(width: 10),
                          Text('Add Expense',
                              style: AppTypography.h4.copyWith(color: AppColors.textPrimaryDark)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: TextField(
                              controller: _amountCtrl,
                              keyboardType: TextInputType.number,
                              style: AppTypography.mono.copyWith(
                                  color: AppColors.textPrimaryDark, fontSize: 16),
                              decoration: InputDecoration(
                                prefixText: '₹ ',
                                prefixStyle: AppTypography.mono
                                    .copyWith(color: AppColors.textTertiaryDark),
                                hintText: '0.00',
                                hintStyle: const TextStyle(color: AppColors.textTertiaryDark),
                                filled: true,
                                fillColor: AppColors.surfaceDark,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(color: AppColors.cardBorderDark),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(color: AppColors.cardBorderDark),
                                ),
                                contentPadding:
                                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 2,
                            child: DropdownButtonFormField<String>(
                              value: _selectedCategory,
                              onChanged: (v) => setState(() => _selectedCategory = v!),
                              dropdownColor: AppColors.cardDark,
                              style: const TextStyle(
                                  color: AppColors.textPrimaryDark, fontSize: 13),
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: AppColors.surfaceDark,
                                contentPadding:
                                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(color: AppColors.cardBorderDark),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(color: AppColors.cardBorderDark),
                                ),
                              ),
                              items: AppConstants.expenseCategories
                                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                                  .toList(),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _noteCtrl,
                              style: const TextStyle(
                                  color: AppColors.textPrimaryDark, fontSize: 13),
                              decoration: InputDecoration(
                                hintText: 'Note (optional)',
                                hintStyle:
                                    const TextStyle(color: AppColors.textTertiaryDark, fontSize: 12),
                                filled: true,
                                fillColor: AppColors.surfaceDark,
                                contentPadding:
                                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(color: AppColors.cardBorderDark),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(color: AppColors.cardBorderDark),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          ElevatedButton.icon(
                            onPressed: _addExpense,
                            icon: const Icon(Icons.add_rounded, size: 18),
                            label: const Text('Add'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.error,
                              foregroundColor: Colors.white,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // ─── Summary Card ───
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.errorBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.error.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${DateFilterHelper.filterLabel(provider.filterType)} Expenses',
                            style: AppTypography.labelMedium.copyWith(color: AppColors.error),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${provider.expenseCount} transaction${provider.expenseCount != 1 ? 's' : ''}',
                            style: AppTypography.labelSmall.copyWith(color: AppColors.textTertiaryDark),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Text(
                        Formatters.currency(provider.totalExpenses),
                        style: AppTypography.mono.copyWith(
                          color: AppColors.error,
                          fontWeight: FontWeight.w700,
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

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
                        const Icon(Icons.error_outline, color: AppColors.error, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(provider.error,
                              style: AppTypography.bodySmall.copyWith(color: AppColors.error)),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 16, color: AppColors.error),
                          onPressed: provider.clearError,
                        ),
                      ],
                    ),
                  ),

                // ─── Grouped Expenses List ───
                Expanded(
                  child: provider.isLoading
                      ? const Center(
                          child: CircularProgressIndicator(color: AppColors.accent))
                      : _filteredExpenses.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.money_off_rounded,
                                      size: 56,
                                      color: AppColors.textTertiaryDark.withValues(alpha: 0.3)),
                                  const SizedBox(height: 12),
                                  Text('No expenses for ${DateFilterHelper.filterLabel(provider.filterType).toLowerCase()}',
                                      style: AppTypography.bodyMedium
                                          .copyWith(color: AppColors.textTertiaryDark)),
                                ],
                              ),
                            )
                          : ListView.builder(
                              itemCount: _buildGroupedItems(grouped, groupKeys).length,
                              itemBuilder: (context, index) {
                                return _buildGroupedItems(grouped, groupKeys)[index];
                              },
                            ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  List<ExpenseModel> get _filteredExpenses =>
      context.read<ExpenseProvider>().expenses;

  List<Widget> _buildGroupedItems(
      Map<String, List<ExpenseModel>> grouped, List<String> keys) {
    final widgets = <Widget>[];
    for (final dateLabel in keys) {
      final items = grouped[dateLabel]!;
      final dayTotal = items.fold<double>(0, (sum, e) => sum + e.amount);

      // Date group header
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 6),
          child: Row(
            children: [
              const Icon(Icons.calendar_today_rounded, size: 14, color: AppColors.accent),
              const SizedBox(width: 8),
              Text(
                dateLabel,
                style: AppTypography.labelMedium.copyWith(
                  color: AppColors.accent,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(height: 1, color: AppColors.cardBorderDark),
              ),
              const SizedBox(width: 8),
              Text(
                Formatters.currency(dayTotal),
                style: AppTypography.monoSmall.copyWith(
                  color: AppColors.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );

      // Expense items for this date
      for (final expense in items) {
        widgets.add(_expenseCard(expense));
      }
    }
    return widgets;
  }

  Widget _expenseCard(dynamic expense) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorderDark),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        leading: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: AppColors.errorBg,
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.arrow_upward_rounded,
              color: AppColors.error, size: 18),
        ),
        title: Row(
          children: [
            Text(
              Formatters.currency(expense.amount),
              style: AppTypography.mono.copyWith(
                color: AppColors.error,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                expense.category,
                style: AppTypography.labelSmall.copyWith(color: AppColors.accent),
              ),
            ),
          ],
        ),
        subtitle: expense.note.isNotEmpty
            ? Text(expense.note,
                style: AppTypography.bodySmall.copyWith(color: AppColors.textTertiaryDark))
            : null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              Formatters.time(expense.createdAt),
              style: AppTypography.labelSmall.copyWith(color: AppColors.textTertiaryDark),
            ),
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.delete_outline,
                  color: AppColors.textTertiaryDark, size: 18),
              onPressed: () {
                context.read<ExpenseProvider>().deleteExpense(expense.id);
                context.read<CashTillProvider>().refresh();
              },
            ),
          ],
        ),
      ),
    );
  }
}
