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
import '../../providers/cash_till_provider.dart';
import '../../providers/loyalty_settings_provider.dart';
import '../../providers/category_provider.dart';
import '../../data/models/category_model.dart';
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

  // Printer Config
  final _shopNameCtrl = TextEditingController();
  final _shopPhoneCtrl = TextEditingController();
  final _shopAddressCtrl = TextEditingController();
  final _shopLogoCtrl = TextEditingController();
  final _receiptFooterCtrl = TextEditingController();
  bool _autoPrint = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    // Load categories via provider
    Future.microtask(() => context.read<CategoryProvider>().loadCategories());
  }

  @override
  void dispose() {
    _storeNameCtrl.dispose();
    _addressCtrl.dispose();
    _receiptTermsCtrl.dispose();
    _categoryNameCtrl.dispose();
    _shopNameCtrl.dispose();
    _shopPhoneCtrl.dispose();
    _shopAddressCtrl.dispose();
    _shopLogoCtrl.dispose();
    _receiptFooterCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final db = DBHelper.instance;
    _storeNameCtrl.text = await db.getSetting('store_name') ?? '';
    _addressCtrl.text = await db.getSetting('store_address') ?? '';
    _receiptTermsCtrl.text = await db.getSetting('receipt_terms') ?? 'Thank you for your business!\nGoods once sold cannot be returned.';
    // Printer settings
    _shopNameCtrl.text = await db.getSetting('shop_name') ?? '';
    _shopPhoneCtrl.text = await db.getSetting('shop_phone') ?? '';
    _shopAddressCtrl.text = await db.getSetting('shop_address') ?? '';
    _shopLogoCtrl.text = await db.getSetting('shop_logo') ?? '';
    _receiptFooterCtrl.text = await db.getSetting('receipt_footer') ?? 'Thank you! Visit again';
    _autoPrint = (await db.getSetting('auto_print') ?? 'false') == 'true';
    if (mounted) setState(() {});
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

  void _showToast(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: isError ? AppColors.error : AppColors.success,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  Future<void> _addCategory() async {
    final name = _categoryNameCtrl.text.trim();
    if (name.isEmpty) {
      _showToast('Category name cannot be empty', isError: true);
      return;
    }
    final provider = context.read<CategoryProvider>();
    final success = await provider.addCategory(
      name: name,
      requiresSize: _requiresSize,
      requiresColor: _requiresColor,
    );
    if (success) {
      _categoryNameCtrl.clear();
      setState(() { _requiresSize = false; _requiresColor = false; });
      _showToast('Category "$name" added successfully');
    } else {
      _showToast(provider.error, isError: true);
    }
  }

  Future<void> _deleteCategory(CategoryModel cat) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Delete Category', style: AppTypography.h3.copyWith(color: AppColors.textPrimary(context))),
        content: Text('Delete "${cat.name}"? Items using this category won\'t be affected.',
          style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary(context))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final success = await context.read<CategoryProvider>().deleteCategory(cat.id);
    if (success) {
      _showToast('Category "${cat.name}" deleted');
    }
  }

  Future<void> _showEditDialog(CategoryModel cat) async {
    final nameCtrl = TextEditingController(text: cat.name);
    bool reqSize = cat.requiresSize;
    bool reqColor = cat.requiresColor;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final isDark = Theme.of(ctx).brightness == Brightness.dark;
          return AlertDialog(
            backgroundColor: AppColors.card(context),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(children: [
              Icon(Icons.edit_rounded, color: AppColors.accent, size: 20),
              const SizedBox(width: 8),
              Text('Edit Category', style: AppTypography.h3.copyWith(color: AppColors.textPrimary(context))),
            ]),
            content: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(
                controller: nameCtrl,
                style: AppTypography.bodyMedium.copyWith(color: AppColors.textPrimary(context)),
                decoration: InputDecoration(
                  labelText: 'Category Name',
                  labelStyle: TextStyle(color: AppColors.textSecondary(context)),
                  filled: true,
                  fillColor: isDark ? AppColors.sidebarDark.withValues(alpha: 0.5) : Colors.grey.shade50,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: AppColors.cardBorder(context))),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: AppColors.primary, width: 1.5)),
                ),
              ),
              const SizedBox(height: 12),
              Row(children: [
                Checkbox(value: reqSize, activeColor: AppColors.primary,
                  onChanged: (v) => setDialogState(() => reqSize = v!)),
                Text('Requires Size?', style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary(context))),
                const SizedBox(width: 16),
                Checkbox(value: reqColor, activeColor: AppColors.primary,
                  onChanged: (v) => setDialogState(() => reqColor = v!)),
                Text('Requires Color?', style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary(context))),
              ]),
            ]),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                child: const Text('Save', style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        },
      ),
    );
    final editedName = nameCtrl.text;
    nameCtrl.dispose();

    if (result != true) return;
    final success = await context.read<CategoryProvider>().updateCategory(cat,
      name: editedName, requiresSize: reqSize, requiresColor: reqColor);
    if (success) {
      _showToast('Category updated');
    } else {
      _showToast(context.read<CategoryProvider>().error, isError: true);
    }
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
      if (!mounted) return;
      setState(() => _backupStatus = 'Syncing cash till...');
      final cashTill = context.read<CashTillProvider>();
      if (cashTill.today != null) {
        await supabase.syncRecord('cash_till', cashTill.today!.id, 'insert', cashTill.today!.toMap());
      }
      if (!mounted) return;
      setState(() => _backupStatus = 'Syncing categories...');
      final catProvider = context.read<CategoryProvider>();
      for (final cat in catProvider.categories) {
        await supabase.syncRecord('categories', cat.id, 'insert', cat.toMap());
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

            // ─── Thermal Printer Config ───
            _buildSection(isDark, 'Thermal Printer (80mm)', Icons.print_rounded, [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                child: Row(children: [
                  Expanded(child: Text('Auto-Print on Sale', style: AppTypography.bodyMedium.copyWith(
                      color: isDark ? AppColors.textPrimary(context) : AppColors.textPrimaryLight))),
                  Switch(
                    value: _autoPrint,
                    activeColor: AppColors.success,
                    onChanged: (v) async {
                      setState(() => _autoPrint = v);
                      await DBHelper.instance.setSetting('auto_print', v.toString());
                    },
                  ),
                ]),
              ),
              _buildTextField('Shop Name (on receipt)', _shopNameCtrl, isDark),
              _buildTextField('Shop Address', _shopAddressCtrl, isDark),
              _buildTextField('Shop Phone', _shopPhoneCtrl, isDark),
              _buildTextField('Logo URL (optional)', _shopLogoCtrl, isDark),
              _buildTextField('Receipt Footer', _receiptFooterCtrl, isDark),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: SizedBox(
                  width: double.infinity, height: 48,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final db = DBHelper.instance;
                      await db.setSetting('shop_name', _shopNameCtrl.text.trim());
                      await db.setSetting('shop_address', _shopAddressCtrl.text.trim());
                      await db.setSetting('shop_phone', _shopPhoneCtrl.text.trim());
                      await db.setSetting('shop_logo', _shopLogoCtrl.text.trim());
                      await db.setSetting('receipt_footer', _receiptFooterCtrl.text.trim());
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: const Text('Printer settings saved'),
                          backgroundColor: AppColors.success,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ));
                      }
                    },
                    icon: const Icon(Icons.save_rounded, size: 18),
                    label: Text('Save Printer Settings', style: AppTypography.button.copyWith(color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 16),
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
                  child: ElevatedButton.icon(
                    onPressed: _addCategory,
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: Text('Add Category', style: AppTypography.button.copyWith(color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Category list from provider
              Consumer<CategoryProvider>(
                builder: (context, catProvider, _) {
                  if (catProvider.categories.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.03),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.cardBorder(context).withValues(alpha: 0.5)),
                        ),
                        child: Column(children: [
                          Icon(Icons.category_outlined, size: 36, color: AppColors.textTertiary(context).withValues(alpha: 0.4)),
                          const SizedBox(height: 8),
                          Text('No categories yet', style: AppTypography.bodyMedium.copyWith(
                            color: AppColors.textTertiary(context))),
                          const SizedBox(height: 4),
                          Text('Add your first category above', style: AppTypography.labelSmall.copyWith(
                            color: AppColors.textTertiary(context).withValues(alpha: 0.7))),
                        ]),
                      ),
                    );
                  }
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${catProvider.categories.length} Categories', style: AppTypography.labelSmall.copyWith(
                          color: AppColors.textTertiary(context), fontWeight: FontWeight.w600, letterSpacing: 0.5)),
                        const SizedBox(height: 8),
                        ...catProvider.categories.map((cat) => Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.cardBorder(context).withValues(alpha: 0.5)),
                          ),
                          child: Row(children: [
                            Container(
                              width: 32, height: 32,
                              decoration: BoxDecoration(
                                gradient: AppColors.primaryGradient,
                                borderRadius: BorderRadius.circular(8)),
                              child: Center(child: Text(
                                cat.name.isNotEmpty ? cat.name[0].toUpperCase() : '?',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14))),
                            ),
                            const SizedBox(width: 12),
                            Expanded(child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(cat.name, style: AppTypography.bodyMedium.copyWith(
                                  color: AppColors.textPrimary(context), fontWeight: FontWeight.w600)),
                                const SizedBox(height: 2),
                                Row(children: [
                                  if (cat.requiresSize) _tagChip('Size', AppColors.accent),
                                  if (cat.requiresSize && cat.requiresColor) const SizedBox(width: 6),
                                  if (cat.requiresColor) _tagChip('Color', AppColors.warning),
                                  if (!cat.requiresSize && !cat.requiresColor)
                                    Text('No variants', style: AppTypography.labelSmall.copyWith(
                                      color: AppColors.textTertiary(context), fontStyle: FontStyle.italic)),
                                ]),
                              ],
                            )),
                            IconButton(
                              icon: Icon(Icons.edit_rounded, size: 18, color: AppColors.accent),
                              tooltip: 'Edit',
                              onPressed: () => _showEditDialog(cat),
                              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                              padding: EdgeInsets.zero,
                            ),
                            IconButton(
                              icon: Icon(Icons.delete_rounded, size: 18, color: AppColors.error),
                              tooltip: 'Delete',
                              onPressed: () => _deleteCategory(cat),
                              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                              padding: EdgeInsets.zero,
                            ),
                          ]),
                        )),
                      ],
                    ),
                  );
                },
              ),
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

            // ─── Loyalty Program ───
            _buildLoyaltySection(isDark),
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

  // ─── Backfill Loyalty Points ───

  Future<void> _backfillLoyaltyPoints(LoyaltySettingsProvider loyalty) async {
    // Confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          Icon(Icons.star_rounded, color: AppColors.warning),
          const SizedBox(width: 8),
          Text('Backfill Points?', style: TextStyle(color: AppColors.textPrimary(context))),
        ]),
        content: Text(
          'This will award loyalty points to all existing customers based on their total spending history.\n\n'
          'Rate: ${loyalty.earnRate} point(s) per ₹100 spent.\n\n'
          'Existing points will be preserved (only adds new points).',
          style: TextStyle(color: AppColors.textSecondary(context), fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: TextStyle(color: AppColors.textTertiary(context))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.warning,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Award Points', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final customerProvider = context.read<CustomerProvider>();
    final salesProvider = context.read<SalesProvider>();

    int customersUpdated = 0;
    int totalPointsAwarded = 0;

    // Get customer summaries from sales data
    final summaries = salesProvider.getCustomerSummaries();

    for (final customer in customerProvider.customers) {
      // Match by phone first, then name
      final key = customer.phone.isNotEmpty
          ? customer.phone
          : customer.name.toLowerCase().trim();
      final summary = summaries[key];

      if (summary == null) continue;

      final totalSpent = (summary['totalSpent'] as double?) ?? 0;
      if (totalSpent <= 0) continue;

      // Calculate points they should have earned
      final shouldHaveEarned = loyalty.pointsForAmount(totalSpent);
      final currentPoints = customer.loyaltyPoints;

      // Only add if they're missing points
      if (shouldHaveEarned > currentPoints) {
        final pointsToAdd = shouldHaveEarned - currentPoints;
        final updated = customer.copyWith(loyaltyPoints: shouldHaveEarned);
        await customerProvider.updateCustomer(updated);
        customersUpdated++;
        totalPointsAwarded += pointsToAdd;
      }
    }

    if (!mounted) return;

    // Show result
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        Icon(Icons.star_rounded, color: Colors.white, size: 20),
        const SizedBox(width: 8),
        Text(customersUpdated > 0
            ? 'Awarded $totalPointsAwarded points to $customersUpdated customers!'
            : 'All customers already have correct points.'),
      ]),
      backgroundColor: customersUpdated > 0 ? AppColors.warning : AppColors.accent,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  // ─── Loyalty Program Section ───

  Widget _buildLoyaltySection(bool isDark) {
    final loyalty = context.watch<LoyaltySettingsProvider>();
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.card(context) : AppColors.cardLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppColors.cardBorder(context) : AppColors.cardBorderLight),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header
        Padding(
          padding: const EdgeInsets.all(20),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12)),
              child: Icon(Icons.star_rounded, color: AppColors.warning, size: 22)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Loyalty Program', style: AppTypography.h4.copyWith(
                  color: AppColors.textPrimary(context), fontWeight: FontWeight.w600)),
              Text('Reward customers with points on every purchase',
                  style: AppTypography.labelSmall.copyWith(color: AppColors.textTertiary(context))),
            ])),
          ]),
        ),
        // Master toggle
        _SettingsTile(
          icon: Icons.toggle_on_rounded,
          title: 'Enable Loyalty Points',
          subtitle: loyalty.isEnabled
              ? 'Customers earn points on purchases'
              : 'Loyalty program is disabled',
          isDark: isDark,
          trailing: Switch.adaptive(
            value: loyalty.isEnabled,
            onChanged: (v) => loyalty.setEnabled(v),
            activeColor: AppColors.warning,
            activeTrackColor: AppColors.warning.withValues(alpha: 0.4),
          ),
        ),
        // Config fields (only visible when enabled)
        if (loyalty.isEnabled) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.warning.withValues(alpha: 0.15))),
              child: Column(children: [
                _loyaltyField('Earn Rate', '${loyalty.earnRate}',
                    'points per \u20b9100 spent', Icons.trending_up_rounded,
                    onChanged: (v) {
                      final val = int.tryParse(v);
                      if (val != null && val > 0) loyalty.setEarnRate(val);
                    }),
                const SizedBox(height: 12),
                _loyaltyField('Redeem Value', '${loyalty.redeemValue.toStringAsFixed(0)}',
                    '\u20b9 per point', Icons.currency_rupee_rounded,
                    onChanged: (v) {
                      final val = double.tryParse(v);
                      if (val != null && val > 0) loyalty.setRedeemValue(val);
                    }),
                const SizedBox(height: 12),
                _loyaltyField('Min. Redeem', '${loyalty.minRedeem}',
                    'minimum points to redeem', Icons.low_priority_rounded,
                    onChanged: (v) {
                      final val = int.tryParse(v);
                      if (val != null && val >= 0) loyalty.setMinRedeem(val);
                    }),
                const SizedBox(height: 16),
                // ─── Backfill Button ───
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _backfillLoyaltyPoints(loyalty),
                    icon: Icon(Icons.history_rounded, size: 18, color: AppColors.warning),
                    label: Text('Award Points for Past Purchases',
                        style: TextStyle(color: AppColors.warning, fontSize: 12, fontWeight: FontWeight.w600)),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: AppColors.warning.withValues(alpha: 0.4)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ]),
            ),
          ),
        ],
      ]),
    );
  }

  Widget _loyaltyField(String label, String value, String suffix, IconData icon,
      {required ValueChanged<String> onChanged}) {
    return Row(children: [
      Icon(icon, size: 18, color: AppColors.warning),
      const SizedBox(width: 10),
      Expanded(child: Text(label, style: TextStyle(
          color: AppColors.textPrimary(context), fontSize: 13, fontWeight: FontWeight.w500))),
      SizedBox(
        width: 60,
        child: TextField(
          controller: TextEditingController(text: value),
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.warning, fontWeight: FontWeight.w700, fontSize: 14),
          onSubmitted: onChanged,
          decoration: InputDecoration(
            filled: true, fillColor: AppColors.surface(context),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: AppColors.cardBorder(context))),
            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6)),
        ),
      ),
      const SizedBox(width: 8),
      Text(suffix, style: TextStyle(color: AppColors.textTertiary(context), fontSize: 11)),
    ]);
  }

  // ─── Helpers ───

  Widget _tagChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600)),
    );
  }

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
