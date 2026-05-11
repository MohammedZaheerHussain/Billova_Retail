import 'dart:convert';
import 'dart:js' as js;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/formatters.dart';
import '../../providers/inventory_provider.dart';
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
                Row(children: [
                  Expanded(child: Text('Inventory',
                    style: AppTypography.h1.copyWith(color: AppColors.textPrimary(context)))),
                  _statChip('${provider.totalItems}', 'Items', AppColors.primary),
                  const SizedBox(width: 8),
                  if (provider.lowStockCount > 0)
                    _statChip('${provider.lowStockCount}', 'Low', AppColors.warning),
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
                ]),
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
                const SizedBox(height: 16),

                if (provider.error.isNotEmpty) _errorBanner(context, provider),

                // ─── Grouped Items List ───
                Expanded(
                  child: provider.isLoading
                      ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
                      : provider.items.isEmpty
                          ? _emptyState(context)
                          : ListView.builder(
                              itemCount: grouped.length,
                              itemBuilder: (context, index) {
                                final category = grouped.keys.elementAt(index);
                                final items = grouped[category]!;
                                final isCollapsed = _collapsedCategories.contains(category);
                                return _categorySection(context, category, items, isCollapsed, provider);
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
          ...items.map((item) => _itemTile(context, item, provider)),
        ],
      ]),
    );
  }

  Widget _itemTile(BuildContext context, ItemModel item, InventoryProvider provider) {
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
          PopupMenuButton(
            icon: Icon(Icons.more_vert_rounded, color: AppColors.textSecondary(context)),
            color: AppColors.card(context),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            itemBuilder: (ctx) => [
              PopupMenuItem(
                onTap: () => Future.microtask(() => _showItemForm(context, item: item)),
                child: Row(children: [
                  Icon(Icons.edit_rounded, size: 18, color: AppColors.textSecondary(context)),
                  SizedBox(width: 8),
                  Text('Edit', style: TextStyle(color: AppColors.textPrimary(context))),
                ]),
              ),
              PopupMenuItem(
                onTap: () => _confirmDelete(context, provider, item),
                child: const Row(children: [
                  Icon(Icons.delete_rounded, size: 18, color: AppColors.error),
                  SizedBox(width: 8),
                  Text('Delete', style: TextStyle(color: AppColors.error)),
                ]),
              ),
            ],
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
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: AppColors.card(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480, maxHeight: 580),
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
                        onPressed: () => _printBarcode(item),
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
                const Divider(height: 20),
                Row(children: [
                  Expanded(child: _detailCard(context, 'Selling Price', Formatters.currency(item.price), AppColors.accent)),
                  const SizedBox(width: 8),
                  Expanded(child: _detailCard(context, 'Cost Price', Formatters.currency(item.costPrice), AppColors.primary)),
                  const SizedBox(width: 8),
                  Expanded(child: _detailCard(context, 'Profit', Formatters.currency(item.profit),
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
              ]))),
              const SizedBox(height: 12),
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                OutlinedButton.icon(
                  onPressed: () { Navigator.pop(ctx); _showItemForm(context, item: item); },
                  icon: Icon(Icons.edit_rounded, size: 16, color: AppColors.accent),
                  label: Text('Edit', style: TextStyle(color: AppColors.accent)),
                  style: OutlinedButton.styleFrom(side: BorderSide(color: AppColors.accent),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                ),
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

  void _printBarcode(ItemModel item) {
    final name = item.name.replaceAll("'", "\\'");
    final barcode = item.barcode.replaceAll("'", "\\'");
    final price = Formatters.currency(item.price).replaceAll("'", "\\'");
    js.context.callMethod('eval', [
      '''
      var w = window.open('', '_blank', 'width=400,height=300');
      if (w) {
        w.document.write('<html><head><title>Barcode Label</title>');
        w.document.write('<script src="https://cdn.jsdelivr.net/npm/jsbarcode@3.11.6/dist/JsBarcode.all.min.js"><\\/script>');
        w.document.write('<style>');
        w.document.write('@page { size: 50mm 30mm; margin: 0; }');
        w.document.write('@media print { body { margin: 0; } }');
        w.document.write('body { font-family: Arial, sans-serif; text-align: center; padding: 4mm; background: #fff; }');
        w.document.write('.name { font-size: 10px; font-weight: bold; margin-bottom: 2px; }');
        w.document.write('.price { font-size: 10px; margin-top: 2px; }');
        w.document.write('canvas { max-width: 100%; }');
        w.document.write('</style></head><body>');
        w.document.write('<div class="name">$name</div>');
        w.document.write('<canvas id="bc"></canvas>');
        w.document.write('<div class="price">$price</div>');
        w.document.write('<script>');
        w.document.write('JsBarcode("#bc", "$barcode", { format: "CODE128", width: 2, height: 50, displayValue: true, fontSize: 12, fontOptions: "bold", margin: 4 });');
        w.document.write('<\\/script>');
        w.document.write('</body></html>');
        w.document.close();
        setTimeout(function() { w.print(); }, 700);
        setTimeout(function() { w.close(); }, 3000);
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
              provider.deleteItem(item.id);
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
