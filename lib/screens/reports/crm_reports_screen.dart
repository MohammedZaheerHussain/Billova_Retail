import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/formatters.dart';
import '../../providers/sales_provider.dart';
import '../../providers/inventory_provider.dart';
import '../../providers/customer_provider.dart';
import '../../providers/expense_provider.dart';

class CrmReportsScreen extends StatefulWidget {
  const CrmReportsScreen({super.key});

  @override
  State<CrmReportsScreen> createState() => _CrmReportsScreenState();
}

class _CrmReportsScreenState extends State<CrmReportsScreen> {
  String _period = 'Today';
  static const _periods = ['Today', 'This Week', 'This Month', 'All Time'];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sales = context.watch<SalesProvider>();
    final inventory = context.watch<InventoryProvider>();
    final customers = context.watch<CustomerProvider>();
    final expenses = context.watch<ExpenseProvider>();

    // Calculate metrics based on period
    final now = DateTime.now();
    final filteredSales = sales.sales.where((s) {
      if (_period == 'All Time') return true;
      final diff = now.difference(s.createdAt).inDays;
      if (_period == 'Today') return diff == 0;
      if (_period == 'This Week') return diff <= 7;
      if (_period == 'This Month') return diff <= 30;
      return true;
    }).toList();

    final totalRevenue = filteredSales.fold(0.0, (sum, s) => sum + s.total);
    final totalOrders = filteredSales.length;
    final avgOrderValue = totalOrders > 0 ? totalRevenue / totalOrders : 0.0;

    final totalExpenses = expenses.expenses.where((e) {
      if (_period == 'All Time') return true;
      final diff = now.difference(e.createdAt).inDays;
      if (_period == 'Today') return diff == 0;
      if (_period == 'This Week') return diff <= 7;
      if (_period == 'This Month') return diff <= 30;
      return true;
    }).fold(0.0, (sum, e) => sum + e.amount);

    final profit = totalRevenue - totalExpenses;
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

    // Top customers
    final topCustomers = customers.customers.toList()
      ..sort((a, b) => b.totalSpent.compareTo(a.totalSpent));

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
              // Period selector
              ...List.generate(_periods.length, (i) {
                final p = _periods[i];
                return Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: GestureDetector(
                    onTap: () => setState(() => _period = p),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: _period == p
                            ? AppColors.primary.withValues(alpha: 0.15)
                            : AppColors.surface(context),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: _period == p
                            ? AppColors.primary : AppColors.cardBorder(context)),
                      ),
                      child: Text(p, style: AppTypography.labelSmall.copyWith(
                          color: _period == p ? AppColors.primary : AppColors.textSecondary(context),
                          fontWeight: _period == p ? FontWeight.w700 : FontWeight.w400)),
                    ),
                  ),
                );
              }),
            ]),
            const SizedBox(height: 20),

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
              _kpiCard('Low Stock', '$lowStockItems', Icons.warning_amber_rounded, AppColors.warning),
              const SizedBox(width: 12),
              _kpiCard('Out of Stock', '$outOfStock', Icons.block_rounded, AppColors.error),
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
                    'Top Customers',
                    Icons.people_rounded,
                    topCustomers.isEmpty
                        ? Center(child: Text('No customers yet', style: AppTypography.bodySmall.copyWith(
                            color: AppColors.textTertiary(context))))
                        : ListView.builder(
                            itemCount: topCustomers.length.clamp(0, 10),
                            itemBuilder: (_, i) {
                              final c = topCustomers[i];
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                child: ListTile(
                                  dense: true,
                                  contentPadding: EdgeInsets.zero,
                                  leading: CircleAvatar(
                                    radius: 16,
                                    backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                                    child: Text(c.name.isNotEmpty ? c.name[0].toUpperCase() : '?',
                                        style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 12)),
                                  ),
                                  title: Text(c.name, style: AppTypography.bodySmall.copyWith(
                                      color: AppColors.textPrimary(context), fontWeight: FontWeight.w500)),
                                  subtitle: Text('${c.totalOrders} orders • ${c.loyaltyPoints} pts',
                                      style: AppTypography.labelSmall.copyWith(
                                          color: AppColors.textTertiary(context))),
                                  trailing: Text(Formatters.currency(c.totalSpent),
                                      style: AppTypography.mono.copyWith(
                                          color: AppColors.success, fontSize: 12, fontWeight: FontWeight.w600)),
                                ),
                              );
                            },
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

  Widget _kpiCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
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
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8)),
                child: Icon(icon, size: 16, color: color),
              ),
              const Spacer(),
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
    );
  }

  Widget _panelCard(String title, IconData icon, Widget child) {
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
          ]),
          Divider(color: AppColors.cardBorder(context), height: 20),
          Expanded(child: child),
        ],
      ),
    );
  }
}
