import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/formatters.dart';
import '../../providers/inventory_provider.dart';
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

  // Clearance reasons
  static const _reasons = ['Damaged', 'Slow Moving', 'Old Season', 'Returned Defective', 'End of Line'];

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<ItemModel> _getClearanceItems(InventoryProvider inventory) {
    var items = inventory.items.toList();

    // Show items that are: low stock, old (>90 days), or zero quantity
    List<ItemModel> clearanceItems = [];
    final now = DateTime.now();

    for (final item in items) {
      final age = now.difference(item.createdAt).inDays;
      final isOld = age > 90;
      final isLowStock = item.isLowStock && item.quantity > 0;
      final isDead = item.quantity == 0;

      if (_filter == 'All' && (isOld || isLowStock || isDead)) {
        clearanceItems.add(item);
      } else if (_filter == 'Old Season' && isOld) {
        clearanceItems.add(item);
      } else if (_filter == 'Low Stock' && isLowStock) {
        clearanceItems.add(item);
      } else if (_filter == 'Dead Stock' && isDead) {
        clearanceItems.add(item);
      }
    }

    // Search filter
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      clearanceItems = clearanceItems.where((i) =>
          i.name.toLowerCase().contains(q) ||
          i.barcode.toLowerCase().contains(q) ||
          i.category.toLowerCase().contains(q)
      ).toList();
    }

    return clearanceItems;
  }

  void _showClearanceDialog(ItemModel item) {
    String reason = _reasons[0];
    final clearancePriceCtrl = TextEditingController(
        text: (item.price * 0.5).toStringAsFixed(0)); // Default 50% off
    final discount = ((1 - 0.5) * 100).toStringAsFixed(0);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final clearancePrice = double.tryParse(clearancePriceCtrl.text) ?? 0;
          final discountPct = item.price > 0
              ? ((1 - clearancePrice / item.price) * 100).clamp(0.0, 100.0)
              : 0.0;

          return AlertDialog(
            backgroundColor: AppColors.card(context),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(children: [
              Icon(Icons.local_offer_rounded, color: AppColors.warning, size: 22),
              const SizedBox(width: 8),
              Text('Mark for Clearance', style: AppTypography.h4.copyWith(
                  color: AppColors.textPrimary(context))),
            ]),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.name, style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textPrimary(context), fontWeight: FontWeight.w600)),
                Text('Current Price: ${Formatters.currency(item.price)} • Stock: ${item.quantity}',
                    style: AppTypography.labelSmall.copyWith(color: AppColors.textTertiary(context))),
                const SizedBox(height: 16),
                Text('Reason', style: AppTypography.labelSmall.copyWith(
                    color: AppColors.textSecondary(context))),
                const SizedBox(height: 4),
                DropdownButtonFormField<String>(
                  value: reason,
                  dropdownColor: AppColors.card(context),
                  style: TextStyle(color: AppColors.textPrimary(context), fontSize: 13),
                  items: _reasons.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                  onChanged: (v) => setDialogState(() => reason = v!),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: AppColors.surface(context),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: AppColors.cardBorder(context))),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
                const SizedBox(height: 12),
                Text('Clearance Price (₹)', style: AppTypography.labelSmall.copyWith(
                    color: AppColors.textSecondary(context))),
                const SizedBox(height: 4),
                TextField(
                  controller: clearancePriceCtrl,
                  keyboardType: TextInputType.number,
                  style: TextStyle(color: AppColors.textPrimary(context), fontSize: 14),
                  onChanged: (_) => setDialogState(() {}),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: AppColors.surface(context),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: AppColors.cardBorder(context))),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    suffixText: '${discountPct.toStringAsFixed(0)}% off',
                    suffixStyle: TextStyle(color: AppColors.error, fontWeight: FontWeight.w700, fontSize: 12),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('Cancel', style: TextStyle(color: AppColors.textTertiary(context))),
              ),
              ElevatedButton(
                onPressed: () async {
                  final inventory = context.read<InventoryProvider>();
                  await inventory.updateItem(item.copyWith(
                    price: clearancePrice,
                    storageLocation: 'CLEARANCE: $reason',
                  ));
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('${item.name} marked for clearance at ${Formatters.currency(clearancePrice)}'),
                      backgroundColor: AppColors.warning,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ));
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.warning,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Mark Clearance'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inventory = context.watch<InventoryProvider>();
    final clearanceItems = _getClearanceItems(inventory);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(children: [
              Text('Clearance Stock', style: AppTypography.h1.copyWith(
                  color: isDark ? AppColors.textPrimary(context) : AppColors.textPrimaryLight)),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8)),
                child: Text('${clearanceItems.length} items',
                    style: AppTypography.labelSmall.copyWith(
                        color: AppColors.warning, fontWeight: FontWeight.w700)),
              ),
            ]),
            const SizedBox(height: 16),

            // Filters
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (v) => setState(() => _searchQuery = v),
                  style: TextStyle(color: AppColors.textPrimary(context), fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Search clearance items...',
                    hintStyle: TextStyle(color: AppColors.textTertiary(context), fontSize: 12),
                    prefixIcon: Icon(Icons.search_rounded, color: AppColors.textTertiary(context)),
                    filled: true,
                    fillColor: isDark ? AppColors.surface(context) : Colors.grey.shade50,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AppColors.cardBorder(context))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AppColors.cardBorder(context))),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ...['All', 'Old Season', 'Low Stock', 'Dead Stock'].map((f) =>
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: GestureDetector(
                      onTap: () => setState(() => _filter = f),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: _filter == f
                              ? AppColors.warning.withValues(alpha: 0.2)
                              : AppColors.surface(context),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: _filter == f
                              ? AppColors.warning : AppColors.cardBorder(context)),
                        ),
                        child: Text(f, style: AppTypography.labelSmall.copyWith(
                            color: _filter == f ? AppColors.warning : AppColors.textSecondary(context),
                            fontWeight: _filter == f ? FontWeight.w700 : FontWeight.w400)),
                      ),
                    ),
                  )),
            ]),
            const SizedBox(height: 16),

            // Items table
            Expanded(
              child: clearanceItems.isEmpty
                  ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.check_circle_outline_rounded, size: 64,
                          color: AppColors.success.withValues(alpha: 0.3)),
                      const SizedBox(height: 12),
                      Text('No clearance items found',
                          style: AppTypography.bodyMedium.copyWith(
                              color: AppColors.textTertiary(context))),
                      const SizedBox(height: 4),
                      Text('All stock is healthy!',
                          style: AppTypography.labelSmall.copyWith(
                              color: AppColors.success)),
                    ]))
                  : Container(
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.card(context) : AppColors.cardLight,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: isDark ? AppColors.cardBorder(context) : AppColors.cardBorderLight),
                      ),
                      child: ListView.separated(
                        padding: const EdgeInsets.all(12),
                        itemCount: clearanceItems.length,
                        separatorBuilder: (_, __) => Divider(
                            color: AppColors.cardBorder(context), height: 1),
                        itemBuilder: (_, i) {
                          final item = clearanceItems[i];
                          final age = DateTime.now().difference(item.createdAt).inDays;
                          final isClearance = item.storageLocation.startsWith('CLEARANCE:');

                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            leading: Container(
                              width: 40, height: 40,
                              decoration: BoxDecoration(
                                color: isClearance
                                    ? AppColors.warning.withValues(alpha: 0.15)
                                    : item.quantity == 0
                                        ? AppColors.error.withValues(alpha: 0.15)
                                        : AppColors.accent.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                isClearance ? Icons.local_offer_rounded
                                    : item.quantity == 0 ? Icons.block_rounded
                                    : Icons.warning_amber_rounded,
                                size: 20,
                                color: isClearance ? AppColors.warning
                                    : item.quantity == 0 ? AppColors.error
                                    : AppColors.accent,
                              ),
                            ),
                            title: Text(item.name, style: AppTypography.bodyMedium.copyWith(
                                color: AppColors.textPrimary(context), fontWeight: FontWeight.w500)),
                            subtitle: Row(children: [
                              Text('${item.category} • ${age}d old • Qty: ${item.quantity}',
                                  style: AppTypography.labelSmall.copyWith(
                                      color: AppColors.textTertiary(context))),
                              if (isClearance) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.warning.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(4)),
                                  child: Text('CLEARANCE', style: AppTypography.labelSmall.copyWith(
                                      color: AppColors.warning, fontWeight: FontWeight.w700, fontSize: 9)),
                                ),
                              ],
                            ]),
                            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                              Text(Formatters.currency(item.price),
                                  style: AppTypography.mono.copyWith(
                                      color: isClearance ? AppColors.warning : AppColors.accent,
                                      fontWeight: FontWeight.w700)),
                              const SizedBox(width: 8),
                              if (!isClearance)
                                IconButton(
                                  icon: Icon(Icons.local_offer_rounded, size: 20, color: AppColors.warning),
                                  tooltip: 'Mark for Clearance',
                                  onPressed: () => _showClearanceDialog(item),
                                ),
                            ]),
                          );
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
