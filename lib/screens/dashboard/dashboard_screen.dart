import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/formatters.dart';
import '../../data/local/db_helper.dart';
import '../../data/remote/groq_service.dart';
import '../../providers/inventory_provider.dart';
import '../../providers/sales_provider.dart';
import '../../providers/expense_provider.dart';
import '../../providers/customer_provider.dart';
import '../../providers/vendor_provider.dart';
import '../../providers/purchase_provider.dart';
import '../../data/models/vendor_model.dart';
import '../shell/app_shell.dart';
import '../../widgets/stock_alert_drawer.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final DBHelper _db = DBHelper.instance;

  // Core metrics
  double _todaySales = 0;
  double _weekSales = 0;
  double _stockValue = 0;
  int _lowStockCount = 0;
  double _todayExpenses = 0;
  int _todaySalesCount = 0;
  double _todayProfit = 0;
  List<Map<String, dynamic>> _recentSales = [];
  List<Map<String, dynamic>> _chartData = [];
  List<Map<String, dynamic>> _lowStockItems = [];
  List<Map<String, dynamic>> _topProducts = [];
  Map<String, double> _paymentDistribution = {};
  List<VendorModel> _vendorsWithDues = [];
  double _totalVendorDues = 0;
  double _todayPurchases = 0;

  // AI Insights
  String _aiInsights = '';
  bool _isLoadingAI = false;
  bool _showMonthlyBackupBanner = false;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
    _checkMonthlyBackup();
    // Re-load when Supabase data pull completes (web: in-memory DB starts empty)
    AppShell.dataVersion.addListener(_onDataReady);
  }

  void _onDataReady() {
    if (mounted) _loadDashboardData();
  }

  Future<void> _checkMonthlyBackup() async {
    final lastExport = await DBHelper.instance.getSetting('last_csv_export_month');
    final currentMonth = '${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}';
    if (lastExport != currentMonth && mounted) {
      setState(() => _showMonthlyBackupBanner = true);
    }
  }

  Widget _buildMonthlyBackupBanner() {
    final now = DateTime.now();
    final monthName = ['Jan','Feb','Mar','Apr','May','Jun',
                       'Jul','Aug','Sep','Oct','Nov','Dec'][now.month - 1];
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.warning.withValues(alpha: 0.15), AppColors.accent.withValues(alpha: 0.08)],
          begin: Alignment.centerLeft, end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.backup_rounded, color: AppColors.warning, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Monthly Backup Due — $monthName ${now.year}',
                    style: AppTypography.labelSmall.copyWith(
                        color: AppColors.warning, fontWeight: FontWeight.w700, fontSize: 12)),
                Text('Download your monthly CSV backup to keep your data safe',
                    style: AppTypography.labelSmall.copyWith(
                        color: AppColors.textSecondary(context), fontSize: 10)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          TextButton.icon(
            onPressed: () {
              // Navigate to Settings via AppShell
              AppShell.navigateTo.value = 'Settings & Backup';
            },
            icon: Icon(Icons.download_rounded, size: 14, color: AppColors.accent),
            label: Text('Export Now', style: TextStyle(color: AppColors.accent, fontSize: 11, fontWeight: FontWeight.w700)),
            style: TextButton.styleFrom(
              backgroundColor: AppColors.accent.withValues(alpha: 0.12),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            onPressed: () async {
              await DBHelper.instance.setSetting('last_csv_export_month',
                  '${now.year}-${now.month.toString().padLeft(2, '0')}');
              if (mounted) setState(() => _showMonthlyBackupBanner = false);
            },
            icon: Icon(Icons.close_rounded, size: 16, color: AppColors.textTertiary(context)),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            tooltip: 'Dismiss',
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    AppShell.dataVersion.removeListener(_onDataReady);
    super.dispose();
  }

  Future<void> _loadDashboardData() async {
    final results = await Future.wait([
      _db.todaySalesTotal(),       // 0
      _db.totalStockValue(),       // 1
      _db.todayExpensesTotal(),    // 2
      _db.todaySalesCount(),       // 3
      _db.recentSales(limit: 5),   // 4
      _db.salesLast7Days(),        // 5
      _db.lowStockItems(),         // 6
    ]);

    // Calculate week total from chart data
    final chartData = results[5] as List<Map<String, dynamic>>;
    double weekTotal = 0;
    for (final day in chartData) {
      weekTotal += (day['total'] as num).toDouble();
    }

    // Get top products + payment distribution
    final topProducts = await _getTopProducts();
    final paymentDist = await _getPaymentDistribution();

    // Get vendor dues — ensure data is loaded first
    List<VendorModel> vendorsWithDues = [];
    double totalDues = 0;
    double todayPurchases = 0;
    try {
      final vendorProvider = context.read<VendorProvider>();
      final purchaseProvider = context.read<PurchaseProvider>();
      // Ensure vendors and purchases are loaded
      await vendorProvider.loadVendors();
      await purchaseProvider.loadPurchases();
      vendorsWithDues = vendorProvider.vendors.where((v) => v.balance > 0).toList()
        ..sort((a, b) => b.balance.compareTo(a.balance));
      totalDues = vendorsWithDues.fold(0.0, (sum, v) => sum + v.balance);
      todayPurchases = purchaseProvider.todayPurchasePayments;
    } catch (_) {}

    if (mounted) {
      setState(() {
        _todaySales = results[0] as double;
        _weekSales = weekTotal;
        _stockValue = results[1] as double;
        _todayExpenses = results[2] as double;
        _todaySalesCount = results[3] as int;
        _recentSales = results[4] as List<Map<String, dynamic>>;
        _chartData = chartData;
        _lowStockItems = results[6] as List<Map<String, dynamic>>;
        _lowStockCount = _lowStockItems.length;
        _todayProfit = _todaySales - _todayExpenses;
        _topProducts = topProducts;
        _paymentDistribution = paymentDist;
        _vendorsWithDues = vendorsWithDues;
        _totalVendorDues = totalDues;
        _todayPurchases = todayPurchases;
      });
    }
  }

  Future<Map<String, double>> _getPaymentDistribution() async {
    try {
      final sales = await _db.query('sales', where: 'is_deleted = 0');
      final dist = <String, double>{};
      for (final sale in sales) {
        final mode = sale['payment_mode'] as String? ?? 'Cash';
        final total = (sale['total'] as num?)?.toDouble() ?? 0;
        dist[mode] = (dist[mode] ?? 0) + total;
      }
      return dist;
    } catch (_) {
      return {};
    }
  }

  String _formatRupees(double amount) => '₹${amount.toStringAsFixed(2)}';

  Future<List<Map<String, dynamic>>> _getTopProducts() async {
    try {
      final sales = await _db.query('sales', where: 'is_deleted = 0', orderBy: 'created_at DESC');
      final productCount = <String, int>{};
      final productRevenue = <String, double>{};

      for (final sale in sales) {
        final items = sale['items'];
        if (items is String && items.isNotEmpty) {
          try {
            final List decoded = jsonDecode(items);
            for (final item in decoded) {
              if (item is Map) {
                final name = item['name'] as String? ?? '';
                final qty = (item['quantity'] as num?)?.toInt() ?? 0;
                final total = (item['total'] as num?)?.toDouble() ?? 0;
                productCount[name] = (productCount[name] ?? 0) + qty;
                productRevenue[name] = (productRevenue[name] ?? 0) + total;
              }
            }
          } catch (_) {}
        }
      }

      final sorted = productCount.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      return sorted.take(5).map((e) => {
        'name': e.key,
        'quantity': e.value,
        'revenue': productRevenue[e.key] ?? 0,
      }).toList();
    } catch (e) {
      return [];
    }
  }


  Future<void> _generateAIInsights() async {
    setState(() => _isLoadingAI = true);

    // Build customer insights for AI
    final customerProv = context.read<CustomerProvider>();
    final salesProv = context.read<SalesProvider>();
    final summaries = salesProv.getCustomerSummaries();
    final now = DateTime.now();

    // Top 5 spenders
    final sortedCustomers = customerProv.customers.map((c) {
      final key = c.phone.isNotEmpty ? c.phone : c.name.toLowerCase().trim();
      final s = summaries[key];
      return {
        'name': c.name,
        'phone': c.phone,
        'totalSpent': (s?['totalSpent'] as double?) ?? c.totalSpent,
        'totalOrders': (s?['totalOrders'] as int?) ?? c.totalOrders,
        'lastPurchaseDate': ((s?['lastPurchaseDate'] as DateTime?) ?? c.lastPurchaseDate)?.toIso8601String(),
        'daysSinceLastVisit': ((s?['lastPurchaseDate'] as DateTime?) ?? c.lastPurchaseDate) != null
            ? now.difference((s?['lastPurchaseDate'] as DateTime?) ?? c.lastPurchaseDate!).inDays
            : null,
      };
    }).toList();

    sortedCustomers.sort((a, b) => ((b['totalSpent'] as double?) ?? 0).compareTo((a['totalSpent'] as double?) ?? 0));
    final topSpenders = sortedCustomers.take(5).toList();
    final inactive = sortedCustomers.where((c) => (c['daysSinceLastVisit'] as int?) != null && (c['daysSinceLastVisit'] as int?) != null && (c['daysSinceLastVisit'] as int)! > 7).take(5).toList();

    final businessData = {
      'today_sales': _todaySales,
      'today_sales_count': _todaySalesCount,
      'week_sales': _weekSales,
      'today_expenses': _todayExpenses,
      'today_profit': _todayProfit,
      'stock_value': _stockValue,
      'low_stock_count': _lowStockCount,
      'low_stock_items': _lowStockItems.take(8).map((i) => {
        'name': i['name'], 'quantity': i['quantity'],
      }).toList(),
      'top_products': _topProducts,
      'total_customers': customerProv.customers.length,
      'top_spenders': topSpenders,
      'inactive_customers': inactive,
    };

    final insights = await GroqService.instance.generateInsights(businessData);

    if (mounted) {
      setState(() {
        _aiInsights = insights;
        _isLoadingAI = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _loadDashboardData,
      color: AppColors.accent,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── Header ───
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Dashboard', style: AppTypography.h1.copyWith(color: AppColors.textPrimary(context))),
                      SizedBox(height: 4),
                      Text(Formatters.date(DateTime.now()),
                          style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary(context))),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: _loadDashboardData,
                  icon: Icon(Icons.refresh_rounded),
                  color: AppColors.textSecondary(context),
                  tooltip: 'Refresh',
                ),
              ],
            ),
            const SizedBox(height: 24),

            // ─── Monthly Backup Reminder ───
            if (_showMonthlyBackupBanner)
              _buildMonthlyBackupBanner(),

            // ─── Stat Cards (6 cards) ───
            LayoutBuilder(
              builder: (context, constraints) {
                final crossAxisCount = constraints.maxWidth > 1100 ? 6
                    : constraints.maxWidth > 700 ? 3 : 2;
                final cardWidth = (constraints.maxWidth - (12.0 * (crossAxisCount - 1))) / crossAxisCount;
                final cardHeight = 120.0;
                return GridView.count(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: cardWidth / cardHeight,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _statCard('Today Sales', Formatters.currency(_todaySales),
                        '$_todaySalesCount bills', Icons.trending_up_rounded,
                        AppColors.successGradient),
                    _statCard('Week Sales', Formatters.currency(_weekSales),
                        'Last 7 days', Icons.calendar_month_rounded,
                        AppColors.primaryGradient),
                    _statCard('Today Profit', Formatters.currency(_todayProfit),
                        _todayProfit >= 0 ? 'Positive ✓' : 'Negative ✗', Icons.account_balance_rounded,
                        _todayProfit >= 0 ? AppColors.successGradient : AppColors.errorGradient),
                    _statCard('Expenses', Formatters.currency(_todayExpenses),
                        'Today', Icons.money_off_rounded,
                        AppColors.errorGradient),
                    _statCard('Stock Value', Formatters.currencyCompact(_stockValue),
                        'Total inventory', Icons.inventory_2_rounded,
                        AppColors.primaryGradient),
                    _statCard('Low Stock', _lowStockCount.toString(),
                        'Need restock', Icons.warning_rounded,
                        AppColors.warningGradient, onTap: () => _openStockDrawer('low')),
                  ],
                );
              },
            ),
            const SizedBox(height: 24),

            // ─── Chart + Pie + Recent Sales ───
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth > 1000) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 3, child: _buildChart()),
                      const SizedBox(width: 16),
                      Expanded(flex: 2, child: _buildPaymentPieChart()),
                      const SizedBox(width: 16),
                      Expanded(flex: 2, child: _buildRecentSales()),
                    ],
                  );
                }
                if (constraints.maxWidth > 600) {
                  return Column(children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 3, child: _buildChart()),
                        const SizedBox(width: 16),
                        Expanded(flex: 2, child: _buildPaymentPieChart()),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildRecentSales(),
                  ]);
                }
                return Column(children: [
                  _buildChart(),
                  const SizedBox(height: 16),
                  _buildPaymentPieChart(),
                  const SizedBox(height: 16),
                  _buildRecentSales(),
                ]);
              },
            ),
            const SizedBox(height: 16),

            // ─── Top Products + AI Insights ───
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth > 800) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 2, child: _buildTopProducts()),
                      const SizedBox(width: 16),
                      Expanded(flex: 3, child: _buildAIInsights()),
                    ],
                  );
                }
                return Column(children: [
                  _buildTopProducts(), const SizedBox(height: 16), _buildAIInsights(),
                ]);
              },
            ),
            const SizedBox(height: 16),

            // ─── Vendor Dues + Low Stock Alerts ───
            LayoutBuilder(
              builder: (context, constraints) {
                final hasVendorDues = _vendorsWithDues.isNotEmpty;
                final hasLowStock = _lowStockItems.isNotEmpty;
                if (!hasVendorDues && !hasLowStock) return const SizedBox.shrink();
                if (constraints.maxWidth > 800 && hasVendorDues && hasLowStock) {
                  return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(child: _buildVendorAlerts()),
                    const SizedBox(width: 16),
                    Expanded(child: _buildLowStockAlert()),
                  ]);
                }
                return Column(children: [
                  if (hasVendorDues) _buildVendorAlerts(),
                  if (hasVendorDues && hasLowStock) const SizedBox(height: 16),
                  if (hasLowStock) _buildLowStockAlert(),
                ]);
              },
            ),
          ],
        ),
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

  Widget _statCard(String title, String value, String subtitle, IconData icon,
      LinearGradient gradient, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: MouseRegion(
        cursor: onTap != null ? SystemMouseCursors.click : SystemMouseCursors.basic,
        child: Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.card(context),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: onTap != null
                ? AppColors.warning.withValues(alpha: 0.3)
                : AppColors.cardBorder(context)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(child: Text(title, style: AppTypography.labelMedium.copyWith(
                      color: AppColors.textSecondary(context)), overflow: TextOverflow.ellipsis)),
                  Container(
                    padding: EdgeInsets.all(6),
                    decoration: BoxDecoration(gradient: gradient, borderRadius: BorderRadius.circular(8)),
                    child: Icon(icon, size: 16, color: Colors.white),
                  ),
                ],
              ),
              SizedBox(height: 8),
              Text(value, style: AppTypography.monoLarge.copyWith(
                  color: AppColors.textPrimary(context), fontSize: 18),
                  overflow: TextOverflow.ellipsis),
              SizedBox(height: 2),
              Row(children: [
                Expanded(child: Text(subtitle, style: AppTypography.labelSmall.copyWith(
                    color: AppColors.textTertiary(context)))),
                if (onTap != null)
                  Icon(Icons.arrow_forward_ios_rounded, size: 10,
                      color: AppColors.warning.withValues(alpha: 0.5)),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChart() {
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
          Text('Sales (Last 7 Days)', style: AppTypography.h4.copyWith(color: AppColors.textPrimary(context))),
          SizedBox(height: 20),
          SizedBox(
            height: 200,
            child: _chartData.isEmpty
                ? Center(child: Text('No sales data yet',
                    style: AppTypography.bodyMedium.copyWith(color: AppColors.textTertiary(context))))
                : BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      maxY: _chartData.isEmpty ? 100
                          : (_chartData.map((e) => (e['total'] as num).toDouble()).reduce((a, b) => a > b ? a : b) * 1.2),
                      borderData: FlBorderData(show: false),
                      gridData: FlGridData(
                        show: true, drawVerticalLine: false,
                        getDrawingHorizontalLine: (value) => FlLine(
                          color: AppColors.cardBorder(context).withValues(alpha: 0.5), strokeWidth: 1),
                      ),
                      titlesData: FlTitlesData(
                        leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              final index = value.toInt();
                              if (index >= 0 && index < _chartData.length) {
                                final date = _chartData[index]['date'] as String;
                                return Padding(
                                  padding: EdgeInsets.only(top: 8),
                                  child: Text(date.substring(8, 10),
                                      style: AppTypography.labelSmall.copyWith(color: AppColors.textTertiary(context))),
                                );
                              }
                              return const SizedBox();
                            },
                          ),
                        ),
                      ),
                      barGroups: _chartData.asMap().entries.map((entry) {
                        return BarChartGroupData(x: entry.key, barRods: [
                          BarChartRodData(
                            toY: (entry.value['total'] as num).toDouble(),
                            width: 20,
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                            gradient: AppColors.primaryGradient,
                          ),
                        ]);
                      }).toList(),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  static const List<Color> _pieColors = [
    Color(0xFF6C5CE7), // Purple
    Color(0xFF00B894), // Green
    Color(0xFFE17055), // Orange
    Color(0xFF0984E3), // Blue
    Color(0xFFFDAA5D), // Gold
  ];

  Widget _buildPaymentPieChart() {
    final total = _paymentDistribution.values.fold(0.0, (a, b) => a + b);
    final entries = _paymentDistribution.entries.toList();

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
          Row(children: [
            Icon(Icons.pie_chart_rounded, color: AppColors.accent, size: 18),
            SizedBox(width: 8),
            Text('Sales by Payment', style: AppTypography.h4.copyWith(color: AppColors.textPrimary(context))),
          ]),
          SizedBox(height: 16),
          if (_paymentDistribution.isEmpty || total == 0)
            SizedBox(
              height: 180,
              child: Center(child: Text('No sales data yet',
                  style: AppTypography.bodyMedium.copyWith(color: AppColors.textTertiary(context)))),
            )
          else ...[
            SizedBox(
              height: 160,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 3,
                  centerSpaceRadius: 30,
                  sections: entries.asMap().entries.map((e) {
                    final color = _pieColors[e.key % _pieColors.length];
                    final pct = (e.value.value / total * 100);
                    return PieChartSectionData(
                      value: e.value.value,
                      title: '${pct.toStringAsFixed(0)}%',
                      color: color,
                      radius: 50,
                      titleStyle: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                    );
                  }).toList(),
                ),
              ),
            ),
            SizedBox(height: 14),
            ...entries.asMap().entries.map((e) {
              final color = _pieColors[e.key % _pieColors.length];
              return Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Row(children: [
                  Container(width: 12, height: 12, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
                  SizedBox(width: 8),
                  Expanded(child: Text(e.value.key, style: AppTypography.bodySmall.copyWith(color: AppColors.textPrimary(context)))),
                  Text(Formatters.currency(e.value.value),
                      style: AppTypography.mono.copyWith(color: AppColors.textSecondary(context), fontSize: 12)),
                ]),
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildRecentSales() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card(context), borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Recent Sales', style: AppTypography.h4.copyWith(color: AppColors.textPrimary(context))),
          SizedBox(height: 16),
          if (_recentSales.isEmpty)
            Padding(padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: Text('No sales yet today',
                  style: AppTypography.bodyMedium.copyWith(color: AppColors.textTertiary(context)))))
          else
            ...List.generate(_recentSales.length, (index) {
              final sale = _recentSales[index];
              return Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Row(children: [
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                    child: Icon(Icons.receipt_rounded, size: 18, color: AppColors.accent),
                  ),
                  SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(sale['invoice_number'] as String? ?? 'INV-0000',
                        style: AppTypography.mono.copyWith(color: AppColors.textPrimary(context), fontSize: 13)),
                    Text(sale['customer_name'] as String? ?? 'Walk-in',
                        style: AppTypography.labelSmall.copyWith(color: AppColors.textTertiary(context))),
                  ])),
                  Text(Formatters.currency((sale['total'] as num).toDouble()),
                      style: AppTypography.mono.copyWith(color: AppColors.success, fontSize: 13, fontWeight: FontWeight.w600)),
                ]),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildTopProducts() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card(context), borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.star_rounded, color: AppColors.accent, size: 20),
            SizedBox(width: 8),
            Text('Top Products', style: AppTypography.h4.copyWith(color: AppColors.textPrimary(context))),
          ]),
          SizedBox(height: 16),
          if (_topProducts.isEmpty)
            Center(child: Text('No product data yet',
                style: AppTypography.bodyMedium.copyWith(color: AppColors.textTertiary(context))))
          else
            ..._topProducts.asMap().entries.map((e) {
              final p = e.value;
              return Padding(
                padding: EdgeInsets.only(bottom: 10),
                child: Row(children: [
                  Container(
                    width: 24, height: 24,
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6)),
                    child: Center(child: Text('${e.key + 1}',
                        style: AppTypography.mono.copyWith(color: AppColors.accent, fontSize: 11))),
                  ),
                  SizedBox(width: 10),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(p['name'] as String, style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.textPrimary(context), fontWeight: FontWeight.w500),
                        overflow: TextOverflow.ellipsis),
                    Text('${p['quantity']} sold', style: AppTypography.labelSmall.copyWith(
                        color: AppColors.textTertiary(context))),
                  ])),
                  Text(Formatters.currency((p['revenue'] as num).toDouble()),
                      style: AppTypography.mono.copyWith(color: AppColors.success, fontSize: 12)),
                ]),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildAIInsights() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card(context), borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(8)),
              child: Icon(Icons.auto_awesome_rounded, size: 16, color: Colors.white),
            ),
            SizedBox(width: 10),
            Text('AI Business Advisor', style: AppTypography.h4.copyWith(color: AppColors.textPrimary(context))),
            const Spacer(),
            SizedBox(
              height: 32,
              child: ElevatedButton.icon(
                onPressed: _isLoadingAI ? null : _generateAIInsights,
                icon: _isLoadingAI
                    ? const SizedBox(width: 14, height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Icon(Icons.refresh_rounded, size: 14),
                label: Text(_isLoadingAI ? 'Analyzing...' : 'Get Insights',
                    style: const TextStyle(fontSize: 12)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: AppColors.accent.withValues(alpha: 0.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
              ),
            ),
          ]),
          SizedBox(height: 16),
          if (_aiInsights.isEmpty && !_isLoadingAI)
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface(context),
                borderRadius: BorderRadius.circular(10)),
              child: Row(children: [
                Icon(Icons.lightbulb_outline_rounded, color: AppColors.accent.withValues(alpha: 0.5), size: 20),
                SizedBox(width: 12),
                Flexible(child: Text(
                  'Click "Get Insights" to analyze your business data with AI',
                  style: AppTypography.bodyMedium.copyWith(color: AppColors.textTertiary(context)),
                )),
              ]),
            )
          else if (_isLoadingAI)
            Center(child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                CircularProgressIndicator(color: AppColors.accent),
                SizedBox(height: 12),
                Text('Analyzing your business data...', style: TextStyle(color: AppColors.textTertiary(context))),
              ]),
            ))
          else
            Container(
              padding: EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surface(context),
                borderRadius: BorderRadius.circular(10)),
              child: SelectableText(
                _aiInsights,
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textPrimary(context),
                  height: 1.6,
                  fontSize: 13,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildVendorAlerts() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding: EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8)),
              child: Icon(Icons.account_balance_wallet_rounded, color: AppColors.error, size: 16),
            ),
            SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Vendor Dues (Udhaar)', style: AppTypography.h4.copyWith(color: AppColors.error)),
              Text('${_vendorsWithDues.length} vendor${_vendorsWithDues.length != 1 ? "s" : ""} with pending payments',
                  style: AppTypography.labelSmall.copyWith(color: AppColors.textTertiary(context))),
            ])),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8)),
              child: Text(Formatters.currency(_totalVendorDues),
                  style: AppTypography.mono.copyWith(color: AppColors.error, fontWeight: FontWeight.w700, fontSize: 14)),
            ),
          ]),
          const SizedBox(height: 14),
          ..._vendorsWithDues.take(5).map((vendor) => Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.card(context),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.cardBorder(context))),
              child: Row(children: [
                Container(
                  width: 28, height: 28,
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(7)),
                  child: Center(child: Text(vendor.name[0].toUpperCase(),
                      style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w700, fontSize: 12))),
                ),
                SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(vendor.name, style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textPrimary(context), fontWeight: FontWeight.w500)),
                  if (vendor.phone.isNotEmpty)
                    Text(vendor.phone, style: AppTypography.labelSmall.copyWith(
                        color: AppColors.textTertiary(context), fontSize: 10)),
                ])),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6)),
                  child: Text(Formatters.currency(vendor.balance),
                      style: AppTypography.mono.copyWith(color: AppColors.error, fontWeight: FontWeight.w600, fontSize: 12)),
                ),
              ]),
            ),
          )),
          if (_vendorsWithDues.length > 5)
            Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text('+ ${_vendorsWithDues.length - 5} more vendors...',
                  style: AppTypography.labelSmall.copyWith(color: AppColors.textTertiary(context))),
            ),
        ],
      ),
    );
  }

  Widget _buildLowStockAlert() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.warningBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => _openStockDrawer('low'),
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: Row(children: [
                Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 20),
                SizedBox(width: 8),
                Text('Low Stock Alert', style: AppTypography.h4.copyWith(color: AppColors.warning)),
                const Spacer(),
                Text('View All', style: AppTypography.labelSmall.copyWith(
                    color: AppColors.accent, fontWeight: FontWeight.w600)),
                const SizedBox(width: 4),
                Icon(Icons.arrow_forward_ios_rounded, size: 12, color: AppColors.accent),
              ]),
            ),
          ),
          SizedBox(height: 12),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: _lowStockItems.take(6).map((item) {
              return Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.card(context), borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.cardBorder(context))),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(item['name'] as String, style: AppTypography.bodySmall.copyWith(color: AppColors.textPrimary(context))),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: (item['quantity'] as int) == 0 ? AppColors.errorBg : AppColors.warningBg,
                      borderRadius: BorderRadius.circular(4)),
                    child: Text('${item['quantity']}', style: AppTypography.monoSmall.copyWith(
                        color: (item['quantity'] as int) == 0 ? AppColors.error : AppColors.warning,
                        fontWeight: FontWeight.w700)),
                  ),
                ]),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

