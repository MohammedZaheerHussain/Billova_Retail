import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/formatters.dart';
import '../../providers/purchase_provider.dart';
import '../../providers/vendor_provider.dart';
import '../../providers/inventory_provider.dart';
import '../../data/models/vendor_model.dart';
import '../../data/models/purchase_model.dart';
import '../../data/models/item_model.dart';

class VendorDetailScreen extends StatelessWidget {
  final VendorModel vendor;
  const VendorDetailScreen({super.key, required this.vendor});

  @override
  Widget build(BuildContext context) {
    final purchaseProvider = context.watch<PurchaseProvider>();
    final summary = purchaseProvider.getVendorSummary(vendor.id);
    final purchases = purchaseProvider.getVendorPurchases(vendor.id);

    final totalPurchase = summary['totalPurchase'] as double;
    final totalPaid = summary['totalPaid'] as double;
    final pending = summary['pending'] as double;
    final totalItems = summary['totalItems'] as int;

    return Scaffold(
      backgroundColor: AppColors.scaffold(context),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary(context)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(vendor.name,
            style: AppTypography.h3.copyWith(color: AppColors.textPrimary(context))),
        actions: [
          if (pending > 0)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ElevatedButton.icon(
                onPressed: () => _showPaymentDialog(context, pending),
                icon: const Icon(Icons.payment_rounded, size: 16),
                label: const Text('Pay'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.error,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  textStyle: const TextStyle(fontSize: 13),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ElevatedButton.icon(
              onPressed: () => _showAddPurchaseDialog(context),
              icon: const Icon(Icons.add_rounded, size: 16),
              label: const Text('New Purchase'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                textStyle: const TextStyle(fontSize: 13),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSummarySection(context, totalPurchase, totalPaid, pending, totalItems),
            const SizedBox(height: 24),

            // Top Items Supplied
            if (purchases.isNotEmpty) ...[
              _buildTopItems(context, purchases),
              const SizedBox(height: 24),
            ],

            _buildPurchaseHistory(context, purchases),
          ],
        ),
      ),
    );
  }

  // ─── Summary Section ───
  Widget _buildSummarySection(BuildContext context, double totalPurchase, double totalPaid, double pending, int totalItems) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: Text(
                    vendor.name.isNotEmpty ? vendor.name[0].toUpperCase() : '?',
                    style: AppTypography.h3.copyWith(color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(vendor.name,
                        style: AppTypography.h4.copyWith(color: AppColors.textPrimary(context))),
                    if (vendor.phone.isNotEmpty)
                      Text('📞 ${vendor.phone}',
                          style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary(context))),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              _statBox(context, '💰 Total Purchase', Formatters.currency(totalPurchase), AppColors.primary),
              const SizedBox(width: 12),
              _statBox(context, '✅ Total Paid', Formatters.currency(totalPaid), AppColors.success),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _statBox(context, '⚠️ Pending', Formatters.currency(pending),
                  pending > 0 ? AppColors.error : AppColors.success),
              const SizedBox(width: 12),
              _statBox(context, '📦 Items Bought', '$totalItems pcs', AppColors.accent),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statBox(BuildContext context, String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: AppTypography.labelSmall.copyWith(
                    color: AppColors.textTertiary(context), fontSize: 10)),
            const SizedBox(height: 4),
            Text(value,
                style: AppTypography.mono.copyWith(
                    color: color, fontWeight: FontWeight.w700, fontSize: 16)),
          ],
        ),
      ),
    );
  }

  // ─── Top Items Supplied ───
  Widget _buildTopItems(BuildContext context, List<PurchaseModel> purchases) {
    // Aggregate items across all purchases
    final Map<String, int> itemCounts = {};
    for (final p in purchases) {
      for (final item in p.itemsList) {
        final name = (item['name'] ?? item['item_name'] ?? 'Item') as String;
        final qty = ((item['quantity'] as num?) ?? 0).toInt();
        itemCounts[name] = (itemCounts[name] ?? 0) + qty;
      }
    }
    if (itemCounts.isEmpty) return const SizedBox.shrink();

    final sorted = itemCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top = sorted.take(5);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Top Items Supplied',
              style: AppTypography.h4.copyWith(color: AppColors.textPrimary(context))),
          const SizedBox(height: 12),
          ...top.map((e) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(child: Text('📦', style: TextStyle(fontSize: 14))),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(e.key,
                      style: AppTypography.bodySmall.copyWith(
                          color: AppColors.textPrimary(context), fontWeight: FontWeight.w500)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text('${e.value} units',
                      style: AppTypography.mono.copyWith(
                          color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }

  // ─── Purchase History ───
  Widget _buildPurchaseHistory(BuildContext context, List<PurchaseModel> purchases) {
    if (purchases.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: AppColors.card(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.cardBorder(context)),
        ),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.receipt_long_rounded, size: 48,
                  color: AppColors.textTertiary(context).withValues(alpha: 0.3)),
              const SizedBox(height: 12),
              Text('No purchases yet',
                  style: AppTypography.bodyMedium.copyWith(color: AppColors.textTertiary(context))),
              const SizedBox(height: 4),
              Text('Tap "+ New Purchase" to record your first purchase',
                  style: AppTypography.bodySmall.copyWith(color: AppColors.textTertiary(context))),
            ],
          ),
        ),
      );
    }

    final Map<String, List<PurchaseModel>> grouped = {};
    for (final p in purchases) {
      final dateKey = p.createdAt.toIso8601String().substring(0, 10);
      grouped.putIfAbsent(dateKey, () => []);
      grouped[dateKey]!.add(p);
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Purchase History',
                  style: AppTypography.h4.copyWith(color: AppColors.textPrimary(context))),
              const Spacer(),
              Text('${purchases.length} records',
                  style: AppTypography.labelSmall.copyWith(
                      color: AppColors.textTertiary(context), fontSize: 10)),
            ],
          ),
          const SizedBox(height: 16),
          ...grouped.entries.map((entry) {
            final date = entry.key;
            final dayPurchases = entry.value;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text('📅 $date',
                      style: AppTypography.labelSmall.copyWith(
                          color: AppColors.accent, fontWeight: FontWeight.w700, fontSize: 11)),
                ),
                const SizedBox(height: 8),
                ...dayPurchases.map((p) => _purchaseEntry(context, p)),
                Divider(color: AppColors.cardBorder(context), height: 20),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _purchaseEntry(BuildContext context, PurchaseModel purchase) {
    final items = purchase.itemsList;
    final isPaid = purchase.isFullyPaid;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface(context),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Item details table
            ...items.map((item) {
              final name = item['name'] ?? item['item_name'] ?? 'Item';
              final qty = item['quantity'] ?? 0;
              final cost = (item['cost_price'] as num?)?.toDouble() ?? 0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Icon(Icons.inventory_2_rounded, size: 14, color: AppColors.accent),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(name.toString(),
                          style: AppTypography.bodySmall.copyWith(
                              color: AppColors.textPrimary(context), fontSize: 13)),
                    ),
                    Text('×$qty',
                        style: AppTypography.mono.copyWith(
                            color: AppColors.textSecondary(context), fontSize: 12)),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 80,
                      child: Text(Formatters.currency(cost * (qty as num).toInt()),
                          textAlign: TextAlign.right,
                          style: AppTypography.mono.copyWith(
                              color: AppColors.textPrimary(context), fontSize: 12)),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 8),
            // Bottom summary
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: (isPaid ? AppColors.success : AppColors.error).withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: (isPaid ? AppColors.success : AppColors.error).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      isPaid ? '✅ Paid' : '⚠️ Due: ${Formatters.currency(purchase.dueAmount)}',
                      style: AppTypography.labelSmall.copyWith(
                        color: isPaid ? AppColors.success : AppColors.error,
                        fontWeight: FontWeight.w700, fontSize: 10,
                      ),
                    ),
                  ),
                  if (purchase.paymentMode.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Text(purchase.paymentMode,
                        style: AppTypography.labelSmall.copyWith(
                            color: AppColors.textTertiary(context), fontSize: 10)),
                  ],
                  const Spacer(),
                  Text('Total: ${Formatters.currency(purchase.totalAmount)}',
                      style: AppTypography.mono.copyWith(
                          color: AppColors.textPrimary(context), fontWeight: FontWeight.w700, fontSize: 13)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Add Purchase Dialog ───
  void _showAddPurchaseDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => _AddPurchaseDialog(vendor: vendor),
    );
  }

  // ─── Payment Dialog ───
  void _showPaymentDialog(BuildContext context, double maxDue) {
    final amountCtrl = TextEditingController();
    String paymentMode = 'Cash';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Dialog(
          backgroundColor: AppColors.card(context),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          gradient: AppColors.primaryGradient,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.payment_rounded, color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Text('Record Payment',
                          style: AppTypography.h3.copyWith(color: AppColors.textPrimary(context))),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('Pending: ${Formatters.currency(maxDue)}',
                      style: AppTypography.bodySmall.copyWith(color: AppColors.error)),
                  const SizedBox(height: 20),
                  TextField(
                    controller: amountCtrl,
                    keyboardType: TextInputType.number,
                    autofocus: true,
                    style: TextStyle(color: AppColors.textPrimary(context)),
                    decoration: InputDecoration(
                      labelText: 'Amount (₹)',
                      labelStyle: TextStyle(color: AppColors.textSecondary(context)),
                      filled: true,
                      fillColor: AppColors.surface(context),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AppColors.cardBorder(context)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AppColors.cardBorder(context)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    children: ['Cash', 'UPI', 'Card'].map((mode) {
                      final isActive = paymentMode == mode;
                      return ChoiceChip(
                        label: Text(mode),
                        selected: isActive,
                        selectedColor: AppColors.primary.withValues(alpha: 0.15),
                        labelStyle: TextStyle(
                          color: isActive ? AppColors.primary : AppColors.textSecondary(context),
                          fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
                        ),
                        onSelected: (_) => setDialogState(() => paymentMode = mode),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () async {
                      final amount = double.tryParse(amountCtrl.text) ?? 0;
                      if (amount <= 0 || amount > maxDue) return;
                      final pp = context.read<PurchaseProvider>();
                      final vp = context.read<VendorProvider>();
                      await pp.recordVendorPayment(
                        vendorId: vendor.id, amount: amount,
                        paymentMode: paymentMode, vendorProvider: vp,
                      );
                      if (ctx.mounted) Navigator.pop(ctx);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text('₹${amount.toStringAsFixed(0)} paid to ${vendor.name}'),
                          backgroundColor: AppColors.success,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ));
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Record Payment'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Add Purchase Dialog (inline, lightweight) ───
class _AddPurchaseDialog extends StatefulWidget {
  final VendorModel vendor;
  const _AddPurchaseDialog({required this.vendor});

  @override
  State<_AddPurchaseDialog> createState() => _AddPurchaseDialogState();
}

class _PurchaseItem {
  String name;
  int quantity;
  double costPrice;
  String? itemId; // null for manual entries
  _PurchaseItem({required this.name, this.quantity = 1, this.costPrice = 0, this.itemId});
  double get total => quantity * costPrice;
}

class _AddPurchaseDialogState extends State<_AddPurchaseDialog> {
  final List<_PurchaseItem> _items = [];
  final _paidCtrl = TextEditingController(text: '0');
  String _paymentMode = 'Cash';
  bool _submitting = false;

  // Manual entry
  final _nameCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController(text: '1');
  final _priceCtrl = TextEditingController();

  double get _total => _items.fold(0, (s, i) => s + i.total);
  double get _paid => double.tryParse(_paidCtrl.text) ?? 0;
  double get _due => (_total - _paid).clamp(0, double.infinity);

  void _addManualItem() {
    final name = _nameCtrl.text.trim();
    final qty = int.tryParse(_qtyCtrl.text) ?? 1;
    final price = double.tryParse(_priceCtrl.text) ?? 0;
    if (name.isEmpty || price <= 0) return;

    setState(() {
      _items.add(_PurchaseItem(name: name, quantity: qty, costPrice: price));
      _nameCtrl.clear();
      _qtyCtrl.text = '1';
      _priceCtrl.clear();
    });
  }

  void _addFromInventory(ItemModel item) {
    final existing = _items.indexWhere((e) => e.itemId == item.id);
    if (existing != -1) {
      setState(() => _items[existing].quantity++);
    } else {
      setState(() => _items.add(_PurchaseItem(
        name: item.name,
        quantity: 1,
        costPrice: item.costPrice > 0 ? item.costPrice : item.price,
        itemId: item.id,
      )));
    }
  }

  Future<void> _submit() async {
    if (_items.isEmpty) return;
    setState(() => _submitting = true);

    final itemMaps = _items.map((i) => {
      'item_id': i.itemId ?? '',
      'name': i.name,
      'quantity': i.quantity,
      'cost_price': i.costPrice,
    }).toList();

    final pp = context.read<PurchaseProvider>();
    final vp = context.read<VendorProvider>();
    final ip = context.read<InventoryProvider>();

    await pp.addPurchase(
      vendorId: widget.vendor.id,
      vendorName: widget.vendor.name,
      items: itemMaps,
      totalAmount: _total,
      paidAmount: _paid,
      paymentMode: _paymentMode,
      inventoryProvider: ip,
      vendorProvider: vp,
    );

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Purchase of ${Formatters.currency(_total)} recorded'),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));
    }
  }

  @override
  void dispose() {
    _paidCtrl.dispose();
    _nameCtrl.dispose();
    _qtyCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final inventory = context.watch<InventoryProvider>();

    return Dialog(
      backgroundColor: AppColors.card(context),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 620),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.add_shopping_cart_rounded, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Record Purchase',
                            style: AppTypography.h3.copyWith(color: AppColors.textPrimary(context))),
                        Text('From ${widget.vendor.name}',
                            style: AppTypography.labelSmall.copyWith(
                                color: AppColors.textTertiary(context), fontSize: 10)),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close_rounded, color: AppColors.textTertiary(context)),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Quick add from inventory
              if (inventory.items.isNotEmpty)
                SizedBox(
                  height: 36,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: inventory.items.length > 10 ? 10 : inventory.items.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 6),
                    itemBuilder: (_, i) {
                      final item = inventory.items[i];
                      return ActionChip(
                        label: Text(item.name, style: const TextStyle(fontSize: 11)),
                        avatar: Icon(Icons.add, size: 14, color: AppColors.primary),
                        backgroundColor: AppColors.surface(context),
                        onPressed: () => _addFromInventory(item),
                      );
                    },
                  ),
                ),

              const SizedBox(height: 12),

              // Manual entry row
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: _miniField(_nameCtrl, 'Item Name'),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _miniField(_qtyCtrl, 'Qty', isNumber: true),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    flex: 2,
                    child: _miniField(_priceCtrl, 'Cost ₹', isNumber: true),
                  ),
                  const SizedBox(width: 6),
                  SizedBox(
                    width: 36, height: 36,
                    child: IconButton(
                      onPressed: _addManualItem,
                      icon: Icon(Icons.add_circle_rounded, color: AppColors.primary),
                      padding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Items list
              Flexible(
                child: _items.isEmpty
                    ? Center(
                        child: Text('Add items above',
                            style: AppTypography.bodySmall.copyWith(
                                color: AppColors.textTertiary(context))),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: _items.length,
                        itemBuilder: (_, i) {
                          final item = _items[i];
                          return Container(
                            margin: const EdgeInsets.only(bottom: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              color: AppColors.surface(context),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(item.name,
                                      style: AppTypography.bodySmall.copyWith(
                                          color: AppColors.textPrimary(context), fontSize: 12)),
                                ),
                                Text('×${item.quantity}',
                                    style: AppTypography.mono.copyWith(
                                        color: AppColors.textSecondary(context), fontSize: 11)),
                                const SizedBox(width: 8),
                                Text(Formatters.currency(item.total),
                                    style: AppTypography.mono.copyWith(
                                        color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w600)),
                                const SizedBox(width: 4),
                                GestureDetector(
                                  onTap: () => setState(() => _items.removeAt(i)),
                                  child: Icon(Icons.close_rounded, size: 16, color: AppColors.error),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),

              if (_items.isNotEmpty) ...[
                Divider(color: AppColors.cardBorder(context)),
                // Total row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Total', style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textSecondary(context))),
                    Text(Formatters.currency(_total),
                        style: AppTypography.mono.copyWith(
                            color: AppColors.textPrimary(context), fontWeight: FontWeight.w700, fontSize: 16)),
                  ],
                ),
                const SizedBox(height: 10),

                // Paid + mode
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _paidCtrl,
                        keyboardType: TextInputType.number,
                        onChanged: (_) => setState(() {}),
                        style: TextStyle(color: AppColors.textPrimary(context), fontSize: 13),
                        decoration: InputDecoration(
                          labelText: 'Paid ₹',
                          labelStyle: TextStyle(color: AppColors.textSecondary(context), fontSize: 11),
                          isDense: true,
                          filled: true,
                          fillColor: AppColors.surface(context),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: AppColors.cardBorder(context)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: AppColors.cardBorder(context)),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ...['Cash', 'UPI'].map((m) => Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: ChoiceChip(
                        label: Text(m, style: TextStyle(fontSize: 10)),
                        selected: _paymentMode == m,
                        visualDensity: VisualDensity.compact,
                        selectedColor: AppColors.primary.withValues(alpha: 0.15),
                        onSelected: (_) => setState(() => _paymentMode = m),
                      ),
                    )),
                  ],
                ),

                if (_due > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text('Due: ${Formatters.currency(_due)}',
                        style: AppTypography.mono.copyWith(color: AppColors.error, fontSize: 12)),
                  ),

                const SizedBox(height: 14),
                ElevatedButton(
                  onPressed: _submitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _submitting
                      ? const SizedBox(width: 20, height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text('Record Purchase — ${Formatters.currency(_total)}'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _miniField(TextEditingController ctrl, String hint, {bool isNumber = false}) {
    return TextField(
      controller: ctrl,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      style: TextStyle(color: AppColors.textPrimary(context), fontSize: 12),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: AppColors.textTertiary(context), fontSize: 11),
        isDense: true,
        filled: true,
        fillColor: AppColors.surface(context),
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: AppColors.cardBorder(context)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: AppColors.cardBorder(context)),
        ),
      ),
    );
  }
}
