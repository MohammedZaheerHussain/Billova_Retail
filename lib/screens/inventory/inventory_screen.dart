import 'dart:convert';
import 'dart:js' as js;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/permission_helper.dart';
import '../../providers/auth_provider.dart';
import '../../providers/inventory_provider.dart';
import '../../providers/sales_provider.dart';
import '../../providers/category_provider.dart';
import '../../data/models/item_model.dart';
import 'item_form_screen.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  final Set<String> _collapsedCategories = {};
  String? _selectedCategory; // null = show all

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      final catProvider = context.read<CategoryProvider>();
      if (catProvider.categories.isEmpty) catProvider.loadCategories();
    });
  }

  /// Group items by category name. Uncategorized items go to "Uncategorized".
  Map<String, List<ItemModel>> _groupByCategory(List<ItemModel> items) {
    final Map<String, List<ItemModel>> grouped = {};
    for (final item in items) {
      final cat = item.category.isNotEmpty ? item.category : 'Uncategorized';
      grouped.putIfAbsent(cat, () => []).add(item);
    }
    // Sort keys alphabetically, but put Uncategorized last
    final sorted = Map<String, List<ItemModel>>.fromEntries(
      grouped.entries.toList()..sort((a, b) {
        if (a.key == 'Uncategorized') return 1;
        if (b.key == 'Uncategorized') return -1;
        return a.key.toLowerCase().compareTo(b.key.toLowerCase());
      }),
    );
    return sorted;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<InventoryProvider>(
      builder: (context, provider, _) {
        final grouped = _groupByCategory(provider.items);
        return Scaffold(
          backgroundColor: Colors.transparent,
          body: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ─── Header ───
                Builder(builder: (context) {
                  final perms = PermissionHelper(context.watch<AuthProvider>().userType);
                  return Row(children: [
                    Expanded(child: Text('Inventory',
                      style: AppTypography.h1.copyWith(color: AppColors.textPrimary(context)))),
                    _statChip('${provider.totalItems}', 'Items', AppColors.primary),
                    const SizedBox(width: 8),
                    if (provider.lowStockCount > 0)
                      _statChip('${provider.lowStockCount}', 'Low', AppColors.warning),
                    if (perms.canAddInventory) ...[
                      const SizedBox(width: 16),
                      ElevatedButton.icon(
                        onPressed: () => _showItemForm(context),
                        icon: Icon(Icons.add_rounded, size: 20),
                        label: const Text('Add Item'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary, foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ],
                  ]);
                }),
                SizedBox(height: 16),

                // ─── Search ───
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.card(context), borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.cardBorder(context)),
                  ),
                  child: TextField(
                    onChanged: provider.search,
                    style: TextStyle(color: AppColors.textPrimary(context)),
                    decoration: InputDecoration(
                      hintText: 'Search items...', hintStyle: TextStyle(color: AppColors.textTertiary(context)),
                      prefixIcon: Icon(Icons.search_rounded, color: AppColors.textTertiary(context)),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // ─── Category Quick Filter ───
                if (grouped.keys.length > 1)
                  SizedBox(
                    height: 38,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        _categoryFilterChip('All', null),
                        const SizedBox(width: 6),
                        ...grouped.keys.map((cat) => Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: _categoryFilterChip(cat, cat),
                        )),
                      ],
                    ),
                  ),
                const SizedBox(height: 12),

                if (provider.error.isNotEmpty) _errorBanner(context, provider),

                // ─── Grouped Items List ───
                Expanded(
                  child: provider.isLoading
                      ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
                      : provider.items.isEmpty
                          ? _emptyState(context)
                          : Builder(
                              builder: (context) {
                                // Apply category filter
                                final filteredGrouped = _selectedCategory == null
                                    ? grouped
                                    : Map.fromEntries(
                                        grouped.entries.where((e) => e.key == _selectedCategory));
                                if (filteredGrouped.isEmpty) {
                                  return Center(
                                    child: Text('No items in this category',
                                      style: AppTypography.bodyMedium.copyWith(
                                        color: AppColors.textTertiary(context))),
                                  );
                                }
                                return ListView.builder(
                                  itemCount: filteredGrouped.length,
                                  itemBuilder: (context, index) {
                                    final category = filteredGrouped.keys.elementAt(index);
                                    final items = filteredGrouped[category]!;
                                    final isCollapsed = _collapsedCategories.contains(category);
                                    return _categorySection(context, category, items, isCollapsed, provider);
                                  },
                                );
                              },
                            ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _categorySection(BuildContext context, String category, List<ItemModel> items, bool isCollapsed, InventoryProvider provider) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardBorder(context)),
      ),
      child: Column(children: [
        // Category header
        InkWell(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
          onTap: () => setState(() {
            isCollapsed ? _collapsedCategories.remove(category) : _collapsedCategories.add(category);
          }),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  gradient: category == 'Uncategorized'
                      ? LinearGradient(colors: [Colors.grey.shade500, Colors.grey.shade600])
                      : AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(10)),
                child: Center(child: Text(
                  category.isNotEmpty ? category[0].toUpperCase() : '?',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16))),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(category, style: AppTypography.h4.copyWith(
                  color: AppColors.textPrimary(context), fontWeight: FontWeight.w600)),
                Text('${items.length} item${items.length != 1 ? 's' : ''}',
                  style: AppTypography.labelSmall.copyWith(color: AppColors.textTertiary(context))),
              ])),
              _statChip('${items.length}', '', AppColors.accent),
              const SizedBox(width: 8),
              AnimatedRotation(
                turns: isCollapsed ? -0.25 : 0,
                duration: const Duration(milliseconds: 200),
                child: Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.textTertiary(context)),
              ),
            ]),
          ),
        ),
        // Items (collapsible)
        if (!isCollapsed) ...[
          Divider(height: 1, color: AppColors.cardBorder(context).withValues(alpha: 0.5)),
          ...items.map((item) => _itemTile(context, item, provider, context.watch<AuthProvider>().userType)),
        ],
      ]),
    );
  }

  Widget _itemTile(BuildContext context, ItemModel item, InventoryProvider provider, String userRole) {
    Color stockColor = AppColors.success;
    String stockLabel = '${item.quantity} in stock';
    if (item.isOutOfStock) { stockColor = AppColors.error; stockLabel = 'Out of stock'; }
    else if (item.isLowStock) { stockColor = AppColors.warning; stockLabel = '${item.quantity} left (low)'; }

    return InkWell(
      onTap: () => _showItemDetail(context, item),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10)),
            child: Center(child: Text(item.name.isNotEmpty ? item.name[0].toUpperCase() : '?',
              style: AppTypography.h4.copyWith(color: AppColors.accent))),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(item.name, style: AppTypography.bodyLarge.copyWith(
              color: AppColors.textPrimary(context), fontWeight: FontWeight.w600)),
            if (item.vendor.isNotEmpty)
              Text(item.vendor, style: AppTypography.labelSmall.copyWith(
                color: AppColors.textTertiary(context), fontStyle: FontStyle.italic)),
            Row(children: [
              Text(Formatters.currency(item.price), style: AppTypography.mono.copyWith(color: AppColors.accent, fontSize: 13)),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: stockColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                child: Text(stockLabel, style: AppTypography.labelSmall.copyWith(color: stockColor)),
              ),
            ]),
          ])),
          // Only show Edit/Delete menu for admin users
          Builder(builder: (context) {
            final perms = PermissionHelper(userRole);
            if (!perms.canEditInventory && !perms.canDeleteInventory) {
              return const SizedBox.shrink();
            }
            return PopupMenuButton(
              icon: Icon(Icons.more_vert_rounded, color: AppColors.textSecondary(context)),
              color: AppColors.card(context),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              itemBuilder: (ctx) => [
                if (perms.canEditInventory)
                  PopupMenuItem(
                    onTap: () => Future.microtask(() => _showItemForm(context, item: item)),
                    child: Row(children: [
                      Icon(Icons.edit_rounded, size: 18, color: AppColors.textSecondary(context)),
                      SizedBox(width: 8),
                      Text('Edit', style: TextStyle(color: AppColors.textPrimary(context))),
                    ]),
                  ),
                if (perms.canDeleteInventory)
                  PopupMenuItem(
                    onTap: () => _confirmDelete(context, provider, item),
                    child: const Row(children: [
                      Icon(Icons.delete_rounded, size: 18, color: AppColors.error),
                      SizedBox(width: 8),
                      Text('Delete', style: TextStyle(color: AppColors.error)),
                    ]),
                  ),
              ],
            );
          }),
        ]),
      ),
    );
  }

  Widget _categoryFilterChip(String label, String? categoryValue) {
    final isSelected = _selectedCategory == categoryValue;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: () => setState(() => _selectedCategory = categoryValue),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          gradient: isSelected ? AppColors.primaryGradient : null,
          color: isSelected ? null : (isDark ? AppColors.card(context) : AppColors.cardLight),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? Colors.transparent
                : (isDark ? AppColors.cardBorder(context) : AppColors.cardBorderLight),
          ),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (categoryValue != null)
            Container(
              width: 20, height: 20, margin: const EdgeInsets.only(right: 6),
              decoration: BoxDecoration(
                color: isSelected ? Colors.white.withValues(alpha: 0.25) : AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Center(child: Text(
                label.isNotEmpty ? label[0].toUpperCase() : '?',
                style: TextStyle(
                  color: isSelected ? Colors.white : AppColors.accent,
                  fontSize: 10, fontWeight: FontWeight.w700),
              )),
            ),
          Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : (isDark ? AppColors.textPrimary(context) : AppColors.textPrimaryLight),
              fontSize: 12, fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ]),
      ),
    );
  }

  Widget _statChip(String value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(value, style: AppTypography.mono.copyWith(color: color, fontWeight: FontWeight.w700, fontSize: 13)),
        if (label.isNotEmpty) ...[const SizedBox(width: 4),
          Text(label, style: AppTypography.labelSmall.copyWith(color: color.withValues(alpha: 0.8)))],
      ]),
    );
  }

  Widget _errorBanner(BuildContext context, InventoryProvider provider) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.errorBg, borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.3))),
      child: Row(children: [
        Icon(Icons.error_outline, color: AppColors.error, size: 18), const SizedBox(width: 8),
        Expanded(child: Text(provider.error, style: AppTypography.bodySmall.copyWith(color: AppColors.error))),
        IconButton(icon: Icon(Icons.close, size: 16, color: AppColors.error),
          onPressed: provider.clearError, padding: EdgeInsets.zero, constraints: const BoxConstraints()),
      ]),
    );
  }

  Widget _emptyState(BuildContext context) {
    return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.inventory_2_outlined, size: 64, color: AppColors.textTertiary(context).withValues(alpha: 0.3)),
      SizedBox(height: 16),
      Text('No items yet', style: AppTypography.h3.copyWith(color: AppColors.textSecondary(context))),
      SizedBox(height: 8),
      Text('Add your first product to get started', style: AppTypography.bodyMedium.copyWith(color: AppColors.textTertiary(context))),
    ]));
  }

  void _showItemDetail(BuildContext context, ItemModel item) {
    // Capture role BEFORE opening dialog (dialog context != widget context)
    final userRole = context.read<AuthProvider>().userType;
    final perms = PermissionHelper(userRole);

    // Calculate total sold & revenue from all sales history
    // Revenue and profit use ACTUAL paid amounts (after bill discount),
    // not MRP. Discount is proportionally distributed across items.
    final allSales = context.read<SalesProvider>().allSales;
    int totalSold = 0;
    double totalRevenue = 0;
    double totalProfit = 0;
    for (final sale in allSales) {
      for (final si in sale.items) {
        if (si.itemId == item.id) {
          totalSold += si.quantity;
          // Proportional discount: this item's share of the bill discount
          // effectiveRevenue = (itemTotal / subtotal) * sale.total
          // sale.total already = subtotal - discount (actual paid amount)
          final proportion = sale.subtotal > 0 ? si.total / sale.subtotal : 0.0;
          final effectiveRevenue = proportion * sale.total;
          final costOfGoods = si.costPrice * si.quantity;
          totalRevenue += effectiveRevenue;
          totalProfit += (effectiveRevenue - costOfGoods);
        }
      }
    }

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: AppColors.card(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480, maxHeight: 620),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Row(children: [
                Container(padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(gradient: AppColors.primaryGradient, borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.inventory_2_rounded, color: Colors.white, size: 22)),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(item.name, style: AppTypography.h3.copyWith(color: AppColors.textPrimary(context)), overflow: TextOverflow.ellipsis),
                  if (item.vendor.isNotEmpty) Text(item.vendor, style: AppTypography.labelSmall.copyWith(
                    color: AppColors.textTertiary(context), fontStyle: FontStyle.italic)),
                ])),
                IconButton(onPressed: () => Navigator.pop(ctx),
                  icon: Icon(Icons.close_rounded, color: AppColors.textTertiary(context))),
              ]),
              const SizedBox(height: 16),
              Flexible(child: SingleChildScrollView(child: Column(children: [
                if (item.barcode.isNotEmpty) ...[
                  Container(width: double.infinity, padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300)),
                    child: Column(children: [
                      Builder(builder: (_) {
                        final dataUrl = js.context.callMethod('generateBarcodeDataUrl', [item.barcode, 2, 50]);
                        final url = dataUrl?.toString() ?? '';
                        if (url.isNotEmpty && url.startsWith('data:image')) {
                          return Image.memory(base64Decode(url.split(',').last), height: 80, fit: BoxFit.contain);
                        }
                        return Column(children: [
                          Icon(Icons.view_week_rounded, size: 48, color: Colors.black87),
                          const SizedBox(height: 4),
                          Text(item.barcode, style: const TextStyle(fontFamily: 'Courier', fontSize: 14,
                            fontWeight: FontWeight.w700, color: Colors.black, letterSpacing: 2)),
                        ]);
                      }),
                      const SizedBox(height: 8),
                      SizedBox(width: double.infinity, height: 36, child: ElevatedButton.icon(
                        onPressed: () => _printBarcode(context, item),
                        icon: const Icon(Icons.print_rounded, size: 16),
                        label: const Text('Print Barcode Label', style: TextStyle(fontSize: 12)),
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent, foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                      )),
                    ])),
                  const SizedBox(height: 12),
                ],
                _detailRow(context, 'Category', item.category, Icons.category_rounded),
                _detailRow(context, 'Size', item.size, Icons.straighten_rounded),
                _detailRow(context, 'Color', item.color, Icons.palette_rounded),
                _detailRow(context, 'Location', item.storageLocation, Icons.location_on_rounded),
                _detailRow(context, 'Barcode / SKU', item.barcode, Icons.qr_code_scanner_rounded),
                if (item.gstRate > 0) _detailRow(context, 'GST Rate', '${item.gstRate.toStringAsFixed(0)}%', Icons.receipt_long_rounded),
                const Divider(height: 20),
                Row(children: [
                  Expanded(child: _detailCard(context, 'Selling Price', Formatters.currency(item.price), AppColors.accent)),
                  const SizedBox(width: 8),
                  Expanded(child: _detailCard(context, 'Cost Price', Formatters.currency(item.costPrice), AppColors.primary)),
                  const SizedBox(width: 8),
                  Expanded(child: _detailCard(context, 'Profit/Unit', Formatters.currency(item.profit),
                    item.profit > 0 ? AppColors.success : AppColors.error)),
                ]),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(child: _detailCard(context, 'In Stock', '${item.quantity}',
                    item.isOutOfStock ? AppColors.error : item.isLowStock ? AppColors.warning : AppColors.success)),
                  const SizedBox(width: 8),
                  Expanded(child: _detailCard(context, 'Stock Value', Formatters.currency(item.stockValue), AppColors.accent)),
                  const SizedBox(width: 8),
                  Expanded(child: _detailCard(context, 'Margin', '${item.profitMargin.toStringAsFixed(1)}%',
                    item.profitMargin > 0 ? AppColors.success : AppColors.error)),
                ]),
                const SizedBox(height: 8),
                // ─── Sales Performance Row ───
                Row(children: [
                  Expanded(child: _detailCard(context, 'Total Sold', '$totalSold units',
                    totalSold > 0 ? AppColors.accent : AppColors.primary)),
                  const SizedBox(width: 8),
                  Expanded(child: _detailCard(context, 'Revenue', Formatters.currency(totalRevenue),
                    totalRevenue > 0 ? AppColors.success : AppColors.primary)),
                  const SizedBox(width: 8),
                  Expanded(child: _detailCard(context, 'Total Profit', Formatters.currency(totalProfit),
                    totalProfit > 0 ? AppColors.success : AppColors.error)),
                ]),
              ]))),
              const SizedBox(height: 12),
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                // Edit button — admin only
                if (perms.canEditInventory)
                  OutlinedButton.icon(
                    onPressed: () { Navigator.pop(ctx); _showItemForm(context, item: item); },
                    icon: Icon(Icons.edit_rounded, size: 16, color: AppColors.accent),
                    label: Text('Edit', style: TextStyle(color: AppColors.accent)),
                    style: OutlinedButton.styleFrom(side: BorderSide(color: AppColors.accent),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                  ),
                if (perms.canEditInventory)
                  const SizedBox(width: 8),
                ElevatedButton(onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                  child: const Text('Close', style: TextStyle(color: Colors.white))),
              ]),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _detailRow(BuildContext context, String label, String value, IconData icon) {
    if (value.isEmpty) return const SizedBox.shrink();
    return Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Row(children: [
      Icon(icon, size: 16, color: AppColors.textTertiary(context)), const SizedBox(width: 8),
      Text('$label: ', style: TextStyle(color: AppColors.textTertiary(context), fontSize: 12)),
      Expanded(child: Text(value, style: TextStyle(color: AppColors.textPrimary(context), fontSize: 13, fontWeight: FontWeight.w500))),
    ]));
  }

  Widget _detailCard(BuildContext context, String label, String value, Color color) {
    return Container(padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2))),
      child: Column(children: [
        Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 14)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(color: AppColors.textTertiary(context), fontSize: 10)),
      ]),
    );
  }

  void _printBarcode(BuildContext context, ItemModel item) {
    // Show quantity dialog first
    final qtyCtrl = TextEditingController(text: '${item.quantity}');

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppColors.card(dialogCtx),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          Icon(Icons.print_rounded, color: AppColors.accent, size: 22),
          const SizedBox(width: 8),
          Text('Print Labels', style: AppTypography.h4.copyWith(color: AppColors.textPrimary(dialogCtx))),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('How many barcode labels to print?',
              style: TextStyle(color: AppColors.textSecondary(dialogCtx), fontSize: 13)),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: TextField(
                controller: qtyCtrl,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.w700, fontSize: 18),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: AppColors.surface(dialogCtx),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: AppColors.cardBorder(dialogCtx)),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text('labels', style: TextStyle(color: AppColors.textTertiary(dialogCtx), fontSize: 13)),
          ]),
          const SizedBox(height: 8),
          Text('Stock quantity: ${item.quantity}',
              style: TextStyle(color: AppColors.textTertiary(dialogCtx), fontSize: 11)),
        ]),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text('Cancel', style: TextStyle(color: AppColors.textTertiary(dialogCtx))),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(dialogCtx);
              final qty = int.tryParse(qtyCtrl.text) ?? item.quantity;
              _doPrintLabels(item, qty.clamp(1, 500));
            },
            icon: const Icon(Icons.print_rounded, size: 16),
            label: const Text('Print'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }

  /// Generate and print N barcode labels in a grid layout
  void _doPrintLabels(ItemModel item, int count) {
    final name = item.name.replaceAll("'", "\\'").replaceAll('"', '\\"');
    final barcode = item.barcode.replaceAll("'", "\\'").replaceAll('"', '\\"');
    final price = Formatters.currency(item.price).replaceAll("'", "\\'").replaceAll('"', '\\"');
    final size = item.size.replaceAll("'", "\\'").replaceAll('"', '\\"');

    final labelsHtml = StringBuffer();
    for (int i = 0; i < count; i++) {
      labelsHtml.write('<div class="label"><div class="shop">SKYWALK</div>');
      if (size.isNotEmpty) labelsHtml.write('<div class="size">$size</div>');
      labelsHtml.write('<canvas id="bc$i"></canvas><div class="price">MRP: $price</div></div>');
    }

    final barcodeJs = StringBuffer();
    for (int i = 0; i < count; i++) {
      barcodeJs.write('JsBarcode("#bc$i","$barcode",{format:"CODE128",width:1.5,height:35,displayValue:true,fontSize:9,fontOptions:"bold",margin:2});');
    }

    js.context.callMethod('eval', [
      '''
      var w = window.open('', '_blank', 'width=800,height=900');
      if (w) {
        var html = '<html><head><title>$count Labels - $name</title>';
        html += '<script src="https://cdn.jsdelivr.net/npm/jsbarcode@3.11.6/dist/JsBarcode.all.min.js"><\/script>';
        html += '<style>';
        html += '@page{size:A4;margin:8mm}';
        html += 'body{font-family:Arial,sans-serif;margin:0;padding:0;background:#fff}';
        html += '.grid{display:grid;grid-template-columns:repeat(3,1fr);gap:0}';
        html += '.label{border:1px solid #ccc;padding:6px 4px;text-align:center;box-sizing:border-box;min-height:90px;display:flex;flex-direction:column;align-items:center;justify-content:center}';
        html += '.shop{font-size:9px;font-weight:bold;letter-spacing:1px;margin-bottom:1px}';
        html += '.size{font-size:8px;margin-bottom:1px}';
        html += '.price{font-size:9px;font-weight:bold;margin-top:1px}';
        html += 'canvas{max-width:95%;height:35px}';
        html += '.no-print{text-align:center;padding:12px;background:#f5f5f5;border-bottom:1px solid #ddd;display:flex;justify-content:center;gap:10px;align-items:center}';
        html += '.print-btn{background:#00BCD4;color:#fff;border:none;padding:10px 24px;border-radius:8px;font-size:14px;font-weight:bold;cursor:pointer}';
        html += '.print-btn:hover{background:#00ACC1}';
        html += '.badge{background:#333;color:#fff;padding:5px 12px;border-radius:12px;font-size:12px;font-weight:bold}';
        html += '@media print{.no-print{display:none!important}}';
        html += '</style></head><body>';
        html += '<div class="no-print"><span class="badge">$count labels</span><button class="print-btn" onclick="window.print()">🖨 Print All Labels</button></div>';
        html += '<div class="grid">';
        html += '${labelsHtml.toString().replaceAll("'", "\\'")}';
        html += '</div>';
        html += '<script>';
        html += '${barcodeJs.toString().replaceAll("'", "\\'")}';
        html += 'setTimeout(function(){window.print();},800);';
        html += '<\/script>';
        html += '</body></html>';
        w.document.write(html);
        w.document.close();
      }
      '''
    ]);
  }

  void _showItemForm(BuildContext context, {ItemModel? item}) {
    showDialog(context: context, builder: (ctx) => ItemFormDialog(item: item));
  }

  void _confirmDelete(BuildContext context, InventoryProvider provider, ItemModel item) {
    Future.microtask(() {
      showDialog(context: context, builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Delete Item', style: AppTypography.h3.copyWith(color: AppColors.textPrimary(context))),
        content: Text('Are you sure you want to delete "${item.name}"?',
          style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary(context))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              provider.deleteItem(item.id, userRole: context.read<AuthProvider>().userType);
              Navigator.pop(ctx);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text('${item.name} deleted'), backgroundColor: AppColors.card(context)));
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ));
    });
  }
}
