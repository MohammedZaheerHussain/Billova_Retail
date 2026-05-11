import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/formatters.dart';

class LoansChitsScreen extends StatefulWidget {
  const LoansChitsScreen({super.key});

  @override
  State<LoansChitsScreen> createState() => _LoansChitsScreenState();
}

class _LoansChitsScreenState extends State<LoansChitsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  final List<_LoanEntry> _loans = [];
  final List<_ChitEntry> _chits = [];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  void _showAddLoanDialog() {
    final nameCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    String type = 'Given';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppColors.card(context),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(children: [
            Icon(Icons.account_balance_wallet_rounded, color: AppColors.primary, size: 22),
            const SizedBox(width: 8),
            Text('Add Loan / Udhaar', style: AppTypography.h4.copyWith(
                color: AppColors.textPrimary(context))),
          ]),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            // Type toggle
            Row(children: [
              _toggleChip('Given (You Lent)', type == 'Given',
                  () => setDialogState(() => type = 'Given')),
              const SizedBox(width: 8),
              _toggleChip('Taken (You Owe)', type == 'Taken',
                  () => setDialogState(() => type = 'Taken')),
            ]),
            const SizedBox(height: 12),
            _dialogField(nameCtrl, 'Person Name', Icons.person_rounded),
            const SizedBox(height: 10),
            _dialogField(phoneCtrl, 'Phone (optional)', Icons.phone_rounded),
            const SizedBox(height: 10),
            _dialogField(amountCtrl, 'Amount (₹)', Icons.currency_rupee_rounded,
                keyboardType: TextInputType.number),
          ]),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel', style: TextStyle(color: AppColors.textTertiary(context))),
            ),
            ElevatedButton(
              onPressed: () {
                final amount = double.tryParse(amountCtrl.text) ?? 0;
                if (nameCtrl.text.trim().isEmpty || amount <= 0) return;
                setState(() => _loans.add(_LoanEntry(
                  name: nameCtrl.text.trim(),
                  phone: phoneCtrl.text.trim(),
                  amount: amount,
                  remaining: amount,
                  type: type,
                  date: DateTime.now(),
                )));
                Navigator.pop(ctx);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddChitDialog() {
    final nameCtrl = TextEditingController();
    final monthlyCtrl = TextEditingController();
    final totalCtrl = TextEditingController();
    final membersCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          Icon(Icons.groups_rounded, color: AppColors.warning, size: 22),
          const SizedBox(width: 8),
          Text('Add Chit Fund', style: AppTypography.h4.copyWith(
              color: AppColors.textPrimary(context))),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          _dialogField(nameCtrl, 'Chit Name', Icons.label_rounded),
          const SizedBox(height: 10),
          _dialogField(monthlyCtrl, 'Monthly Amount (₹)', Icons.calendar_month_rounded,
              keyboardType: TextInputType.number),
          const SizedBox(height: 10),
          _dialogField(totalCtrl, 'Total Value (₹)', Icons.account_balance_rounded,
              keyboardType: TextInputType.number),
          const SizedBox(height: 10),
          _dialogField(membersCtrl, 'Total Members', Icons.people_rounded,
              keyboardType: TextInputType.number),
        ]),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: AppColors.textTertiary(context))),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameCtrl.text.trim().isEmpty) return;
              setState(() => _chits.add(_ChitEntry(
                name: nameCtrl.text.trim(),
                monthlyAmount: double.tryParse(monthlyCtrl.text) ?? 0,
                totalValue: double.tryParse(totalCtrl.text) ?? 0,
                totalMembers: int.tryParse(membersCtrl.text) ?? 0,
                paidMonths: 0,
                startDate: DateTime.now(),
              )));
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.warning,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _recordPayment(int index) {
    final loan = _loans[index];
    final ctrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Record Payment', style: AppTypography.h4.copyWith(
            color: AppColors.textPrimary(context))),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('${loan.name} — Remaining: ${Formatters.currency(loan.remaining)}',
              style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary(context))),
          const SizedBox(height: 12),
          _dialogField(ctrl, 'Payment Amount (₹)', Icons.currency_rupee_rounded,
              keyboardType: TextInputType.number),
        ]),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: AppColors.textTertiary(context))),
          ),
          ElevatedButton(
            onPressed: () {
              final payment = double.tryParse(ctrl.text) ?? 0;
              if (payment <= 0) return;
              setState(() {
                _loans[index] = loan.copyWith(
                    remaining: (loan.remaining - payment).clamp(0.0, loan.amount));
              });
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Record'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final totalGiven = _loans.where((l) => l.type == 'Given').fold(0.0, (s, l) => s + l.remaining);
    final totalTaken = _loans.where((l) => l.type == 'Taken').fold(0.0, (s, l) => s + l.remaining);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(children: [
              Text('Loans & Chits', style: AppTypography.h1.copyWith(
                  color: isDark ? AppColors.textPrimary(context) : AppColors.textPrimaryLight)),
              const Spacer(),
              // Summary badges
              _summaryBadge('You Lent', Formatters.currency(totalGiven), AppColors.error),
              const SizedBox(width: 10),
              _summaryBadge('You Owe', Formatters.currency(totalTaken), AppColors.warning),
            ]),
            const SizedBox(height: 16),

            // Tab bar
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface(context),
                borderRadius: BorderRadius.circular(10)),
              child: TabBar(
                controller: _tabCtrl,
                indicator: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10)),
                labelColor: AppColors.primary,
                unselectedLabelColor: AppColors.textTertiary(context),
                labelStyle: AppTypography.labelMedium.copyWith(fontWeight: FontWeight.w700),
                tabs: const [
                  Tab(text: 'Loans / Udhaar'),
                  Tab(text: 'Chit Funds'),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Tab views
            Expanded(
              child: TabBarView(
                controller: _tabCtrl,
                children: [
                  _buildLoansTab(),
                  _buildChitsTab(),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          if (_tabCtrl.index == 0) {
            _showAddLoanDialog();
          } else {
            _showAddChitDialog();
          }
        },
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add New'),
      ),
    );
  }

  Widget _buildLoansTab() {
    if (_loans.isEmpty) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.account_balance_wallet_outlined, size: 64,
            color: AppColors.accent.withValues(alpha: 0.2)),
        const SizedBox(height: 12),
        Text('No loans recorded', style: AppTypography.bodyMedium.copyWith(
            color: AppColors.textTertiary(context))),
        const SizedBox(height: 4),
        Text('Tap + to add a loan or udhaar entry', style: AppTypography.labelSmall.copyWith(
            color: AppColors.textTertiary(context))),
      ]));
    }

    return ListView.builder(
      itemCount: _loans.length,
      itemBuilder: (_, i) {
        final loan = _loans[i];
        final isPaid = loan.remaining <= 0;
        final isGiven = loan.type == 'Given';
        final pct = loan.amount > 0 ? (1 - loan.remaining / loan.amount) : 1.0;

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.card(context),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: isPaid
                ? AppColors.success.withValues(alpha: 0.4)
                : AppColors.cardBorder(context)),
          ),
          child: Column(children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: (isGiven ? AppColors.error : AppColors.warning).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10)),
                child: Icon(
                  isGiven ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                  color: isGiven ? AppColors.error : AppColors.warning, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(loan.name, style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.textPrimary(context), fontWeight: FontWeight.w600)),
                  Text('${loan.type} • ${loan.date.day}/${loan.date.month}/${loan.date.year}',
                      style: AppTypography.labelSmall.copyWith(
                          color: AppColors.textTertiary(context))),
                ],
              )),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(Formatters.currency(loan.amount),
                    style: AppTypography.mono.copyWith(
                        color: AppColors.textSecondary(context), fontSize: 12,
                        decoration: isPaid ? TextDecoration.lineThrough : null)),
                Text(isPaid ? 'PAID' : 'Due: ${Formatters.currency(loan.remaining)}',
                    style: AppTypography.mono.copyWith(
                        color: isPaid ? AppColors.success : AppColors.error,
                        fontWeight: FontWeight.w700, fontSize: 13)),
              ]),
              if (!isPaid) ...[
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(Icons.payments_rounded, color: AppColors.success, size: 20),
                  tooltip: 'Record Payment',
                  onPressed: () => _recordPayment(i),
                ),
              ],
            ]),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: pct,
                backgroundColor: AppColors.cardBorder(context),
                color: isPaid ? AppColors.success : AppColors.primary,
                minHeight: 4,
              ),
            ),
          ]),
        );
      },
    );
  }

  Widget _buildChitsTab() {
    if (_chits.isEmpty) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.groups_outlined, size: 64,
            color: AppColors.accent.withValues(alpha: 0.2)),
        const SizedBox(height: 12),
        Text('No chit funds recorded', style: AppTypography.bodyMedium.copyWith(
            color: AppColors.textTertiary(context))),
        const SizedBox(height: 4),
        Text('Tap + to add a chit fund', style: AppTypography.labelSmall.copyWith(
            color: AppColors.textTertiary(context))),
      ]));
    }

    return ListView.builder(
      itemCount: _chits.length,
      itemBuilder: (_, i) {
        final chit = _chits[i];
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.card(context),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.cardBorder(context)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10)),
                  child: Icon(Icons.groups_rounded, color: AppColors.warning, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(chit.name, style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.textPrimary(context), fontWeight: FontWeight.w600)),
                    Text('${chit.totalMembers} members • Started ${chit.startDate.day}/${chit.startDate.month}/${chit.startDate.year}',
                        style: AppTypography.labelSmall.copyWith(
                            color: AppColors.textTertiary(context))),
                  ],
                )),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text(Formatters.currency(chit.totalValue),
                      style: AppTypography.mono.copyWith(
                          color: AppColors.accent, fontWeight: FontWeight.w700)),
                  Text('${Formatters.currency(chit.monthlyAmount)}/mo',
                      style: AppTypography.labelSmall.copyWith(
                          color: AppColors.textTertiary(context))),
                ]),
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(Icons.add_circle_rounded, color: AppColors.success, size: 20),
                  tooltip: 'Record Monthly Payment',
                  onPressed: () {
                    setState(() => _chits[i] = chit.copyWith(
                        paidMonths: chit.paidMonths + 1));
                  },
                ),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                Text('Paid: ${chit.paidMonths}/${chit.totalMembers} months',
                    style: AppTypography.labelSmall.copyWith(
                        color: AppColors.textSecondary(context))),
                const Spacer(),
                Text('${Formatters.currency(chit.monthlyAmount * chit.paidMonths)} paid',
                    style: AppTypography.mono.copyWith(
                        color: AppColors.success, fontSize: 12)),
              ]),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: chit.totalMembers > 0 ? chit.paidMonths / chit.totalMembers : 0,
                  backgroundColor: AppColors.cardBorder(context),
                  color: AppColors.warning,
                  minHeight: 4,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _summaryBadge(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text('$label: ', style: AppTypography.labelSmall.copyWith(
            color: AppColors.textSecondary(context))),
        Text(value, style: AppTypography.mono.copyWith(
            color: color, fontWeight: FontWeight.w700, fontSize: 13)),
      ]),
    );
  }

  Widget _toggleChip(String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: active ? AppColors.primary.withValues(alpha: 0.15) : AppColors.surface(context),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: active ? AppColors.primary : AppColors.cardBorder(context)),
        ),
        child: Text(label, style: AppTypography.labelSmall.copyWith(
            color: active ? AppColors.primary : AppColors.textSecondary(context),
            fontWeight: active ? FontWeight.w700 : FontWeight.w400)),
      ),
    );
  }

  Widget _dialogField(TextEditingController ctrl, String hint, IconData icon,
      {TextInputType? keyboardType}) {
    return TextField(
      controller: ctrl,
      keyboardType: keyboardType,
      style: TextStyle(color: AppColors.textPrimary(context), fontSize: 13),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: AppColors.textTertiary(context), fontSize: 12),
        prefixIcon: Icon(icon, size: 18, color: AppColors.textTertiary(context)),
        filled: true,
        fillColor: AppColors.surface(context),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: AppColors.cardBorder(context))),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
    );
  }
}

// ─── Data models (in-memory for now) ───

class _LoanEntry {
  final String name;
  final String phone;
  final double amount;
  final double remaining;
  final String type; // 'Given' or 'Taken'
  final DateTime date;

  _LoanEntry({
    required this.name,
    this.phone = '',
    required this.amount,
    required this.remaining,
    required this.type,
    required this.date,
  });

  _LoanEntry copyWith({double? remaining}) => _LoanEntry(
    name: name, phone: phone, amount: amount,
    remaining: remaining ?? this.remaining,
    type: type, date: date,
  );
}

class _ChitEntry {
  final String name;
  final double monthlyAmount;
  final double totalValue;
  final int totalMembers;
  final int paidMonths;
  final DateTime startDate;

  _ChitEntry({
    required this.name,
    required this.monthlyAmount,
    required this.totalValue,
    required this.totalMembers,
    required this.paidMonths,
    required this.startDate,
  });

  _ChitEntry copyWith({int? paidMonths}) => _ChitEntry(
    name: name, monthlyAmount: monthlyAmount, totalValue: totalValue,
    totalMembers: totalMembers, paidMonths: paidMonths ?? this.paidMonths,
    startDate: startDate,
  );
}
