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
  // Month selector state — defaults to current month
  late DateTime _selectedMonth;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonth = DateTime(now.year, now.month);
    Future.microtask(() {
      final catProvider = context.read<CategoryProvider>();
      if (catProvider.categories.isEmpty) catProvider.loadCategories();
    });
  }

  String get _monthLabel {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return '${months[_selectedMonth.month - 1]} ${_selectedMonth.year}';
  }

  Future<void> _pickMonth(BuildContext context) async {
    // Show date picker — user picks any day; we only use year+month
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedMonth,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      helpText: 'Select Month',
      initialEntryMode: DatePickerEntryMode.calendarOnly,
    );
    if (picked != null) {
      setState(() => _selectedMonth = DateTime(picked.year, picked.month));
    }
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
                    if (provider.lowStockCount > 0) ...[
                      _statChip('${provider.lowStockCount}', 'Low', AppColors.warning),
                      const SizedBox(width: 8),
                    ],
                    // ─── Month Selector ───
                    GestureDetector(
                      onTap: () => _pickMonth(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.calendar_month_rounded, size: 15, color: AppColors.primary),
                          const SizedBox(width: 6),
                          Text(_monthLabel,
                            style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600, fontSize: 13)),
                          const SizedBox(width: 2),
                          Icon(Icons.arrow_drop_down_rounded, size: 18, color: AppColors.primary),
                        ]),
                      ),
                    ),
                    if (perms.canAddInventory) ...[
                      const SizedBox(width: 12),
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

    // ── Month-filtered sales stats ──
    // Only count sales whose createdAt falls within the selected month.
    // Revenue and profit use ACTUAL paid amounts (after bill discount),
    // not MRP. Discount is proportionally distributed across items.
    final allSales = context.read<SalesProvider>().allSales;
    final monthSales = allSales.where((sale) {
      final d = sale.createdAt.toLocal();
      return d.year == _selectedMonth.year && d.month == _selectedMonth.month;
    }).toList();

    int totalSold = 0;
    double totalRevenue = 0;
    double totalProfit = 0;
    for (final sale in monthSales) {
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
                // ─── Month-Wise Sales Performance ───
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
                  ),
                  child: Row(children: [
                    Icon(Icons.calendar_month_rounded, size: 13, color: AppColors.primary),
                    const SizedBox(width: 5),
                    Text('Performance for $_monthLabel',
                      style: TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.w600)),
                  ]),
                ),
                const SizedBox(height: 6),
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
    int count = item.quantity > 0 ? item.quantity : 10;
    String selectedFormat = 'zebra2up'; // 'zebra2up' | 'zebra1up' | 'zebra4x2' | 'a4'

    final qtyCtrl = TextEditingController(text: '$count');

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppColors.card(dialogCtx),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.qr_code_2_rounded, color: AppColors.accent, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Print Barcode Labels',
                      style: AppTypography.h4.copyWith(color: AppColors.textPrimary(dialogCtx), fontSize: 16)),
                  Text('${item.name} (${item.barcode})',
                      style: AppTypography.labelSmall.copyWith(color: AppColors.textTertiary(dialogCtx)),
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ]),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ─── Label Quantity ───
                  Text('Number of Labels',
                      style: TextStyle(color: AppColors.textSecondary(dialogCtx), fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(
                      child: TextField(
                        controller: qtyCtrl,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.w700, fontSize: 18),
                        onChanged: (val) {
                          final parsed = int.tryParse(val);
                          if (parsed != null && parsed > 0) count = parsed;
                        },
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: AppColors.surface(dialogCtx),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: AppColors.cardBorder(dialogCtx)),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _quickQtyChip('2', 2, () { setDialogState(() { count = 2; qtyCtrl.text = '2'; }); }),
                    const SizedBox(width: 4),
                    _quickQtyChip('10', 10, () { setDialogState(() { count = 10; qtyCtrl.text = '10'; }); }),
                    const SizedBox(width: 4),
                    _quickQtyChip('Stock (${item.quantity})', item.quantity > 0 ? item.quantity : 1, () {
                      setDialogState(() {
                        count = item.quantity > 0 ? item.quantity : 1;
                        qtyCtrl.text = '$count';
                      });
                    }),
                  ]),
                  const SizedBox(height: 16),

                  // ─── Printer / Paper Format ───
                  Text('Printer & Label Format',
                      style: TextStyle(color: AppColors.textSecondary(dialogCtx), fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface(dialogCtx),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.cardBorder(dialogCtx)),
                    ),
                    child: Column(
                      children: [
                        _formatRadioTile(
                          value: 'zebra2up',
                          groupValue: selectedFormat,
                          title: 'Zebra 2-Up Roll (50×25mm × 2 across)',
                          subtitle: '⭐ Default for ZD220 Dual Sticker Roll',
                          onChanged: (v) => setDialogState(() => selectedFormat = v!),
                        ),
                        const Divider(height: 1),
                        _formatRadioTile(
                          value: 'zebra1up',
                          groupValue: selectedFormat,
                          title: 'Zebra 1-Up Roll (50×25mm / 2"×1")',
                          subtitle: 'Single column continuous sticker roll',
                          onChanged: (v) => setDialogState(() => selectedFormat = v!),
                        ),
                        const Divider(height: 1),
                        _formatRadioTile(
                          value: 'zebra4x2',
                          groupValue: selectedFormat,
                          title: 'Zebra 1-Up Large (100×50mm / 4"×2")',
                          subtitle: 'Full width 4-inch shipping/box label',
                          onChanged: (v) => setDialogState(() => selectedFormat = v!),
                        ),
                        const Divider(height: 1),
                        _formatRadioTile(
                          value: 'a4',
                          groupValue: selectedFormat,
                          title: 'A4 Sheet (3×8 Grid - 24 Labels)',
                          subtitle: 'Standard desktop laser/inkjet sheet paper',
                          onChanged: (v) => setDialogState(() => selectedFormat = v!),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: Text('Cancel', style: TextStyle(color: AppColors.textTertiary(dialogCtx))),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(dialogCtx);
                final finalQty = (int.tryParse(qtyCtrl.text) ?? count).clamp(1, 500);
                _doPrintLabels(item, finalQty, format: selectedFormat, highDensity: true);
              },
              icon: const Icon(Icons.print_rounded, size: 16),
              label: const Text('Print Labels'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _quickQtyChip(String label, int val, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
        ),
        child: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.accent)),
      ),
    );
  }

  Widget _formatRadioTile({
    required String value,
    required String groupValue,
    required String title,
    required String subtitle,
    required ValueChanged<String?> onChanged,
  }) {
    final isSelected = value == groupValue;
    return InkWell(
      onTap: () => onChanged(value),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          children: [
            Radio<String>(
              value: value,
              groupValue: groupValue,
              onChanged: onChanged,
              activeColor: AppColors.accent,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontSize: 12, fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500)),
                  Text(subtitle, style: TextStyle(fontSize: 10, color: isSelected ? AppColors.accent : Colors.grey)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Generate and print N barcode labels optimized for Zebra 203 DPI / thermal sticker rolls
  void _doPrintLabels(ItemModel item, int count, {String format = 'zebra2up', bool highDensity = true}) {
    final name = item.name.replaceAll("'", "\\'").replaceAll('"', '\\"');
    final barcode = item.barcode.replaceAll("'", "\\'").replaceAll('"', '\\"');
    final price = Formatters.currency(item.price).replaceAll("'", "\\'").replaceAll('"', '\\"');
    final size = item.size.replaceAll("'", "\\'").replaceAll('"', '\\"');

    final barWidth = 2.0;
    final barHeight = format == 'zebra4x2' ? 52 : 36;
    final fontSize = format == 'zebra4x2' ? 14 : 11;

    final labelsHtml = StringBuffer();
    final barcodeJs = StringBuffer();

    if (format == 'zebra2up') {
      // 2 labels per row on a 104mm roll (50x25mm each)
      for (int i = 0; i < count; i += 2) {
        labelsHtml.write('<div class="row-2up">');
        // Left label
        labelsHtml.write(
          '<div class="label-2up">'
          '<div class="shop">SKYWALK</div>'
          '<div class="item-name">$name</div>'
          '<div class="bc-wrap"><svg id="bc$i" class="barcode-svg"></svg></div>'
          '<div class="footer-row">'
          '${size.isNotEmpty ? '<span class="size">$size</span>' : '<span></span>'}'
          '<span class="price">MRP: $price</span>'
          '</div></div>'
        );
        barcodeJs.write('JsBarcode("#bc$i","$barcode",{format:"CODE128",width:$barWidth,height:$barHeight,displayValue:true,fontSize:$fontSize,fontOptions:"bold",font:"monospace",textMargin:1,margin:0,background:"#ffffff",lineColor:"#000000"});');

        // Right label (if exists)
        if (i + 1 < count) {
          final nextIdx = i + 1;
          labelsHtml.write(
            '<div class="label-2up">'
            '<div class="shop">SKYWALK</div>'
            '<div class="item-name">$name</div>'
            '<div class="bc-wrap"><svg id="bc$nextIdx" class="barcode-svg"></svg></div>'
            '<div class="footer-row">'
            '${size.isNotEmpty ? '<span class="size">$size</span>' : '<span></span>'}'
            '<span class="price">MRP: $price</span>'
            '</div></div>'
          );
          barcodeJs.write('JsBarcode("#bc$nextIdx","$barcode",{format:"CODE128",width:$barWidth,height:$barHeight,displayValue:true,fontSize:$fontSize,fontOptions:"bold",font:"monospace",textMargin:1,margin:0,background:"#ffffff",lineColor:"#000000"});');
        } else {
          labelsHtml.write('<div class="label-2up empty-slot"></div>');
        }
        labelsHtml.write('</div>');
      }
    } else if (format == 'zebra1up') {
      // Single 50x25mm continuous label
      for (int i = 0; i < count; i++) {
        labelsHtml.write(
          '<div class="label-1up">'
          '<div class="shop">SKYWALK</div>'
          '<div class="item-name">$name</div>'
          '<div class="bc-wrap"><svg id="bc$i" class="barcode-svg"></svg></div>'
          '<div class="footer-row">'
          '${size.isNotEmpty ? '<span class="size">$size</span>' : '<span></span>'}'
          '<span class="price">MRP: $price</span>'
          '</div></div>'
        );
        barcodeJs.write('JsBarcode("#bc$i","$barcode",{format:"CODE128",width:$barWidth,height:$barHeight,displayValue:true,fontSize:$fontSize,fontOptions:"bold",font:"monospace",textMargin:1,margin:0,background:"#ffffff",lineColor:"#000000"});');
      }
    } else if (format == 'zebra4x2') {
      // Large 100x50mm (4"x2") label
      for (int i = 0; i < count; i++) {
        labelsHtml.write(
          '<div class="label-4x2">'
          '<div class="shop-lg">SKYWALK</div>'
          '<div class="item-name-lg">$name</div>'
          '<div class="bc-wrap-lg"><svg id="bc$i" class="barcode-svg-lg"></svg></div>'
          '<div class="footer-row-lg">'
          '${size.isNotEmpty ? '<span class="size-lg">Size: $size</span>' : '<span></span>'}'
          '<span class="price-lg">MRP: $price</span>'
          '</div></div>'
        );
        barcodeJs.write('JsBarcode("#bc$i","$barcode",{format:"CODE128",width:2.5,height:$barHeight,displayValue:true,fontSize:$fontSize,fontOptions:"bold",font:"monospace",textMargin:2,margin:0,background:"#ffffff",lineColor:"#000000"});');
      }
    } else {
      // A4 Sheet 3x8 Grid
      labelsHtml.write('<div class="grid-a4">');
      for (int i = 0; i < count; i++) {
        labelsHtml.write(
          '<div class="label-a4">'
          '<div class="shop">SKYWALK</div>'
          '<div class="item-name">$name</div>'
          '<div class="bc-wrap"><svg id="bc$i" class="barcode-svg"></svg></div>'
          '<div class="footer-row">'
          '${size.isNotEmpty ? '<span class="size">$size</span>' : '<span></span>'}'
          '<span class="price">MRP: $price</span>'
          '</div></div>'
        );
        barcodeJs.write('JsBarcode("#bc$i","$barcode",{format:"CODE128",width:$barWidth,height:$barHeight,displayValue:true,fontSize:$fontSize,fontOptions:"bold",font:"monospace",textMargin:1,margin:0,background:"#ffffff",lineColor:"#000000"});');
      }
      labelsHtml.write('</div>');
    }

    String cssRules = '';
    if (format == 'zebra2up') {
      cssRules = '''
        @page { size: 104mm 25mm; margin: 0; }
        @media print { body { margin: 0; padding: 0; background: #fff; } .no-print { display: none !important; } }
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Arial, sans-serif; background: #f0f2f5; color: #000; }
        .sheet { width: 104mm; margin: 0 auto; background: #fff; }
        .row-2up { width: 104mm; height: 25mm; display: flex; flex-direction: row; justify-content: space-between; align-items: stretch; page-break-after: always; break-after: page; padding: 0.5mm 1.5mm; overflow: hidden; }
        .label-2up { width: 49.5mm; height: 24mm; display: flex; flex-direction: column; align-items: center; justify-content: space-between; text-align: center; padding: 0.8mm 1mm; overflow: hidden; }
        .empty-slot { visibility: hidden; }
        .shop { font-size: 8.5px; font-weight: 900; letter-spacing: 0.6px; line-height: 1; text-transform: uppercase; }
        .item-name { font-size: 7.5px; font-weight: 700; max-width: 96%; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; line-height: 1; }
        .bc-wrap { width: 100%; display: flex; justify-content: center; align-items: center; }
        svg.barcode-svg { width: 96%; max-height: 14mm; shape-rendering: crispEdges; }
        .footer-row { width: 96%; display: flex; justify-content: space-between; align-items: center; font-size: 8px; line-height: 1; }
        .size { font-size: 7.5px; font-weight: 600; }
        .price { font-size: 9px; font-weight: 900; }
      ''';
    } else if (format == 'zebra1up') {
      cssRules = '''
        @page { size: 50mm 25mm; margin: 0; }
        @media print { body { margin: 0; padding: 0; background: #fff; } .no-print { display: none !important; } }
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Arial, sans-serif; background: #f0f2f5; color: #000; }
        .sheet { width: 50mm; margin: 0 auto; background: #fff; }
        .label-1up { width: 50mm; height: 25mm; display: flex; flex-direction: column; align-items: center; justify-content: space-between; text-align: center; padding: 0.8mm 1.5mm; page-break-after: always; break-after: page; overflow: hidden; }
        .shop { font-size: 8.5px; font-weight: 900; letter-spacing: 0.6px; line-height: 1; text-transform: uppercase; }
        .item-name { font-size: 7.5px; font-weight: 700; max-width: 96%; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; line-height: 1; }
        .bc-wrap { width: 100%; display: flex; justify-content: center; align-items: center; }
        svg.barcode-svg { width: 96%; max-height: 14mm; shape-rendering: crispEdges; }
        .footer-row { width: 96%; display: flex; justify-content: space-between; align-items: center; font-size: 8px; line-height: 1; }
        .size { font-size: 7.5px; font-weight: 600; }
        .price { font-size: 9px; font-weight: 900; }
      ''';
    } else if (format == 'zebra4x2') {
      cssRules = '''
        @page { size: 100mm 50mm; margin: 0; }
        @media print { body { margin: 0; padding: 0; background: #fff; } .no-print { display: none !important; } }
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Arial, sans-serif; background: #f0f2f5; color: #000; }
        .sheet { width: 100mm; margin: 0 auto; background: #fff; }
        .label-4x2 { width: 100mm; height: 50mm; display: flex; flex-direction: column; align-items: center; justify-content: space-between; text-align: center; padding: 2mm 3mm; page-break-after: always; break-after: page; overflow: hidden; }
        .shop-lg { font-size: 14px; font-weight: 900; letter-spacing: 1px; line-height: 1.1; text-transform: uppercase; }
        .item-name-lg { font-size: 12px; font-weight: 700; max-width: 96%; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; line-height: 1.1; }
        .bc-wrap-lg { width: 100%; display: flex; justify-content: center; align-items: center; }
        svg.barcode-svg-lg { width: 96%; max-height: 28mm; shape-rendering: crispEdges; }
        .footer-row-lg { width: 96%; display: flex; justify-content: space-between; align-items: center; font-size: 13px; line-height: 1.1; }
        .size-lg { font-size: 12px; font-weight: 600; }
        .price-lg { font-size: 14px; font-weight: 900; }
      ''';
    } else {
      cssRules = '''
        @page { size: A4; margin: 8mm 6mm; }
        @media print { body { margin: 0; padding: 0; background: #fff; } .no-print { display: none !important; } }
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Arial, sans-serif; background: #f0f2f5; color: #000; }
        .sheet { max-width: 100%; margin: 0 auto; background: #fff; }
        .grid-a4 { display: grid; grid-template-columns: repeat(3, 1fr); gap: 2mm 3mm; padding: 4mm; }
        .label-a4 { border: 1px dashed #bbb; padding: 2mm; height: 32mm; display: flex; flex-direction: column; align-items: center; justify-content: space-between; text-align: center; }
        .shop { font-size: 8.5px; font-weight: 900; letter-spacing: 0.6px; line-height: 1; text-transform: uppercase; }
        .item-name { font-size: 7.5px; font-weight: 700; max-width: 96%; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; line-height: 1; }
        .bc-wrap { width: 100%; display: flex; justify-content: center; align-items: center; }
        svg.barcode-svg { width: 96%; max-height: 14mm; shape-rendering: crispEdges; }
        .footer-row { width: 96%; display: flex; justify-content: space-between; align-items: center; font-size: 8px; line-height: 1; }
        .size { font-size: 7.5px; font-weight: 600; }
        .price { font-size: 9px; font-weight: 900; }
      ''';
    }

    js.context.callMethod('eval', [
      '''
      var w = window.open('', '_blank', 'width=840,height=900');
      if (w) {
        var html = '<!DOCTYPE html><html><head><meta charset="utf-8"><title>$count Labels - $name</title>';
        html += '<script src="https://cdn.jsdelivr.net/npm/jsbarcode@3.11.6/dist/JsBarcode.all.min.js"></script>';
        html += '<style>';
        html += '${cssRules.replaceAll('\n', ' ').replaceAll("'", "\\'")}';
        html += '.no-print{text-align:center;padding:12px;background:#1E293B;color:#fff;border-bottom:1px solid #334155;display:flex;justify-content:center;gap:12px;align-items:center}';
        html += '.print-btn{background:#06B6D4;color:#fff;border:none;padding:10px 24px;border-radius:8px;font-size:14px;font-weight:bold;cursor:pointer;display:inline-flex;align-items:center;gap:6px;}';
        html += '.print-btn:hover{background:#0891B2}';
        html += '.badge{background:#0F172A;color:#94A3B8;padding:6px 14px;border-radius:8px;font-size:12px;font-weight:600;border:1px solid #334155;}';
        html += '</style></head><body>';
        html += '<div class="no-print"><span class="badge">$count labels • Zebra 203 DPI Optimized</span><button class="print-btn" onclick="window.print()">🖨 Print All Labels</button></div>';
        html += '<div class="sheet">';
        html += '${labelsHtml.toString().replaceAll("'", "\\'")}';
        html += '</div>';
        html += '<script>';
        html += '${barcodeJs.toString().replaceAll("'", "\\'")}';
        html += 'setTimeout(function(){window.print();},600);';
        html += '</script>';
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
