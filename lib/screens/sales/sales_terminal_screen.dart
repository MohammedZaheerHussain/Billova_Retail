import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/formatters.dart';
import '../../core/constants.dart';
import '../../data/models/item_model.dart';
import '../../data/models/sale_model.dart';
import '../../providers/sales_provider.dart';
import '../../providers/inventory_provider.dart';
import '../../providers/cash_till_provider.dart';
import '../../providers/staff_provider.dart';
import '../../providers/customer_provider.dart';

class SalesTerminalScreen extends StatefulWidget {
  const SalesTerminalScreen({super.key});

  @override
  State<SalesTerminalScreen> createState() => _SalesTerminalScreenState();
}

class _SalesTerminalScreenState extends State<SalesTerminalScreen> {
  final _searchCtrl = TextEditingController();
  final _customerNameCtrl = TextEditingController();
  final _customerPhoneCtrl = TextEditingController();
  final _discountCtrl = TextEditingController(text: '0');
  String _searchQuery = '';
  String _selectedCategory = 'All';

  @override
  void dispose() {
    _searchCtrl.dispose();
    _customerNameCtrl.dispose();
    _customerPhoneCtrl.dispose();
    _discountCtrl.dispose();
    super.dispose();
  }

  List<ItemModel> _getFilteredItems(InventoryProvider inventory) {
    var items = inventory.items.where((i) => !i.isOutOfStock).toList();

    // Filter by category
    if (_selectedCategory != 'All') {
      items = items.where((i) =>
        i.category.toLowerCase() == _selectedCategory.toLowerCase()).toList();
    }

    // Filter by search (name OR barcode)
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      items = items.where((i) =>
        i.name.toLowerCase().contains(q) ||
        i.barcode.toLowerCase().contains(q) ||
        i.vendor.toLowerCase().contains(q)
      ).toList();
    }

    return items;
  }

  List<String> _getCategories(InventoryProvider inventory) {
    final cats = inventory.items
        .map((i) => i.category)
        .where((c) => c.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    return ['All', ...cats];
  }

  void _onSearchChanged(String query) {
    setState(() => _searchQuery = query);

    // Auto-detect barcode scan (fast input, usually 8+ chars)
    if (query.length >= 8) {
      final inventory = context.read<InventoryProvider>();
      final exactMatch = inventory.items.firstWhere(
        (i) => i.barcode == query && !i.isOutOfStock,
        orElse: () => ItemModel(id: '', name: '', price: 0),
      );
      if (exactMatch.id.isNotEmpty) {
        _addToCart(exactMatch);
        _searchCtrl.clear();
        setState(() => _searchQuery = '');
      }
    }
  }

  void _addToCart(ItemModel item) {
    context.read<SalesProvider>().addToCart(item);
  }

  Future<void> _completeSale() async {
    final sales = context.read<SalesProvider>();
    if (sales.isCartEmpty) return;

    // Set customer info
    sales.setCustomerInfo(
      _customerNameCtrl.text.trim(),
      _customerPhoneCtrl.text.trim(),
    );

    // Set discount (already applied via percentage)
    final discountPct = double.tryParse(_discountCtrl.text) ?? 0;
    sales.setDiscount(discountPct);

    // Complete sale with staff info
    final staff = context.read<StaffProvider>();
    final sale = await sales.completeSale(
      staffId: staff.currentStaffId ?? '',
      staffName: staff.currentStaffName,
    );

    if (sale != null && mounted) {
      // Deduct stock
      final inventory = context.read<InventoryProvider>();
      for (final item in sale.items) {
        await inventory.deductStock(item.itemId, item.quantity);
      }

      if (!mounted) return;
      // Refresh cash till
      context.read<CashTillProvider>().refresh();

      // Auto-save customer + track purchase stats
      if (sale.customerName.isNotEmpty && sale.customerName != 'Walk-in Customer') {
        final customerProvider = context.read<CustomerProvider>();
        await customerProvider.recordSaleByName(
          sale.customerName,
          sale.customerPhone,
          sale.total,
        );
      }

      // Clear form
      _customerNameCtrl.clear();
      _customerPhoneCtrl.clear();
      _discountCtrl.text = '0';

      // Success feedback
      _showSuccessDialog(sale);
    }
  }

  void _showSuccessDialog(SaleModel sale) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.successBg,
                borderRadius: BorderRadius.circular(32),
              ),
              child: const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 40),
            ),
            const SizedBox(height: 16),
            Text('Sale Complete!', style: AppTypography.h2.copyWith(color: AppColors.textPrimaryDark)),
            const SizedBox(height: 8),
            Text(
              sale.invoiceNumber,
              style: AppTypography.mono.copyWith(color: AppColors.accent, fontSize: 16),
            ),
            const SizedBox(height: 4),
            Text(
              Formatters.currency(sale.total),
              style: AppTypography.monoLarge.copyWith(color: AppColors.success),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    // TODO: Share via WhatsApp
                  },
                  icon: const Icon(Icons.share_rounded, size: 18),
                  label: const Text('Share'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.accent,
                    side: const BorderSide(color: AppColors.accent),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Done', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sales = context.watch<SalesProvider>();
    final inventory = context.watch<InventoryProvider>();
    final width = MediaQuery.of(context).size.width;
    final isWide = width > 900;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Text('Sales Terminal', style: AppTypography.h1.copyWith(color: AppColors.textPrimaryDark)),
                const Spacer(),
                // Barcode scanner indicator
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.qr_code_scanner_rounded, size: 16, color: AppColors.accent),
                      const SizedBox(width: 6),
                      Text('Barcode Ready', style: AppTypography.labelSmall.copyWith(
                          color: AppColors.accent, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            Expanded(
              child: isWide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(flex: 3, child: _buildProductPanel(inventory)),
                        const SizedBox(width: 16),
                        Expanded(flex: 2, child: _buildCartPanel(sales)),
                      ],
                    )
                  : Column(
                      children: [
                        Expanded(flex: 3, child: _buildProductPanel(inventory)),
                        const SizedBox(height: 16),
                        Expanded(flex: 2, child: _buildCartPanel(sales)),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductPanel(InventoryProvider inventory) {
    final filteredItems = _getFilteredItems(inventory);
    final categories = _getCategories(inventory);

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
          // Title + count
          Row(children: [
            Text('Products', style: AppTypography.h4.copyWith(color: AppColors.textPrimaryDark)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text('${filteredItems.length}',
                  style: AppTypography.labelSmall.copyWith(color: AppColors.accent, fontWeight: FontWeight.w700)),
            ),
          ]),
          const SizedBox(height: 12),

          // Search bar
          TextField(
            controller: _searchCtrl,
            onChanged: _onSearchChanged,
            style: const TextStyle(color: AppColors.textPrimaryDark),
            decoration: InputDecoration(
              hintText: 'Search by name, barcode, or brand...',
              hintStyle: const TextStyle(color: AppColors.textTertiaryDark, fontSize: 13),
              prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textTertiaryDark),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 18, color: AppColors.textTertiaryDark),
                      onPressed: () { _searchCtrl.clear(); setState(() => _searchQuery = ''); })
                  : const Icon(Icons.qr_code_scanner_rounded, size: 18, color: AppColors.textTertiaryDark),
              filled: true,
              fillColor: AppColors.surfaceDark,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.cardBorderDark),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.cardBorderDark),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Category chips
          if (categories.length > 1)
            SizedBox(
              height: 32,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: categories.length,
                separatorBuilder: (_, __) => const SizedBox(width: 6),
                itemBuilder: (_, i) {
                  final cat = categories[i];
                  final isSelected = cat == _selectedCategory;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedCategory = cat),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.accent.withValues(alpha: 0.2) : AppColors.surfaceDark,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected ? AppColors.accent : AppColors.cardBorderDark),
                      ),
                      child: Text(cat, style: AppTypography.labelSmall.copyWith(
                        color: isSelected ? AppColors.accent : AppColors.textSecondaryDark,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                      )),
                    ),
                  );
                },
              ),
            ),
          if (categories.length > 1) const SizedBox(height: 10),

          // Product grid
          Expanded(
            child: filteredItems.isEmpty
                ? Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.inventory_2_outlined, size: 48,
                          color: AppColors.textTertiaryDark.withValues(alpha: 0.5)),
                      const SizedBox(height: 8),
                      Text(
                        _searchQuery.isEmpty ? 'All products shown above' : 'No products found',
                        style: AppTypography.bodyMedium.copyWith(color: AppColors.textTertiaryDark),
                      ),
                    ]),
                  )
                : GridView.builder(
                    gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 200,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                      childAspectRatio: 1.5,
                    ),
                    itemCount: filteredItems.length,
                    itemBuilder: (context, index) {
                      final item = filteredItems[index];
                      return _buildProductCard(item);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductCard(ItemModel item) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _addToCart(item),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surfaceDark,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.cardBorderDark),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Top: Name + initial
              Row(
                children: [
                  Container(
                    width: 30, height: 30,
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(child: Text(
                      item.name[0].toUpperCase(),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
                    )),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(item.name,
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.textPrimaryDark, fontWeight: FontWeight.w500),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
              // Bottom: Price + Stock
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(Formatters.currency(item.price),
                      style: AppTypography.mono.copyWith(color: AppColors.accent, fontSize: 12, fontWeight: FontWeight.w700)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: item.isLowStock
                          ? AppColors.warning.withValues(alpha: 0.15)
                          : AppColors.success.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text('${item.quantity}',
                        style: AppTypography.labelSmall.copyWith(
                          color: item.isLowStock ? AppColors.warning : AppColors.success,
                          fontWeight: FontWeight.w700, fontSize: 10)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCartPanel(SalesProvider sales) {
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
          // Header
          Row(
            children: [
              const Icon(Icons.shopping_cart_rounded, color: AppColors.accent, size: 20),
              const SizedBox(width: 8),
              Text('Cart', style: AppTypography.h4.copyWith(color: AppColors.textPrimaryDark)),
              if (!sales.isCartEmpty) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10)),
                  child: Text('${sales.cartItemCount}',
                      style: AppTypography.labelSmall.copyWith(
                          color: AppColors.accent, fontWeight: FontWeight.w700)),
                ),
              ],
              const Spacer(),
              if (!sales.isCartEmpty)
                TextButton(
                  onPressed: sales.clearCart,
                  child: Text('Clear', style: AppTypography.labelSmall.copyWith(color: AppColors.error)),
                ),
            ],
          ),
          const Divider(color: AppColors.cardBorderDark),
          const SizedBox(height: 8),

          // Cart Items
          Expanded(
            child: sales.isCartEmpty
                ? Center(
                    child: Text(
                      'Add products to cart',
                      style: AppTypography.bodyMedium.copyWith(color: AppColors.textTertiaryDark),
                    ),
                  )
                : ListView.builder(
                    itemCount: sales.cart.length,
                    itemBuilder: (context, index) {
                      final item = sales.cart[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceDark,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.name,
                                    style: AppTypography.bodyMedium.copyWith(
                                      color: AppColors.textPrimaryDark,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  Text(
                                    '${Formatters.currency(item.price)} × ${item.quantity}',
                                    style: AppTypography.monoSmall.copyWith(color: AppColors.textTertiaryDark),
                                  ),
                                ],
                              ),
                            ),
                            // Qty controls
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _qtyBtn(Icons.remove, () {
                                  sales.updateCartItemQty(index, item.quantity - 1);
                                }),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                  child: Text(
                                    '${item.quantity}',
                                    style: AppTypography.mono.copyWith(color: AppColors.textPrimaryDark),
                                  ),
                                ),
                                _qtyBtn(Icons.add, () {
                                  sales.updateCartItemQty(index, item.quantity + 1);
                                }),
                              ],
                            ),
                            const SizedBox(width: 12),
                            Text(
                              Formatters.currency(item.total),
                              style: AppTypography.mono.copyWith(
                                color: AppColors.accent,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),

          // ─── Customer Info ───
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _miniField(_customerNameCtrl, 'Customer Name (optional)'),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _miniField(_customerPhoneCtrl, 'Phone (optional)', keyboardType: TextInputType.phone),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // ─── Payment Mode + Discount ───
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: sales.paymentMode,
                  onChanged: (v) => sales.setPaymentMode(v!),
                  dropdownColor: AppColors.cardDark,
                  style: const TextStyle(color: AppColors.textPrimaryDark, fontSize: 13),
                  decoration: InputDecoration(
                    labelText: 'Payment',
                    labelStyle: const TextStyle(color: AppColors.textTertiaryDark, fontSize: 12),
                    filled: true,
                    fillColor: AppColors.surfaceDark,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.cardBorderDark),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.cardBorderDark),
                    ),
                  ),
                  items: AppConstants.paymentModes.map((mode) {
                    return DropdownMenuItem(value: mode, child: Text(mode));
                  }).toList(),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 110,
                child: _miniField(_discountCtrl, 'Discount %',
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (v) {
                      sales.setDiscount(double.tryParse(v) ?? 0);
                    }),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ─── Totals ───
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surfaceDark,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
            ),
            child: Column(
              children: [
                _totalRow('Subtotal', Formatters.currency(sales.subtotal)),
                if (sales.discountPercent > 0) ...[                  _totalRow(
                    'Discount (${sales.discountPercent.toStringAsFixed(sales.discountPercent.truncateToDouble() == sales.discountPercent ? 0 : 1)}%)',
                    '- ${Formatters.currency(sales.discountAmount)}',
                    color: AppColors.error,
                  ),
                ],
                const Divider(color: AppColors.cardBorderDark, height: 16),
                _totalRow('Total', Formatters.currency(sales.total),
                    isBold: true, color: AppColors.accent),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ─── Complete Sale ───
          SizedBox(
            height: 52,
            child: ElevatedButton.icon(
              onPressed: sales.isCartEmpty ? null : _completeSale,
              icon: const Icon(Icons.check_circle_rounded),
              label: Text(
                'Complete Sale (${sales.cartItemCount} items)',
                style: AppTypography.button.copyWith(color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                foregroundColor: Colors.white,
                disabledBackgroundColor: AppColors.cardBorderDark,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _qtyBtn(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(icon, size: 16, color: AppColors.accent),
      ),
    );
  }

  Widget _miniField(TextEditingController ctrl, String hint,
      {TextInputType? keyboardType, void Function(String)? onChanged}) {
    return TextField(
      controller: ctrl,
      keyboardType: keyboardType,
      onChanged: onChanged,
      style: const TextStyle(color: AppColors.textPrimaryDark, fontSize: 13),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppColors.textTertiaryDark, fontSize: 12),
        filled: true,
        fillColor: AppColors.surfaceDark,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.cardBorderDark),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.cardBorderDark),
        ),
      ),
    );
  }

  Widget _totalRow(String label, String value, {bool isBold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textSecondaryDark,
                fontWeight: isBold ? FontWeight.w600 : FontWeight.w400,
              )),
          Text(value,
              style: AppTypography.mono.copyWith(
                color: color ?? AppColors.textPrimaryDark,
                fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
                fontSize: isBold ? 18 : 14,
              )),
        ],
      ),
    );
  }
}
