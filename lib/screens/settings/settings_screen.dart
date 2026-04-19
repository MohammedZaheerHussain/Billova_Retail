import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../providers/theme_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/inventory_provider.dart';
import '../../providers/sales_provider.dart';
import '../../providers/expense_provider.dart';
import '../../providers/vendor_provider.dart';
import '../../providers/purchase_provider.dart';
import '../../providers/staff_provider.dart';
import '../../providers/customer_provider.dart';
import '../../data/remote/supabase_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isBackingUp = false;
  String _backupStatus = '';

  Future<void> _performManualBackup() async {
    setState(() {
      _isBackingUp = true;
      _backupStatus = 'Syncing items...';
    });

    try {
      final supabase = SupabaseService.instance;

      // 1. Sync all inventory items
      final inventory = context.read<InventoryProvider>();
      for (final item in inventory.items) {
        await supabase.syncRecord('items', item.id, 'insert', item.toMap());
      }
      if (!mounted) return;
      setState(() => _backupStatus = 'Syncing sales...');

      // 2. Sync all sales
      final sales = context.read<SalesProvider>();
      for (final sale in sales.sales) {
        await supabase.syncRecord('sales', sale.id, 'insert', sale.toMap());
      }
      if (!mounted) return;
      setState(() => _backupStatus = 'Syncing vendors...');

      // 3. Sync all vendors
      final vendors = context.read<VendorProvider>();
      for (final vendor in vendors.vendors) {
        await supabase.syncRecord('vendors', vendor.id, 'insert', vendor.toMap());
      }
      if (!mounted) return;
      setState(() => _backupStatus = 'Syncing purchases...');

      // 4. Sync all purchases
      final purchases = context.read<PurchaseProvider>();
      for (final purchase in purchases.purchases) {
        await supabase.syncRecord('purchases', purchase.id, 'insert', purchase.toMap());
      }
      if (!mounted) return;
      setState(() => _backupStatus = 'Syncing staff...');

      // 5. Sync all staff
      final staffProvider = context.read<StaffProvider>();
      for (final member in staffProvider.staff) {
        await supabase.syncRecord('staff', member.id, 'insert', member.toMap());
      }
      if (!mounted) return;
      setState(() => _backupStatus = 'Syncing attendance...');

      // 6. Sync today's attendance
      for (final record in staffProvider.todayAttendance) {
        await supabase.syncRecord('attendance', record.id, 'insert', record.toMap());
      }
      if (!mounted) return;
      setState(() => _backupStatus = 'Syncing customers...');

      // 7. Sync all customers
      final customerProvider = context.read<CustomerProvider>();
      for (final customer in customerProvider.customers) {
        await supabase.syncRecord('customers', customer.id, 'insert', customer.toMap());
      }
      if (!mounted) return;
      setState(() => _backupStatus = 'Syncing expenses...');

      // 8. Sync all expenses
      final expenses = context.read<ExpenseProvider>();
      for (final exp in expenses.expenses) {
        await supabase.syncRecord('expenses', exp.id, 'insert', exp.toMap());
      }
      if (!mounted) return;
      setState(() => _backupStatus = 'Processing sync queue...');

      // 9. Process any remaining sync queue
      await supabase.processSyncQueue();

      if (!mounted) return;
      setState(() {
        _backupStatus = 'Backup complete! ✅';
        _isBackingUp = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('All data backed up to cloud successfully!'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );

      // Clear status after 3 seconds
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) setState(() => _backupStatus = '');
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _backupStatus = 'Backup failed: ${e.toString().split(':').last.trim()}';
        _isBackingUp = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final themeProvider = context.watch<ThemeProvider>();
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Settings',
                style: AppTypography.h1.copyWith(
                  color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                )),
            const SizedBox(height: 24),

            // ─── Appearance ───
            _SettingsSection(
              title: 'Appearance',
              icon: Icons.palette_rounded,
              isDark: isDark,
              children: [
                _SettingsTile(
                  icon: themeProvider.isDark
                      ? Icons.dark_mode_rounded
                      : Icons.light_mode_rounded,
                  title: 'Dark Mode',
                  subtitle: themeProvider.isDark
                      ? 'Currently using dark theme'
                      : 'Currently using light theme',
                  isDark: isDark,
                  trailing: Switch.adaptive(
                    value: themeProvider.isDark,
                    onChanged: (_) => themeProvider.toggleTheme(),
                    activeColor: AppColors.primary,
                    activeTrackColor: AppColors.primary.withValues(alpha: 0.4),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // ─── Data & Cloud Backup ───
            _SettingsSection(
              title: 'Data & Cloud Backup',
              icon: Icons.cloud_rounded,
              isDark: isDark,
              children: [
                _SettingsTile(
                  icon: Icons.cloud_sync_rounded,
                  title: 'Auto Sync',
                  subtitle: auth.isSyncing
                      ? 'Syncing data with Supabase...'
                      : 'All data auto-syncs to cloud',
                  isDark: isDark,
                  trailing: auth.isSyncing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.accent,
                          ),
                        )
                      : const Icon(
                          Icons.check_circle_rounded,
                          color: AppColors.success,
                          size: 22,
                        ),
                ),

                // Manual Backup Button
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        height: 48,
                        child: ElevatedButton.icon(
                          onPressed: _isBackingUp ? null : _performManualBackup,
                          icon: _isBackingUp
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.backup_rounded, size: 20),
                          label: Text(
                            _isBackingUp ? 'Backing up...' : 'Manual Backup to Cloud',
                            style: AppTypography.button.copyWith(color: Colors.white),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.5),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      if (_backupStatus.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          _backupStatus,
                          style: AppTypography.labelSmall.copyWith(
                            color: _backupStatus.contains('✅')
                                ? AppColors.success
                                : _backupStatus.contains('failed')
                                    ? AppColors.error
                                    : AppColors.accent,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // ─── Account ───
            _SettingsSection(
              title: 'Account',
              icon: Icons.person_rounded,
              isDark: isDark,
              children: [
                _SettingsTile(
                  icon: Icons.email_rounded,
                  title: 'Email',
                  subtitle: auth.userEmail ?? 'Not logged in',
                  isDark: isDark,
                ),
              ],
            ),

            const SizedBox(height: 16),

            // ─── Billing (Coming Soon) ───
            _SettingsSection(
              title: 'Billing & Printer',
              icon: Icons.print_rounded,
              isDark: isDark,
              children: [
                _SettingsTile(
                  icon: Icons.print_rounded,
                  title: 'Printer Settings',
                  subtitle: 'Coming soon — Configure bill printer',
                  isDark: isDark,
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.warningBg,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Soon',
                      style: AppTypography.labelSmall.copyWith(
                        color: AppColors.warning,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                _SettingsTile(
                  icon: Icons.receipt_long_rounded,
                  title: 'Invoice Format',
                  subtitle: 'Coming soon — Customize bill layout',
                  isDark: isDark,
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.warningBg,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Soon',
                      style: AppTypography.labelSmall.copyWith(
                        color: AppColors.warning,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // ─── About ───
            _SettingsSection(
              title: 'About',
              icon: Icons.info_rounded,
              isDark: isDark,
              children: [
                _SettingsTile(
                  icon: Icons.storefront_rounded,
                  title: 'SKYWALK Billing',
                  subtitle: 'Version 1.0.0 • Built for shoe retail',
                  isDark: isDark,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Settings Section Widget ───
class _SettingsSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool isDark;
  final List<Widget> children;

  const _SettingsSection({
    required this.title,
    required this.icon,
    required this.isDark,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : AppColors.cardLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.cardBorderDark : AppColors.cardBorderLight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(
              children: [
                Icon(icon, size: 18, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: AppTypography.labelLarge.copyWith(
                    color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                    fontSize: 13,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          ...children,
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

// ─── Individual Settings Tile ───
class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isDark;
  final Widget? trailing;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isDark,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 8),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 20, color: AppColors.primary),
        ),
        title: Text(
          title,
          style: AppTypography.bodyMedium.copyWith(
            color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: AppTypography.labelSmall.copyWith(
            color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight,
          ),
        ),
        trailing: trailing,
      ),
    );
  }
}
