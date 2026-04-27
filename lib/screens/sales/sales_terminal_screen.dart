import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/whatsapp_helper.dart';
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
  final _cashPaidCtrl = TextEditingController(text: '0');
  final _upiPaidCtrl = TextEditingController(text: '0');
  String _searchQuery = '';
  String _selectedCategory = 'All';

  @override
  void dispose() {
    _searchCtrl.dispose();
    _customerNameCtrl.dispose();
    _customerPhoneCtrl.dispose();
    _discountCtrl.dispose();
    _cashPaidCtrl.dispose();
    _upiPaidCtrl.dispose();
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
      _cashPaidCtrl.text = '0';
      _upiPaidCtrl.text = '0';

      // Success feedback
      _showSuccessDialog(sale);
    }
  }

  void _showSuccessDialog(SaleModel sale) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card(context),
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
              child: Icon(Icons.check_circle_rounded, color: AppColors.success, size: 40),
            ),
            SizedBox(height: 16),
            Text('Sale Complete!', style: AppTypography.h2.copyWith(color: AppColors.textPrimary(context))),
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
                    final items = sale.items.map((i) => {
                      'name': i.name,
                      'qty': i.quantity,
                      'total': i.total,
                    }).toList();
                    final msg = WhatsAppHelper.invoiceMessage(
                      invoiceNumber: sale.invoiceNumber,
                      total: sale.total,
                      discount: sale.discount,
                      paymentMode: sale.paymentMode,
                      items: items,
                      customerName: sale.customerName,
                    );
                    if (sale.customerPhone.isNotEmpty) {
                      WhatsAppHelper.send(phone: sale.customerPhone, message: msg);
                    } else {
                      // No phone — open with empty phone so user can choose contact
                      WhatsAppHelper.send(phone: '', message: msg);
                    }
                  },
                  icon: Icon(Icons.chat_rounded, size: 18, color: Color(0xFF25D366)),
                  label: const Text('WhatsApp'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Color(0xFF25D366),
                    side: const BorderSide(color: Color(0xFF25D366)),
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
        padding: EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Text('Sales Terminal', style: AppTypography.h1.copyWith(color: AppColors.textPrimary(context))),
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
                      Icon(Icons.qr_code_scanner_rounded, size: 16, color: AppColors.accent),
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
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title + count
          Row(children: [
            Text('Products', style: AppTypography.h4.copyWith(color: AppColors.textPrimary(context))),
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
          SizedBox(height: 12),

          // Search bar
          TextField(
            controller: _searchCtrl,
            onChanged: _onSearchChanged,
            style: TextStyle(color: AppColors.textPrimary(context)),
            decoration: InputDecoration(
              hintText: 'SCAN BARCODE or search by name, brand...',
              hintStyle: TextStyle(color: AppColors.textTertiary(context), fontSize: 13),
              prefixIcon: Icon(Icons.search_rounded, color: AppColors.textTertiary(context)),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.clear_rounded, size: 18, color: AppColors.textTertiary(context)),
                      onPressed: () { _searchCtrl.clear(); setState(() => _searchQuery = ''); })
                  : Icon(Icons.qr_code_scanner_rounded, size: 18, color: AppColors.textTertiary(context)),
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
          const SizedBox(height: 10),

          // Category chips
          if (categories.length > 1)
            SizedBox(
              height: 32,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: categories.length,
                separatorBuilder: (_, __) => SizedBox(width: 6),
                itemBuilder: (_, i) {
                  final cat = categories[i];
                  final isSelected = cat == _selectedCategory;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedCategory = cat),
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.accent.withValues(alpha: 0.2) : AppColors.surface(context),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected ? AppColors.accent : AppColors.cardBorder(context)),
                      ),
                      child: Text(cat, style: AppTypography.labelSmall.copyWith(
                        color: isSelected ? AppColors.accent : AppColors.textSecondary(context),
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                      )),
                    ),
                  );
                },
              ),
            ),
          if (categories.length > 1) SizedBox(height: 10),

          // Product grid
          Expanded(
            child: filteredItems.isEmpty
                ? Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.inventory_2_outlined, size: 48,
                          color: AppColors.textTertiary(context).withValues(alpha: 0.5)),
                      SizedBox(height: 8),
                      Text(
                        _searchQuery.isEmpty ? 'All products shown above' : 'No products found',
                        style: AppTypography.bodyMedium.copyWith(color: AppColors.textTertiary(context)),
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
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surface(context),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.cardBorder(context)),
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
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
                    )),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(item.name,
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.textPrimary(context), fontWeight: FontWeight.w500),
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
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Row(
            children: [
              Icon(Icons.shopping_cart_rounded, color: AppColors.accent, size: 20),
              SizedBox(width: 8),
              Text('Cart', style: AppTypography.h4.copyWith(color: AppColors.textPrimary(context))),
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
          Divider(color: AppColors.cardBorder(context)),
          SizedBox(height: 8),

          // Cart Items
          Expanded(
            child: sales.isCartEmpty
                ? Center(
                    child: Text(
                      'Add products to cart',
                      style: AppTypography.bodyMedium.copyWith(color: AppColors.textTertiary(context)),
                    ),
                  )
                : ListView.builder(
                    itemCount: sales.cart.length,
                    itemBuilder: (context, index) {
                      final item = sales.cart[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.surface(context),
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
                                      color: AppColors.textPrimary(context),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  Text(
                                    '${Formatters.currency(item.price)} × ${item.quantity}',
                                    style: AppTypography.monoSmall.copyWith(color: AppColors.textTertiary(context)),
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
                                  padding: EdgeInsets.symmetric(horizontal: 8),
                                  child: Text(
                                    '${item.quantity}',
                                    style: AppTypography.mono.copyWith(color: AppColors.textPrimary(context)),
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
          SizedBox(height: 8),

          // ─── Payment: Split Cash + UPI ───
          Row(
            children: [
              Expanded(
                child: _miniField(_cashPaidCtrl, 'Cash Paid (₹)',
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => setState(() {})),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _miniField(_upiPaidCtrl, 'UPI/Card Paid (₹)',
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => setState(() {})),
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

          // ─── Totals + Udhaar ───
          Builder(
            builder: (context) {
              final cashPaid = double.tryParse(_cashPaidCtrl.text) ?? 0;
              final upiPaid = double.tryParse(_upiPaidCtrl.text) ?? 0;
              final totalPaid = cashPaid + upiPaid;
              final pendingDue = (sales.total - totalPaid).clamp(0.0, double.infinity);

              return Container(
                padding: EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surface(context),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                ),
                child: Column(
                  children: [
                    _totalRow('Subtotal', Formatters.currency(sales.subtotal)),
                    if (sales.discountPercent > 0)
                      _totalRow(
                        'Discount (${sales.discountPercent.toStringAsFixed(sales.discountPercent.truncateToDouble() == sales.discountPercent ? 0 : 1)}%)',
                        '- ${Formatters.currency(sales.discountAmount)}',
                        color: AppColors.error,
                      ),
                    Divider(color: AppColors.cardBorder(context), height: 16),
                    _totalRow('Total', Formatters.currency(sales.total),
                        isBold: true, color: AppColors.accent),
                    if (totalPaid > 0) ...[                      const SizedBox(height: 4),
                      if (cashPaid > 0)
                        _totalRow('Cash Paid', Formatters.currency(cashPaid), color: AppColors.success),
                      if (upiPaid > 0)
                        _totalRow('UPI/Card Paid', Formatters.currency(upiPaid), color: AppColors.success),
                      if (pendingDue > 0) ...[                        Divider(color: AppColors.warning.withValues(alpha: 0.3), height: 12),
                        _totalRow('Pending Udhaar', Formatters.currency(pendingDue),
                            isBold: true, color: AppColors.warning),
                      ],
                    ],
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 12),

          // ─── Complete Sale ───
          SizedBox(
            height: 52,
            child: ElevatedButton.icon(
              onPressed: sales.isCartEmpty ? null : _completeSale,
              icon: Icon(Icons.check_circle_rounded),
              label: Text(
                'Complete Sale (${sales.cartItemCount} items)',
                style: AppTypography.button.copyWith(color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                foregroundColor: Colors.white,
                disabledBackgroundColor: AppColors.cardBorder(context),
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
      style: TextStyle(color: AppColors.textPrimary(context), fontSize: 13),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: AppColors.textTertiary(context), fontSize: 12),
        filled: true,
        fillColor: AppColors.surface(context),
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: AppColors.cardBorder(context)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: AppColors.cardBorder(context)),
        ),
      ),
    );
  }

  Widget _totalRow(String label, String value, {bool isBold = false, Color? color}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textSecondary(context),
                fontWeight: isBold ? FontWeight.w600 : FontWeight.w400,
              )),
          Text(value,
              style: AppTypography.mono.copyWith(
                color: color ?? AppColors.textPrimary(context),
                fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
                fontSize: isBold ? 18 : 14,
              )),
        ],
      ),
    );
  }
}
