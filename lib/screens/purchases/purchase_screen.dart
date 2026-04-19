import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/formatters.dart';
import '../../core/constants.dart';
import '../../providers/vendor_provider.dart';
import '../../providers/inventory_provider.dart';
import '../../providers/purchase_provider.dart';
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
    final priceCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          const Icon(Icons.add_circle_rounded, color: AppColors.accent, size: 20),
          const SizedBox(width: 8),
          Text('Quick Add Item', style: AppTypography.h4.copyWith(color: AppColors.textPrimaryDark)),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          _dialogField(nameCtrl, 'Item Name', 'e.g. Nike Air Max'),
          const SizedBox(height: 12),
          _dialogField(priceCtrl, 'Cost Price (₹)', '0', keyboardType: TextInputType.number),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty) return;
              final inv = context.read<InventoryProvider>();
              await inv.addItem(
                name: nameCtrl.text.trim(),
                price: double.tryParse(priceCtrl.text) ?? 0,
                costPrice: double.tryParse(priceCtrl.text) ?? 0,
                quantity: 0,
                vendor: _selectedVendor?.name ?? '',
              );
              if (ctx.mounted) Navigator.pop(ctx);
              // Add the newly created item to entries
              await inv.loadItems();
              final newItem = inv.items.firstWhere(
                (i) => i.name == nameCtrl.text.trim(),
                orElse: () => ItemModel(id: '', name: '', price: 0),
              );
              if (newItem.id.isNotEmpty) _addItemToEntries(newItem);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('Add', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showPurchaseDetails(PurchaseModel purchase) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: AppColors.cardDark,
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
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.receipt_long_rounded, color: Colors.white, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Purchase Details', style: AppTypography.h4.copyWith(color: AppColors.textPrimaryDark)),
                    Text(Formatters.dateTime(purchase.createdAt),
                        style: AppTypography.labelSmall.copyWith(color: AppColors.textTertiaryDark)),
                  ])),
                  IconButton(onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close_rounded, color: AppColors.textTertiaryDark)),
                ]),
                const SizedBox(height: 16),
                // Vendor
                _detailRow('Vendor', purchase.vendorName),
                _detailRow('Payment', purchase.paymentMode),
                const Divider(color: AppColors.cardBorderDark, height: 20),
                // Items
                Text('Items', style: AppTypography.labelMedium.copyWith(color: AppColors.textSecondaryDark)),
                const SizedBox(height: 8),
                ...purchase.itemsList.map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(children: [
                    Expanded(child: Text(item['name'] ?? '', style: const TextStyle(color: AppColors.textPrimaryDark, fontSize: 13))),
                    Text('×${item['quantity']}', style: AppTypography.mono.copyWith(color: AppColors.textSecondaryDark, fontSize: 12)),
                    const SizedBox(width: 8),
                    Text(Formatters.currency((item['total'] as num?)?.toDouble() ?? 0),
                        style: AppTypography.mono.copyWith(color: AppColors.accent, fontSize: 12)),
                  ]),
                )),
                const Divider(color: AppColors.cardBorderDark, height: 20),
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
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondaryDark)),
        Text(value, style: AppTypography.mono.copyWith(
          color: color ?? AppColors.textPrimaryDark,
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
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Text('Purchases (Inward Stock)',
                  style: AppTypography.h1.copyWith(color: AppColors.textPrimaryDark)),
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
                    const Icon(Icons.warning_rounded, size: 14, color: AppColors.error),
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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorderDark),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Text('New Purchase', style: AppTypography.h3.copyWith(color: AppColors.textPrimaryDark)),
            const Spacer(),
            // Quick add item button
            TextButton.icon(
              onPressed: _showQuickAddItem,
              icon: const Icon(Icons.add_rounded, size: 16),
              label: const Text('New Item', style: TextStyle(fontSize: 12)),
              style: TextButton.styleFrom(foregroundColor: AppColors.accent),
            ),
          ]),
          const SizedBox(height: 16),

          // ─── Vendor Selector ───
          Row(children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                value: _selectedVendor?.id,
                decoration: _inputDecor('Select Vendor'),
                dropdownColor: AppColors.surfaceDark,
                style: const TextStyle(color: AppColors.textPrimaryDark),
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
          const SizedBox(height: 16),

          // ─── Item Search ───
          TextField(
            controller: _itemSearchCtrl,
            onChanged: (v) => setState(() => _itemSearch = v),
            style: const TextStyle(color: AppColors.textPrimaryDark),
            decoration: InputDecoration(
              labelText: 'Search items to add',
              hintText: 'Type item name or barcode...',
              labelStyle: const TextStyle(color: AppColors.textSecondaryDark, fontSize: 13),
              hintStyle: const TextStyle(color: AppColors.textTertiaryDark),
              prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textTertiaryDark),
              suffixIcon: const Icon(Icons.qr_code_scanner_rounded, size: 18, color: AppColors.textTertiaryDark),
              filled: true,
              fillColor: AppColors.surfaceDark,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.cardBorderDark)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.cardBorderDark)),
            ),
          ),

          // Search Results
          if (searchResults.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 4),
              constraints: const BoxConstraints(maxHeight: 200),
              decoration: BoxDecoration(
                color: AppColors.surfaceDark,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.cardBorderDark),
              ),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: searchResults.length,
                itemBuilder: (_, i) {
                  final item = searchResults[i];
                  return ListTile(
                    dense: true,
                    title: Text(item.name, style: const TextStyle(color: AppColors.textPrimaryDark, fontSize: 14)),
                    subtitle: Text('Stock: ${item.quantity} • ${Formatters.currency(item.costPrice > 0 ? item.costPrice : item.price)}',
                        style: AppTypography.labelSmall.copyWith(color: AppColors.textTertiaryDark)),
                    trailing: IconButton(
                      onPressed: () => _addItemToEntries(item),
                      icon: const Icon(Icons.add_circle_rounded, color: AppColors.accent),
                    ),
                  );
                },
              ),
            ),

          // Low stock suggestions
          if (_entries.isEmpty && lowStockItems.isNotEmpty && _itemSearch.isEmpty) ...[
            const SizedBox(height: 12),
            Row(children: [
              const Icon(Icons.lightbulb_rounded, size: 14, color: AppColors.warning),
              const SizedBox(width: 6),
              Text('Low Stock — Suggested Purchases',
                  style: AppTypography.labelSmall.copyWith(color: AppColors.warning, fontWeight: FontWeight.w600)),
            ]),
            const SizedBox(height: 6),
            Wrap(spacing: 6, runSpacing: 6, children: lowStockItems.map((item) =>
              ActionChip(
                label: Text('${item.name} (${item.quantity})', style: const TextStyle(fontSize: 11)),
                avatar: Icon(item.isOutOfStock ? Icons.error_rounded : Icons.warning_rounded,
                    size: 14, color: item.isOutOfStock ? AppColors.error : AppColors.warning),
                onPressed: () => _addItemToEntries(item),
                backgroundColor: AppColors.surfaceDark,
                side: BorderSide(color: item.isOutOfStock ? AppColors.error.withValues(alpha: 0.3) : AppColors.warning.withValues(alpha: 0.3)),
              ),
            ).toList()),
          ],

          const SizedBox(height: 16),

          // ─── Entries Table ───
          if (_entries.isNotEmpty) ...[
            // Table header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
              ),
              child: Row(children: [
                const Expanded(flex: 3, child: Text('Item', style: TextStyle(color: AppColors.textSecondaryDark, fontSize: 12, fontWeight: FontWeight.w600))),
                const SizedBox(width: 80, child: Center(child: Text('Qty', style: TextStyle(color: AppColors.textSecondaryDark, fontSize: 12, fontWeight: FontWeight.w600)))),
                const SizedBox(width: 8),
                const SizedBox(width: 80, child: Center(child: Text('Cost ₹', style: TextStyle(color: AppColors.textSecondaryDark, fontSize: 12, fontWeight: FontWeight.w600)))),
                const SizedBox(width: 8),
                const SizedBox(width: 80, child: Text('Total', textAlign: TextAlign.right, style: TextStyle(color: AppColors.textSecondaryDark, fontSize: 12, fontWeight: FontWeight.w600))),
                const SizedBox(width: 28),
              ]),
            ),
            ..._entries.asMap().entries.map((e) => _entryRow(e.key, e.value)),
            const Divider(color: AppColors.cardBorderDark, height: 24),

            // Totals summary
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surfaceDark,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
              ),
              child: Column(children: [
                _totalRow('Total Amount', Formatters.currency(_totalAmount), isBold: true),
              ]),
            ),
            const SizedBox(height: 12),

            // ─── Payment Section ───
            Row(children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _paymentMode,
                  decoration: _inputDecor('Payment Mode'),
                  dropdownColor: AppColors.surfaceDark,
                  style: const TextStyle(color: AppColors.textPrimaryDark),
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
              const SizedBox(width: 12),
              SizedBox(
                width: 130,
                child: TextFormField(
                  controller: _paidCtrl,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setState(() {}),
                  style: const TextStyle(color: AppColors.textPrimaryDark),
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
                    const Icon(Icons.warning_rounded, size: 16, color: AppColors.error),
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
                    : const Icon(Icons.inventory_rounded, size: 20),
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
      margin: const EdgeInsets.only(bottom: 2),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: index.isEven ? AppColors.surfaceDark : Colors.transparent,
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(entry.name, style: const TextStyle(color: AppColors.textPrimaryDark, fontSize: 14)),
          ),
          // Qty controls
          SizedBox(
            width: 80,
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              _smallIconBtn(Icons.remove, () => setState(() {
                if (entry.quantity > 1) entry.quantity--;
              })),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Text('${entry.quantity}', style: AppTypography.mono.copyWith(color: AppColors.textPrimaryDark, fontSize: 13)),
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
                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                filled: true,
                fillColor: AppColors.cardDark,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide.none),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 80,
            child: Text(Formatters.currency(entry.total),
                style: AppTypography.mono.copyWith(color: AppColors.textPrimaryDark, fontSize: 13),
                textAlign: TextAlign.right),
          ),
          IconButton(
            onPressed: () => setState(() => _entries.removeAt(index)),
            icon: const Icon(Icons.close_rounded, size: 18, color: AppColors.error),
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
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: AppTypography.bodyMedium.copyWith(
          color: color ?? AppColors.textSecondaryDark,
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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorderDark),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.history_rounded, color: AppColors.accent, size: 18),
            const SizedBox(width: 8),
            Text('Recent Purchases', style: AppTypography.h4.copyWith(color: AppColors.textPrimaryDark)),
            if (provider.purchases.isNotEmpty) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: AppColors.accent.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(10)),
                child: Text('${provider.purchases.length}',
                    style: AppTypography.labelSmall.copyWith(color: AppColors.accent, fontWeight: FontWeight.w700)),
              ),
            ],
          ]),
          const SizedBox(height: 12),
          Flexible(
            child: provider.purchases.isEmpty
                ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.receipt_long_rounded, size: 48, color: AppColors.textTertiaryDark.withValues(alpha: 0.4)),
                    const SizedBox(height: 8),
                    Text('No purchases yet', style: AppTypography.bodyMedium.copyWith(color: AppColors.textTertiaryDark)),
                  ]))
                : ListView.separated(
                    itemCount: provider.purchases.length,
                    separatorBuilder: (_, __) => const Divider(color: AppColors.cardBorderDark, height: 1),
                    itemBuilder: (_, i) {
                      final p = provider.purchases[i];
                      return InkWell(
                        onTap: () => _showPurchaseDetails(p),
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
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
                            const SizedBox(width: 10),
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(p.vendorName, style: AppTypography.bodyMedium.copyWith(
                                  color: AppColors.textPrimaryDark, fontWeight: FontWeight.w500)),
                              Text('${p.itemsList.length} items • ${Formatters.dateShort(p.createdAt)}',
                                  style: AppTypography.labelSmall.copyWith(color: AppColors.textTertiaryDark)),
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
      labelStyle: const TextStyle(color: AppColors.textSecondaryDark, fontSize: 13),
      filled: true,
      fillColor: AppColors.surfaceDark,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.cardBorderDark)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.cardBorderDark)),
    );
  }

  Widget _dialogField(TextEditingController ctrl, String label, String hint, {TextInputType? keyboardType}) {
    return TextField(
      controller: ctrl,
      keyboardType: keyboardType,
      style: const TextStyle(color: AppColors.textPrimaryDark),
      decoration: _inputDecor(label).copyWith(hintText: hint, hintStyle: const TextStyle(color: AppColors.textTertiaryDark, fontSize: 13)),
    );
  }

  /// Compact version for non-wide layout (no Expanded — safe in SingleChildScrollView)
  Widget _buildRecentPurchasesCompact(PurchaseProvider provider) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorderDark),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.history_rounded, color: AppColors.accent, size: 18),
            const SizedBox(width: 8),
            Text('Recent Purchases', style: AppTypography.h4.copyWith(color: AppColors.textPrimaryDark)),
          ]),
          const SizedBox(height: 12),
          if (provider.purchases.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(child: Text('No purchases yet',
                  style: AppTypography.bodyMedium.copyWith(color: AppColors.textTertiaryDark))),
            )
          else
            ...provider.purchases.take(10).map((p) => InkWell(
              onTap: () => _showPurchaseDetails(p),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(children: [
                  Expanded(child: Text(p.vendorName, style: AppTypography.bodySmall.copyWith(color: AppColors.textPrimaryDark))),
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
