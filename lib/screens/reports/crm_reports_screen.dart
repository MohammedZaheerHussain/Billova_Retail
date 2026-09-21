import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/formatters.dart';
import '../../providers/sales_provider.dart';
import '../../providers/inventory_provider.dart';
import '../../providers/customer_provider.dart';
import '../../providers/expense_provider.dart';
import '../../widgets/stock_alert_drawer.dart';

class CrmReportsScreen extends StatefulWidget {
  const CrmReportsScreen({super.key});

  @override
  State<CrmReportsScreen> createState() => _CrmReportsScreenState();
}

class _CrmReportsScreenState extends State<CrmReportsScreen> {
  String _period = 'Today';
  DateTime? _customStart;
  DateTime? _customEnd;
  bool _showOnlyDues = false;  // Filter: show only customers with outstanding balance

  static const _periods = ['Today', 'Yesterday', 'Last 7 Days', 'Last 30 Days', 'This Month', 'This Year', 'All Time', 'Custom'];

  /// Get the date range for the current period
  ({DateTime start, DateTime end}) _getDateRange() {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = todayStart.add(const Duration(days: 1));

    switch (_period) {
      case 'Today':
        return (start: todayStart, end: todayEnd);
      case 'Yesterday':
        final ys = todayStart.subtract(const Duration(days: 1));
        return (start: ys, end: todayStart);
      case 'Last 7 Days':
        return (start: todayStart.subtract(const Duration(days: 7)), end: todayEnd);
      case 'Last 30 Days':
        return (start: todayStart.subtract(const Duration(days: 30)), end: todayEnd);
      case 'This Month':
        return (start: DateTime(now.year, now.month, 1), end: todayEnd);
      case 'This Year':
        return (start: DateTime(now.year, 1, 1), end: todayEnd);
      case 'Custom':
        return (
          start: _customStart ?? todayStart,
          end: (_customEnd ?? todayStart).add(const Duration(days: 1)),
        );
      default: // All Time
        return (start: DateTime(2020), end: todayEnd);
    }
  }

  /// Format a date for display
  String _fmtDate(DateTime d) {
    const months = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${d.day} ${months[d.month]} ${d.year}';
  }

  /// Show the calendar date picker dialog
  Future<void> _showCalendarPicker() async {
    final now = DateTime.now();

    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: now,
      initialDateRange: _customStart != null && _customEnd != null
          ? DateTimeRange(start: _customStart!, end: _customEnd!)
          : DateTimeRange(start: now, end: now),
      helpText: 'SELECT DATE RANGE',
      cancelText: 'CANCEL',
      confirmText: 'APPLY',
      saveText: 'APPLY',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.dark(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              surface: const Color(0xFF1A1A2E),
              onSurface: Colors.white,
              secondary: AppColors.accent,
              onSecondary: Colors.white,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(foregroundColor: AppColors.accent),
            ),
            datePickerTheme: DatePickerThemeData(
              backgroundColor: const Color(0xFF1A1A2E),
              headerBackgroundColor: AppColors.primary.withValues(alpha: 0.15),
              headerForegroundColor: Colors.white,
              dayForegroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) return Colors.white;
                if (states.contains(WidgetState.disabled)) return Colors.white24;
                return Colors.white70;
              }),
              dayBackgroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) return AppColors.primary;
                return null;
              }),
              todayForegroundColor: WidgetStateProperty.all(AppColors.accent),
              rangePickerBackgroundColor: const Color(0xFF1A1A2E),
              rangePickerHeaderBackgroundColor: AppColors.primary.withValues(alpha: 0.15),
              rangePickerHeaderForegroundColor: Colors.white,
              rangeSelectionBackgroundColor: AppColors.primary.withValues(alpha: 0.2),
              surfaceTintColor: Colors.transparent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ), dialogTheme: DialogThemeData(backgroundColor: const Color(0xFF1A1A2E)),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: child!,
          ),
        );
      },
    );

    if (picked != null) {
      setState(() {
        _customStart = picked.start;
        _customEnd = picked.end;
        _period = 'Custom';
      });
    }
  }

  /// Show single date picker
  Future<void> _showSingleDatePicker() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _customStart ?? now,
      firstDate: DateTime(2020),
      lastDate: now,
      helpText: 'SELECT DATE',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.dark(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              surface: const Color(0xFF1A1A2E),
              onSurface: Colors.white,
              secondary: AppColors.accent,
            ),
            datePickerTheme: DatePickerThemeData(
              backgroundColor: const Color(0xFF1A1A2E),
              headerBackgroundColor: AppColors.primary.withValues(alpha: 0.15),
              headerForegroundColor: Colors.white,
              dayForegroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) return Colors.white;
                if (states.contains(WidgetState.disabled)) return Colors.white24;
                return Colors.white70;
              }),
              dayBackgroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) return AppColors.primary;
                return null;
              }),
              todayForegroundColor: WidgetStateProperty.all(AppColors.accent),
              surfaceTintColor: Colors.transparent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ), dialogTheme: DialogThemeData(backgroundColor: const Color(0xFF1A1A2E)),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _customStart = picked;
        _customEnd = picked;
        _period = 'Custom';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sales = context.watch<SalesProvider>();
    final inventory = context.watch<InventoryProvider>();
    final customers = context.watch<CustomerProvider>();
    final expenses = context.watch<ExpenseProvider>();

    // Get date range
    final range = _getDateRange();

    // Filter sales by date range — use allSales (not .sales which is pre-filtered by bill history)
    final filteredSales = sales.allSales.where((s) {
      if (_period == 'All Time') return true;
      final localTime = s.createdAt.toLocal();
      return !localTime.isBefore(range.start) && localTime.isBefore(range.end);
    }).toList();

    final totalRevenue = filteredSales.fold(0.0, (sum, s) => sum + s.total);
    final totalOrders = filteredSales.length;
    final avgOrderValue = totalOrders > 0 ? totalRevenue / totalOrders : 0.0;

    final totalExpenses = expenses.expenses.where((e) {
      if (_period == 'All Time') return true;
      final localTime = e.createdAt.toLocal();
      return !localTime.isBefore(range.start) && localTime.isBefore(range.end);
    }).fold(0.0, (sum, e) => sum + e.amount);

    // Gross Profit = sum of per-item (selling_price - cost_price) * quantity - discount
    // NOT revenue - expenses (that's net profit, and expenses != cost of goods)
    final profit = filteredSales.fold(0.0, (sum, s) => sum + s.grossProfit);
    final totalStock = inventory.items.fold(0, (sum, i) => sum + i.quantity);
    final lowStockItems = inventory.items.where((i) => i.isLowStock && i.quantity > 0).length;
    final outOfStock = inventory.items.where((i) => i.quantity == 0).length;
    final totalCustomers = customers.customers.length;
    final loyaltyTotal = customers.customers.fold(0, (sum, c) => sum + c.loyaltyPoints);

    // Top selling items
    final itemSales = <String, double>{};
    for (final sale in filteredSales) {
      for (final item in sale.items) {
        final key = item.name.isNotEmpty ? item.name : 'Unknown';
        itemSales[key] = (itemSales[key] ?? 0) + item.total;
      }
    }
    final topItems = itemSales.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    // Top customers (apply Udhar filter if active)
    final filteredCustomers = _showOnlyDues
        ? customers.customers.where((c) => c.balance > 0).toList()
        : customers.customers.toList();
    final topCustomers = filteredCustomers
      ..sort((a, b) => _showOnlyDues
          ? b.balance.compareTo(a.balance)
          : b.totalSpent.compareTo(a.totalSpent));

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(children: [
              Text('CRM Reports', style: AppTypography.h1.copyWith(
                  color: isDark ? AppColors.textPrimary(context) : AppColors.textPrimaryLight)),
              const Spacer(),
              // Custom date label
              if (_period == 'Custom' && _customStart != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.date_range_rounded, size: 14, color: AppColors.accent),
                    const SizedBox(width: 6),
                    Text(
                      _customStart == _customEnd
                          ? _fmtDate(_customStart!)
                          : '${_fmtDate(_customStart!)} - ${_fmtDate(_customEnd!)}',
                      style: AppTypography.labelSmall.copyWith(
                          color: AppColors.accent, fontWeight: FontWeight.w600, fontSize: 11),
                    ),
                  ]),
                ),
                const SizedBox(width: 8),
              ],
            ]),
            const SizedBox(height: 14),

            // Period selector with quick shortcuts
            SizedBox(
              height: 38,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  ..._periods.map((p) {
                    final isActive = _period == p;
                    final isCalendar = p == 'Custom';
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: () {
                            if (isCalendar) {
                              _showCalendarOptions();
                            } else {
                              setState(() => _period = p);
                            }
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: isActive
                                  ? AppColors.primary.withValues(alpha: 0.15)
                                  : AppColors.surface(context),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isActive ? AppColors.primary : AppColors.cardBorder(context),
                                width: isActive ? 1.5 : 1,
                              ),
                            ),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              if (isCalendar) ...[
                                Icon(Icons.calendar_month_rounded, size: 14,
                                    color: isActive ? AppColors.accent : AppColors.textTertiary(context)),
                                const SizedBox(width: 5),
                              ],
                              Text(p, style: AppTypography.labelSmall.copyWith(
                                color: isActive ? AppColors.accent : AppColors.textSecondary(context),
                                fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
                                fontSize: 12,
                              )),
                            ]),
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // KPI Cards
            Row(children: [
              _kpiCard('Revenue', Formatters.currency(totalRevenue), Icons.trending_up_rounded, AppColors.success),
              const SizedBox(width: 12),
              _kpiCard('Expenses', Formatters.currency(totalExpenses), Icons.trending_down_rounded, AppColors.error),
              const SizedBox(width: 12),
              _kpiCard('Profit', Formatters.currency(profit), Icons.account_balance_rounded,
                  profit >= 0 ? AppColors.success : AppColors.error),
              const SizedBox(width: 12),
              _kpiCard('Orders', '$totalOrders', Icons.receipt_long_rounded, AppColors.accent),
              const SizedBox(width: 12),
              _kpiCard('Avg Order', Formatters.currency(avgOrderValue), Icons.analytics_rounded, AppColors.primary),
            ]),
            const SizedBox(height: 16),

            // Second row: Inventory + Customer KPIs
            Row(children: [
              _kpiCard('Total Stock', '$totalStock', Icons.inventory_2_rounded, AppColors.accent),
              const SizedBox(width: 12),
              _kpiCard('Low Stock', '$lowStockItems', Icons.warning_amber_rounded, AppColors.warning,
                  onTap: () => _openStockDrawer('low')),
              const SizedBox(width: 12),
              _kpiCard('Out of Stock', '$outOfStock', Icons.block_rounded, AppColors.error,
                  onTap: () => _openStockDrawer('out')),
              const SizedBox(width: 12),
              _kpiCard('Customers', '$totalCustomers', Icons.people_rounded, AppColors.primary),
              const SizedBox(width: 12),
              _kpiCard('Loyalty Pts', '$loyaltyTotal', Icons.star_rounded, AppColors.warning),
            ]),
            const SizedBox(height: 20),

            // Bottom panels
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Top Items
                  Expanded(flex: 1, child: _panelCard(
                    'Top Selling Items',
                    Icons.trending_up_rounded,
                    topItems.isEmpty
                        ? Center(child: Text('No sales data', style: AppTypography.bodySmall.copyWith(
                            color: AppColors.textTertiary(context))))
                        : ListView.builder(
                            itemCount: topItems.length.clamp(0, 10),
                            itemBuilder: (_, i) {
                              final item = topItems[i];
                              final pct = totalRevenue > 0 ? (item.value / totalRevenue * 100) : 0;
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 6),
                                child: Row(children: [
                                  Container(
                                    width: 28, height: 28,
                                    decoration: BoxDecoration(
                                      color: AppColors.accent.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(6)),
                                    child: Center(child: Text('${i + 1}',
                                        style: AppTypography.labelSmall.copyWith(
                                            color: AppColors.accent, fontWeight: FontWeight.w700))),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(item.key, style: AppTypography.bodySmall.copyWith(
                                          color: AppColors.textPrimary(context), fontWeight: FontWeight.w500)),
                                      const SizedBox(height: 4),
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(3),
                                        child: LinearProgressIndicator(
                                          value: pct / 100,
                                          backgroundColor: AppColors.cardBorder(context),
                                          color: AppColors.accent,
                                          minHeight: 4,
                                        ),
                                      ),
                                    ],
                                  )),
                                  const SizedBox(width: 10),
                                  Text(Formatters.currency(item.value),
                                      style: AppTypography.mono.copyWith(
                                          color: AppColors.accent, fontSize: 12, fontWeight: FontWeight.w600)),
                                ]),
                              );
                            },
                          ),
                  )),
                  const SizedBox(width: 16),
                  // Top Customers
                  Expanded(flex: 1, child: _panelCard(
                    _showOnlyDues ? 'Customers with Udhar' : 'Top Customers',
                    Icons.people_rounded,
                    topCustomers.isEmpty
                        ? Center(child: Text(
                            _showOnlyDues ? 'No outstanding dues' : 'No customers yet',
                            style: AppTypography.bodySmall.copyWith(
                                color: AppColors.textTertiary(context))))
                        : ListView.builder(
                            itemCount: topCustomers.length.clamp(0, 15),
                            itemBuilder: (_, i) {
                              final c = topCustomers[i];
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                child: ListTile(
                                  dense: true,
                                  contentPadding: EdgeInsets.zero,
                                  leading: CircleAvatar(
                                    radius: 16,
                                    backgroundColor: c.balance > 0
                                        ? AppColors.warning.withValues(alpha: 0.1)
                                        : AppColors.primary.withValues(alpha: 0.1),
                                    child: Text(c.name.isNotEmpty ? c.name[0].toUpperCase() : '?',
                                        style: TextStyle(
                                            color: c.balance > 0 ? AppColors.warning : AppColors.primary,
                                            fontWeight: FontWeight.w700, fontSize: 12)),
                                  ),
                                  title: Text(c.name, style: AppTypography.bodySmall.copyWith(
                                      color: AppColors.textPrimary(context), fontWeight: FontWeight.w500)),
                                  subtitle: Row(children: [
                                    Text('${c.totalOrders} orders - ${c.loyaltyPoints} pts',
                                        style: AppTypography.labelSmall.copyWith(
                                            color: AppColors.textTertiary(context))),
                                    if (c.balance > 0) ...[
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                        decoration: BoxDecoration(
                                          color: AppColors.warning.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text('Udhar: ${Formatters.currency(c.balance)}',
                                            style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: AppColors.warning)),
                                      ),
                                    ],
                                  ]),
                                  trailing: Text(Formatters.currency(c.totalSpent),
                                      style: AppTypography.mono.copyWith(
                                          color: AppColors.success, fontSize: 12, fontWeight: FontWeight.w600)),
                                ),
                              );
                            },
                          ),
                    headerAction: GestureDetector(
                      onTap: () => setState(() => _showOnlyDues = !_showOnlyDues),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _showOnlyDues
                              ? AppColors.warning.withValues(alpha: 0.15)
                              : AppColors.surface(context),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: _showOnlyDues ? AppColors.warning : AppColors.cardBorder(context)),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.access_time_rounded, size: 12,
                              color: _showOnlyDues ? AppColors.warning : AppColors.textTertiary(context)),
                          const SizedBox(width: 4),
                          Text('Dues',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600,
                                  color: _showOnlyDues ? AppColors.warning : AppColors.textTertiary(context))),
                        ]),
                      ),
                    ),
                  )),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Show calendar options (single date or date range)
  void _showCalendarOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.card(context),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          border: Border.all(color: AppColors.cardBorder(context)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: AppColors.textTertiary(context).withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          Text('Select Date Filter', style: AppTypography.h3.copyWith(
              color: AppColors.textPrimary(context))),
          const SizedBox(height: 20),
          Row(children: [
            Expanded(child: _calendarOption(
              icon: Icons.calendar_today_rounded,
              label: 'Single Date',
              subtitle: 'Pick one specific date',
              onTap: () {
                Navigator.pop(ctx);
                _showSingleDatePicker();
              },
            )),
            const SizedBox(width: 12),
            Expanded(child: _calendarOption(
              icon: Icons.date_range_rounded,
              label: 'Date Range',
              subtitle: 'Pick start and end date',
              onTap: () {
                Navigator.pop(ctx);
                _showCalendarPicker();
              },
            )),
          ]),
          const SizedBox(height: 16),
        ]),
      ),
    );
  }

  void _openStockDrawer(String mode) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Stock Alert',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (_, __, ___) => StockAlertDrawer(mode: mode),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return SlideTransition(
          position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
              .animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
          child: child,
        );
      },
    );
  }

  Widget _calendarOption({
    required IconData icon,
    required String label,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surface(context),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.cardBorder(context)),
          ),
          child: Column(children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 28, color: AppColors.primary),
            ),
            const SizedBox(height: 12),
            Text(label, style: AppTypography.bodySmall.copyWith(
                color: AppColors.textPrimary(context), fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(subtitle, style: AppTypography.labelSmall.copyWith(
                color: AppColors.textTertiary(context), fontSize: 10),
                textAlign: TextAlign.center),
          ]),
        ),
      ),
    );
  }

  Widget _kpiCard(String label, String value, IconData icon, Color color, {VoidCallback? onTap}) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: MouseRegion(
          cursor: onTap != null ? SystemMouseCursors.click : SystemMouseCursors.basic,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.card(context),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: onTap != null ? color.withValues(alpha: 0.3) : AppColors.cardBorder(context)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8)),
                    child: Icon(icon, size: 16, color: color),
                  ),
                  const Spacer(),
                  if (onTap != null)
                    Icon(Icons.arrow_forward_ios_rounded, size: 12, color: color.withValues(alpha: 0.5)),
                ]),
                const SizedBox(height: 8),
                Text(value, style: AppTypography.mono.copyWith(
                    color: AppColors.textPrimary(context), fontWeight: FontWeight.w700, fontSize: 16)),
                const SizedBox(height: 2),
                Text(label, style: AppTypography.labelSmall.copyWith(
                    color: AppColors.textTertiary(context))),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _panelCard(String title, IconData icon, Widget child, {Widget? headerAction}) {
    return Container(
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
            Icon(icon, size: 18, color: AppColors.accent),
            const SizedBox(width: 8),
            Text(title, style: AppTypography.h4.copyWith(
                color: AppColors.textPrimary(context))),
            if (headerAction != null) ...[
              const Spacer(),
              headerAction,
            ],
          ]),
          Divider(color: AppColors.cardBorder(context), height: 20),
          Expanded(child: child),
        ],
      ),
    );
  }
}
