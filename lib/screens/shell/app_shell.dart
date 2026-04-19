import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
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
import '../../data/remote/supabase_service.dart';
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

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _selectedIndex = 0;
  bool _sidebarExpanded = true;
  final FocusNode _focusNode = FocusNode();

  // F-key → absolute nav index mapping
  static final Map<LogicalKeyboardKey, int> _shortcutMap = {
    LogicalKeyboardKey.f1: 0,
    LogicalKeyboardKey.f2: 1,
    LogicalKeyboardKey.f3: 2,
    LogicalKeyboardKey.f4: 3,
    LogicalKeyboardKey.f5: 4,
    LogicalKeyboardKey.f6: 5,
    LogicalKeyboardKey.f7: 6,
    LogicalKeyboardKey.f8: 7,
    LogicalKeyboardKey.f9: 8,
    LogicalKeyboardKey.f10: 9,
    LogicalKeyboardKey.f11: 10,
  };

  // All nav items — filtered dynamically by role
  static const List<_NavItem> _allNavItems = [
    _NavItem(icon: Icons.dashboard_rounded, label: 'Dashboard', shortcut: 'F1', adminOnly: true),
    _NavItem(icon: Icons.account_balance_wallet_rounded, label: 'Cash Till', shortcut: 'F2', adminOnly: true),
    _NavItem(icon: Icons.inventory_2_rounded, label: 'Inventory', shortcut: 'F3', adminOnly: false),
    _NavItem(icon: Icons.point_of_sale_rounded, label: 'Sales Terminal', shortcut: 'F4', adminOnly: false),
    _NavItem(icon: Icons.local_shipping_rounded, label: 'Purchases (In)', shortcut: 'F5', adminOnly: true),
    _NavItem(icon: Icons.store_rounded, label: 'Vendors', shortcut: 'F6', adminOnly: true),
    _NavItem(icon: Icons.people_outline_rounded, label: 'Customers', shortcut: 'F7', adminOnly: false),
    _NavItem(icon: Icons.money_off_rounded, label: 'Expenses', shortcut: 'F8', adminOnly: true),
    _NavItem(icon: Icons.history_rounded, label: 'Bill History', shortcut: 'F9', adminOnly: false),
    _NavItem(icon: Icons.badge_rounded, label: 'Staff & Attendance', shortcut: 'F10', adminOnly: true),
    _NavItem(icon: Icons.settings_rounded, label: 'Settings', shortcut: 'F11', adminOnly: true),
  ];

  static const List<Widget> _allScreens = [
    DashboardScreen(),
    CashTillScreen(),
    InventoryScreen(),
    SalesTerminalScreen(),
    PurchaseScreen(),
    VendorScreen(),
    CustomerScreen(),
    ExpensesScreen(),
    BillHistoryScreen(),
    StaffScreen(),
    SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAllData();
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
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

    // ─── STEP 1: Pull from Supabase FIRST (cloud → local) ───
    // On web, _WebDB is in-memory — starts empty every restart.
    // We MUST pull cloud data before providers try to read local DB.
    try {
      final supabase = SupabaseService.instance;
      if (supabase.isLoggedIn) {
        debugPrint('📥 Pulling data from Supabase...');
        await supabase.pullAllData();
        debugPrint('📥 Pull complete — now loading providers');
      }
    } catch (e) {
      debugPrint('⚠️ Supabase pull failed (will use local data): $e');
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

    await Future.wait([
      inventory.loadItems(),
      sales.loadSales(),
      expenses.loadExpenses(),
      cashTill.loadToday(),
      staffProvider.loadStaff(),
      staffProvider.loadTodayAttendance(),
      customerProvider.loadCustomers(),
      vendorProvider.loadVendors(),
      purchaseProvider.loadPurchases(),
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
                  color: (isDark ? AppColors.cardBorderDark : AppColors.cardBorderLight).withValues(alpha: 0.5),
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
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      width: sidebarWidth,
      decoration: BoxDecoration(
        color: isDark ? AppColors.sidebarDark : AppColors.sidebarLight,
        border: Border(
          right: BorderSide(
            color: (isDark ? AppColors.cardBorderDark : AppColors.cardBorderLight).withValues(alpha: 0.3),
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
                  child: const Icon(Icons.receipt_long_rounded, size: 22, color: Colors.white),
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

          // ─── Nav Items ───
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              itemCount: navItems.length,
              itemBuilder: (context, index) {
                final item = navItems[index];
                final isSelected = index == _selectedIndex.clamp(0, navItems.length - 1);

                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => setState(() => _selectedIndex = index),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: EdgeInsets.symmetric(
                          horizontal: _sidebarExpanded ? 14 : 0, vertical: 12),
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
                            Icon(item.icon, size: 22,
                                color: isSelected ? AppColors.accent
                                    : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight)),
                            if (_sidebarExpanded) ...[
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(item.label,
                                    style: AppTypography.bodyMedium.copyWith(
                                      color: isSelected
                                          ? (isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight)
                                          : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
                                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                                    ),
                                    overflow: TextOverflow.ellipsis),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? AppColors.accent.withValues(alpha: 0.2)
                                      : (isDark ? AppColors.cardBorderDark : AppColors.cardBorderLight).withValues(alpha: 0.5),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(item.shortcut,
                                    style: AppTypography.monoSmall.copyWith(
                                      color: isSelected ? AppColors.accent
                                          : (isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight),
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
                        child: const Icon(Icons.person_rounded, size: 16, color: AppColors.accent),
                      ),
                      const SizedBox(width: 8),
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
                            backgroundColor: AppColors.cardDark,
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
                padding: const EdgeInsets.all(16),
                child: Icon(
                  _sidebarExpanded ? Icons.chevron_left_rounded : Icons.chevron_right_rounded,
                  color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight,
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
                        const SizedBox(width: 8),
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
                      backgroundColor: AppColors.cardDark,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      title: Text(signOutLabel, style: AppTypography.h3.copyWith(color: AppColors.textPrimaryDark)),
                      content: Text(
                          isStaffSession
                              ? 'This will clock you out and end your shift.'
                              : 'Are you sure you want to sign out?',
                          style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondaryDark)),
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
                    if (isStaffSession) {
                      // Staff logout: clockOut → clear session → back to login
                      await staffProv.logoutStaff();
                      if (mounted) {
                        await auth.signOut();
                        Navigator.of(context).pushReplacementNamed('/login');
                      }
                    } else {
                      // Admin logout: full Supabase sign out
                      await auth.signOut();
                      if (mounted) Navigator.of(context).pushReplacementNamed('/login');
                    }
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
                        const SizedBox(width: 12),
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
  const _NavItem({required this.icon, required this.label, this.shortcut = '', this.adminOnly = false});
}
