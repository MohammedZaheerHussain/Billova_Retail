import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
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
import '../../data/local/db_helper.dart';
import '../../data/remote/supabase_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isBackingUp = false;
  String _backupStatus = '';

  // Store Profile controllers
  final _storeNameCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _receiptTermsCtrl = TextEditingController();

  // Category Manager
  final _categoryNameCtrl = TextEditingController();
  bool _requiresSize = false;
  bool _requiresColor = false;
  List<Map<String, dynamic>> _categories = [];

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadCategories();
  }

  @override
  void dispose() {
    _storeNameCtrl.dispose();
    _addressCtrl.dispose();
    _receiptTermsCtrl.dispose();
    _categoryNameCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final db = DBHelper.instance;
    _storeNameCtrl.text = await db.getSetting('store_name') ?? '';
    _addressCtrl.text = await db.getSetting('store_address') ?? '';
    _receiptTermsCtrl.text = await db.getSetting('receipt_terms') ?? 'Thank you for your business!\nGoods once sold cannot be returned.';
    if (mounted) setState(() {});
  }

  Future<void> _loadCategories() async {
    final rows = await DBHelper.instance.getCategories();
    if (mounted) setState(() => _categories = rows);
  }

  Future<void> _saveSettings() async {
    final db = DBHelper.instance;
    await db.setSetting('store_name', _storeNameCtrl.text.trim());
    await db.setSetting('store_address', _addressCtrl.text.trim());
    await db.setSetting('receipt_terms', _receiptTermsCtrl.text.trim());
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Settings saved'),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));
    }
  }

  Future<void> _addCategory() async {
    final name = _categoryNameCtrl.text.trim();
    if (name.isEmpty) return;
    await DBHelper.instance.insertCategory({
      'id': const Uuid().v4(),
      'name': name,
      'requires_size': _requiresSize ? 1 : 0,
      'requires_color': _requiresColor ? 1 : 0,
      'created_at': DateTime.now().toIso8601String(),
    });
    _categoryNameCtrl.clear();
    setState(() { _requiresSize = false; _requiresColor = false; });
    await _loadCategories();
  }

  Future<void> _deleteCategory(String id) async {
    await DBHelper.instance.deleteCategory(id);
    await _loadCategories();
  }

  Future<void> _performManualBackup() async {
    setState(() { _isBackingUp = true; _backupStatus = 'Syncing items...'; });
    try {
      final supabase = SupabaseService.instance;
      final inventory = context.read<InventoryProvider>();
      for (final item in inventory.items) {
        await supabase.syncRecord('items', item.id, 'insert', item.toMap());
      }
      if (!mounted) return;
      setState(() => _backupStatus = 'Syncing sales...');
      final sales = context.read<SalesProvider>();
      for (final sale in sales.sales) {
        await supabase.syncRecord('sales', sale.id, 'insert', sale.toMap());
      }
      if (!mounted) return;
      setState(() => _backupStatus = 'Syncing vendors...');
      final vendors = context.read<VendorProvider>();
      for (final vendor in vendors.vendors) {
        await supabase.syncRecord('vendors', vendor.id, 'insert', vendor.toMap());
      }
      if (!mounted) return;
      setState(() => _backupStatus = 'Syncing purchases...');
      final purchases = context.read<PurchaseProvider>();
      for (final purchase in purchases.purchases) {
        await supabase.syncRecord('purchases', purchase.id, 'insert', purchase.toMap());
      }
      if (!mounted) return;
      setState(() => _backupStatus = 'Syncing staff & customers...');
      final staffProvider = context.read<StaffProvider>();
      for (final member in staffProvider.staff) {
        await supabase.syncRecord('staff', member.id, 'insert', member.toMap());
      }
      for (final record in staffProvider.todayAttendance) {
        await supabase.syncRecord('attendance', record.id, 'insert', record.toMap());
      }
      final customerProvider = context.read<CustomerProvider>();
      for (final customer in customerProvider.customers) {
        await supabase.syncRecord('customers', customer.id, 'insert', customer.toMap());
      }
      if (!mounted) return;
      setState(() => _backupStatus = 'Syncing expenses...');
      final expenses = context.read<ExpenseProvider>();
      for (final exp in expenses.expenses) {
        await supabase.syncRecord('expenses', exp.id, 'insert', exp.toMap());
      }
      await supabase.processSyncQueue();
      if (!mounted) return;
      setState(() { _backupStatus = 'Backup complete!'; _isBackingUp = false; });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('All data backed up to cloud successfully!'),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));
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
            Text('Settings & Memory Backup',
                style: AppTypography.h1.copyWith(
                  color: isDark ? AppColors.textPrimary(context) : AppColors.textPrimaryLight,
                )),
            const SizedBox(height: 24),

            // ─── Store Profile ───
            _buildSection(isDark, 'Store Profile', Icons.storefront_rounded, [
              _buildTextField('Store Name', _storeNameCtrl, isDark),
              _buildTextField('Address', _addressCtrl, isDark),
              _buildLabel('Receipt Terms & Conditions', isDark),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: TextField(
                  controller: _receiptTermsCtrl,
                  maxLines: 3,
                  style: AppTypography.bodyMedium.copyWith(
                    color: isDark ? AppColors.textPrimary(context) : AppColors.textPrimaryLight),
                  decoration: _inputDeco(isDark, 'e.g. Thank you for your business!'),
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: SizedBox(
                  width: double.infinity, height: 48,
                  child: ElevatedButton(
                    onPressed: _saveSettings,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text('Save Settings', style: AppTypography.button.copyWith(color: Colors.white)),
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 16),

            // ─── Category Manager ───
            _buildSection(isDark, 'Category Manager', Icons.category_rounded, [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: TextField(
                  controller: _categoryNameCtrl,
                  style: AppTypography.bodyMedium.copyWith(
                    color: isDark ? AppColors.textPrimary(context) : AppColors.textPrimaryLight),
                  decoration: _inputDeco(isDark, 'Category Name (e.g. Wallets)'),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(children: [
                  Checkbox(value: _requiresSize, onChanged: (v) => setState(() => _requiresSize = v!),
                    activeColor: AppColors.primary),
                  Text('Requires Size?', style: AppTypography.bodySmall.copyWith(
                    color: isDark ? AppColors.textSecondary(context) : AppColors.textSecondaryLight)),
                  const SizedBox(width: 20),
                  Checkbox(value: _requiresColor, onChanged: (v) => setState(() => _requiresColor = v!),
                    activeColor: AppColors.primary),
                  Text('Requires Color?', style: AppTypography.bodySmall.copyWith(
                    color: isDark ? AppColors.textSecondary(context) : AppColors.textSecondaryLight)),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                child: SizedBox(
                  width: double.infinity, height: 48,
                  child: ElevatedButton(
                    onPressed: _addCategory,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDark ? AppColors.card(context) : Colors.black87,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text('Add Category', style: AppTypography.button.copyWith(color: Colors.white)),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // List existing categories
              ..._categories.map((cat) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
                child: Row(children: [
                  Expanded(
                    child: RichText(text: TextSpan(
                      style: AppTypography.bodyMedium.copyWith(
                        color: isDark ? AppColors.textPrimary(context) : AppColors.textPrimaryLight),
                      children: [
                        TextSpan(text: cat['name'] as String, style: const TextStyle(fontWeight: FontWeight.w600)),
                        TextSpan(
                          text: '  ${[
                            if (cat['requires_size'] == 1) 'Size',
                            if (cat['requires_color'] == 1) 'Color',
                          ].join(', ')}',
                          style: TextStyle(fontSize: 11, color: AppColors.accent)),
                      ],
                    )),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, size: 18, color: AppColors.error),
                    onPressed: () => _deleteCategory(cat['id'] as String),
                  ),
                ]),
              )),
              const SizedBox(height: 8),
            ]),
            const SizedBox(height: 16),

            // ─── Appearance ───
            _buildSection(isDark, 'Appearance', Icons.palette_rounded, [
              _SettingsTile(
                icon: themeProvider.isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                title: 'Dark Mode',
                subtitle: themeProvider.isDark ? 'Currently using dark theme' : 'Currently using light theme',
                isDark: isDark,
                trailing: Switch.adaptive(
                  value: themeProvider.isDark,
                  onChanged: (_) => themeProvider.toggleTheme(),
                  activeColor: AppColors.primary,
                  activeTrackColor: AppColors.primary.withValues(alpha: 0.4),
                ),
              ),
            ]),
            const SizedBox(height: 16),

            // ─── Bulletproof Data Security ───
            _buildSection(isDark, 'Bulletproof Data Security', Icons.shield_rounded, [
              // Cloud backup
              _SettingsTile(
                icon: Icons.cloud_sync_rounded,
                title: 'Auto Sync',
                subtitle: auth.isSyncing ? 'Syncing data with Supabase...' : 'All data auto-syncs to cloud',
                isDark: isDark,
                trailing: auth.isSyncing
                    ? const SizedBox(width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent))
                    : const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 22),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('1. Download Backup File', style: AppTypography.labelLarge.copyWith(
                        color: isDark ? AppColors.textPrimary(context) : AppColors.textPrimaryLight, fontSize: 13)),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity, height: 44,
                        child: ElevatedButton.icon(
                          onPressed: _isBackingUp ? null : _performManualBackup,
                          icon: _isBackingUp
                              ? const SizedBox(width: 16, height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.cloud_download_rounded, size: 18),
                          label: Text(_isBackingUp ? 'Backing up...' : 'DOWNLOAD DATA FILE',
                            style: AppTypography.button.copyWith(color: Colors.white, fontSize: 12)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.5),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                      if (_backupStatus.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(_backupStatus, style: AppTypography.labelSmall.copyWith(
                          color: _backupStatus.contains('complete') ? AppColors.success
                              : _backupStatus.contains('failed') ? AppColors.error : AppColors.accent),
                          textAlign: TextAlign.center),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.error.withValues(alpha: 0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('2. Restore Database', style: AppTypography.labelLarge.copyWith(
                        color: isDark ? AppColors.textPrimary(context) : AppColors.textPrimaryLight, fontSize: 13)),
                      Row(children: [
                        Icon(Icons.warning_rounded, size: 14, color: AppColors.warning),
                        const SizedBox(width: 4),
                        Text('WARNING: THIS WILL OVERWRITE CURRENT DATA', style: AppTypography.labelSmall.copyWith(
                          color: AppColors.warning, fontSize: 9, fontWeight: FontWeight.w700)),
                      ]),
                      const SizedBox(height: 10),
                      Row(children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: AppColors.accent.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8)),
                          child: Text('Choose File', style: AppTypography.labelSmall.copyWith(
                            color: AppColors.accent, fontWeight: FontWeight.w600)),
                        ),
                        const SizedBox(width: 12),
                        Text('No file chosen', style: AppTypography.bodySmall.copyWith(
                          color: isDark ? AppColors.textTertiary(context) : AppColors.textTertiaryLight)),
                      ]),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity, height: 44,
                        child: ElevatedButton.icon(
                          onPressed: null, // Restore not yet implemented
                          icon: const Icon(Icons.cloud_upload_rounded, size: 18),
                          label: Text('RESTORE DATA', style: AppTypography.button.copyWith(
                            color: Colors.white, fontSize: 12)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.error,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: AppColors.error.withValues(alpha: 0.4),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 16),

            // ─── Account ───
            _buildSection(isDark, 'Account', Icons.person_rounded, [
              _SettingsTile(
                icon: Icons.email_rounded,
                title: 'Email',
                subtitle: auth.userEmail ?? 'Not logged in',
                isDark: isDark,
              ),
            ]),
            const SizedBox(height: 16),

            // ─── About ───
            _buildSection(isDark, 'About', Icons.info_rounded, [
              _SettingsTile(
                icon: Icons.storefront_rounded,
                title: 'SKYWALK Billing',
                subtitle: 'Version 2.0.0 - Built for commercial retail',
                isDark: isDark,
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppColors.primary.withValues(alpha: 0.05), AppColors.accent.withValues(alpha: 0.05)],
                      begin: Alignment.topLeft, end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: isDark ? AppColors.cardBorder(context).withValues(alpha: 0.5) : AppColors.cardBorderLight),
                  ),
                  child: Column(children: [
                    Container(
                      width: 48, height: 48,
                      decoration: BoxDecoration(gradient: AppColors.primaryGradient, borderRadius: BorderRadius.circular(14)),
                      child: const Icon(Icons.receipt_long_rounded, color: Colors.white, size: 24),
                    ),
                    const SizedBox(height: 12),
                    ShaderMask(
                      shaderCallback: (bounds) => AppColors.primaryGradient.createShader(bounds),
                      child: Text('SKYWALK', style: AppTypography.h3.copyWith(
                        color: Colors.white, letterSpacing: 4, fontWeight: FontWeight.w800)),
                    ),
                    const SizedBox(height: 4),
                    Text('Billing Software', style: AppTypography.bodySmall.copyWith(
                      color: isDark ? AppColors.textSecondary(context) : AppColors.textSecondaryLight)),
                    const SizedBox(height: 16),
                    Container(width: 40, height: 1, color: (isDark ? AppColors.cardBorder(context) : AppColors.cardBorderLight).withValues(alpha: 0.5)),
                    const SizedBox(height: 14),
                    Text('Powered & Developed by', style: AppTypography.labelSmall.copyWith(
                      color: isDark ? AppColors.textTertiary(context) : AppColors.textTertiaryLight, fontSize: 10)),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.asset('assets/images/barakah_logo.png', width: 44, height: 44, fit: BoxFit.contain),
                    ),
                    const SizedBox(height: 6),
                    Text('Barakah Tech', style: AppTypography.h4.copyWith(
                      color: AppColors.primary, fontWeight: FontWeight.w700, letterSpacing: 1)),
                  ]),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  // ─── Helpers ───

  Widget _buildSection(bool isDark, String title, IconData icon, List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.card(context) : AppColors.cardLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppColors.cardBorder(context) : AppColors.cardBorderLight),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Row(children: [
            Icon(icon, size: 18, color: AppColors.primary),
            const SizedBox(width: 8),
            Text(title, style: AppTypography.labelLarge.copyWith(
              color: isDark ? AppColors.textPrimary(context) : AppColors.textPrimaryLight, fontSize: 13, letterSpacing: 0.5)),
          ]),
        ),
        ...children,
        const SizedBox(height: 4),
      ]),
    );
  }

  Widget _buildTextField(String label, TextEditingController ctrl, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: AppTypography.labelSmall.copyWith(
          color: isDark ? AppColors.textSecondary(context) : AppColors.textSecondaryLight, fontSize: 11)),
        const SizedBox(height: 4),
        TextField(
          controller: ctrl,
          style: AppTypography.bodyMedium.copyWith(
            color: isDark ? AppColors.textPrimary(context) : AppColors.textPrimaryLight),
          decoration: _inputDeco(isDark, label),
        ),
      ]),
    );
  }

  Widget _buildLabel(String label, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
      child: Text(label, style: AppTypography.labelSmall.copyWith(
        color: isDark ? AppColors.textSecondary(context) : AppColors.textSecondaryLight, fontSize: 11)),
    );
  }

  InputDecoration _inputDeco(bool isDark, String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: AppTypography.bodyMedium.copyWith(
        color: (isDark ? AppColors.textTertiary(context) : AppColors.textTertiaryLight).withValues(alpha: 0.5)),
      filled: true,
      fillColor: isDark ? AppColors.sidebarDark.withValues(alpha: 0.5) : Colors.grey.shade50,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: isDark ? AppColors.cardBorder(context) : AppColors.cardBorderLight)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: isDark ? AppColors.cardBorder(context) : AppColors.cardBorderLight)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: AppColors.primary, width: 1.5)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    );
  }
}

// ─── Individual Settings Tile (reused) ───
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
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 20, color: AppColors.primary),
        ),
        title: Text(title, style: AppTypography.bodyMedium.copyWith(
          color: isDark ? AppColors.textPrimary(context) : AppColors.textPrimaryLight, fontWeight: FontWeight.w500)),
        subtitle: Text(subtitle, style: AppTypography.labelSmall.copyWith(
          color: isDark ? AppColors.textTertiary(context) : AppColors.textTertiaryLight)),
        trailing: trailing,
      ),
    );
  }
}
