import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/item_model.dart';
import '../../providers/inventory_provider.dart';

/// Professional Stock Alert Drawer for Low Stock / Out of Stock items
class StockAlertDrawer extends StatefulWidget {
  final String mode; // 'low' or 'out'
  const StockAlertDrawer({super.key, required this.mode});

  @override
  State<StockAlertDrawer> createState() => _StockAlertDrawerState();
}

class _StockAlertDrawerState extends State<StockAlertDrawer> {
  String _search = '';
  String _sortBy = 'stock'; // stock, name, updated
  String _categoryFilter = 'All';

  @override
  Widget build(BuildContext context) {
    final inventory = context.watch<InventoryProvider>();
    final isLow = widget.mode == 'low';
    final accentColor = isLow ? AppColors.warning : AppColors.error;
    final title = isLow ? 'Low Stock Alert' : 'Out of Stock';
    final icon = isLow ? Icons.warning_amber_rounded : Icons.block_rounded;

    // Get filtered items
    List<ItemModel> items = isLow
        ? inventory.items.where((i) => i.isLowStock).toList()
        : inventory.items.where((i) => i.isOutOfStock).toList();

    // Get unique categories
    final categories = <String>{'All'};
    for (final item in items) {
      if (item.category.isNotEmpty) categories.add(item.category);
    }

    // Apply category filter
    if (_categoryFilter != 'All') {
      items = items.where((i) => i.category == _categoryFilter).toList();
    }

    // Apply search
    if (_search.isNotEmpty) {
      final q = _search.toLowerCase();
      items = items.where((i) =>
          i.name.toLowerCase().contains(q) ||
          i.barcode.toLowerCase().contains(q) ||
          i.category.toLowerCase().contains(q) ||
          i.vendor.toLowerCase().contains(q)).toList();
    }

    // Apply sort
    switch (_sortBy) {
      case 'stock':
        items.sort((a, b) => a.quantity.compareTo(b.quantity));
        break;
      case 'name':
        items.sort((a, b) => a.name.compareTo(b.name));
        break;
      case 'updated':
        items.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        break;
    }

    final width = MediaQuery.of(context).size.width;
    final drawerWidth = width > 800 ? 520.0 : width * 0.9;

    return Align(
      alignment: Alignment.centerRight,
      child: Material(
        color: Colors.transparent,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: drawerWidth,
          height: double.infinity,
          decoration: BoxDecoration(
            color: AppColors.card(context),
            borderRadius: const BorderRadius.horizontal(left: Radius.circular(20)),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 30, offset: const Offset(-10, 0)),
            ],
          ),
          child: Column(children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(24, 20, 16, 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [accentColor.withValues(alpha: 0.15), Colors.transparent],
                  begin: Alignment.topCenter, end: Alignment.bottomCenter,
                ),
                borderRadius: const BorderRadius.only(topLeft: Radius.circular(20)),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: accentColor, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(title, style: AppTypography.h3.copyWith(color: AppColors.textPrimary(context))),
                    const SizedBox(height: 2),
                    Text('${items.length} products need attention',
                        style: AppTypography.labelSmall.copyWith(color: AppColors.textTertiary(context))),
                  ])),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close_rounded, color: AppColors.textSecondary(context)),
                  ),
                ]),
                const SizedBox(height: 16),

                // Search bar
                TextField(
                  onChanged: (v) => setState(() => _search = v),
                  style: TextStyle(color: AppColors.textPrimary(context), fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Search by name, SKU, category...',
                    hintStyle: TextStyle(color: AppColors.textTertiary(context), fontSize: 12),
                    prefixIcon: Icon(Icons.search_rounded, size: 18, color: AppColors.textTertiary(context)),
                    isDense: true, filled: true,
                    fillColor: AppColors.surface(context),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 12),

                // Filters row
                Row(children: [
                  // Category filter
                  Expanded(child: SizedBox(
                    height: 32,
                    child: ListView(scrollDirection: Axis.horizontal, children: categories.map((c) {
                      final active = _categoryFilter == c;
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: GestureDetector(
                          onTap: () => setState(() => _categoryFilter = c),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: active ? accentColor.withValues(alpha: 0.15) : AppColors.surface(context),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: active ? accentColor : AppColors.cardBorder(context)),
                            ),
                            child: Text(c, style: AppTypography.labelSmall.copyWith(
                                color: active ? accentColor : AppColors.textSecondary(context),
                                fontWeight: active ? FontWeight.w700 : FontWeight.w400, fontSize: 11)),
                          ),
                        ),
                      );
                    }).toList()),
                  )),
                  const SizedBox(width: 8),
                  // Sort dropdown
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: AppColors.surface(context),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.cardBorder(context)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _sortBy,
                        isDense: true,
                        dropdownColor: AppColors.card(context),
                        style: AppTypography.labelSmall.copyWith(color: AppColors.textSecondary(context), fontSize: 11),
                        items: const [
                          DropdownMenuItem(value: 'stock', child: Text('Lowest Stock')),
                          DropdownMenuItem(value: 'name', child: Text('A-Z Name')),
                          DropdownMenuItem(value: 'updated', child: Text('Recently Updated')),
                        ],
                        onChanged: (v) => setState(() => _sortBy = v!),
                      ),
                    ),
                  ),
                ]),
              ]),
            ),

            // Item list
            Expanded(
              child: items.isEmpty
                  ? _buildEmptyState(isLow, accentColor)
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      itemCount: items.length,
                      itemBuilder: (_, i) => _buildProductCard(items[i], accentColor, inventory),
                    ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isLow, Color accent) {
    return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.success.withValues(alpha: 0.08),
          shape: BoxShape.circle,
        ),
        child: Icon(
          isLow ? Icons.check_circle_outline_rounded : Icons.inventory_2_rounded,
          size: 48, color: AppColors.success,
        ),
      ),
      const SizedBox(height: 16),
      Text(
        isLow ? 'No low stock products!' : 'All products are in stock!',
        style: AppTypography.h4.copyWith(color: AppColors.textPrimary(context)),
      ),
      const SizedBox(height: 6),
      Text(
        isLow ? 'All items are above their threshold' : 'Your inventory is fully stocked',
        style: AppTypography.bodySmall.copyWith(color: AppColors.textTertiary(context)),
      ),
    ]));
  }

  Widget _buildProductCard(ItemModel item, Color accent, InventoryProvider inventory) {
    final isOut = item.isOutOfStock;
    final statusColor = isOut ? AppColors.error : AppColors.warning;
    final statusText = isOut ? 'OUT OF STOCK' : 'LOW STOCK';
    final stockPct = item.lowStockThreshold > 0
        ? (item.quantity / item.lowStockThreshold).clamp(0.0, 1.0)
        : 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: BorderRadius.circular(14),
        border: Border(left: BorderSide(color: statusColor, width: 4)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Top row: name + status badge
        Row(children: [
          // Product avatar
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(child: Text(
              item.name.isNotEmpty ? item.name[0].toUpperCase() : '?',
              style: TextStyle(color: statusColor, fontWeight: FontWeight.w800, fontSize: 16),
            )),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(item.name, style: AppTypography.bodySmall.copyWith(
                color: AppColors.textPrimary(context), fontWeight: FontWeight.w600)),
            if (item.category.isNotEmpty)
              Text(item.category, style: AppTypography.labelSmall.copyWith(
                  color: AppColors.textTertiary(context), fontSize: 10)),
          ])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(statusText, style: AppTypography.labelSmall.copyWith(
                color: statusColor, fontWeight: FontWeight.w700, fontSize: 9)),
          ),
        ]),
        const SizedBox(height: 12),

        // Stock progress bar
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text('Stock: ', style: AppTypography.labelSmall.copyWith(
                  color: AppColors.textTertiary(context), fontSize: 10)),
              Text('${item.quantity}', style: AppTypography.mono.copyWith(
                  color: statusColor, fontWeight: FontWeight.w700, fontSize: 14)),
              Text(' / ${item.lowStockThreshold} threshold', style: AppTypography.labelSmall.copyWith(
                  color: AppColors.textTertiary(context), fontSize: 10)),
            ]),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: stockPct,
                backgroundColor: AppColors.cardBorder(context),
                color: statusColor,
                minHeight: 5,
              ),
            ),
          ])),
        ]),
        const SizedBox(height: 10),

        // Details row
        Wrap(spacing: 12, runSpacing: 6, children: [
          if (item.barcode.isNotEmpty) _detailChip(Icons.qr_code_rounded, item.barcode),
          if (item.vendor.isNotEmpty) _detailChip(Icons.store_rounded, item.vendor),
          _detailChip(Icons.attach_money_rounded, Formatters.currency(item.costPrice)),
          _detailChip(Icons.schedule_rounded, _fmtDate(item.updatedAt)),
        ]),
        const SizedBox(height: 10),

        // Action buttons
        Row(children: [
          Expanded(child: _actionButton(
            icon: Icons.add_rounded,
            label: 'Restock',
            color: AppColors.success,
            onTap: () => _showRestockDialog(item, inventory),
          )),
          const SizedBox(width: 8),
          Expanded(child: _actionButton(
            icon: Icons.edit_rounded,
            label: 'Update Qty',
            color: AppColors.primary,
            onTap: () => _showUpdateQtyDialog(item, inventory),
          )),
        ]),
      ]),
    );
  }

  Widget _detailChip(IconData icon, String text) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 12, color: AppColors.textTertiary(context)),
      const SizedBox(width: 4),
      Text(text, style: AppTypography.labelSmall.copyWith(
          color: AppColors.textSecondary(context), fontSize: 10)),
    ]);
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withValues(alpha: 0.25)),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Text(label, style: AppTypography.labelSmall.copyWith(
                color: color, fontWeight: FontWeight.w600, fontSize: 11)),
          ]),
        ),
      ),
    );
  }

  String _fmtDate(DateTime d) {
    const m = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${d.day} ${m[d.month]}';
  }

  // Restock dialog
  void _showRestockDialog(ItemModel item, InventoryProvider inventory) {
    final qtyCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          Icon(Icons.add_circle_rounded, color: AppColors.success, size: 22),
          const SizedBox(width: 8),
          Expanded(child: Text('Restock - ${item.name}',
              style: AppTypography.h4.copyWith(color: AppColors.textPrimary(context)))),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          // Current stock info
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surface(context),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('Current Stock', style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textSecondary(context))),
              Text('${item.quantity} pcs', style: AppTypography.mono.copyWith(
                  color: item.isOutOfStock ? AppColors.error : AppColors.warning,
                  fontWeight: FontWeight.w700)),
            ]),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: qtyCtrl,
            keyboardType: TextInputType.number,
            autofocus: true,
            style: TextStyle(color: AppColors.textPrimary(context), fontSize: 14),
            decoration: InputDecoration(
              labelText: 'Add Quantity',
              labelStyle: TextStyle(color: AppColors.textSecondary(context), fontSize: 12),
              filled: true, fillColor: AppColors.surface(context),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              prefixIcon: Icon(Icons.add_rounded, color: AppColors.success, size: 20),
            ),
          ),
        ]),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: AppColors.textSecondary(context))),
          ),
          ElevatedButton(
            onPressed: () {
              final addQty = int.tryParse(qtyCtrl.text) ?? 0;
              if (addQty > 0) {
                inventory.restockItem(item.id, addQty);
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text('Restocked ${item.name} (+$addQty)'),
                  backgroundColor: AppColors.success,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ));
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Restock'),
          ),
        ],
      ),
    );
  }

  // Update quantity dialog
  void _showUpdateQtyDialog(ItemModel item, InventoryProvider inventory) {
    final qtyCtrl = TextEditingController(text: '${item.quantity}');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          Icon(Icons.edit_rounded, color: AppColors.primary, size: 22),
          const SizedBox(width: 8),
          Expanded(child: Text('Update - ${item.name}',
              style: AppTypography.h4.copyWith(color: AppColors.textPrimary(context)))),
        ]),
        content: TextField(
          controller: qtyCtrl,
          keyboardType: TextInputType.number,
          autofocus: true,
          style: TextStyle(color: AppColors.textPrimary(context), fontSize: 14),
          decoration: InputDecoration(
            labelText: 'New Quantity',
            labelStyle: TextStyle(color: AppColors.textSecondary(context), fontSize: 12),
            filled: true, fillColor: AppColors.surface(context),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
            prefixIcon: Icon(Icons.inventory_2_rounded, color: AppColors.primary, size: 20),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: AppColors.textSecondary(context))),
          ),
          ElevatedButton(
            onPressed: () {
              final newQty = int.tryParse(qtyCtrl.text) ?? item.quantity;
              inventory.updateStock(item.id, newQty);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text('Updated ${item.name} to $newQty pcs'),
                backgroundColor: AppColors.primary,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ));
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }
}
