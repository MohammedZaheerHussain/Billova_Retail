import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/formatters.dart';
import '../../providers/inventory_provider.dart';
import '../../providers/clearance_provider.dart';
import '../../data/models/item_model.dart';

class ClearanceStockScreen extends StatefulWidget {
  const ClearanceStockScreen({super.key});
  @override
  State<ClearanceStockScreen> createState() => _ClearanceStockScreenState();
}

class _ClearanceStockScreenState extends State<ClearanceStockScreen> {
  String _filter = 'All';
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';
  static const _reasons = ['Damaged', 'Slow Moving', 'Old Season', 'Returned Defective', 'End of Line'];

  @override
  void dispose() { _searchCtrl.dispose(); super.dispose(); }

  List<ItemModel> _getClearanceItems(InventoryProvider inv) {
    final now = DateTime.now();
    var items = <ItemModel>[];
    for (final item in inv.items) {
      final age = now.difference(item.createdAt).inDays;
      final isClearance = item.storageLocation.startsWith('CLEARANCE:');
      final isOld = age > 90;
      final isLow = item.isLowStock && item.quantity > 0;
      final isDead = item.quantity == 0;

      if (_filter == 'All' && (isClearance || isOld || isLow || isDead)) {
        items.add(item);
      } else if (_filter == 'Manual' && isClearance) {
        items.add(item);
      } else if (_filter == 'Old Season' && isOld) {
        items.add(item);
      } else if (_filter == 'Low Stock' && isLow) {
        items.add(item);
      } else if (_filter == 'Dead Stock' && isDead) {
        items.add(item);
      }
    }
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      items = items.where((i) =>
          i.name.toLowerCase().contains(q) ||
          i.barcode.toLowerCase().contains(q) ||
          i.category.toLowerCase().contains(q)).toList();
    }
    return items;
  }

  // ─── Add from Inventory picker ───
  void _showAddToClearance() {
    final inv = context.read<InventoryProvider>();
    final pickerSearch = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, ss) {
        final q = pickerSearch.text.toLowerCase();
        // Show only items NOT already in clearance and with stock > 0
        final available = inv.items.where((i) =>
            !i.storageLocation.startsWith('CLEARANCE:') &&
            i.parentItemId.isEmpty &&  // exclude clearance copies
            i.quantity > 0 &&
            (q.isEmpty || i.name.toLowerCase().contains(q) ||
             i.barcode.toLowerCase().contains(q) ||
             i.category.toLowerCase().contains(q))).toList();

        return Dialog(
          backgroundColor: AppColors.card(context),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520, maxHeight: 560),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                // Header
                Row(children: [
                  Container(padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(gradient: AppColors.primaryGradient, borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.add_shopping_cart_rounded, color: Colors.white, size: 20)),
                  const SizedBox(width: 12),
                  Text('Add to Clearance', style: AppTypography.h3.copyWith(color: AppColors.textPrimary(context))),
                  const Spacer(),
                  IconButton(onPressed: () => Navigator.pop(ctx), icon: Icon(Icons.close_rounded, color: AppColors.textTertiary(context))),
                ]),
                const SizedBox(height: 12),
                // Search
                TextField(
                  controller: pickerSearch,
                  onChanged: (_) => ss(() {}),
                  style: TextStyle(color: AppColors.textPrimary(context), fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Search inventory by name, barcode, category...',
                    hintStyle: TextStyle(color: AppColors.textTertiary(context), fontSize: 12),
                    prefixIcon: Icon(Icons.search_rounded, color: AppColors.textTertiary(context)),
                    filled: true, fillColor: AppColors.surface(context),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppColors.cardBorder(context))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppColors.cardBorder(context))),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
                const SizedBox(height: 8),
                Text('${available.length} items available', style: TextStyle(color: AppColors.textTertiary(context), fontSize: 11)),
                const SizedBox(height: 8),
                // List
                Expanded(
                  child: available.isEmpty
                    ? Center(child: Text('No items found', style: TextStyle(color: AppColors.textTertiary(context))))
                    : ListView.separated(
                        itemCount: available.length,
                        separatorBuilder: (_, __) => Divider(color: AppColors.cardBorder(context), height: 1),
                        itemBuilder: (_, i) {
                          final item = available[i];
                          return ListTile(
                            dense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            leading: CircleAvatar(
                              radius: 18, backgroundColor: AppColors.accent.withValues(alpha: 0.1),
                              child: Text(item.name[0].toUpperCase(), style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.w700, fontSize: 14)),
                            ),
                            title: Text(item.name, style: TextStyle(color: AppColors.textPrimary(context), fontSize: 13, fontWeight: FontWeight.w500)),
                            subtitle: Text('${item.category} • ${Formatters.currency(item.price)} • Qty: ${item.quantity}',
                                style: TextStyle(color: AppColors.textTertiary(context), fontSize: 11)),
                            trailing: ElevatedButton.icon(
                              onPressed: () {
                                Navigator.pop(ctx);
                                _showClearanceDialog(item);
                              },
                              icon: const Icon(Icons.local_offer_rounded, size: 14),
                              label: const Text('Select', style: TextStyle(fontSize: 11)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.warning, foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                            ),
                          );
                        }),
                ),
              ]),
            ),
          ),
        );
      }),
    );
  }

  // ─── Mark for clearance dialog (with quantity picker) ───
  void _showClearanceDialog(ItemModel item) {
    String reason = _reasons[0];
    final cpCtrl = TextEditingController(text: (item.price * 0.5).toStringAsFixed(0));
    final qtyCtrl = TextEditingController(text: '${item.quantity}');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, ss) {
        final cp = double.tryParse(cpCtrl.text) ?? 0;
        final qty = int.tryParse(qtyCtrl.text) ?? item.quantity;
        final disc = item.price > 0 ? ((1 - cp / item.price) * 100).clamp(0.0, 100.0) : 0.0;

        return AlertDialog(
          backgroundColor: AppColors.card(context),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(children: [
            Icon(Icons.local_offer_rounded, color: AppColors.warning, size: 22),
            const SizedBox(width: 8),
            Text('Mark for Clearance', style: AppTypography.h4.copyWith(color: AppColors.textPrimary(context))),
          ]),
          content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(item.name, style: AppTypography.bodyMedium.copyWith(color: AppColors.textPrimary(context), fontWeight: FontWeight.w600)),
            Text('Current: ${Formatters.currency(item.price)} • Stock: ${item.quantity}',
                style: AppTypography.labelSmall.copyWith(color: AppColors.textTertiary(context))),
            const SizedBox(height: 16),

            // ─── Quantity to Move ───
            Text('Quantity to Move', style: AppTypography.labelSmall.copyWith(color: AppColors.textSecondary(context))),
            const SizedBox(height: 4),
            Row(children: [
              Expanded(
                child: TextField(
                  controller: qtyCtrl, keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.w700, fontSize: 16),
                  onChanged: (_) => ss(() {}),
                  decoration: InputDecoration(
                    filled: true, fillColor: AppColors.surface(context),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppColors.cardBorder(context))),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text('of ${item.quantity} items', style: TextStyle(color: AppColors.textTertiary(context), fontSize: 12)),
            ]),
            if (qty > 0 && qty < item.quantity)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('${item.quantity - qty} will remain in regular inventory',
                    style: TextStyle(color: AppColors.success, fontSize: 10, fontWeight: FontWeight.w500)),
              ),
            const SizedBox(height: 12),

            // ─── Reason ───
            Text('Reason', style: AppTypography.labelSmall.copyWith(color: AppColors.textSecondary(context))),
            const SizedBox(height: 4),
            DropdownButtonFormField<String>(
              value: reason, dropdownColor: AppColors.card(context),
              style: TextStyle(color: AppColors.textPrimary(context), fontSize: 13),
              items: _reasons.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
              onChanged: (v) => ss(() => reason = v!),
              decoration: InputDecoration(
                filled: true, fillColor: AppColors.surface(context),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppColors.cardBorder(context))),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
            ),
            const SizedBox(height: 12),

            // ─── Clearance Price ───
            Text('Clearance Price (₹)', style: AppTypography.labelSmall.copyWith(color: AppColors.textSecondary(context))),
            const SizedBox(height: 4),
            TextField(
              controller: cpCtrl, keyboardType: TextInputType.number,
              style: TextStyle(color: AppColors.textPrimary(context), fontSize: 14),
              onChanged: (_) => ss(() {}),
              decoration: InputDecoration(
                filled: true, fillColor: AppColors.surface(context),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppColors.cardBorder(context))),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                suffixText: '${disc.toStringAsFixed(0)}% off',
                suffixStyle: TextStyle(color: AppColors.error, fontWeight: FontWeight.w700, fontSize: 12)),
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: TextStyle(color: AppColors.textTertiary(context)))),
            ElevatedButton(
              onPressed: (qty < 1 || qty > item.quantity || cp <= 0) ? null : () async {
                final clearanceProvider = context.read<ClearanceProvider>();
                final inv = context.read<InventoryProvider>();

                await clearanceProvider.splitForClearance(
                  originalItem: item,
                  qty: qty,
                  clearancePrice: cp,
                  reason: reason,
                  inventoryProvider: inv,
                );

                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('$qty × ${item.name} moved to clearance at ${Formatters.currency(cp)}'),
                    backgroundColor: AppColors.warning, behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))));
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.warning, foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              child: const Text('Mark Clearance'),
            ),
          ],
        );
      }),
    );
  }

  // ─── Edit clearance item ───
  void _showEditClearanceDialog(ItemModel item) {
    final clearanceProvider = context.read<ClearanceProvider>();
    final inv = context.read<InventoryProvider>();
    final record = clearanceProvider.findByItemId(item.id);
    if (record == null) return;

    // Find original item to compute max available qty
    final originalItem = inv.items.firstWhere(
      (i) => i.id == record.originalItemId,
      orElse: () => ItemModel(id: '', name: '', price: 0),
    );
    final maxQty = item.quantity + originalItem.quantity; // current clearance + remaining original

    String reason = item.storageLocation.replaceFirst('CLEARANCE: ', '');
    if (!_reasons.contains(reason)) reason = _reasons[0];
    final cpCtrl = TextEditingController(text: item.price.toStringAsFixed(0));
    final qtyCtrl = TextEditingController(text: '${item.quantity}');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, ss) {
        final cp = double.tryParse(cpCtrl.text) ?? 0;
        final qty = int.tryParse(qtyCtrl.text) ?? item.quantity;
        final origPrice = item.originalPrice > 0 ? item.originalPrice : record.originalPrice;
        final disc = origPrice > 0 ? ((1 - cp / origPrice) * 100).clamp(0.0, 100.0) : 0.0;
        final isValid = qty >= 1 && qty <= maxQty && cp > 0;

        return AlertDialog(
          backgroundColor: AppColors.card(context),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(children: [
            Icon(Icons.edit_rounded, color: AppColors.accent, size: 22),
            const SizedBox(width: 8),
            Text('Edit Clearance', style: AppTypography.h4.copyWith(color: AppColors.textPrimary(context))),
          ]),
          content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(item.name, style: AppTypography.bodyMedium.copyWith(color: AppColors.textPrimary(context), fontWeight: FontWeight.w600)),
            Text('Original MRP: ${Formatters.currency(origPrice)}',
                style: AppTypography.labelSmall.copyWith(color: AppColors.textTertiary(context))),
            const SizedBox(height: 16),

            // Quantity
            Text('Clearance Quantity', style: AppTypography.labelSmall.copyWith(color: AppColors.textSecondary(context))),
            const SizedBox(height: 4),
            Row(children: [
              Expanded(
                child: TextField(
                  controller: qtyCtrl, keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.w700, fontSize: 16),
                  onChanged: (_) => ss(() {}),
                  decoration: InputDecoration(
                    filled: true, fillColor: AppColors.surface(context),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppColors.cardBorder(context))),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text('of $maxQty max', style: TextStyle(color: AppColors.textTertiary(context), fontSize: 12)),
            ]),
            if (qty != item.quantity && qty >= 1 && qty <= maxQty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  qty > item.quantity
                      ? '${qty - item.quantity} more moving to clearance'
                      : '${item.quantity - qty} returning to inventory',
                  style: TextStyle(
                      color: qty > item.quantity ? AppColors.warning : AppColors.success,
                      fontSize: 10, fontWeight: FontWeight.w500)),
              ),
            const SizedBox(height: 12),

            // Reason
            Text('Reason', style: AppTypography.labelSmall.copyWith(color: AppColors.textSecondary(context))),
            const SizedBox(height: 4),
            DropdownButtonFormField<String>(
              value: reason, dropdownColor: AppColors.card(context),
              style: TextStyle(color: AppColors.textPrimary(context), fontSize: 13),
              items: _reasons.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
              onChanged: (v) => ss(() => reason = v!),
              decoration: InputDecoration(
                filled: true, fillColor: AppColors.surface(context),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppColors.cardBorder(context))),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
            ),
            const SizedBox(height: 12),

            // Price
            Text('Clearance Price (₹)', style: AppTypography.labelSmall.copyWith(color: AppColors.textSecondary(context))),
            const SizedBox(height: 4),
            TextField(
              controller: cpCtrl, keyboardType: TextInputType.number,
              style: TextStyle(color: AppColors.textPrimary(context), fontSize: 14),
              onChanged: (_) => ss(() {}),
              decoration: InputDecoration(
                filled: true, fillColor: AppColors.surface(context),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppColors.cardBorder(context))),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                suffixText: '${disc.toStringAsFixed(0)}% off',
                suffixStyle: TextStyle(color: AppColors.error, fontWeight: FontWeight.w700, fontSize: 12)),
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: TextStyle(color: AppColors.textTertiary(context)))),
            ElevatedButton.icon(
              onPressed: !isValid ? null : () async {
                try {
                  await clearanceProvider.updateClearanceItem(
                    record: record,
                    newPrice: cp,
                    newQty: qty,
                    newReason: reason,
                    inventoryProvider: inv,
                  );
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('${item.name} clearance updated'),
                      backgroundColor: AppColors.accent, behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))));
                  }
                } catch (e) {
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('Error: $e'),
                      backgroundColor: AppColors.error, behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))));
                  }
                }
              },
              icon: const Icon(Icons.save_rounded, size: 16),
              label: const Text('Save Changes'),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent, foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            ),
          ],
        );
      }),
    );
  }

  // ─── Remove from clearance (restore to inventory) ───
  void _removeClearance(ItemModel item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Restore to Inventory?', style: AppTypography.h4.copyWith(color: AppColors.textPrimary(context))),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Move "${item.name}" back to regular inventory?',
              style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary(context))),
          const SizedBox(height: 8),
          Text('${item.quantity} units at ${Formatters.currency(item.originalPrice > 0 ? item.originalPrice : item.price)} will be restored.',
              style: TextStyle(color: AppColors.textTertiary(context), fontSize: 11)),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final clearanceProvider = context.read<ClearanceProvider>();
              final inv = context.read<InventoryProvider>();

              // Find the audit record for this clearance item
              final record = clearanceProvider.findByItemId(item.id);
              if (record != null) {
                await clearanceProvider.restoreFromClearance(
                  record: record,
                  inventoryProvider: inv,
                );
              } else {
                // Legacy clearance item (no audit record) — just reset storageLocation
                await inv.updateItem(item.copyWith(storageLocation: ''));
              }

              if (ctx.mounted) Navigator.pop(ctx);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text('${item.name} restored to inventory'),
                  backgroundColor: AppColors.success, behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))));
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.success, foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            child: const Text('Restore'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inv = context.watch<InventoryProvider>();
    final items = _getClearanceItems(inv);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Header + Add button
          Row(children: [
            Text('Clearance Stock', style: AppTypography.h1.copyWith(
                color: isDark ? AppColors.textPrimary(context) : AppColors.textPrimaryLight)),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: AppColors.warning.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
              child: Text('${items.length} items', style: AppTypography.labelSmall.copyWith(color: AppColors.warning, fontWeight: FontWeight.w700)),
            ),
            const Spacer(),
            ElevatedButton.icon(
              onPressed: _showAddToClearance,
              icon: const Icon(Icons.add_rounded, size: 20),
              label: const Text('Add to Clearance'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.warning, foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            ),
          ]),
          const SizedBox(height: 16),

          // Search + Filters
          Row(children: [
            Expanded(child: TextField(
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _searchQuery = v),
              style: TextStyle(color: AppColors.textPrimary(context), fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Search clearance items...', hintStyle: TextStyle(color: AppColors.textTertiary(context), fontSize: 12),
                prefixIcon: Icon(Icons.search_rounded, color: AppColors.textTertiary(context)),
                filled: true, fillColor: isDark ? AppColors.surface(context) : Colors.grey.shade50,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.cardBorder(context))),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.cardBorder(context))),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
            )),
            const SizedBox(width: 12),
            ...['All', 'Manual', 'Old Season', 'Low Stock', 'Dead Stock'].map((f) =>
              Padding(padding: const EdgeInsets.only(right: 6), child: GestureDetector(
                onTap: () => setState(() => _filter = f),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: _filter == f ? AppColors.warning.withValues(alpha: 0.2) : AppColors.surface(context),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _filter == f ? AppColors.warning : AppColors.cardBorder(context))),
                  child: Text(f, style: AppTypography.labelSmall.copyWith(
                      color: _filter == f ? AppColors.warning : AppColors.textSecondary(context),
                      fontWeight: _filter == f ? FontWeight.w700 : FontWeight.w400)),
                ),
              ))),
          ]),
          const SizedBox(height: 16),

          // Items list
          Expanded(
            child: items.isEmpty
              ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.check_circle_outline_rounded, size: 64, color: AppColors.success.withValues(alpha: 0.3)),
                  const SizedBox(height: 12),
                  Text('No clearance items found', style: AppTypography.bodyMedium.copyWith(color: AppColors.textTertiary(context))),
                  const SizedBox(height: 4),
                  Text('Tap "Add to Clearance" to select items from inventory',
                      style: AppTypography.labelSmall.copyWith(color: AppColors.textTertiary(context))),
                ]))
              : Container(
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.card(context) : AppColors.cardLight,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: isDark ? AppColors.cardBorder(context) : AppColors.cardBorderLight)),
                  child: ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => Divider(color: AppColors.cardBorder(context), height: 1),
                    itemBuilder: (_, i) {
                      final item = items[i];
                      final age = DateTime.now().difference(item.createdAt).inDays;
                      final isClearance = item.storageLocation.startsWith('CLEARANCE:');
                      final reason = isClearance ? item.storageLocation.replaceFirst('CLEARANCE: ', '') : '';

                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        leading: Container(
                          width: 40, height: 40,
                          decoration: BoxDecoration(
                            color: isClearance ? AppColors.warning.withValues(alpha: 0.15)
                                : item.quantity == 0 ? AppColors.error.withValues(alpha: 0.15)
                                : AppColors.accent.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10)),
                          child: Icon(
                            isClearance ? Icons.local_offer_rounded : item.quantity == 0 ? Icons.block_rounded : Icons.warning_amber_rounded,
                            size: 20,
                            color: isClearance ? AppColors.warning : item.quantity == 0 ? AppColors.error : AppColors.accent),
                        ),
                        title: Text(item.name, style: AppTypography.bodyMedium.copyWith(
                            color: AppColors.textPrimary(context), fontWeight: FontWeight.w500)),
                        subtitle: Row(children: [
                          Text('${item.category.isNotEmpty ? '${item.category} • ' : ''}${age}d old • Qty: ${item.quantity}',
                              style: AppTypography.labelSmall.copyWith(color: AppColors.textTertiary(context))),
                          if (isClearance) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: AppColors.warning.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4)),
                              child: Text(reason, style: AppTypography.labelSmall.copyWith(
                                  color: AppColors.warning, fontWeight: FontWeight.w700, fontSize: 9)),
                            ),
                          ],
                          if (isClearance && item.originalPrice > 0) ...[
                            const SizedBox(width: 6),
                            Text('was ${Formatters.currency(item.originalPrice)}',
                                style: TextStyle(color: AppColors.textTertiary(context), fontSize: 9,
                                    decoration: TextDecoration.lineThrough)),
                          ],
                        ]),
                        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                          Text(Formatters.currency(item.price), style: AppTypography.mono.copyWith(
                              color: isClearance ? AppColors.warning : AppColors.accent, fontWeight: FontWeight.w700)),
                          const SizedBox(width: 4),
                          if (isClearance) ...[
                            IconButton(icon: Icon(Icons.edit_rounded, size: 18, color: AppColors.accent),
                              tooltip: 'Edit Clearance', onPressed: () => _showEditClearanceDialog(item)),
                            IconButton(icon: Icon(Icons.restore_rounded, size: 20, color: AppColors.success),
                              tooltip: 'Remove from Clearance', onPressed: () => _removeClearance(item)),
                          ] else
                            IconButton(icon: Icon(Icons.local_offer_rounded, size: 20, color: AppColors.warning),
                              tooltip: 'Mark for Clearance', onPressed: () => _showClearanceDialog(item)),
                        ]),
                      );
                    }),
                ),
          ),
        ]),
      ),
    );
  }
}
