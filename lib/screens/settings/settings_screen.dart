import 'dart:convert';
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
import 'package:image_picker/image_picker.dart';
import '../../core/utils/data_export_service.dart';
import '../../core/utils/formatters.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isBackingUp = false;
  String _backupStatus = '';
  bool _isExporting = false;
  String _exportStatus = '';
  bool _showMonthlyReminder = false;

  // Store Profile + Receipt Settings (unified — single source of truth)
  final _shopNameCtrl = TextEditingController();
  final _shopAddressCtrl = TextEditingController();
  final _shopPhoneCtrl = TextEditingController();
  final _shopLogoCtrl = TextEditingController();
  final _receiptFooterCtrl = TextEditingController();
  bool _autoPrint = false;

  // Category Manager
  final _categoryNameCtrl = TextEditingController();
  bool _requiresSize = false;
  bool _requiresColor = false;
  bool _categoryExpanded = false;
  final _categorySearchCtrl = TextEditingController();
  String _categorySearch = '';

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _checkMonthlyBackupReminder();
    // Load categories via provider
    Future.microtask(() => context.read<CategoryProvider>().loadCategories());
  }

  @override
  void dispose() {
    _shopNameCtrl.dispose();
    _shopAddressCtrl.dispose();
    _shopPhoneCtrl.dispose();
    _shopLogoCtrl.dispose();
    _receiptFooterCtrl.dispose();
    _categoryNameCtrl.dispose();
    _categorySearchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final db = DBHelper.instance;
    // Unified store/receipt settings — single source of truth
    _shopNameCtrl.text = await db.getSetting('shop_name') ?? '';
    _shopAddressCtrl.text = await db.getSetting('shop_address') ?? '';
    _shopPhoneCtrl.text = await db.getSetting('shop_phone') ?? '';
    _shopLogoCtrl.text = await db.getSetting('shop_logo') ?? '';
    _receiptFooterCtrl.text = await db.getSetting('receipt_footer') ?? 'Thank you! Visit again';
    _autoPrint = (await db.getSetting('auto_print') ?? 'false') == 'true';
    if (mounted) setState(() {});
  }

  Future<void> _saveSettings() async {
    final db = DBHelper.instance;
    await db.setSetting('shop_name', _shopNameCtrl.text.trim());
    await db.setSetting('shop_address', _shopAddressCtrl.text.trim());
    await db.setSetting('shop_phone', _shopPhoneCtrl.text.trim());
    await db.setSetting('shop_logo', _shopLogoCtrl.text);
    await db.setSetting('receipt_footer', _receiptFooterCtrl.text.trim());
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

  /// Pick a logo image from device (PNG/JPEG supported)
  Future<void> _pickLogo() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 400,
        maxHeight: 400,
        imageQuality: 85,
      );
      if (picked != null) {
        final bytes = await picked.readAsBytes();
        final name = picked.name.toLowerCase();
        final mime = name.endsWith('.png') ? 'image/png' : 'image/jpeg';
        final b64 = base64Encode(bytes);
        final dataUri = 'data:$mime;base64,$b64';
        setState(() => _shopLogoCtrl.text = dataUri);
        _showToast('Logo uploaded — press Save to apply');
      }
    } catch (e) {
      debugPrint('Logo pick error: $e');
      _showToast('Failed to load image. Try a different file.', isError: true);
    }
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

  // ─── Monthly Backup Reminder ───

  Future<void> _checkMonthlyBackupReminder() async {
    final db = DBHelper.instance;
    final lastExport = await db.getSetting('last_csv_export_month');
    final currentMonth = '${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}';

    // Show reminder if we're in a new month and haven't exported yet
    if (lastExport != currentMonth) {
      if (mounted) setState(() => _showMonthlyReminder = true);
    }
  }

  Future<void> _dismissMonthlyReminder() async {
    final db = DBHelper.instance;
    final currentMonth = '${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}';
    await db.setSetting('last_csv_export_month', currentMonth);
    if (mounted) setState(() => _showMonthlyReminder = false);
  }

  // ─── CSV Export ───

  Future<void> _exportFullCSV() async {
    setState(() { _isExporting = true; _exportStatus = 'Preparing full data export...'; });
    try {
      final counts = await DataExportService.instance.exportAll();
      final total = counts.values.where((v) => v >= 0).fold<int>(0, (a, b) => a + b);
      if (!mounted) return;
      setState(() {
        _exportStatus = 'Exported $total records across ${counts.length} tables';
        _isExporting = false;
      });
      // Mark monthly export done
      await _dismissMonthlyReminder();

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Full data export complete — $total records downloaded'),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));
      Future.delayed(const Duration(seconds: 4), () {
        if (mounted) setState(() => _exportStatus = '');
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _exportStatus = 'Export failed: ${e.toString().split(':').last.trim()}';
        _isExporting = false;
      });
    }
  }

  Future<void> _exportMonthlyCSV() async {
    // Export previous month's data
    final now = DateTime.now();
    final prevMonth = DateTime(now.year, now.month - 1, 1);
    setState(() { _isExporting = true; _exportStatus = 'Generating monthly report...'; });
    try {
      final counts = await DataExportService.instance.exportMonthlyReport(month: prevMonth);
      final total = counts.values.where((v) => v >= 0).fold<int>(0, (a, b) => a + b);
      if (!mounted) return;
      setState(() {
        _exportStatus = 'Monthly report: $total records exported';
        _isExporting = false;
      });
      await _dismissMonthlyReminder();

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Monthly report downloaded — $total records'),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));
      Future.delayed(const Duration(seconds: 4), () {
        if (mounted) setState(() => _exportStatus = '');
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _exportStatus = 'Export failed: ${e.toString().split(':').last.trim()}';
        _isExporting = false;
      });
    }
  }

  Future<void> _exportSingleTable(String tableName) async {
    try {
      final count = await DataExportService.instance.exportTable(tableName);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('$tableName: $count records exported'),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Export failed: $e'),
        backgroundColor: AppColors.error,
      ));
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

            // ─── Store & Receipt Settings (Unified) ───
            _buildSection(isDark, 'Store & Receipt Settings', Icons.storefront_rounded, [
              _buildTextField('Store Name', _shopNameCtrl, isDark),
              _buildTextField('Address', _shopAddressCtrl, isDark),
              _buildTextField('Phone', _shopPhoneCtrl, isDark),
              // ─── Logo Upload ───
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Receipt Logo', style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w500,
                      color: isDark ? AppColors.textSecondary(context) : AppColors.textSecondaryLight,
                    )),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        // Preview
                        Container(
                          width: 56, height: 56,
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: isDark ? Colors.white12 : Colors.grey.shade300),
                          ),
                          child: _shopLogoCtrl.text.isNotEmpty
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(9),
                                  child: _shopLogoCtrl.text.startsWith('data:')
                                      ? Image.memory(
                                          base64Decode(_shopLogoCtrl.text.split(',').last),
                                          fit: BoxFit.contain,
                                          errorBuilder: (_, __, ___) => Icon(Icons.broken_image_rounded,
                                              color: AppColors.textTertiary(context), size: 24),
                                        )
                                      : Image.network(
                                          _shopLogoCtrl.text,
                                          fit: BoxFit.contain,
                                          errorBuilder: (_, __, ___) => Icon(Icons.broken_image_rounded,
                                              color: AppColors.textTertiary(context), size: 24),
                                        ),
                                )
                              : Icon(Icons.image_outlined,
                                  color: AppColors.textTertiary(context), size: 24),
                        ),
                        const SizedBox(width: 12),
                        // Upload button
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _pickLogo(),
                            icon: const Icon(Icons.upload_file_rounded, size: 18),
                            label: Text(
                              _shopLogoCtrl.text.isNotEmpty ? 'Change Logo' : 'Upload Logo (PNG/JPG)',
                              style: const TextStyle(fontSize: 13),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey.shade100,
                              foregroundColor: isDark ? AppColors.textPrimary(context) : AppColors.textPrimaryLight,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                                side: BorderSide(color: isDark ? Colors.white12 : Colors.grey.shade300),
                              ),
                            ),
                          ),
                        ),
                        // Remove button
                        if (_shopLogoCtrl.text.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          IconButton(
                            onPressed: () => setState(() => _shopLogoCtrl.text = ''),
                            icon: Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 20),
                            tooltip: 'Remove logo',
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              _buildTextField('Receipt Footer', _receiptFooterCtrl, isDark),
              // ─── Auto-Print Toggle ───
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                child: Row(children: [
                  Icon(Icons.print_rounded, size: 18,
                      color: isDark ? AppColors.textSecondary(context) : AppColors.textSecondaryLight),
                  const SizedBox(width: 10),
                  Expanded(child: Text('Auto-Print Receipt on Sale', style: AppTypography.bodyMedium.copyWith(
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
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: SizedBox(
                  width: double.infinity, height: 48,
                  child: ElevatedButton.icon(
                    onPressed: _saveSettings,
                    icon: const Icon(Icons.save_rounded, size: 18),
                    label: Text('Save Settings', style: AppTypography.button.copyWith(color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 16),
            _buildCategoryManagerAccordion(isDark),
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

            // ─── CSV Data Export ───
            _buildSection(isDark, 'Data Export (CSV)', Icons.download_rounded, [
              // Monthly backup reminder banner
              if (_showMonthlyReminder)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppColors.warning.withValues(alpha: 0.15), AppColors.accent.withValues(alpha: 0.1)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.notification_important_rounded, size: 20, color: AppColors.warning),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Monthly Backup Reminder',
                                  style: AppTypography.labelSmall.copyWith(
                                      color: AppColors.warning, fontWeight: FontWeight.w700, fontSize: 12)),
                              Text('Download your monthly data to keep a safe copy',
                                  style: TextStyle(
                                      color: isDark ? AppColors.textSecondary(context) : AppColors.textSecondaryLight,
                                      fontSize: 10)),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: _dismissMonthlyReminder,
                          icon: Icon(Icons.close_rounded, size: 16,
                              color: isDark ? AppColors.textTertiary(context) : AppColors.textTertiaryLight),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  ),
                ),

              _SettingsTile(
                icon: Icons.info_outline_rounded,
                title: 'Offline-Safe Data Downloads',
                subtitle: 'Export your data as CSV files — works even without internet',
                isDark: isDark,
                trailing: Icon(Icons.verified_rounded, color: AppColors.success, size: 20),
              ),

              // Full backup export
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.accent.withValues(alpha: 0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.storage_rounded, size: 16, color: AppColors.accent),
                          const SizedBox(width: 6),
                          Text('Full Data Export', style: AppTypography.labelLarge.copyWith(
                            color: isDark ? AppColors.textPrimary(context) : AppColors.textPrimaryLight, fontSize: 13)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text('Downloads ALL data — Items, Sales, Customers, Vendors, Expenses, Staff, Attendance',
                          style: TextStyle(
                              color: isDark ? AppColors.textTertiary(context) : AppColors.textTertiaryLight,
                              fontSize: 10)),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity, height: 44,
                        child: ElevatedButton.icon(
                          onPressed: _isExporting ? null : _exportFullCSV,
                          icon: _isExporting
                              ? const SizedBox(width: 16, height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.download_rounded, size: 18),
                          label: Text(_isExporting ? 'Exporting...' : 'DOWNLOAD FULL BACKUP (CSV)',
                            style: AppTypography.button.copyWith(color: Colors.white, fontSize: 12)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.accent,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: AppColors.accent.withValues(alpha: 0.5),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 4),

              // Monthly report export
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
                      Row(
                        children: [
                          Icon(Icons.calendar_month_rounded, size: 16, color: AppColors.primary),
                          const SizedBox(width: 6),
                          Text('Monthly Report', style: AppTypography.labelLarge.copyWith(
                            color: isDark ? AppColors.textPrimary(context) : AppColors.textPrimaryLight, fontSize: 13)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text('Sales, Purchases, Expenses & Attendance from last month + full inventory snapshot',
                          style: TextStyle(
                              color: isDark ? AppColors.textTertiary(context) : AppColors.textTertiaryLight,
                              fontSize: 10)),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity, height: 44,
                        child: ElevatedButton.icon(
                          onPressed: _isExporting ? null : _exportMonthlyCSV,
                          icon: const Icon(Icons.calendar_today_rounded, size: 16),
                          label: Text('DOWNLOAD MONTHLY REPORT (CSV)',
                            style: AppTypography.button.copyWith(color: Colors.white, fontSize: 12)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.5),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 4),

              // Export status
              if (_exportStatus.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
                  child: Text(_exportStatus, style: AppTypography.labelSmall.copyWith(
                    color: _exportStatus.contains('Exported') || _exportStatus.contains('report')
                        ? AppColors.success
                        : _exportStatus.contains('failed') ? AppColors.error : AppColors.accent),
                    textAlign: TextAlign.center),
                ),

              // Individual table exports
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Export Individual Tables',
                        style: AppTypography.labelSmall.copyWith(
                            color: isDark ? AppColors.textSecondary(context) : AppColors.textSecondaryLight,
                            fontWeight: FontWeight.w600, fontSize: 11)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6, runSpacing: 6,
                      children: [
                        _tableChip('items', Icons.inventory_2_rounded),
                        _tableChip('sales', Icons.point_of_sale_rounded),
                        _tableChip('customers', Icons.people_rounded),
                        _tableChip('vendors', Icons.store_rounded),
                        _tableChip('purchases', Icons.local_shipping_rounded),
                        _tableChip('expenses', Icons.money_off_rounded),
                        _tableChip('staff', Icons.badge_rounded),
                        _tableChip('attendance', Icons.access_time_rounded),
                        _tableChip('categories', Icons.category_rounded),
                        _tableChip('clearance_items', Icons.cleaning_services_rounded),
                      ],
                    ),
                  ],
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

  // ─── Category Manager Accordion ───

  Widget _buildCategoryManagerAccordion(bool isDark) {
    final catProvider = context.watch<CategoryProvider>();
    final catCount = catProvider.categories.length;
    final inventory = context.watch<InventoryProvider>();

    // Filter categories by search
    final filtered = _categorySearch.isEmpty
        ? catProvider.categories
        : catProvider.categories.where((c) =>
            c.name.toLowerCase().contains(_categorySearch)).toList();

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.card(context) : AppColors.cardLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppColors.cardBorder(context) : AppColors.cardBorderLight),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: [
        // ─── Accordion Header ───
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => setState(() => _categoryExpanded = !_categoryExpanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.category_rounded, color: AppColors.primary, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Category Manager', style: AppTypography.labelLarge.copyWith(
                    color: isDark ? AppColors.textPrimary(context) : AppColors.textPrimaryLight,
                    fontSize: 13, letterSpacing: 0.5)),
                  const SizedBox(height: 2),
                  Text('$catCount ${catCount == 1 ? "category" : "categories"} configured',
                    style: AppTypography.labelSmall.copyWith(
                      color: AppColors.textTertiary(context), fontSize: 11)),
                ])),
                // Category count badge
                if (catCount > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text('$catCount', style: TextStyle(
                      color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w700)),
                  ),
                const SizedBox(width: 10),
                AnimatedRotation(
                  turns: _categoryExpanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeInOut,
                  child: Icon(Icons.keyboard_arrow_down_rounded,
                    color: AppColors.textTertiary(context), size: 24),
                ),
              ]),
            ),
          ),
        ),

        // ─── Accordion Body ───
        AnimatedCrossFade(
          firstChild: const SizedBox.shrink(),
          secondChild: _buildCategoryBody(isDark, catProvider, filtered, inventory),
          crossFadeState: _categoryExpanded
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 300),
          sizeCurve: Curves.easeInOut,
          firstCurve: Curves.easeIn,
          secondCurve: Curves.easeOut,
        ),
      ]),
    );
  }

  Widget _buildCategoryBody(bool isDark, CategoryProvider catProvider,
      List<CategoryModel> filtered, InventoryProvider inventory) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Divider(color: AppColors.cardBorder(context), height: 1),

      // ─── Add Category Form ───
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        child: Text('New Category', style: AppTypography.labelSmall.copyWith(
          color: AppColors.textTertiary(context), fontWeight: FontWeight.w600,
          letterSpacing: 0.8, fontSize: 10)),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
        child: TextField(
          controller: _categoryNameCtrl,
          style: AppTypography.bodyMedium.copyWith(
            color: isDark ? AppColors.textPrimary(context) : AppColors.textPrimaryLight),
          decoration: InputDecoration(
            hintText: 'Category Name (e.g. Wallets)',
            hintStyle: AppTypography.bodyMedium.copyWith(
              color: (isDark ? AppColors.textTertiary(context) : AppColors.textTertiaryLight).withValues(alpha: 0.5)),
            prefixIcon: Icon(Icons.label_rounded, size: 18, color: AppColors.textTertiary(context)),
            filled: true,
            fillColor: isDark ? AppColors.sidebarDark.withValues(alpha: 0.5) : Colors.grey.shade50,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: AppColors.cardBorder(context))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: AppColors.cardBorder(context))),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: AppColors.primary, width: 1.5)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
          onSubmitted: (_) => _addCategory(),
        ),
      ),

      // ─── Variant Toggles (improved UX) ───
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
        child: Row(children: [
          Expanded(child: _variantToggle(
            isDark: isDark,
            value: _requiresSize,
            label: 'Enable Size Variants',
            helper: 'Products have multiple sizes',
            icon: Icons.straighten_rounded,
            color: AppColors.accent,
            onChanged: (v) => setState(() => _requiresSize = v),
          )),
          const SizedBox(width: 10),
          Expanded(child: _variantToggle(
            isDark: isDark,
            value: _requiresColor,
            label: 'Enable Color Variants',
            helper: 'Products have multiple colors',
            icon: Icons.palette_rounded,
            color: AppColors.warning,
            onChanged: (v) => setState(() => _requiresColor = v),
          )),
        ]),
      ),

      // ─── Add Button ───
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
        child: SizedBox(
          width: double.infinity, height: 44,
          child: ElevatedButton.icon(
            onPressed: _addCategory,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: Text('Add Category', style: AppTypography.button.copyWith(color: Colors.white, fontSize: 13)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ),
      ),

      Divider(color: AppColors.cardBorder(context), height: 1),

      // ─── Category List Header + Search ───
      if (catProvider.categories.isNotEmpty) ...[
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
          child: Row(children: [
            Text('${catProvider.categories.length} Categories',
              style: AppTypography.labelSmall.copyWith(
                color: AppColors.textTertiary(context), fontWeight: FontWeight.w600,
                letterSpacing: 0.8, fontSize: 10)),
            const Spacer(),
            if (catProvider.categories.length > 5)
              SizedBox(
                width: 180, height: 32,
                child: TextField(
                  controller: _categorySearchCtrl,
                  style: TextStyle(color: AppColors.textPrimary(context), fontSize: 12),
                  onChanged: (v) => setState(() => _categorySearch = v.toLowerCase()),
                  decoration: InputDecoration(
                    hintText: 'Search...',
                    hintStyle: TextStyle(color: AppColors.textTertiary(context), fontSize: 11),
                    prefixIcon: Icon(Icons.search_rounded, size: 16, color: AppColors.textTertiary(context)),
                    filled: true,
                    fillColor: AppColors.surface(context),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: AppColors.cardBorder(context))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: AppColors.cardBorder(context))),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                    isDense: true,
                  ),
                ),
              ),
          ]),
        ),
        const SizedBox(height: 8),

        // ─── Scrollable Category List ───
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 320),
            child: filtered.isEmpty
                ? Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.03),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(child: Text('No categories match "$_categorySearch"',
                      style: AppTypography.bodySmall.copyWith(color: AppColors.textTertiary(context)))),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: filtered.length,
                    itemBuilder: (_, i) => _buildCategoryCard(isDark, filtered[i], inventory),
                  ),
          ),
        ),
        const SizedBox(height: 16),
      ] else ...[
        // Empty state
        Padding(
          padding: const EdgeInsets.all(20),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.cardBorder(context).withValues(alpha: 0.5)),
            ),
            child: Column(children: [
              Icon(Icons.category_outlined, size: 40, color: AppColors.textTertiary(context).withValues(alpha: 0.4)),
              const SizedBox(height: 10),
              Text('No categories yet', style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textTertiary(context))),
              const SizedBox(height: 4),
              Text('Add your first category above to get started',
                style: AppTypography.labelSmall.copyWith(
                  color: AppColors.textTertiary(context).withValues(alpha: 0.7))),
            ]),
          ),
        ),
      ],
    ]);
  }

  Widget _buildCategoryCard(bool isDark, CategoryModel cat, InventoryProvider inventory) {
    // Count products using this category
    final productCount = inventory.items.where(
      (item) => item.category.toLowerCase() == cat.name.toLowerCase()).length;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.cardBorder(context).withValues(alpha: 0.5)),
      ),
      child: Row(children: [
        // Avatar
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            borderRadius: BorderRadius.circular(10)),
          child: Center(child: Text(
            cat.name.isNotEmpty ? cat.name[0].toUpperCase() : '?',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15))),
        ),
        const SizedBox(width: 12),
        // Info
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(cat.name, style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textPrimary(context), fontWeight: FontWeight.w600)),
            const SizedBox(height: 3),
            Row(children: [
              if (cat.requiresSize) ...[
                _tagChip('Size', AppColors.accent),
                const SizedBox(width: 6),
              ],
              if (cat.requiresColor) ...[
                _tagChip('Color', AppColors.warning),
                const SizedBox(width: 6),
              ],
              if (!cat.requiresSize && !cat.requiresColor)
                Text('No variants', style: AppTypography.labelSmall.copyWith(
                  color: AppColors.textTertiary(context), fontStyle: FontStyle.italic, fontSize: 10)),
              const SizedBox(width: 8),
              // Product count
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: productCount > 0
                      ? AppColors.success.withValues(alpha: 0.1)
                      : AppColors.textTertiary(context).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '$productCount ${productCount == 1 ? "product" : "products"}',
                  style: TextStyle(
                    color: productCount > 0 ? AppColors.success : AppColors.textTertiary(context),
                    fontSize: 9, fontWeight: FontWeight.w600),
                ),
              ),
            ]),
          ],
        )),
        // Actions
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
    );
  }

  Widget _variantToggle({
    required bool isDark,
    required bool value,
    required String label,
    required String helper,
    required IconData icon,
    required Color color,
    required ValueChanged<bool> onChanged,
  }) {
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: value ? color.withValues(alpha: 0.08) : AppColors.surface(context),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: value ? color.withValues(alpha: 0.4) : AppColors.cardBorder(context)),
        ),
        child: Row(children: [
          Icon(icon, size: 16, color: value ? color : AppColors.textTertiary(context)),
          const SizedBox(width: 8),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: TextStyle(
              color: value ? color : AppColors.textSecondary(context),
              fontSize: 11, fontWeight: FontWeight.w600)),
            Text(helper, style: TextStyle(
              color: AppColors.textTertiary(context), fontSize: 9)),
          ])),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: color,
            activeTrackColor: color.withValues(alpha: 0.3),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ]),
      ),
    );
  }
  Widget _tableChip(String tableName, IconData icon) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ActionChip(
      avatar: Icon(icon, size: 14, color: AppColors.accent),
      label: Text(tableName.replaceAll('_', ' '),
          style: TextStyle(fontSize: 11,
              color: isDark ? AppColors.textPrimary(context) : AppColors.textPrimaryLight)),
      backgroundColor: isDark ? AppColors.surface(context) : AppColors.surfaceLight,
      side: BorderSide(color: isDark ? AppColors.cardBorder(context) : AppColors.cardBorderLight),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      onPressed: () => _exportSingleTable(tableName),
      padding: const EdgeInsets.symmetric(horizontal: 4),
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
