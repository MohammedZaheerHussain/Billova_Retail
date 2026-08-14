import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/business_analytics.dart';
import '../../data/local/db_helper.dart';
import '../../data/remote/groq_service.dart';
import '../../data/remote/supabase_service.dart';
import '../../providers/inventory_provider.dart';
import '../../providers/sales_provider.dart';
import '../../providers/customer_provider.dart';
import '../../providers/vendor_provider.dart';
import '../../providers/purchase_provider.dart';
import '../../data/models/vendor_model.dart';
import '../../data/models/customer_model.dart';
import '../shell/app_shell.dart';
import '../../widgets/stock_alert_drawer.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final DBHelper _db = DBHelper.instance;

  // ─── Core metrics (Business Logic Frozen) ───
  double _todaySales = 0;
  double _weekSales = 0;
  double _stockValue = 0;
  double _stockCost = 0;
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
  List<CustomerModel> _customersWithDues = [];
  double _totalCustomerDues = 0;

  // ─── AI Insights ───
  String _aiInsights = '';
  bool _isLoadingAI = false;
  bool _showMonthlyBackupBanner = false;

  // ─── Analytics engine ───
  BusinessAnalytics? _analytics;
  List<BusinessInsight> _insights = [];

  // Revenue by Category filter: 0 = This Week, 1 = This Month, 2+ = Past months
  int _revFilterIndex = 1; // Default: This Month
  List<Map<String, dynamic>> _pastSnapshots = []; // historical month snapshots from DB
  static const List<String> _monthNames = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  static const List<Color> _pieColors = [
    Color(0xFF6C5CE7), // Purple
    Color(0xFF00B894), // Green
    Color(0xFFE17055), // Orange
    Color(0xFF0984E3), // Blue
    Color(0xFFFDAA5D), // Gold
  ];

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
    _checkMonthlyBackup();
    _loadPastSnapshots();
    // Re-load when Supabase data pull completes (web: in-memory DB starts empty)
    AppShell.dataVersion.addListener(_onDataReady);
  }

  void _onDataReady() {
    if (mounted) _loadDashboardData();
  }

  @override
  void dispose() {
    AppShell.dataVersion.removeListener(_onDataReady);
    super.dispose();
  }

  Future<void> _checkMonthlyBackup() async {
    final lastExport = await DBHelper.instance.getSetting('last_csv_export_month');
    final currentMonth = '${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}';
    if (lastExport != currentMonth && mounted) {
      setState(() => _showMonthlyBackupBanner = true);
    }
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
      _db.totalStockCost(),        // 7 — cost-based investment value
    ]);

    // Calculate week total from chart data
    final chartData = results[5] as List<Map<String, dynamic>>;
    double weekTotal = 0;
    for (final day in chartData) {
      weekTotal += (day['total'] as num).toDouble();
    }

    // Get vendor dues — ensure data is loaded first
    List<VendorModel> vendorsWithDues = [];
    double totalDues = 0;
    try {
      final vendorProvider = context.read<VendorProvider>();
      final purchaseProvider = context.read<PurchaseProvider>();
      await vendorProvider.loadVendors();
      await purchaseProvider.loadPurchases();
      vendorsWithDues = vendorProvider.vendors.where((v) => v.balance > 0).toList()
        ..sort((a, b) => b.balance.compareTo(a.balance));
      totalDues = vendorsWithDues.fold(0.0, (sum, v) => sum + v.balance);
    } catch (_) {}

    // Get customer dues (Udhar)
    List<CustomerModel> customersWithDues = [];
    double totalCustomerDues = 0;
    try {
      final customerProvider = context.read<CustomerProvider>();
      customersWithDues = customerProvider.customersWithDues;
      totalCustomerDues = customerProvider.totalCustomerDues;
    } catch (_) {}

    // ─── Build Centralized Analytics Engine ───
    final salesProv = context.read<SalesProvider>();
    final invProv = context.read<InventoryProvider>();

    List<Map<String, dynamic>> rawExpenses = [];
    try {
      rawExpenses = await _db.getAll('expenses');
    } catch (_) {}

    final analytics = BusinessAnalytics(
      allSales: salesProv.allSales,
      allItems: invProv.items,
      allExpenses: rawExpenses,
    );

    final paymentDist = analytics.monthPaymentDistribution;
    final topProducts = analytics.monthTopProducts;

    if (mounted) {
      setState(() {
        _todaySales = results[0] as double;
        _weekSales = weekTotal;
        _stockValue = results[1] as double;
        _stockCost = results[7] as double;
        _todayExpenses = results[2] as double;
        _todaySalesCount = results[3] as int;
        _recentSales = results[4] as List<Map<String, dynamic>>;
        _chartData = chartData;
        _lowStockItems = results[6] as List<Map<String, dynamic>>;
        _lowStockCount = _lowStockItems.length;
        _todayProfit = analytics.todayNetProfit;
        _topProducts = topProducts;
        _paymentDistribution = paymentDist;
        _vendorsWithDues = vendorsWithDues;
        _totalVendorDues = totalDues;
        _customersWithDues = customersWithDues;
        _totalCustomerDues = totalCustomerDues;
        _analytics = analytics;
        _insights = analytics.generateInsights();
      });
      _autoSaveMonthSnapshots(analytics);
    }
  }

  Future<void> _loadPastSnapshots() async {
    try {
      final snapshots = await _db.getAllRevenueSnapshots();
      if (mounted) {
        setState(() => _pastSnapshots = snapshots);
      }
    } catch (e) {
      debugPrint('⚠️ Failed to load past snapshots: $e');
    }
  }

  Future<void> _autoSaveMonthSnapshots(BusinessAnalytics analytics) async {
    try {
      final now = DateTime.now();
      for (int i = 1; i <= 6; i++) {
        final target = DateTime(now.year, now.month - i, 1);
        final year = target.year;
        final month = target.month;

        final existing = await _db.getRevenueSnapshot(year, month);
        if (existing != null) continue;

        final snapshot = analytics.buildMonthlySnapshot(year: year, month: month);

        if ((snapshot['sales_count'] as int) > 0) {
          await _db.saveRevenueSnapshot(snapshot);
          try {
            final supabase = SupabaseService.instance;
            if (supabase.isLoggedIn) {
              final id = 'snapshot_${year}_${month.toString().padLeft(2, '0')}';
              final record = await _db.getById('revenue_snapshots', id);
              if (record != null) {
                await supabase.syncRecord('revenue_snapshots', id, 'insert', record);
              }
            }
          } catch (_) {}
        }
      }
      await _loadPastSnapshots();
    } catch (e) {
      debugPrint('⚠️ Auto-save snapshots error: $e');
    }
  }

  Future<void> _generateAIInsights() async {
    if (_analytics == null) return;
    setState(() => _isLoadingAI = true);

    final payload = _analytics!.buildAIDataPayload();
    final insights = await GroqService.instance.generateInsights(payload);

    if (mounted) {
      setState(() {
        _aiInsights = insights;
        _isLoadingAI = false;
      });
    }
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

  // =========================================================================
  // ─── REDESIGNED UI PRESENTATION LAYER (7-SECTION ENTERPRISE ORDER) ───
  // =========================================================================

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _loadDashboardData,
      color: AppColors.accent,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── SECTION 1: Dashboard Header & Status ───
            _buildDashboardHeader(),
            const SizedBox(height: 18),

            // Monthly Backup Reminder Banner (if due)
            if (_showMonthlyBackupBanner) ...[
              _buildMonthlyBackupBanner(),
              const SizedBox(height: 18),
            ],

            // ─── SECTION 2: Executive KPI Summary (6 Equal Cards) ───
            _buildExecutiveKpiSection(),
            const SizedBox(height: 28),

            // ─── SECTION 3: Sales Overview (Chart + Payment Donut + Recent Sales) ───
            _buildSectionHeading('Sales Overview', 'Recent revenue trends, payment channels, and transactions', Icons.analytics_outlined),
            const SizedBox(height: 14),
            _buildSalesOverviewSection(),
            const SizedBox(height: 28),

            // ─── SECTION 4: Performance Analytics ("What Makes Money?") ───
            if (_analytics != null) ...[
              _buildSectionHeading('Performance Analytics', 'Revenue drivers, product rankings, and profitability breakdown', Icons.trending_up_rounded),
              const SizedBox(height: 14),
              _buildPerformanceAnalyticsSection(),
              const SizedBox(height: 28),
            ],

            // ─── SECTION 5: Financial Monitoring (Compact Enterprise Cards) ───
            _buildSectionHeading('Financial Monitoring & Alerts', 'Real-time receivables, payables, and low stock thresholds', Icons.account_balance_wallet_outlined),
            const SizedBox(height: 14),
            _buildFinancialMonitoringSection(),
            const SizedBox(height: 28),

            // ─── SECTION 6: Business Health (Operational Health Signals) ───
            if (_insights.isNotEmpty) ...[
              _buildSectionHeading('Business Health & Intelligence', 'Automated anomaly detection, growth signals, and inventory alerts', Icons.insights_rounded),
              const SizedBox(height: 14),
              _buildBusinessHealthSection(),
              const SizedBox(height: 28),
            ],

            // ─── SECTION 7: AI Business Advisor (Bottom Placement) ───
            _buildSectionHeading('AI Business Advisor', 'Generative retail analytics, strategic insights, and demand forecasting', Icons.auto_awesome_rounded),
            const SizedBox(height: 14),
            _buildAIBusinessAdvisorSection(),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  // ─── Section 1: Dashboard Header ───
  Widget _buildDashboardHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('Dashboard', style: AppTypography.h1.copyWith(
                    color: AppColors.textPrimary(context),
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  )),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.18)),
                    ),
                    child: Text('ENTERPRISE', style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    )),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                Formatters.date(DateTime.now()),
                style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary(context), fontSize: 13),
              ),
            ],
          ),
        ),
        // Live System Indicator
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.card(context),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.cardBorder(context)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8, height: 8,
                decoration: const BoxDecoration(color: AppColors.success, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Text('Live Connected', style: TextStyle(
                color: AppColors.textPrimary(context),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              )),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Tooltip(
          message: 'Refresh Dashboard',
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _loadDashboardData,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.card(context),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.cardBorder(context)),
                ),
                child: Icon(Icons.refresh_rounded, size: 20, color: AppColors.textSecondary(context)),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeading(String title, String subtitle, IconData icon) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: AppColors.primary),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: AppTypography.h4.copyWith(
              color: AppColors.textPrimary(context),
              fontWeight: FontWeight.w700,
              fontSize: 15,
            )),
            Text(subtitle, style: AppTypography.labelSmall.copyWith(
              color: AppColors.textTertiary(context),
              fontSize: 11,
            )),
          ],
        ),
      ],
    );
  }

  Widget _buildMonthlyBackupBanner() {
    final now = DateTime.now();
    final monthName = _monthNames[now.month - 1];
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.warning.withValues(alpha: 0.12), AppColors.accent.withValues(alpha: 0.06)],
          begin: Alignment.centerLeft, end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.backup_rounded, color: AppColors.warning, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Monthly Backup Due — $monthName ${now.year}',
                    style: AppTypography.labelSmall.copyWith(
                        color: AppColors.warning, fontWeight: FontWeight.w700, fontSize: 12)),
                Text('Download your monthly CSV backup to keep your business records safe',
                    style: AppTypography.labelSmall.copyWith(
                        color: AppColors.textSecondary(context), fontSize: 11)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          TextButton.icon(
            onPressed: () => AppShell.navigateTo.value = 'Settings & Backup',
            icon: const Icon(Icons.download_rounded, size: 14, color: AppColors.accent),
            label: const Text('Export Now', style: TextStyle(color: AppColors.accent, fontSize: 11, fontWeight: FontWeight.w700)),
            style: TextButton.styleFrom(
              backgroundColor: AppColors.accent.withValues(alpha: 0.12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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

  // ─── Section 2: Executive KPI Summary (6 Enterprise Cards) ───
  Widget _buildExecutiveKpiSection() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 1150 ? 6
            : constraints.maxWidth > 720 ? 3 : 2;
        final cardWidth = (constraints.maxWidth - (12.0 * (crossAxisCount - 1))) / crossAxisCount;
        const cardHeight = 118.0;

        return GridView.count(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: cardWidth / cardHeight,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _kpiCard('Today Sales', Formatters.currency(_todaySales),
                '$_todaySalesCount bills processed', Icons.trending_up_rounded,
                AppColors.successGradient, badgeColor: AppColors.success),
            _kpiCard('Week Sales', Formatters.currency(_weekSales),
                'Last 7 rolling days', Icons.calendar_month_rounded,
                AppColors.primaryGradient, badgeColor: AppColors.primary),
            _kpiCard('Today Profit', Formatters.currency(_todayProfit),
                _todayProfit >= 0 ? 'Margin Positive ✓' : 'Deficit ✗', Icons.account_balance_rounded,
                _todayProfit >= 0 ? AppColors.successGradient : AppColors.errorGradient,
                badgeColor: _todayProfit >= 0 ? AppColors.success : AppColors.error),
            _kpiCard('Expenses', Formatters.currency(_todayExpenses),
                'Today outflow', Icons.money_off_rounded,
                AppColors.errorGradient, badgeColor: AppColors.error),
            _kpiCard('Stock Value', Formatters.currencyCompact(_stockValue),
                'Cost: ${Formatters.currencyCompact(_stockCost)}', Icons.inventory_2_rounded,
                AppColors.primaryGradient, badgeColor: AppColors.accent),
            _kpiCard('Low Stock', _lowStockCount.toString(),
                _lowStockCount > 0 ? 'Need restock' : 'Optimal level', Icons.warning_rounded,
                AppColors.warningGradient, badgeColor: AppColors.warning,
                onTap: () => _openStockDrawer('low')),
          ],
        );
      },
    );
  }

  Widget _kpiCard(String title, String value, String subtitle, IconData icon,
      LinearGradient gradient, {required Color badgeColor, VoidCallback? onTap}) {
    return _HoverCard(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.card(context),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: onTap != null
              ? AppColors.warning.withValues(alpha: 0.35)
              : AppColors.cardBorder(context)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(title, style: AppTypography.labelMedium.copyWith(
                    color: AppColors.textSecondary(context),
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ), overflow: TextOverflow.ellipsis),
                ),
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    gradient: gradient,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: badgeColor.withValues(alpha: 0.25),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(icon, size: 14, color: Colors.white),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(value, style: AppTypography.monoLarge.copyWith(
              color: AppColors.textPrimary(context),
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ), overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Row(
              children: [
                Expanded(
                  child: Text(subtitle, style: AppTypography.labelSmall.copyWith(
                    color: AppColors.textTertiary(context),
                    fontSize: 10.5,
                  ), overflow: TextOverflow.ellipsis),
                ),
                if (onTap != null)
                  Icon(Icons.arrow_forward_ios_rounded, size: 9,
                      color: AppColors.warning.withValues(alpha: 0.8)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ─── Section 3: Sales Overview (Chart + Payment Donut + Recent Sales) ───
  Widget _buildSalesOverviewSection() {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth > 1150) {
          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(flex: 3, child: _buildChart()),
                const SizedBox(width: 14),
                Expanded(flex: 2, child: _buildPaymentPieChart()),
                const SizedBox(width: 14),
                Expanded(flex: 2, child: _buildRecentSales()),
              ],
            ),
          );
        }
        if (constraints.maxWidth > 750) {
          return Column(
            children: [
              _buildChart(),
              const SizedBox(height: 14),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: _buildPaymentPieChart()),
                    const SizedBox(width: 14),
                    Expanded(child: _buildRecentSales()),
                  ],
                ),
              ),
            ],
          );
        }
        return Column(
          children: [
            _buildChart(),
            const SizedBox(height: 14),
            _buildPaymentPieChart(),
            const SizedBox(height: 14),
            _buildRecentSales(),
          ],
        );
      },
    );
  }

  Widget _buildChart() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardBorder(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(children: [
                Icon(Icons.bar_chart_rounded, size: 18, color: AppColors.primary),
                const SizedBox(width: 8),
                Text('Sales Trend (Last 7 Days)', style: AppTypography.h4.copyWith(
                  color: AppColors.textPrimary(context),
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                )),
              ]),
              Text(Formatters.currency(_weekSales), style: AppTypography.mono.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              )),
            ],
          ),
          const SizedBox(height: 18),
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
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Text(date.substring(8, 10),
                                      style: AppTypography.labelSmall.copyWith(
                                        color: AppColors.textTertiary(context),
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      )),
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
                            width: 18,
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(5)),
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

  Widget _buildPaymentPieChart() {
    final total = _paymentDistribution.values.fold(0.0, (a, b) => a + b);
    final entries = _paymentDistribution.entries.toList();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardBorder(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.pie_chart_rounded, color: AppColors.accent, size: 18),
            const SizedBox(width: 8),
            Text('Sales by Payment', style: AppTypography.h4.copyWith(
              color: AppColors.textPrimary(context),
              fontWeight: FontWeight.w700,
              fontSize: 14,
            )),
          ]),
          const SizedBox(height: 16),
          if (_paymentDistribution.isEmpty || total == 0)
            Expanded(
              child: Center(child: Text('No sales data yet',
                  style: AppTypography.bodyMedium.copyWith(color: AppColors.textTertiary(context)))),
            )
          else ...[
            SizedBox(
              height: 140,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 3,
                  centerSpaceRadius: 28,
                  sections: entries.asMap().entries.map((e) {
                    final color = _pieColors[e.key % _pieColors.length];
                    final pct = (e.value.value / total * 100);
                    return PieChartSectionData(
                      value: e.value.value,
                      title: '${pct.toStringAsFixed(0)}%',
                      color: color,
                      radius: 44,
                      titleStyle: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 12),
            ...entries.asMap().entries.map((e) {
              final color = _pieColors[e.key % _pieColors.length];
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(children: [
                  Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
                  const SizedBox(width: 8),
                  Expanded(child: Text(e.value.key, style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textPrimary(context), fontSize: 12, fontWeight: FontWeight.w500))),
                  Text(Formatters.currency(e.value.value),
                      style: AppTypography.mono.copyWith(color: AppColors.textSecondary(context), fontSize: 11, fontWeight: FontWeight.w600)),
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
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardBorder(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6)),
                child: const Icon(Icons.receipt_long_rounded, color: AppColors.accent, size: 14),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Recent Transactions', style: AppTypography.h4.copyWith(
                      color: AppColors.textPrimary(context),
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    )),
                    Text('${_recentSales.length} latest sales', style: AppTypography.labelSmall.copyWith(
                      color: AppColors.textTertiary(context), fontSize: 10)),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => AppShell.navigateTo.value = 'Bill History',
                child: Row(children: [
                  Text('View All', style: TextStyle(
                    color: AppColors.accent,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  )),
                  const SizedBox(width: 3),
                  const Icon(Icons.arrow_forward_ios_rounded, size: 10, color: AppColors.accent),
                ]),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_recentSales.isEmpty)
            Expanded(
              child: Center(child: Text('No sales yet today',
                  style: AppTypography.bodyMedium.copyWith(color: AppColors.textTertiary(context), fontSize: 12))),
            )
          else ...[
            ...List.generate(_recentSales.length.clamp(0, 5), (index) {
              final sale = _recentSales[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: AppColors.surface(context),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.cardBorder(context)),
                  ),
                  child: Row(children: [
                    Container(
                      width: 22, height: 22,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(5)),
                      child: const Center(
                        child: Icon(Icons.receipt_outlined, size: 12, color: AppColors.accent),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(sale['invoice_number'] as String? ?? 'INV-0000',
                          style: AppTypography.mono.copyWith(color: AppColors.textPrimary(context), fontSize: 11.5, fontWeight: FontWeight.w600)),
                      Text(sale['customer_name'] as String? ?? 'Walk-in',
                          style: AppTypography.labelSmall.copyWith(color: AppColors.textTertiary(context), fontSize: 9.5)),
                    ])),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4)),
                      child: Text(Formatters.currency((sale['total'] as num).toDouble()),
                          style: AppTypography.mono.copyWith(color: AppColors.success, fontSize: 11, fontWeight: FontWeight.w700)),
                    ),
                  ]),
                ),
              );
            }),
            const Spacer(),
          ],
        ],
      ),
    );
  }

  // ─── Section 4: Business Health (Full-Width Business Intelligence Grid) ───
  Widget _buildBusinessHealthSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.015),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF6C5CE7), Color(0xFF00B894)]),
                borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.insights_rounded, size: 16, color: Colors.white),
            ),
            const SizedBox(width: 10),
            Text('Operational Health Signals', style: AppTypography.h4.copyWith(
                color: AppColors.textPrimary(context), fontWeight: FontWeight.w700, fontSize: 14)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(6)),
              child: Text('${_insights.length} active indicators', style: AppTypography.labelSmall.copyWith(
                  color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 10.5)),
            ),
          ]),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final crossAxisCount = constraints.maxWidth > 1100 ? 3
                  : constraints.maxWidth > 650 ? 2 : 1;
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _insights.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: crossAxisCount == 1 ? 4.0 : crossAxisCount == 2 ? 3.2 : 3.0,
                ),
                itemBuilder: (context, index) {
                  return _insightCard(_insights[index]);
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _insightCard(BusinessInsight insight) {
    final color = _insightColor(insight.priority);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(children: [
            Text(insight.emoji, style: const TextStyle(fontSize: 15)),
            const SizedBox(width: 6),
            Expanded(child: Text(insight.title, style: AppTypography.bodyMedium.copyWith(
                color: color, fontWeight: FontWeight.w700, fontSize: 12.5),
                overflow: TextOverflow.ellipsis)),
            _priorityBadge(insight.priority),
          ]),
          const SizedBox(height: 4),
          Text(insight.description, style: AppTypography.bodySmall.copyWith(
              color: AppColors.textSecondary(context), height: 1.35, fontSize: 11.5),
              maxLines: 2, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  Widget _priorityBadge(InsightPriority priority) {
    final color = _insightColor(priority);
    final label = priority == InsightPriority.critical ? 'HIGH'
        : priority == InsightPriority.warning ? 'MED'
        : priority == InsightPriority.success ? 'OK' : 'INFO';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4)),
      child: Text(label, style: TextStyle(
          color: color, fontSize: 8.5, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
    );
  }

  Color _insightColor(InsightPriority priority) {
    switch (priority) {
      case InsightPriority.critical: return AppColors.error;
      case InsightPriority.warning: return AppColors.warning;
      case InsightPriority.success: return AppColors.success;
      case InsightPriority.info: return const Color(0xFF0984E3);
    }
  }

  // ─── Section 4: Performance Analytics ("What Makes Money?") ───
  Widget _buildPerformanceAnalyticsSection() {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth > 1150) {
          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _buildTopProducts()),
                const SizedBox(width: 14),
                Expanded(child: _buildCategoryRevenueChart()),
                const SizedBox(width: 14),
                Expanded(child: _buildProfitBreakdown()),
              ],
            ),
          );
        }
        if (constraints.maxWidth > 750) {
          return Column(
            children: [
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: _buildTopProducts()),
                    const SizedBox(width: 14),
                    Expanded(child: _buildCategoryRevenueChart()),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _buildProfitBreakdown(),
            ],
          );
        }
        return Column(
          children: [
            _buildTopProducts(),
            const SizedBox(height: 14),
            _buildCategoryRevenueChart(),
            const SizedBox(height: 14),
            _buildProfitBreakdown(),
          ],
        );
      },
    );
  }

  Widget _buildTopProducts() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardBorder(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.star_rounded, color: AppColors.accent, size: 18),
            const SizedBox(width: 8),
            Text('Top Products', style: AppTypography.h4.copyWith(
              color: AppColors.textPrimary(context),
              fontWeight: FontWeight.w700,
              fontSize: 14,
            )),
          ]),
          const SizedBox(height: 14),
          if (_topProducts.isEmpty)
            Expanded(
              child: Center(
                child: Text('No product data yet',
                    style: AppTypography.bodyMedium.copyWith(color: AppColors.textTertiary(context))),
              ),
            )
          else
            ..._topProducts.asMap().entries.take(5).map((e) {
              final p = e.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(children: [
                  Container(
                    width: 22, height: 22,
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6)),
                    child: Center(child: Text('${e.key + 1}',
                        style: AppTypography.mono.copyWith(color: AppColors.accent, fontSize: 10, fontWeight: FontWeight.w700))),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(p['name'] as String, style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textPrimary(context), fontWeight: FontWeight.w500, fontSize: 12.5),
                        overflow: TextOverflow.ellipsis),
                    Text('${p['count']} units sold', style: AppTypography.labelSmall.copyWith(
                        color: AppColors.textTertiary(context), fontSize: 10)),
                  ])),
                  Text(Formatters.currency((p['revenue'] as num).toDouble()),
                      style: AppTypography.mono.copyWith(color: AppColors.success, fontSize: 11.5, fontWeight: FontWeight.w600)),
                ]),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildCategoryRevenueChart() {
    if (_analytics == null) return const SizedBox.shrink();

    Map<String, double> catRev;
    String filterLabel;

    if (_revFilterIndex == 0) {
      catRev = _analytics!.weekCategoryRevenue;
      filterLabel = 'This Week';
    } else if (_revFilterIndex == 1) {
      catRev = _analytics!.monthCategoryRevenue;
      filterLabel = 'This Month';
    } else {
      final snapIdx = _revFilterIndex - 2;
      if (snapIdx < _pastSnapshots.length) {
        final snap = _pastSnapshots[snapIdx];
        final rawCatRev = snap['category_revenue'];
        if (rawCatRev is Map) {
          catRev = rawCatRev.map((k, v) => MapEntry(k.toString(), (v as num).toDouble()));
        } else {
          catRev = {};
        }
        final m = (snap['month'] as num).toInt();
        final y = (snap['year'] as num).toInt();
        filterLabel = '${_monthNames[m - 1]} $y';
      } else {
        catRev = {};
        filterLabel = 'N/A';
      }
    }

    final sorted = catRev.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final topCats = sorted.take(5).toList();
    final maxVal = topCats.isNotEmpty ? topCats.first.value : 0.0;

    final filterLabels = <String>['Week', 'Month'];
    for (final snap in _pastSnapshots) {
      final m = (snap['month'] as num).toInt();
      final y = (snap['year'] as num).toInt();
      filterLabels.add('${_monthNames[m - 1]} $y');
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardBorder(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.donut_large_rounded, color: AppColors.accent, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text('Revenue by Category', style: AppTypography.h4.copyWith(
                  color: AppColors.textPrimary(context), fontWeight: FontWeight.w700, fontSize: 14)),
            ),
          ]),
          const SizedBox(height: 10),
          SizedBox(
            height: 28,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: filterLabels.length,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (context, index) {
                final isActive = _revFilterIndex == index;
                return GestureDetector(
                  onTap: () => setState(() => _revFilterIndex = index),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      gradient: isActive ? AppColors.primaryGradient : null,
                      color: isActive ? null : AppColors.surface(context),
                      borderRadius: BorderRadius.circular(6),
                      border: isActive ? null : Border.all(color: AppColors.cardBorder(context)),
                    ),
                    child: Text(
                      filterLabels[index],
                      style: AppTypography.labelSmall.copyWith(
                        color: isActive ? Colors.white : AppColors.textSecondary(context),
                        fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                        fontSize: 10.5,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          if (topCats.isEmpty)
            Expanded(
              child: Center(
                child: Text('No revenue data for $filterLabel',
                    style: AppTypography.bodyMedium.copyWith(color: AppColors.textTertiary(context))),
              ),
            )
          else
            ...topCats.asMap().entries.map((e) {
              final cat = e.value;
              final pct = maxVal > 0 ? cat.value / maxVal : 0.0;
              final color = _pieColors[e.key % _pieColors.length];
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Container(width: 8, height: 8, decoration: BoxDecoration(
                          color: color, borderRadius: BorderRadius.circular(2))),
                      const SizedBox(width: 8),
                      Expanded(child: Text(cat.key, style: AppTypography.bodySmall.copyWith(
                          color: AppColors.textPrimary(context), fontWeight: FontWeight.w500, fontSize: 12))),
                      Text(Formatters.currency(cat.value), style: AppTypography.mono.copyWith(
                          color: AppColors.textSecondary(context), fontSize: 11)),
                    ]),
                    const SizedBox(height: 3),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: pct.clamp(0.0, 1.0),
                        backgroundColor: AppColors.surface(context),
                        color: color,
                        minHeight: 5,
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildProfitBreakdown() {
    if (_analytics == null) return const SizedBox.shrink();
    final a = _analytics!;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardBorder(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.account_balance_rounded, color: AppColors.accent, size: 18),
            const SizedBox(width: 8),
            Text('Profit Breakdown (Month)', style: AppTypography.h4.copyWith(
                color: AppColors.textPrimary(context), fontWeight: FontWeight.w700, fontSize: 14)),
          ]),
          const SizedBox(height: 12),
          _profitRow('Gross Sales', a.monthGrossSales, AppColors.success),
          _profitRow('(-) Discounts', a.monthDiscounts, AppColors.warning),
          _profitRow('Net Revenue', a.monthRevenue, AppColors.success, bold: true),
          const SizedBox(height: 2),
          _profitRow('(-) Cost of Goods', a.monthCOGS, AppColors.error),
          _profitRow('Gross Profit', a.monthGrossProfit, a.monthGrossProfit >= 0 ? AppColors.success : AppColors.error, bold: true),
          const SizedBox(height: 2),
          _profitRow('(-) Expenses', a.monthExpenses, AppColors.error),
          if (a.monthGST > 0)
            _profitRow('GST Collected', a.monthGST, const Color(0xFF0984E3)),
          const Divider(height: 16),
          Row(children: [
            Expanded(child: Text('Net Profit', style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textPrimary(context), fontWeight: FontWeight.w700, fontSize: 13))),
            Text(Formatters.currency(a.monthNetProfit),
                style: AppTypography.mono.copyWith(
                    color: a.monthNetProfit >= 0 ? AppColors.success : AppColors.error,
                    fontWeight: FontWeight.w800, fontSize: 15)),
          ]),
          const SizedBox(height: 6),
          Row(children: [
            Expanded(child: Text('Profit Margin', style: AppTypography.labelSmall.copyWith(
                color: AppColors.textTertiary(context), fontSize: 11))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: (a.profitMarginPct >= 20 ? AppColors.success : AppColors.warning).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(5)),
              child: Text('${a.profitMarginPct.toStringAsFixed(1)}%',
                  style: AppTypography.mono.copyWith(
                      color: a.profitMarginPct >= 20 ? AppColors.success : AppColors.warning,
                      fontWeight: FontWeight.w700, fontSize: 11)),
            ),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            _growthChip('Week', a.weekGrowthPct),
            const SizedBox(width: 6),
            _growthChip('Month', a.monthGrowthPct),
          ]),
        ],
      ),
    );
  }

  Widget _profitRow(String label, double value, Color color, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(children: [
        Container(width: 6, height: 6, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 8),
        Expanded(child: Text(label, style: AppTypography.bodySmall.copyWith(
            color: bold ? AppColors.textPrimary(context) : AppColors.textSecondary(context),
            fontWeight: bold ? FontWeight.w600 : FontWeight.w400, fontSize: 11.5))),
        Text(Formatters.currency(value), style: AppTypography.mono.copyWith(
            color: bold ? color : AppColors.textPrimary(context),
            fontSize: 11.5,
            fontWeight: bold ? FontWeight.w700 : FontWeight.w400)),
      ]),
    );
  }

  Widget _growthChip(String label, double pct) {
    final isPositive = pct >= 0;
    final color = isPositive ? AppColors.success : AppColors.error;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(isPositive ? Icons.trending_up_rounded : Icons.trending_down_rounded, size: 12, color: color),
        const SizedBox(width: 4),
        Text('$label ${isPositive ? "+" : ""}${pct.toStringAsFixed(1)}%',
            style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700)),
      ]),
    );
  }

  // ─── Section 5: Financial Monitoring (Compact Side-by-Side Enterprise Cards) ───
  Widget _buildFinancialMonitoringSection() {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth > 1050) {
          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _buildCustomerDuesCompact()),
                const SizedBox(width: 14),
                Expanded(child: _buildVendorDuesCompact()),
                const SizedBox(width: 14),
                Expanded(child: _buildLowStockCompact()),
              ],
            ),
          );
        }
        if (constraints.maxWidth > 700) {
          return Column(
            children: [
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: _buildCustomerDuesCompact()),
                    const SizedBox(width: 14),
                    Expanded(child: _buildVendorDuesCompact()),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _buildLowStockCompact(),
            ],
          );
        }
        return Column(
          children: [
            _buildCustomerDuesCompact(),
            const SizedBox(height: 14),
            _buildVendorDuesCompact(),
            const SizedBox(height: 14),
            _buildLowStockCompact(),
          ],
        );
      },
    );
  }

  Widget _buildCustomerDuesCompact() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6)),
              child: const Icon(Icons.access_time_rounded, color: AppColors.warning, size: 14),
            ),
            const SizedBox(width: 8),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Customer Dues (Udhar)', style: AppTypography.h4.copyWith(
                color: AppColors.textPrimary(context), fontWeight: FontWeight.w700, fontSize: 13)),
              Text('${_customersWithDues.length} customers pending', style: AppTypography.labelSmall.copyWith(
                color: AppColors.textTertiary(context), fontSize: 10)),
            ])),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6)),
              child: Text(Formatters.currency(_totalCustomerDues),
                  style: AppTypography.mono.copyWith(color: AppColors.warning, fontWeight: FontWeight.w700, fontSize: 11.5)),
            ),
          ]),
          const SizedBox(height: 12),
          if (_customersWithDues.isEmpty)
            Expanded(
              child: Center(child: Text('No pending customer dues',
                  style: AppTypography.bodyMedium.copyWith(color: AppColors.textTertiary(context), fontSize: 12))),
            )
          else ...[
            ..._customersWithDues.take(5).map((customer) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: AppColors.surface(context),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.cardBorder(context)),
                ),
                child: Row(children: [
                  Container(
                    width: 22, height: 22,
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(5)),
                    child: Center(child: Text(customer.name.isNotEmpty ? customer.name[0].toUpperCase() : 'C',
                        style: const TextStyle(color: AppColors.warning, fontWeight: FontWeight.w700, fontSize: 10))),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(customer.name, style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textPrimary(context), fontWeight: FontWeight.w500, fontSize: 11.5),
                        overflow: TextOverflow.ellipsis),
                    if (customer.phone.isNotEmpty)
                      Text(customer.phone, style: AppTypography.labelSmall.copyWith(
                          color: AppColors.textTertiary(context), fontSize: 9.5)),
                  ])),
                  Text(Formatters.currency(customer.balance),
                      style: AppTypography.mono.copyWith(color: AppColors.warning, fontWeight: FontWeight.w700, fontSize: 11)),
                ]),
              ),
            )),
            const Spacer(),
            if (_customersWithDues.length > 5)
              Align(
                alignment: Alignment.centerRight,
                child: GestureDetector(
                  onTap: () => AppShell.navigateTo.value = 'Customers',
                  child: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text('+ ${_customersWithDues.length - 5} more...',
                        style: TextStyle(color: AppColors.accent, fontSize: 10.5, fontWeight: FontWeight.w600)),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildVendorDuesCompact() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6)),
              child: const Icon(Icons.account_balance_wallet_rounded, color: AppColors.error, size: 14),
            ),
            const SizedBox(width: 8),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Vendor Dues (Udhaar)', style: AppTypography.h4.copyWith(
                color: AppColors.textPrimary(context), fontWeight: FontWeight.w700, fontSize: 13)),
              Text('${_vendorsWithDues.length} vendors payable', style: AppTypography.labelSmall.copyWith(
                color: AppColors.textTertiary(context), fontSize: 10)),
            ])),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6)),
              child: Text(Formatters.currency(_totalVendorDues),
                  style: AppTypography.mono.copyWith(color: AppColors.error, fontWeight: FontWeight.w700, fontSize: 11.5)),
            ),
          ]),
          const SizedBox(height: 12),
          if (_vendorsWithDues.isEmpty)
            Expanded(
              child: Center(child: Text('No pending vendor dues',
                  style: AppTypography.bodyMedium.copyWith(color: AppColors.textTertiary(context), fontSize: 12))),
            )
          else ...[
            ..._vendorsWithDues.take(5).map((vendor) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: AppColors.surface(context),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.cardBorder(context)),
                ),
                child: Row(children: [
                  Container(
                    width: 22, height: 22,
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(5)),
                    child: Center(child: Text(vendor.name.isNotEmpty ? vendor.name[0].toUpperCase() : 'V',
                        style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.w700, fontSize: 10))),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(vendor.name, style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textPrimary(context), fontWeight: FontWeight.w500, fontSize: 11.5),
                        overflow: TextOverflow.ellipsis),
                    if (vendor.phone.isNotEmpty)
                      Text(vendor.phone, style: AppTypography.labelSmall.copyWith(
                          color: AppColors.textTertiary(context), fontSize: 9.5)),
                  ])),
                  Text(Formatters.currency(vendor.balance),
                      style: AppTypography.mono.copyWith(color: AppColors.error, fontWeight: FontWeight.w700, fontSize: 11)),
                ]),
              ),
            )),
            const Spacer(),
            if (_vendorsWithDues.length > 5)
              Align(
                alignment: Alignment.centerRight,
                child: GestureDetector(
                  onTap: () => AppShell.navigateTo.value = 'Vendors',
                  child: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text('+ ${_vendorsWithDues.length - 5} more...',
                        style: TextStyle(color: AppColors.accent, fontSize: 10.5, fontWeight: FontWeight.w600)),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildLowStockCompact() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6)),
              child: const Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 14),
            ),
            const SizedBox(width: 8),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Low Stock Alerts', style: AppTypography.h4.copyWith(
                color: AppColors.textPrimary(context), fontWeight: FontWeight.w700, fontSize: 13)),
              Text('$_lowStockCount items needing restock', style: AppTypography.labelSmall.copyWith(
                color: AppColors.textTertiary(context), fontSize: 10)),
            ])),
            GestureDetector(
              onTap: () => _openStockDrawer('low'),
              child: Row(children: [
                Text('View All', style: TextStyle(color: AppColors.accent, fontSize: 11, fontWeight: FontWeight.w600)),
                const SizedBox(width: 3),
                const Icon(Icons.arrow_forward_ios_rounded, size: 10, color: AppColors.accent),
              ]),
            ),
          ]),
          const SizedBox(height: 12),
          if (_lowStockItems.isEmpty)
            Expanded(
              child: Center(child: Text('All stock levels optimal',
                  style: AppTypography.bodyMedium.copyWith(color: AppColors.textTertiary(context), fontSize: 12))),
            )
          else ...[
            ..._lowStockItems.take(5).map((item) {
              final isZero = (item['quantity'] as int) == 0;
              final name = item['name'] as String? ?? 'Item';
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: AppColors.surface(context),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.cardBorder(context)),
                  ),
                  child: Row(children: [
                    Container(
                      width: 22, height: 22,
                      decoration: BoxDecoration(
                        color: (isZero ? AppColors.error : AppColors.warning).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(5)),
                      child: Center(
                        child: Icon(
                          isZero ? Icons.remove_circle_outline_rounded : Icons.inventory_2_outlined,
                          size: 12,
                          color: isZero ? AppColors.error : AppColors.warning,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(name, style: AppTypography.bodySmall.copyWith(
                          color: AppColors.textPrimary(context), fontWeight: FontWeight.w500, fontSize: 11.5),
                          overflow: TextOverflow.ellipsis),
                      Text(isZero ? 'Immediate reorder needed' : 'Below safety threshold',
                          style: AppTypography.labelSmall.copyWith(
                              color: isZero ? AppColors.error : AppColors.textTertiary(context), fontSize: 9.5)),
                    ])),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: (isZero ? AppColors.error : AppColors.warning).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4)),
                      child: Text(isZero ? '0 Out' : '${item['quantity']} left', style: AppTypography.monoSmall.copyWith(
                          color: isZero ? AppColors.error : AppColors.warning,
                          fontWeight: FontWeight.w700, fontSize: 10)),
                    ),
                  ]),
                ),
              );
            }),
            const Spacer(),
            if (_lowStockItems.length > 5)
              Align(
                alignment: Alignment.centerRight,
                child: GestureDetector(
                  onTap: () => _openStockDrawer('low'),
                  child: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text('+ ${_lowStockItems.length - 5} more items...',
                        style: TextStyle(color: AppColors.accent, fontSize: 10.5, fontWeight: FontWeight.w600)),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  // ─── Section 7: AI Business Advisor (Bottom Full-Width Placement) ───
  Widget _buildAIBusinessAdvisorSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(9)),
              child: const Icon(Icons.auto_awesome_rounded, size: 18, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('AI Retail Intelligence Engine', style: AppTypography.h4.copyWith(
                color: AppColors.textPrimary(context), fontWeight: FontWeight.w700, fontSize: 14.5)),
              Text('Automated demand forecasting, pricing strategy, and promotional guidance', style: AppTypography.labelSmall.copyWith(
                color: AppColors.textTertiary(context), fontSize: 11)),
            ])),
            SizedBox(
              height: 36,
              child: ElevatedButton.icon(
                onPressed: _isLoadingAI ? null : _generateAIInsights,
                icon: _isLoadingAI
                    ? const SizedBox(width: 14, height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.auto_awesome_rounded, size: 15),
                label: Text(_isLoadingAI ? 'Analyzing...' : 'Generate Insights',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: AppColors.accent.withValues(alpha: 0.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                ),
              ),
            ),
          ]),
          const SizedBox(height: 16),
          if (_aiInsights.isEmpty && !_isLoadingAI)
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.surface(context),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.cardBorder(context)),
              ),
              child: Row(children: [
                Icon(Icons.lightbulb_outline_rounded, color: AppColors.accent.withValues(alpha: 0.6), size: 22),
                const SizedBox(width: 14),
                Flexible(child: Text(
                  'Click "Generate Insights" to run deep statistical intelligence across sales patterns, slow-moving stock, customer retention, and category profitability.',
                  style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary(context), fontSize: 12.5),
                )),
              ]),
            )
          else if (_isLoadingAI)
            Center(child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const CircularProgressIndicator(color: AppColors.accent),
                const SizedBox(height: 14),
                Text('Analyzing sales records, customer cohorts, and inventory margins...',
                    style: TextStyle(color: AppColors.textTertiary(context), fontSize: 12)),
              ]),
            ))
          else
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.surface(context),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
              ),
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
}

/// Subtle hover card elevation micro-animation
class _HoverCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;

  const _HoverCard({required this.child, this.onTap});

  @override
  State<_HoverCard> createState() => _HoverCardState();
}

class _HoverCardState extends State<_HoverCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: widget.onTap != null ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          transform: _isHovered ? Matrix4.translationValues(0, -2, 0) : Matrix4.identity(),
          child: widget.child,
        ),
      ),
    );
  }
}
