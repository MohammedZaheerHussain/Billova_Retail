import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/formatters.dart';
import '../../providers/auth_provider.dart';
import '../../providers/inventory_provider.dart';
import '../../providers/sales_provider.dart';
import '../../providers/expense_provider.dart';
import '../../providers/cash_till_provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/staff_provider.dart';
import '../../providers/customer_provider.dart';
import '../../providers/vendor_provider.dart';
import '../../providers/purchase_provider.dart';
import '../../providers/category_provider.dart';
import '../../providers/clearance_provider.dart';
import '../../data/remote/supabase_service.dart';
import '../../data/local/db_helper.dart';
import '../dashboard/dashboard_screen.dart';
import '../inventory/inventory_screen.dart';
import '../sales/sales_terminal_screen.dart';
import '../cash_till/cash_till_screen.dart';
import '../expenses/expenses_screen.dart';
import '../bill_history/bill_history_screen.dart';
import '../vendors/vendor_screen.dart';
import '../purchases/purchase_screen.dart';
import '../staff/staff_screen.dart';
import '../customers/customer_screen.dart';
import '../settings/settings_screen.dart';
import '../returns/return_exchange_screen.dart';
import '../clearance/clearance_stock_screen.dart';
import '../loans/loans_chits_screen.dart';
import '../reports/crm_reports_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  /// Incremented after every Supabase data pull so screens can reload.
  static final ValueNotifier<int> dataVersion = ValueNotifier<int>(0);

  /// Trigger navigation to a named module from anywhere in the widget tree.
  static final ValueNotifier<String> navigateTo = ValueNotifier<String>('');

  /// Flag: set to true when staff login has already pulled + loaded all data.
  /// AppShell checks this and skips the expensive re-pull on init.
  static bool dataPreloaded = false;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _selectedIndex = 0;
  bool _sidebarExpanded = true;
  bool _isInitializing = true;
  final FocusNode _focusNode = FocusNode();

  void _onNavigateTo() {
    final label = AppShell.navigateTo.value;
    if (label.isEmpty) return;
    final idx = _allNavItems.toList().indexWhere((item) => item.label == label);
    if (idx >= 0 && mounted) setState(() => _selectedIndex = idx);
    AppShell.navigateTo.value = ''; // reset
  }

  // F-key → absolute nav index mapping
  static final Map<LogicalKeyboardKey, int> _shortcutMap = {
    LogicalKeyboardKey.f1: 0,   // Dashboard
    LogicalKeyboardKey.f2: 1,   // Daily Cash Till
    LogicalKeyboardKey.f3: 2,   // Sales Terminal
    LogicalKeyboardKey.f4: 3,   // Returns & Exchange
    LogicalKeyboardKey.f5: 4,   // Purchases (In)
    LogicalKeyboardKey.f6: 5,   // Master Inventory
    LogicalKeyboardKey.f7: 6,   // Clearance Stock
    LogicalKeyboardKey.f8: 7,   // Customers
    LogicalKeyboardKey.f9: 8,   // Vendors
    LogicalKeyboardKey.f10: 9,  // Staff & Attendance
    LogicalKeyboardKey.f11: 10, // Expenses
  };

  // All nav items — grouped by section, filtered dynamically by role
  static const List<_NavItem> _allNavItems = [
    // OVERVIEW
    _NavItem(icon: Icons.dashboard_rounded, label: 'Dashboard', shortcut: 'F1', adminOnly: true, section: 'OVERVIEW'),
    _NavItem(icon: Icons.account_balance_wallet_rounded, label: 'Daily Cash Till', shortcut: 'F2', adminOnly: true, section: 'OVERVIEW'),
    // TRANSACTIONS
    _NavItem(icon: Icons.point_of_sale_rounded, label: 'Sales Terminal', shortcut: 'F3', adminOnly: false, section: 'TRANSACTIONS'),
    _NavItem(icon: Icons.swap_horiz_rounded, label: 'Returns & Exchange', shortcut: 'F4', adminOnly: false, section: 'TRANSACTIONS'),
    _NavItem(icon: Icons.local_shipping_rounded, label: 'Purchases (In)', shortcut: 'F5', adminOnly: true, section: 'TRANSACTIONS'),
    // INVENTORY & CLEARANCE
    _NavItem(icon: Icons.inventory_2_rounded, label: 'Master Inventory', shortcut: 'F6', adminOnly: true, section: 'INVENTORY & CLEARANCE'),
    _NavItem(icon: Icons.cleaning_services_rounded, label: 'Clearance Stock', shortcut: 'F7', adminOnly: false, section: 'INVENTORY & CLEARANCE'),
    // DIRECTORY
    _NavItem(icon: Icons.people_outline_rounded, label: 'Customers', shortcut: 'F8', adminOnly: false, section: 'DIRECTORY'),
    _NavItem(icon: Icons.store_rounded, label: 'Vendors', shortcut: 'F9', adminOnly: true, section: 'DIRECTORY'),
    _NavItem(icon: Icons.badge_rounded, label: 'Staff & Attendance', shortcut: 'F10', adminOnly: true, section: 'DIRECTORY'),
    // FINANCE & ANALYTICS
    _NavItem(icon: Icons.money_off_rounded, label: 'Expenses', shortcut: 'F11', adminOnly: true, section: 'FINANCE & ANALYTICS'),
    _NavItem(icon: Icons.receipt_long_rounded, label: 'Bill History', shortcut: '', adminOnly: false, section: 'FINANCE & ANALYTICS'),
    _NavItem(icon: Icons.analytics_rounded, label: 'CRM Reports', shortcut: '', adminOnly: true, section: 'FINANCE & ANALYTICS'),
    // SYSTEM
    _NavItem(icon: Icons.settings_rounded, label: 'Settings & Backup', shortcut: '', adminOnly: true, section: 'SYSTEM'),
  ];

  static const List<Widget> _allScreens = [
    // OVERVIEW
    DashboardScreen(),
    CashTillScreen(),
    // TRANSACTIONS
    SalesTerminalScreen(),
    ReturnExchangeScreen(),
    PurchaseScreen(),
    // INVENTORY & CLEARANCE
    InventoryScreen(),
    ClearanceStockScreen(),
    // DIRECTORY
    CustomerScreen(),
    VendorScreen(),
    StaffScreen(),
    // FINANCE & ANALYTICS
    ExpensesScreen(),
    BillHistoryScreen(),
    CrmReportsScreen(),
    // SYSTEM
    SettingsScreen(),
  ];

  Timer? _syncTimer;

  @override
  void initState() {
    super.initState();
    AppShell.navigateTo.addListener(_onNavigateTo);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAllData();
      _focusNode.requestFocus();
      _startAutoSync();
    });
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    AppShell.navigateTo.removeListener(_onNavigateTo);
    _focusNode.dispose();
    super.dispose();
  }

  /// Auto-sync every 60 seconds — processes pending sync queue
  void _startAutoSync() {
    _syncTimer = Timer.periodic(const Duration(seconds: 60), (_) async {
      try {
        final supabase = SupabaseService.instance;
        if (supabase.isLoggedIn) {
          final synced = await supabase.processSyncQueue();
          if (synced > 0) {
            debugPrint('🔄 Auto-sync: pushed $synced pending items to cloud');
          }
        }
      } catch (e) {
        debugPrint('🔄 Auto-sync skipped: $e');
      }
    });
  }

  /// Handle F-key shortcuts for instant navigation
  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    // Skip if user is typing in a text field
    final primaryFocus = FocusManager.instance.primaryFocus;
    if (primaryFocus != null && primaryFocus.context != null) {
      final widget = primaryFocus.context!.widget;
      if (widget is EditableText) return KeyEventResult.ignored;
    }

    final absoluteIndex = _shortcutMap[event.logicalKey];
    if (absoluteIndex == null) return KeyEventResult.ignored;

    // Map absolute index to visible index (role-filtered)
    final staff = context.read<StaffProvider>();
    final visibleNav = _getVisibleNavItems(staff);
    final targetLabel = _allNavItems[absoluteIndex].label;

    // Find the visible index for this nav item
    final visibleIndex = visibleNav.indexWhere((n) => n.label == targetLabel);
    if (visibleIndex == -1) return KeyEventResult.ignored; // Not visible for this role

    setState(() => _selectedIndex = visibleIndex);
    return KeyEventResult.handled;
  }

  Future<void> _loadAllData() async {
    if (!mounted) return;
    setState(() => _isInitializing = true);

    try {
      // ─── STEP 1: Pull from Supabase FIRST (cloud → local) ───
      if (AppShell.dataPreloaded) {
        debugPrint('⚡ Data already preloaded by staff login — skipping pull');
        AppShell.dataPreloaded = false; // Reset for next session
      } else {
        try {
          final supabase = SupabaseService.instance;
          if (supabase.isLoggedIn) {
            debugPrint('🧹 Clearing local DB before pull (data isolation)...');
            final db = DBHelper.instance;
            await db.clearAllData();
            debugPrint('📥 Pulling data from Supabase for user: ${supabase.userId}...');
            await supabase.pullAllData();
            debugPrint('📥 Pull complete — now loading providers');
          }
        } catch (e) {
          debugPrint('⚠️ Supabase pull failed (will use local data): $e');
        }
      }

      if (!mounted) return;

      // ─── STEP 2: Load providers from local DB (now populated) ───
      final inventory = context.read<InventoryProvider>();
      final sales = context.read<SalesProvider>();
      final expenses = context.read<ExpenseProvider>();
      final cashTill = context.read<CashTillProvider>();
      final staffProvider = context.read<StaffProvider>();
      final customerProvider = context.read<CustomerProvider>();
      final vendorProvider = context.read<VendorProvider>();
      final purchaseProvider = context.read<PurchaseProvider>();
      final categoryProvider = context.read<CategoryProvider>();
      final clearanceProvider = context.read<ClearanceProvider>();

      final now = DateTime.now();
      final monthStart = DateTime(now.year, now.month, 1);

      await Future.wait([
        inventory.loadItems(),
        sales.loadSales(),
        expenses.loadExpenses(),
        cashTill.loadToday(),
        staffProvider.loadStaff(),
        staffProvider.loadAttendance(),
        customerProvider.loadCustomers(),
        vendorProvider.loadVendors(),
        purchaseProvider.loadPurchases(),
        categoryProvider.loadCategories(),
        clearanceProvider.loadClearanceRecords(),
      ]);

      // ─── STEP 3: Restore staff session if applicable ───
      await staffProvider.restoreSession();

      // ─── STEP 4: Process any pending sync queue ───
      try {
        final supabase = SupabaseService.instance;
        if (supabase.isLoggedIn) {
          await supabase.processSyncQueue();
        }
      } catch (_) {}

      // ─── STEP 4.5: Recover any missing customers from sales history ───
      try {
        final recovered = await customerProvider.recoverMissingCustomers(sales.allSales);
        if (recovered > 0) {
          debugPrint('🔄 Recovered $recovered missing customers from sales history');
        }
      } catch (e) {
        debugPrint('⚠️ Customer recovery failed (non-fatal): $e');
      }

      // ─── STEP 4.6: Auto-cleanup old attendance records (60+ days) ───
      try {
        await staffProvider.cleanupOldAttendance();
      } catch (e) {
        debugPrint('⚠️ Attendance cleanup failed (non-fatal): $e');
      }

      // ─── STEP 5: Signal screens to reload with fresh data ───
      AppShell.dataVersion.value++;
      debugPrint('📢 dataVersion bumped to ${AppShell.dataVersion.value}');
    } catch (e) {
      debugPrint('⚠️ Error during _loadAllData: $e');
    } finally {
      if (mounted) {
        setState(() => _isInitializing = false);
      }
    }
  }

  /// Get filtered nav items based on staff role
  List<_NavItem> _getVisibleNavItems(StaffProvider staff) {
    if (staff.isAdmin || !staff.isStaffLoggedIn) {
      return _allNavItems.toList();
    }
    return _allNavItems.where((item) => !item.adminOnly).toList();
  }

  /// Get filtered screens based on staff role
  List<Widget> _getVisibleScreens(StaffProvider staff) {
    if (staff.isAdmin || !staff.isStaffLoggedIn) {
      return _allScreens.toList();
    }
    final visibleLabels = _getVisibleNavItems(staff).map((i) => i.label).toSet();
    final result = <Widget>[];
    for (int i = 0; i < _allNavItems.length; i++) {
      if (visibleLabels.contains(_allNavItems[i].label)) {
        result.add(_allScreens[i]);
      }
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isSmall = width < 800;
    if (isSmall && _sidebarExpanded) _sidebarExpanded = false;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_isInitializing) {
      return Scaffold(
        backgroundColor: isDark ? AppColors.scaffoldDark : AppColors.scaffoldLight,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.receipt_long_rounded,
                  size: 32,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Initializing Skywalk Workspace...',
                style: AppTypography.bodyMedium.copyWith(
                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Focus(
      focusNode: _focusNode,
      onKeyEvent: _handleKeyEvent,
      autofocus: true,
      child: Consumer<StaffProvider>(
        builder: (context, staffProvider, _) {
          final visibleNav = _getVisibleNavItems(staffProvider);
          final visibleScreens = _getVisibleScreens(staffProvider);

          // Clamp selected index
          final safeIndex = _selectedIndex.clamp(0, visibleScreens.length - 1);

          return Scaffold(
            body: Row(
              children: [
                _buildSidebar(isSmall, isDark, visibleNav, staffProvider),
                Container(
                  width: 1,
                  color: (isDark ? AppColors.cardBorder(context) : AppColors.cardBorderLight).withValues(alpha: 0.5),
                ),
                Expanded(child: visibleScreens[safeIndex]),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSidebar(bool isSmall, bool isDark, List<_NavItem> navItems, StaffProvider staffProvider) {
    final sidebarWidth = _sidebarExpanded ? 220.0 : 72.0;

    return AnimatedContainer(
      duration: Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      width: sidebarWidth,
      decoration: BoxDecoration(
        color: isDark ? AppColors.sidebarDark : AppColors.sidebarLight,
        border: Border(
          right: BorderSide(
            color: AppColors.cardBorderDark.withValues(alpha: 0.3),
          ),
        ),
      ),
      child: Column(
        children: [
          // ─── Header ───
          Container(
            padding: EdgeInsets.symmetric(horizontal: _sidebarExpanded ? 20 : 12, vertical: 20),
            child: Row(
              children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.receipt_long_rounded, size: 22, color: Colors.white),
                ),
                if (_sidebarExpanded) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: ShaderMask(
                      shaderCallback: (bounds) => AppColors.primaryGradient.createShader(bounds),
                      child: Text('SKYWALK',
                          style: AppTypography.labelLarge.copyWith(
                            color: Colors.white, letterSpacing: 3, fontSize: 15)),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 8),

          // ─── Nav Items with Section Headers ───
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              itemCount: navItems.length,
              itemBuilder: (context, index) {
                final item = navItems[index];
                final isSelected = index == _selectedIndex.clamp(0, navItems.length - 1);

                // Check if we need a section header
                final showSection = _sidebarExpanded &&
                    item.section.isNotEmpty &&
                    (index == 0 || navItems[index - 1].section != item.section);

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Section header
                    if (showSection)
                      Padding(
                        padding: EdgeInsets.only(
                          left: 14, right: 14,
                          top: index == 0 ? 0 : 16, bottom: 6),
                        child: Text(
                          item.section,
                          style: AppTypography.labelSmall.copyWith(
                            color: AppColors.accent.withValues(alpha: 0.6),
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                    // Nav item
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => setState(() => _selectedIndex = index),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: EdgeInsets.symmetric(
                              horizontal: _sidebarExpanded ? 14 : 0, vertical: 10),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.primary.withValues(alpha: 0.15)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                              border: isSelected
                                  ? Border.all(color: AppColors.primary.withValues(alpha: 0.3))
                                  : null,
                            ),
                            child: Row(
                              mainAxisAlignment: _sidebarExpanded
                                  ? MainAxisAlignment.start : MainAxisAlignment.center,
                              children: [
                                Icon(item.icon, size: 20,
                                    color: isSelected ? AppColors.accent
                                        : AppColors.textSecondaryDark),
                                if (_sidebarExpanded) ...[
                                  SizedBox(width: 12),
                                  Expanded(
                                    child: Text(item.label,
                                        style: AppTypography.bodyMedium.copyWith(
                                          color: isSelected
                                              ? AppColors.textPrimaryDark
                                              : AppColors.textSecondaryDark,
                                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                                          fontSize: 13,
                                        ),
                                        overflow: TextOverflow.ellipsis),
                                  ),
                                  if (item.shortcut.isNotEmpty)
                                    Container(
                                      padding: EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? AppColors.accent.withValues(alpha: 0.2)
                                            : AppColors.cardBorderDark.withValues(alpha: 0.5),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(item.shortcut,
                                          style: AppTypography.monoSmall.copyWith(
                                            color: isSelected ? AppColors.accent
                                                : AppColors.textTertiaryDark,
                                            fontSize: 9,
                                            fontWeight: FontWeight.w600,
                                          )),
                                    ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),

          // ─── Staff Session + Clock In/Out ───
          if (staffProvider.isStaffLoggedIn && _sidebarExpanded)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 28, height: 28,
                        decoration: BoxDecoration(
                          color: AppColors.accent.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.person_rounded, size: 16, color: AppColors.accent),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(staffProvider.currentStaffName,
                                style: AppTypography.labelSmall.copyWith(
                                    color: AppColors.textPrimaryDark, fontWeight: FontWeight.w600),
                                overflow: TextOverflow.ellipsis),
                            Text(staffProvider.currentStaffRole,
                                style: AppTypography.labelSmall.copyWith(
                                    color: AppColors.accent, fontSize: 9, letterSpacing: 0.5)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  // ─── Monthly target progress (staff only) ───
                  if (staffProvider.currentStaff != null &&
                      !staffProvider.isAdmin &&
                      staffProvider.currentStaff!.monthlySaleTarget > 0) ...[
                    const SizedBox(height: 8),
                    Builder(builder: (_) {
                      final target = staffProvider.currentStaff!.monthlySaleTarget;
                      // FIX: Use allSales (not filtered sales) for full month accumulation
                      final salesProv = context.watch<SalesProvider>();
                      final now = DateTime.now();
                      final monthStart = DateTime(now.year, now.month, 1);
                      // Sum ALL sales for this staff in current month
                      final staffSales = salesProv.allSales
                          .where((s) =>
                              s.staffId == staffProvider.currentStaffId &&
                              s.createdAt.toLocal().isAfter(monthStart.subtract(const Duration(seconds: 1))))
                          .fold<double>(0, (sum, s) => sum + s.total);
                      final remaining = (target - staffSales).clamp(0.0, double.infinity);
                      final progress = (staffSales / target).clamp(0.0, 1.0);
                      // Color thresholds: Red <30%, Yellow 30-70%, Green 70%+
                      final progressColor = progress >= 0.7
                          ? AppColors.success
                          : progress >= 0.3
                              ? AppColors.warning
                              : AppColors.error;
                      final isAchieved = progress >= 1.0;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(isAchieved ? Icons.emoji_events_rounded : Icons.flag_rounded,
                                  size: 10, color: progressColor),
                              const SizedBox(width: 4),
                              Expanded(child: Text(
                                  isAchieved ? '🎉 Target Achieved!' : 'Target: ${Formatters.currency(target)}',
                                  style: TextStyle(color: AppColors.textTertiaryDark, fontSize: 9),
                                  overflow: TextOverflow.ellipsis)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(3),
                            child: LinearProgressIndicator(
                              value: progress,
                              minHeight: 5,
                              backgroundColor: AppColors.surface(context).withValues(alpha: 0.3),
                              color: progressColor,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${Formatters.currency(staffSales)} • ${(progress * 100).toStringAsFixed(0)}%',
                            style: TextStyle(color: progressColor, fontSize: 9, fontWeight: FontWeight.w600),
                          ),
                        ],
                      );
                    }),
                  ],
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    height: 34,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        bool success;
                        if (staffProvider.isClockedIn) {
                          success = await staffProvider.clockOut();
                        } else {
                          success = await staffProvider.clockIn();
                        }
                        if (success && mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text(staffProvider.isClockedIn ? 'Clocked In ✅' : 'Clocked Out'),
                            backgroundColor: AppColors.card(context),
                            behavior: SnackBarBehavior.floating,
                          ));
                        }
                      },
                      icon: Icon(
                        staffProvider.isClockedIn ? Icons.logout_rounded : Icons.login_rounded,
                        size: 14,
                      ),
                      label: Text(
                        staffProvider.isClockedIn ? 'Clock Out' : 'Clock In',
                        style: const TextStyle(fontSize: 12),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: staffProvider.isClockedIn ? AppColors.error : AppColors.success,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // ─── Collapse Toggle ───
          if (!isSmall)
            InkWell(
              onTap: () => setState(() => _sidebarExpanded = !_sidebarExpanded),
              child: Container(
                padding: EdgeInsets.all(16),
                child: Icon(
                  _sidebarExpanded ? Icons.chevron_left_rounded : Icons.chevron_right_rounded,
                  color: AppColors.textTertiaryDark,
                  size: 22,
                ),
              ),
            ),

          // ─── Sync Indicator ───
          Consumer<AuthProvider>(
            builder: (context, auth, _) {
              if (auth.isSyncing) {
                return Container(
                  padding: EdgeInsets.symmetric(horizontal: _sidebarExpanded ? 16 : 8, vertical: 8),
                  child: Row(
                    mainAxisAlignment: _sidebarExpanded ? MainAxisAlignment.start : MainAxisAlignment.center,
                    children: [
                      SizedBox(width: 14, height: 14,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: AppColors.accent.withValues(alpha: 0.6))),
                      if (_sidebarExpanded) ...[
                        SizedBox(width: 8),
                        Text('Syncing...',
                            style: AppTypography.labelSmall.copyWith(color: AppColors.textTertiaryDark)),
                      ],
                    ],
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),

          // ─── Sync Status Indicator ───
          if (kIsWeb)
            FutureBuilder<int>(
              future: DBHelper.instance.pendingSyncCount(),
              builder: (context, snapshot) {
                final count = snapshot.data ?? 0;
                final isOnline = SupabaseService.instance.isLoggedIn;

                Color dotColor;
                String label;
                if (!isOnline) {
                  dotColor = AppColors.error;
                  label = 'Offline';
                } else if (count > 0) {
                  dotColor = AppColors.warning;
                  label = 'Pending: $count';
                } else {
                  dotColor = AppColors.success;
                  label = 'All Synced';
                }

                return InkWell(
                  onTap: count > 0
                      ? () async {
                          final synced = await SupabaseService.instance.processSyncQueue();
                          if (mounted) {
                            setState(() {}); // Rebuild to refresh count
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(synced > 0
                                    ? '✅ Synced $synced pending items'
                                    : '⚠️ No items synced — will retry'),
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          }
                        }
                      : null,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: _sidebarExpanded ? 16 : 8,
                      vertical: 6,
                    ),
                    child: Row(
                      mainAxisAlignment: _sidebarExpanded
                          ? MainAxisAlignment.start
                          : MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: dotColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        if (_sidebarExpanded) ...[
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              label,
                              style: AppTypography.labelSmall.copyWith(
                                color: AppColors.textTertiaryDark,
                                fontSize: 10,
                              ),
                            ),
                          ),
                          if (count > 0)
                            Icon(Icons.refresh_rounded, size: 14, color: AppColors.warning),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),

          // ─── Session Info + Logout ───
          Consumer2<AuthProvider, StaffProvider>(
            builder: (context, auth, staffProv, _) {
              final isStaffSession = staffProv.isStaffLoggedIn && !staffProv.isAdmin;
              final displayName = isStaffSession
                  ? staffProv.currentStaffName
                  : (auth.userEmail ?? 'Admin');
              final roleLabel = isStaffSession
                  ? '${staffProv.currentStaffRole} • ${staffProv.isClockedIn ? '🟢 Clocked In' : '🔴 Off'}'
                  : 'ADMIN';
              final signOutLabel = isStaffSession ? 'End Shift' : 'Sign Out';

              return InkWell(
                onTap: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      backgroundColor: AppColors.card(context),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      title: Text(signOutLabel, style: AppTypography.h3.copyWith(color: AppColors.textPrimary(context))),
                      content: Text(
                          isStaffSession
                              ? 'This will clock you out and end your shift.'
                              : 'Are you sure you want to sign out?',
                          style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary(context))),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
                          child: Text(signOutLabel, style: const TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true && mounted) {
                    // Cancel sync timer before navigating away
                    _syncTimer?.cancel();

                    // Capture navigator before any async work that may unmount us
                    final navigator = Navigator.of(context);

                    if (isStaffSession) {
                      // Staff logout: clockOut → clear session
                      await staffProv.logoutStaff();
                    }

                    // Navigate FIRST — removes this widget tree so Consumer
                    // dependents are gone before notifyListeners fires.
                    navigator.pushNamedAndRemoveUntil('/login', (_) => false);

                    // Both admin and staff logout keep Supabase session alive.
                    // Staff needs the admin's session to pull data on next login.
                    // Use fullSignOut() only from Settings → "Switch Account".
                    auth.signOut();
                  }
                },
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: _sidebarExpanded ? 16 : 8, vertical: 16),
                  child: Row(
                    mainAxisAlignment: _sidebarExpanded ? MainAxisAlignment.start : MainAxisAlignment.center,
                    children: [
                      Icon(
                        isStaffSession ? Icons.timer_off_rounded : Icons.logout_rounded,
                        size: 20,
                        color: isStaffSession ? AppColors.warning : AppColors.textTertiaryDark,
                      ),
                      if (_sidebarExpanded) ...[
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(displayName,
                                  style: AppTypography.labelSmall.copyWith(color: AppColors.textSecondaryDark),
                                  overflow: TextOverflow.ellipsis),
                              Text(roleLabel,
                                  style: AppTypography.labelSmall.copyWith(
                                      color: isStaffSession ? AppColors.accent : AppColors.textTertiaryDark,
                                      fontSize: 9)),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  final String shortcut;
  final bool adminOnly;
  final String section;
  const _NavItem({required this.icon, required this.label, this.shortcut = '', this.adminOnly = false, this.section = ''});
}
