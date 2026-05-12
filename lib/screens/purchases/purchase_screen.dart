import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/formatters.dart';
import '../../core/constants.dart';
import '../../providers/vendor_provider.dart';
import '../../providers/inventory_provider.dart';
import '../../providers/purchase_provider.dart';
import '../../providers/category_provider.dart';
import '../../data/models/vendor_model.dart';
import '../../data/models/item_model.dart';
import '../../data/models/purchase_model.dart';

class PurchaseScreen extends StatefulWidget {
  const PurchaseScreen({super.key});

  @override
  State<PurchaseScreen> createState() => _PurchaseScreenState();
}

class _PurchaseScreenState extends State<PurchaseScreen> {
  // Form state
  VendorModel? _selectedVendor;
  final List<_PurchaseEntry> _entries = [];
  final _paidCtrl = TextEditingController(text: '0');
  String _paymentMode = 'Cash';
  bool _isSubmitting = false;

  // Item search
  final _itemSearchCtrl = TextEditingController();
  String _itemSearch = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<VendorProvider>().loadVendors();
      context.read<InventoryProvider>().loadItems();
      context.read<PurchaseProvider>().loadPurchases();
    });
  }

  @override
  void dispose() {
    _paidCtrl.dispose();
    _itemSearchCtrl.dispose();
    super.dispose();
  }

  double get _totalAmount => _entries.fold(0, (sum, e) => sum + e.total);
  double get _paidAmount => double.tryParse(_paidCtrl.text) ?? 0;
  double get _dueAmount => (_totalAmount - _paidAmount).clamp(0, double.infinity);

  void _addItemToEntries(ItemModel item) {
    final existing = _entries.indexWhere((e) => e.itemId == item.id);
    if (existing != -1) {
      setState(() => _entries[existing].quantity++);
    } else {
      setState(() => _entries.add(_PurchaseEntry(
        itemId: item.id,
        name: item.name,
        quantity: 1,
        costPrice: item.costPrice > 0 ? item.costPrice : item.price,
      )));
    }
    _itemSearchCtrl.clear();
    setState(() => _itemSearch = '');
  }

  Future<void> _submitPurchase() async {
    if (_selectedVendor == null) {
      _showError('Please select a vendor');
      return;
    }
    if (_entries.isEmpty) {
      _showError('Please add at least one item');
      return;
    }

    setState(() => _isSubmitting = true);

    final items = _entries.map((e) => {
      'item_id': e.itemId,
      'name': e.name,
      'quantity': e.quantity,
      'cost_price': e.costPrice,
      'total': e.total,
    }).toList();

    final success = await context.read<PurchaseProvider>().addPurchase(
      vendorId: _selectedVendor!.id,
      vendorName: _selectedVendor!.name,
      items: items,
      totalAmount: _totalAmount,
      paidAmount: _paidAmount,
      paymentMode: _paymentMode,
      inventoryProvider: context.read<InventoryProvider>(),
      vendorProvider: context.read<VendorProvider>(),
    );

    setState(() => _isSubmitting = false);

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('✅ Purchase recorded! Stock updated.'),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));
      setState(() {
        _selectedVendor = null;
        _entries.clear();
        _paidCtrl.text = '0';
        _paymentMode = 'Cash';
      });
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: AppColors.error,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  void _showQuickAddItem() {
    final nameCtrl = TextEditingController();
    final vendorCtrl = TextEditingController(text: _selectedVendor?.name ?? '');
    final barcodeCtrl = TextEditingController();
    final categoryCtrl = TextEditingController();
    final sizeCtrl = TextEditingController();
    final colorCtrl = TextEditingController();
    final locationCtrl = TextEditingController();
    final costPriceCtrl = TextEditingController();
    final sellingPriceCtrl = TextEditingController();
    final qtyCtrl = TextEditingController(text: '1');
    bool autoBarcode = true;
    String? selectedCategory;
    bool showSize = true;
    bool showColor = true;

    void generateBarcode() {
      final cat = selectedCategory ?? categoryCtrl.text.trim();
      final code = cat.isNotEmpty
          ? cat.substring(0, cat.length < 3 ? cat.length : 3).toUpperCase()
          : 'GEN';
      final num = (10000 + Random().nextInt(90000)).toString();
      barcodeCtrl.text = 'SKY-\$code-\$num';
    }

    void updateCategoryFields(String categoryName, void Function(void Function()) setDialogState) {
      final catProvider = context.read<CategoryProvider>();
      final match = catProvider.getCategoryByName(categoryName);
      if (match != null) {
        setDialogState(() {
          showSize = match.requiresSize;
          showColor = match.requiresColor;
        });
      } else {
        setDialogState(() { showSize = true; showColor = true; });
      }
    }

    // Auto-generate on open
    generateBarcode();

    // Ensure categories are loaded
    final catProvider = context.read<CategoryProvider>();
    if (catProvider.categories.isEmpty) catProvider.loadCategories();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Dialog(
          backgroundColor: AppColors.card(context),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520, maxHeight: 620),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                // Header
                Row(children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(gradient: AppColors.primaryGradient, borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.add_shopping_cart_rounded, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Text('Add Purchase Item', style: AppTypography.h3.copyWith(color: AppColors.textPrimary(context))),
                  const Spacer(),
                  IconButton(onPressed: () => Navigator.pop(ctx), icon: Icon(Icons.close_rounded, color: AppColors.textTertiary(context))),
                ]),
                const SizedBox(height: 16),
                // Form
                Flexible(child: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  // Basic
                  _purchaseField(ctx, 'Item Name *', nameCtrl, 'e.g. Nike Air Max 90', Icons.inventory_2_rounded),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(child: _purchaseField(ctx, 'Brand / Vendor', vendorCtrl, 'e.g. Nike', Icons.store_rounded)),
                    const SizedBox(width: 8),
                    // Dynamic category dropdown from CategoryProvider
                    Expanded(
                      child: Consumer<CategoryProvider>(
                        builder: (context, catProv, _) {
                          final categories = catProv.categories;
                          if (categories.isEmpty) {
                            return _purchaseField(ctx, 'Category', categoryCtrl, 'e.g. Shoes', Icons.category_rounded);
                          }
                          return DropdownButtonFormField<String>(
                            value: selectedCategory != null &&
                                categories.any((c) => c.name == selectedCategory)
                                ? selectedCategory : null,
                            items: categories.map((c) => DropdownMenuItem(
                              value: c.name,
                              child: Text(c.name, style: const TextStyle(fontSize: 13)),
                            )).toList(),
                            onChanged: (v) {
                              setDialogState(() {
                                selectedCategory = v;
                                categoryCtrl.text = v ?? '';
                              });
                              if (v != null) updateCategoryFields(v, setDialogState);
                              if (autoBarcode) {
                                generateBarcode();
                                setDialogState(() {});
                              }
                            },
                            style: TextStyle(color: AppColors.textPrimary(context), fontSize: 13),
                            dropdownColor: AppColors.card(context),
                            decoration: InputDecoration(
                              labelText: 'Category',
                              labelStyle: TextStyle(color: AppColors.textSecondary(context), fontSize: 12),
                              prefixIcon: Icon(Icons.category_rounded, size: 18, color: AppColors.textTertiary(context)),
                              filled: true,
                              fillColor: AppColors.surface(context),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(color: AppColors.cardBorder(context))),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(color: AppColors.cardBorder(context))),
                              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(color: AppColors.primary, width: 1.5)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            ),
                          );
                        },
                      ),
                    ),
                  ]),
                  const SizedBox(height: 10),
                  // Dynamic Size/Color based on selected category
                  if (showSize || showColor)
                    Row(children: [
                      if (showSize)
                        Expanded(child: _purchaseField(ctx, 'Size', sizeCtrl, 'e.g. 42, XL', Icons.straighten_rounded)),
                      if (showSize && showColor) const SizedBox(width: 8),
                      if (showColor)
                        Expanded(child: _purchaseField(ctx, 'Color', colorCtrl, 'e.g. Black', Icons.palette_rounded)),
                    ]),
                  if (showSize || showColor) const SizedBox(height: 10),
                  // Barcode
                  Row(children: [
                    Checkbox(value: autoBarcode, activeColor: AppColors.accent, onChanged: (v) {
                      setDialogState(() => autoBarcode = v ?? false);
                      if (v == true) generateBarcode();
                    }),
                    Text('Auto Barcode', style: TextStyle(color: AppColors.textSecondary(context), fontSize: 12)),
                    const SizedBox(width: 8),
                    Expanded(child: _purchaseField(ctx, 'Barcode / SKU', barcodeCtrl,
                        autoBarcode ? 'Auto-generated' : 'Enter barcode', Icons.qr_code_scanner_rounded,
                        enabled: !autoBarcode)),
                  ]),
                  const SizedBox(height: 10),
                  _purchaseField(ctx, 'Storage Location', locationCtrl, 'e.g. Rack A / Shelf 3', Icons.location_on_rounded),
                  const SizedBox(height: 10),
                  // Pricing
                  Row(children: [
                    Expanded(child: _purchaseField(ctx, 'Cost Price (\u20b9) *', costPriceCtrl, '0.00', Icons.payments_rounded, isNumber: true)),
                    const SizedBox(width: 8),
                    Expanded(child: _purchaseField(ctx, 'Selling Price (\u20b9)', sellingPriceCtrl, '0.00', Icons.sell_rounded, isNumber: true)),
                    const SizedBox(width: 8),
                    SizedBox(width: 80, child: _purchaseField(ctx, 'Qty', qtyCtrl, '1', Icons.inventory_rounded, isNumber: true)),
                  ]),
                ]))),
                const SizedBox(height: 16),
                // Actions
                Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                  TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () async {
                      if (nameCtrl.text.trim().isEmpty) return;
                      if (autoBarcode && barcodeCtrl.text.isEmpty) generateBarcode();
                      final category = selectedCategory ?? categoryCtrl.text.trim();
                      final inv = context.read<InventoryProvider>();
                      await inv.addItem(
                        name: nameCtrl.text.trim(),
                        vendor: vendorCtrl.text.trim(),
                        barcode: barcodeCtrl.text.trim(),
                        category: category,
                        size: showSize ? sizeCtrl.text.trim() : '',
                        color: showColor ? colorCtrl.text.trim() : '',
                        storageLocation: locationCtrl.text.trim(),
                        price: double.tryParse(sellingPriceCtrl.text) ?? double.tryParse(costPriceCtrl.text) ?? 0,
                        costPrice: double.tryParse(costPriceCtrl.text) ?? 0,
                        quantity: int.tryParse(qtyCtrl.text) ?? 0,
                      );
                      if (ctx.mounted) Navigator.pop(ctx);
                      await inv.loadItems();
                      final newItem = inv.items.firstWhere(
                        (i) => i.name == nameCtrl.text.trim(),
                        orElse: () => ItemModel(id: '', name: '', price: 0),
                      );
                      if (newItem.id.isNotEmpty) _addItemToEntries(newItem);
                    },
                    icon: const Icon(Icons.check_rounded, size: 18),
                    label: const Text('Add to Purchase'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary, foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                  ),
                ]),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _purchaseField(BuildContext ctx, String label, TextEditingController ctrl, String hint, IconData icon,
      {bool isNumber = false, bool enabled = true}) {
    return TextField(
      controller: ctrl,
      enabled: enabled,
      keyboardType: isNumber ? const TextInputType.numberWithOptions(decimal: true) : null,
      style: TextStyle(color: enabled ? AppColors.textPrimary(context) : AppColors.textTertiary(context), fontSize: 13),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: TextStyle(color: AppColors.textSecondary(context), fontSize: 12),
        hintStyle: TextStyle(color: AppColors.textTertiary(context), fontSize: 12),
        prefixIcon: Icon(icon, size: 18, color: AppColors.textTertiary(context)),
        filled: true,
        fillColor: enabled ? AppColors.surface(context) : AppColors.surface(context).withValues(alpha: 0.5),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppColors.cardBorder(context))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppColors.cardBorder(context))),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }

  void _showPurchaseDetails(PurchaseModel purchase) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: AppColors.card(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      borderRadius: BorderRadius.circular(10)),
                    child: Icon(Icons.receipt_long_rounded, color: Colors.white, size: 18),
                  ),
                  SizedBox(width: 10),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Purchase Details', style: AppTypography.h4.copyWith(color: AppColors.textPrimary(context))),
                    Text(Formatters.dateTime(purchase.createdAt),
                        style: AppTypography.labelSmall.copyWith(color: AppColors.textTertiary(context))),
                  ])),
                  IconButton(onPressed: () => Navigator.pop(ctx),
                      icon: Icon(Icons.close_rounded, color: AppColors.textTertiary(context))),
                ]),
                SizedBox(height: 16),
                // Vendor
                _detailRow('Vendor', purchase.vendorName),
                _detailRow('Payment', purchase.paymentMode),
                Divider(color: AppColors.cardBorder(context), height: 20),
                // Items
                Text('Items', style: AppTypography.labelMedium.copyWith(color: AppColors.textSecondary(context))),
                SizedBox(height: 8),
                ...purchase.itemsList.map((item) => Padding(
                  padding: EdgeInsets.only(bottom: 6),
                  child: Row(children: [
                    Expanded(child: Text(item['name'] ?? '', style: TextStyle(color: AppColors.textPrimary(context), fontSize: 13))),
                    Text('×${item['quantity']}', style: AppTypography.mono.copyWith(color: AppColors.textSecondary(context), fontSize: 12)),
                    SizedBox(width: 8),
                    Text(Formatters.currency((item['total'] as num?)?.toDouble() ?? 0),
                        style: AppTypography.mono.copyWith(color: AppColors.accent, fontSize: 12)),
                  ]),
                )),
                Divider(color: AppColors.cardBorder(context), height: 20),
                _detailRow('Total', Formatters.currency(purchase.totalAmount), isBold: true),
                _detailRow('Paid', Formatters.currency(purchase.paidAmount), color: AppColors.success),
                if (purchase.dueAmount > 0)
                  _detailRow('Due', Formatters.currency(purchase.dueAmount), color: AppColors.error),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value, {bool isBold = false, Color? color}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 3),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary(context))),
        Text(value, style: AppTypography.mono.copyWith(
          color: color ?? AppColors.textPrimary(context),
          fontWeight: isBold ? FontWeight.w700 : FontWeight.w500, fontSize: isBold ? 16 : 13)),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vendors = context.watch<VendorProvider>().vendors;
    final inventory = context.watch<InventoryProvider>().items;
    final purchases = context.watch<PurchaseProvider>();
    final width = MediaQuery.of(context).size.width;
    final isWide = width > 900;

    final searchResults = _itemSearch.length >= 2
        ? inventory.where((i) =>
            i.name.toLowerCase().contains(_itemSearch.toLowerCase()) ||
            i.barcode.toLowerCase().contains(_itemSearch.toLowerCase())
          ).take(8).toList()
        : <ItemModel>[];

    // Low stock suggestions
    final lowStockItems = inventory.where((i) => i.isLowStock || i.isOutOfStock).take(5).toList();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Text('Purchases (Inward Stock)',
                  style: AppTypography.h1.copyWith(color: AppColors.textPrimary(context))),
              const Spacer(),
              if (_selectedVendor != null && _selectedVendor!.balance > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.warning_rounded, size: 14, color: AppColors.error),
                    const SizedBox(width: 6),
                    Text('${_selectedVendor!.name} Pending: ${Formatters.currency(_selectedVendor!.balance)}',
                        style: AppTypography.labelSmall.copyWith(color: AppColors.error, fontWeight: FontWeight.w600)),
                  ]),
                ),
            ]),
            const SizedBox(height: 20),

            Expanded(
              child: isWide
                  ? Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      Expanded(flex: 3, child: SingleChildScrollView(
                        child: _buildPurchaseForm(vendors, searchResults, lowStockItems))),
                      const SizedBox(width: 20),
                      Expanded(flex: 2, child: _buildRecentPurchases(purchases)),
                    ])
                  : SingleChildScrollView(child: Column(children: [
                      _buildPurchaseForm(vendors, searchResults, lowStockItems),
                      const SizedBox(height: 20),
                      _buildRecentPurchasesCompact(purchases),
                    ])),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPurchaseForm(List<VendorModel> vendors, List<ItemModel> searchResults, List<ItemModel> lowStockItems) {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Text('New Purchase', style: AppTypography.h3.copyWith(color: AppColors.textPrimary(context))),
            const Spacer(),
            // Quick add item button
            TextButton.icon(
              onPressed: _showQuickAddItem,
              icon: Icon(Icons.add_rounded, size: 16),
              label: Text('New Item', style: TextStyle(fontSize: 12)),
              style: TextButton.styleFrom(foregroundColor: AppColors.accent),
            ),
          ]),
          SizedBox(height: 16),

          // ─── Vendor Selector ───
          Row(children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                value: _selectedVendor?.id,
                decoration: _inputDecor('Select Vendor'),
                dropdownColor: AppColors.surface(context),
                style: TextStyle(color: AppColors.textPrimary(context)),
                items: vendors.map((v) => DropdownMenuItem(
                  value: v.id,
                  child: Text(
                    v.balance > 0 ? '${v.name}  (₹${v.balance.toStringAsFixed(0)} due)' : v.name,
                    overflow: TextOverflow.ellipsis,
                  ),
                )).toList(),
                onChanged: (id) => setState(() => _selectedVendor = vendors.firstWhere((v) => v.id == id)),
              ),
            ),
          ]),
          SizedBox(height: 16),

          // ─── Item Search ───
          TextField(
            controller: _itemSearchCtrl,
            onChanged: (v) => setState(() => _itemSearch = v),
            style: TextStyle(color: AppColors.textPrimary(context)),
            decoration: InputDecoration(
              labelText: 'Search items to add',
              hintText: 'Type item name or barcode...',
              labelStyle: TextStyle(color: AppColors.textSecondary(context), fontSize: 13),
              hintStyle: TextStyle(color: AppColors.textTertiary(context)),
              prefixIcon: Icon(Icons.search_rounded, color: AppColors.textTertiary(context)),
              suffixIcon: Icon(Icons.qr_code_scanner_rounded, size: 18, color: AppColors.textTertiary(context)),
              filled: true,
              fillColor: AppColors.surface(context),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppColors.cardBorder(context))),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppColors.cardBorder(context))),
            ),
          ),

          // Search Results
          if (searchResults.isNotEmpty)
            Container(
              margin: EdgeInsets.only(top: 4),
              constraints: BoxConstraints(maxHeight: 200),
              decoration: BoxDecoration(
                color: AppColors.surface(context),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.cardBorder(context)),
              ),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: searchResults.length,
                itemBuilder: (_, i) {
                  final item = searchResults[i];
                  return ListTile(
                    dense: true,
                    title: Text(item.name, style: TextStyle(color: AppColors.textPrimary(context), fontSize: 14)),
                    subtitle: Text('Stock: ${item.quantity} • ${Formatters.currency(item.costPrice > 0 ? item.costPrice : item.price)}',
                        style: AppTypography.labelSmall.copyWith(color: AppColors.textTertiary(context))),
                    trailing: IconButton(
                      onPressed: () => _addItemToEntries(item),
                      icon: Icon(Icons.add_circle_rounded, color: AppColors.accent),
                    ),
                  );
                },
              ),
            ),

          // Low stock suggestions
          if (_entries.isEmpty && lowStockItems.isNotEmpty && _itemSearch.isEmpty) ...[
            const SizedBox(height: 12),
            Row(children: [
              Icon(Icons.lightbulb_rounded, size: 14, color: AppColors.warning),
              SizedBox(width: 6),
              Text('Low Stock — Suggested Purchases',
                  style: AppTypography.labelSmall.copyWith(color: AppColors.warning, fontWeight: FontWeight.w600)),
            ]),
            SizedBox(height: 6),
            Wrap(spacing: 6, runSpacing: 6, children: lowStockItems.map((item) =>
              ActionChip(
                label: Text('${item.name} (${item.quantity})',
                    style: TextStyle(fontSize: 11, color: item.isOutOfStock ? Colors.white : AppColors.textPrimary(context))),
                avatar: Icon(item.isOutOfStock ? Icons.error_rounded : Icons.warning_rounded,
                    size: 14, color: item.isOutOfStock ? Colors.white : AppColors.warning),
                onPressed: () => _addItemToEntries(item),
                backgroundColor: item.isOutOfStock ? AppColors.error.withValues(alpha: 0.8) : AppColors.warningBg,
                side: BorderSide(color: item.isOutOfStock ? AppColors.error : AppColors.warning.withValues(alpha: 0.4)),
              ),
            ).toList()),
          ],

          const SizedBox(height: 16),

          // ─── Entries Table ───
          if (_entries.isNotEmpty) ...[
            // Table header
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
              ),
              child: Row(children: [
                Expanded(flex: 3, child: Text('Item', style: TextStyle(color: AppColors.textSecondary(context), fontSize: 12, fontWeight: FontWeight.w600))),
                SizedBox(width: 80, child: Center(child: Text('Qty', style: TextStyle(color: AppColors.textSecondary(context), fontSize: 12, fontWeight: FontWeight.w600)))),
                SizedBox(width: 8),
                SizedBox(width: 80, child: Center(child: Text('Cost ₹', style: TextStyle(color: AppColors.textSecondary(context), fontSize: 12, fontWeight: FontWeight.w600)))),
                SizedBox(width: 8),
                SizedBox(width: 80, child: Text('Total', textAlign: TextAlign.right, style: TextStyle(color: AppColors.textSecondary(context), fontSize: 12, fontWeight: FontWeight.w600))),
                SizedBox(width: 28),
              ]),
            ),
            ..._entries.asMap().entries.map((e) => _entryRow(e.key, e.value)),
            Divider(color: AppColors.cardBorder(context), height: 24),

            // Totals summary
            Container(
              padding: EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surface(context),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
              ),
              child: Column(children: [
                _totalRow('Total Amount', Formatters.currency(_totalAmount), isBold: true),
              ]),
            ),
            SizedBox(height: 12),

            // ─── Payment Section ───
            Row(children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _paymentMode,
                  decoration: _inputDecor('Payment Mode'),
                  dropdownColor: AppColors.surface(context),
                  style: TextStyle(color: AppColors.textPrimary(context)),
                  items: [...AppConstants.paymentModes, 'Udhaar (Credit)']
                      .map((m) => DropdownMenuItem(value: m, child: Text(m, style: const TextStyle(fontSize: 14))))
                      .toList(),
                  onChanged: (v) => setState(() {
                    _paymentMode = v ?? 'Cash';
                    if (_paymentMode == 'Udhaar (Credit)') {
                      _paidCtrl.text = '0';
                    } else {
                      _paidCtrl.text = _totalAmount.toStringAsFixed(0);
                    }
                  }),
                ),
              ),
              SizedBox(width: 12),
              SizedBox(
                width: 130,
                child: TextFormField(
                  controller: _paidCtrl,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setState(() {}),
                  style: TextStyle(color: AppColors.textPrimary(context)),
                  decoration: _inputDecor('Paid ₹'),
                ),
              ),
            ]),

            if (_dueAmount > 0) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                ),
                child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Row(children: [
                    Icon(Icons.warning_rounded, size: 16, color: AppColors.error),
                    const SizedBox(width: 8),
                    Text('Due (Udhaar)', style: AppTypography.bodySmall.copyWith(color: AppColors.error, fontWeight: FontWeight.w600)),
                  ]),
                  Text(Formatters.currency(_dueAmount),
                      style: AppTypography.mono.copyWith(color: AppColors.error, fontWeight: FontWeight.w700, fontSize: 16)),
                ]),
              ),
            ],
            const SizedBox(height: 20),

            SizedBox(
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _isSubmitting ? null : _submitPurchase,
                icon: _isSubmitting
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Icon(Icons.inventory_rounded, size: 20),
                label: Text(_isSubmitting ? 'Recording...' : 'Record Purchase & Update Stock',
                    style: AppTypography.button.copyWith(color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  disabledBackgroundColor: AppColors.success.withValues(alpha: 0.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _entryRow(int index, _PurchaseEntry entry) {
    return Container(
      margin: EdgeInsets.only(bottom: 2),
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: index.isEven ? AppColors.surface(context) : Colors.transparent,
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(entry.name, style: TextStyle(color: AppColors.textPrimary(context), fontSize: 14)),
          ),
          // Qty controls
          SizedBox(
            width: 80,
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              _smallIconBtn(Icons.remove, () => setState(() {
                if (entry.quantity > 1) entry.quantity--;
              })),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 6),
                child: Text('${entry.quantity}', style: AppTypography.mono.copyWith(color: AppColors.textPrimary(context), fontSize: 13)),
              ),
              _smallIconBtn(Icons.add, () => setState(() => entry.quantity++)),
            ]),
          ),
          const SizedBox(width: 8),
          // Cost price editable
          SizedBox(
            width: 80,
            child: TextFormField(
              initialValue: entry.costPrice.toStringAsFixed(0),
              keyboardType: TextInputType.number,
              onChanged: (v) => setState(() => entry.costPrice = double.tryParse(v) ?? 0),
              style: AppTypography.mono.copyWith(color: AppColors.accent, fontSize: 13),
              decoration: InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                filled: true,
                fillColor: AppColors.card(context),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide.none),
              ),
            ),
          ),
          SizedBox(width: 8),
          SizedBox(
            width: 80,
            child: Text(Formatters.currency(entry.total),
                style: AppTypography.mono.copyWith(color: AppColors.textPrimary(context), fontSize: 13),
                textAlign: TextAlign.right),
          ),
          IconButton(
            onPressed: () => setState(() => _entries.removeAt(index)),
            icon: Icon(Icons.close_rounded, size: 18, color: AppColors.error),
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            padding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }

  Widget _smallIconBtn(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        width: 22, height: 22,
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(4)),
        child: Icon(icon, size: 14, color: AppColors.accent),
      ),
    );
  }

  Widget _totalRow(String label, String value, {bool isBold = false, Color? color}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 2),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: AppTypography.bodyMedium.copyWith(
          color: color ?? AppColors.textSecondary(context),
          fontWeight: isBold ? FontWeight.w700 : FontWeight.w400)),
        Text(value, style: AppTypography.mono.copyWith(
          color: color ?? AppColors.accent,
          fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
          fontSize: isBold ? 18 : 14)),
      ]),
    );
  }

  Widget _buildRecentPurchases(PurchaseProvider provider) {
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
            Icon(Icons.history_rounded, color: AppColors.accent, size: 18),
            SizedBox(width: 8),
            Text('Recent Purchases', style: AppTypography.h4.copyWith(color: AppColors.textPrimary(context))),
            if (provider.purchases.isNotEmpty) ...[
              const SizedBox(width: 6),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: AppColors.accent.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(10)),
                child: Text('${provider.purchases.length}',
                    style: AppTypography.labelSmall.copyWith(color: AppColors.accent, fontWeight: FontWeight.w700)),
              ),
            ],
          ]),
          SizedBox(height: 12),
          Flexible(
            child: provider.purchases.isEmpty
                ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.receipt_long_rounded, size: 48, color: AppColors.textTertiary(context).withValues(alpha: 0.4)),
                    SizedBox(height: 8),
                    Text('No purchases yet', style: AppTypography.bodyMedium.copyWith(color: AppColors.textTertiary(context))),
                  ]))
                : ListView.separated(
                    itemCount: provider.purchases.length,
                    separatorBuilder: (_, __) => Divider(color: AppColors.cardBorder(context), height: 1),
                    itemBuilder: (_, i) {
                      final p = provider.purchases[i];
                      return InkWell(
                        onTap: () => _showPurchaseDetails(p),
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 4, vertical: 10),
                          child: Row(children: [
                            // Vendor initial
                            Container(
                              width: 34, height: 34,
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8)),
                              child: Center(child: Text(p.vendorName.isNotEmpty ? p.vendorName[0].toUpperCase() : '?',
                                  style: AppTypography.labelLarge.copyWith(color: AppColors.accent))),
                            ),
                            SizedBox(width: 10),
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(p.vendorName, style: AppTypography.bodyMedium.copyWith(
                                  color: AppColors.textPrimary(context), fontWeight: FontWeight.w500)),
                              Text('${p.itemsList.length} items • ${Formatters.dateShort(p.createdAt)}',
                                  style: AppTypography.labelSmall.copyWith(color: AppColors.textTertiary(context))),
                            ])),
                            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                              Text(Formatters.currency(p.totalAmount),
                                  style: AppTypography.mono.copyWith(color: AppColors.accent, fontSize: 13)),
                              if (p.dueAmount > 0)
                                Container(
                                  margin: const EdgeInsets.only(top: 2),
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                  decoration: BoxDecoration(color: AppColors.error.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4)),
                                  child: Text('Due ₹${p.dueAmount.toStringAsFixed(0)}',
                                      style: const TextStyle(color: AppColors.error, fontSize: 10, fontWeight: FontWeight.w600)),
                                )
                              else
                                Container(
                                  margin: const EdgeInsets.only(top: 2),
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                  decoration: BoxDecoration(color: AppColors.success.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4)),
                                  child: const Text('Paid', style: TextStyle(color: AppColors.success, fontSize: 10, fontWeight: FontWeight.w600)),
                                ),
                            ]),
                          ]),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecor(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: AppColors.textSecondary(context), fontSize: 13),
      filled: true,
      fillColor: AppColors.surface(context),
      contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppColors.cardBorder(context))),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppColors.cardBorder(context))),
    );
  }

  Widget _dialogField(TextEditingController ctrl, String label, String hint, {TextInputType? keyboardType}) {
    return TextField(
      controller: ctrl,
      keyboardType: keyboardType,
      style: TextStyle(color: AppColors.textPrimary(context)),
      decoration: _inputDecor(label).copyWith(hintText: hint, hintStyle: TextStyle(color: AppColors.textTertiary(context), fontSize: 13)),
    );
  }

  /// Compact version for non-wide layout (no Expanded — safe in SingleChildScrollView)
  Widget _buildRecentPurchasesCompact(PurchaseProvider provider) {
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
            Icon(Icons.history_rounded, color: AppColors.accent, size: 18),
            SizedBox(width: 8),
            Text('Recent Purchases', style: AppTypography.h4.copyWith(color: AppColors.textPrimary(context))),
          ]),
          SizedBox(height: 12),
          if (provider.purchases.isEmpty)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: Text('No purchases yet',
                  style: AppTypography.bodyMedium.copyWith(color: AppColors.textTertiary(context)))),
            )
          else
            ...provider.purchases.take(10).map((p) => InkWell(
              onTap: () => _showPurchaseDetails(p),
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Row(children: [
                  Expanded(child: Text(p.vendorName, style: AppTypography.bodySmall.copyWith(color: AppColors.textPrimary(context)))),
                  Text(Formatters.currency(p.totalAmount),
                      style: AppTypography.mono.copyWith(color: AppColors.accent, fontSize: 12)),
                ]),
              ),
            )),
        ],
      ),
    );
  }
}

/// Internal model for purchase form entries
class _PurchaseEntry {
  final String itemId;
  final String name;
  int quantity;
  double costPrice;

  _PurchaseEntry({
    required this.itemId,
    required this.name,
    required this.quantity,
    required this.costPrice,
  });

  double get total => quantity * costPrice;
}
