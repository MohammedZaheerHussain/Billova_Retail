import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/whatsapp_helper.dart';
import '../../core/utils/receipt_printer.dart';
import '../../core/constants.dart';
import '../../data/models/item_model.dart';
import '../../data/models/sale_model.dart';
import '../../providers/sales_provider.dart';
import '../../providers/inventory_provider.dart';
import '../../providers/cash_till_provider.dart';
import '../../providers/staff_provider.dart';
import '../../providers/customer_provider.dart';
import '../../providers/loyalty_settings_provider.dart';
import '../../data/local/db_helper.dart';

class SalesTerminalScreen extends StatefulWidget {
  const SalesTerminalScreen({super.key});

  @override
  State<SalesTerminalScreen> createState() => _SalesTerminalScreenState();
}

class _SalesTerminalScreenState extends State<SalesTerminalScreen> {
  final _searchCtrl = TextEditingController();
  final _searchFocus = FocusNode(); // auto-focus for barcode scanner
  final _customerNameCtrl = TextEditingController();
  final _customerPhoneCtrl = TextEditingController();
  final _discountCtrl = TextEditingController();
  final _cashPaidCtrl = TextEditingController();
  final _upiPaidCtrl = TextEditingController();
  String _searchQuery = '';
  String _selectedCategory = 'All';
  bool _isClearanceMode = false;
  bool _usePoints = false;
  int _availablePoints = 0;
  String _matchedCustomerId = '';

  // Barcode scan timing — scanner fires all chars in < 100ms
  DateTime? _lastKeyTime;
  int _rapidKeyCount = 0;

  @override
  void initState() {
    super.initState();
    // Auto-focus the barcode field when terminal opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _searchFocus.requestFocus();
    });
    // Load GST setting
    Future.microtask(() => context.read<SalesProvider>().loadGstSetting());
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _searchFocus.dispose();
    _customerNameCtrl.dispose();
    _customerPhoneCtrl.dispose();
    _discountCtrl.dispose();
    _cashPaidCtrl.dispose();
    _upiPaidCtrl.dispose();
    super.dispose();
  }

  List<ItemModel> _getFilteredItems(InventoryProvider inventory) {
    var items = inventory.items.where((i) => !i.isOutOfStock).toList();

    // Split by clearance mode
    if (_isClearanceMode) {
      items = items.where((i) => i.storageLocation.startsWith('CLEARANCE:')).toList();
    } else {
      items = items.where((i) => !i.storageLocation.startsWith('CLEARANCE:')).toList();
    }

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

    // ─── Barcode Scanner Detection ───
    // Physical scanners type all chars in rapid succession (<50ms each)
    // then typically send an Enter or the text appears all at once.
    final now = DateTime.now();
    if (_lastKeyTime != null && now.difference(_lastKeyTime!).inMilliseconds < 80) {
      _rapidKeyCount++;
    } else {
      _rapidKeyCount = 1;
    }
    _lastKeyTime = now;

    // Detect scan: rapid input of 4+ characters (covers SKY-XXX-NNN and standard barcodes)
    if (query.length >= 4 && _rapidKeyCount >= 3) {
      _tryBarcodeMatch(query);
    }

    // Also try exact match for any input >= 4 chars (handles paste & slower scanners)
    if (query.length >= 4) {
      // Debounce slightly for manual typing vs instant for scan
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted && _searchCtrl.text == query && query.length >= 4) {
          _tryBarcodeMatch(query);
        }
      });
    }
  }

  void _tryBarcodeMatch(String query) {
    final inventory = context.read<InventoryProvider>();
    final exactMatch = inventory.items.firstWhere(
      (i) => i.barcode.toLowerCase() == query.toLowerCase() &&
        !i.isOutOfStock &&
        (_isClearanceMode
          ? i.storageLocation.startsWith('CLEARANCE:')
          : !i.storageLocation.startsWith('CLEARANCE:')),
      orElse: () => ItemModel(id: '', name: '', price: 0),
    );
    if (exactMatch.id.isNotEmpty) {
      _addToCart(exactMatch);
      _searchCtrl.clear();
      setState(() => _searchQuery = '');
      _rapidKeyCount = 0;
    }
  }

  void _addToCart(ItemModel item) {
    context.read<SalesProvider>().addToCart(item);
    // Re-focus search field so scanner is always ready
    Future.microtask(() {
      if (mounted) _searchFocus.requestFocus();
    });
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

    // ─── Calculate loyalty discount ───
    final loyalty = context.read<LoyaltySettingsProvider>();
    double loyaltyDiscount = 0;
    int pointsToRedeem = 0;
    int pointsEarned = 0;

    if (_usePoints && _matchedCustomerId.isNotEmpty && _availablePoints > 0 && loyalty.isEnabled) {
      final maxDiscount = loyalty.valueOfPoints(_availablePoints);
      loyaltyDiscount = maxDiscount.clamp(0.0, sales.total);
      pointsToRedeem = loyaltyDiscount >= maxDiscount
          ? _availablePoints
          : (loyaltyDiscount / loyalty.redeemValue).floor();
      // Recalculate to avoid rounding mismatch
      loyaltyDiscount = loyalty.valueOfPoints(pointsToRedeem).clamp(0.0, sales.total);
    }

    // Calculate points earned on the reduced total
    final payableTotal = (sales.total - loyaltyDiscount).clamp(0.0, double.infinity);
    if (loyalty.isEnabled) {
      pointsEarned = loyalty.pointsForAmount(payableTotal);
    }

    // Complete sale with staff info + loyalty
    final staff = context.read<StaffProvider>();
    final sale = await sales.completeSale(
      staffId: staff.currentStaffId ?? '',
      staffName: staff.currentStaffName,
      loyaltyDiscount: loyaltyDiscount,
      pointsRedeemed: pointsToRedeem,
      pointsEarned: pointsEarned,
    );

    if (sale != null) {
      // ─── CRITICAL: Save customer FIRST (before any mounted check) ───
      // Customer data must NEVER be lost, even if the widget unmounts
      final customerProvider = context.read<CustomerProvider>();
      if (sale.customerName.isNotEmpty && sale.customerName != 'Walk-in Customer') {
        final earnRate = loyalty.isEnabled ? loyalty.earnRate : 0;

        // Redeem points first (if used)
        if (pointsToRedeem > 0 && _matchedCustomerId.isNotEmpty) {
          await customerProvider.redeemPoints(_matchedCustomerId, pointsToRedeem);
          // Log redemption to audit trail
          await _logLoyaltyTransaction(
            customerId: _matchedCustomerId,
            type: 'redeemed',
            points: pointsToRedeem,
            saleId: sale.id,
            balanceAfter: (_availablePoints - pointsToRedeem).clamp(0, _availablePoints),
          );
        }

        await customerProvider.recordSaleByName(
          sale.customerName,
          sale.customerPhone,
          sale.total,
          earnRate: earnRate,
        );

        // Log earning to audit trail
        if (pointsEarned > 0 && loyalty.isEnabled) {
          final customer = customerProvider.findByPhone(sale.customerPhone) ??
              customerProvider.findByName(sale.customerName);
          if (customer != null) {
            await _logLoyaltyTransaction(
              customerId: customer.id,
              type: 'earned',
              points: pointsEarned,
              saleId: sale.id,
              balanceAfter: customer.loyaltyPoints,
            );
          }
        }
      }

      // Deduct stock
      final inventory = context.read<InventoryProvider>();
      for (final item in sale.items) {
        await inventory.deductStock(item.itemId, item.quantity);
      }

      if (!mounted) return;
      // Refresh cash till
      context.read<CashTillProvider>().refresh();

      // Capture payment values before clearing
      final cashPaid = double.tryParse(_cashPaidCtrl.text) ?? 0;
      final upiPaid = double.tryParse(_upiPaidCtrl.text) ?? 0;

      // Store loyalty info before clearing
      final redeemedPts = pointsToRedeem;
      final earnedPts = pointsEarned;

      // Clear form
      _customerNameCtrl.clear();
      _customerPhoneCtrl.clear();
      _discountCtrl.clear();
      _cashPaidCtrl.clear();
      _upiPaidCtrl.clear();
      _searchCtrl.clear();
      setState(() { _usePoints = false; _availablePoints = 0; _matchedCustomerId = ''; _searchQuery = ''; });
      // Re-focus barcode field for next customer
      Future.microtask(() { if (mounted) _searchFocus.requestFocus(); });

      // Auto-print receipt (if enabled in settings)
      ReceiptPrinter.printReceipt(sale, cashPaid: cashPaid, upiPaid: upiPaid);

      // Success feedback
      _showSuccessDialog(sale, cashPaid: cashPaid, upiPaid: upiPaid,
          pointsRedeemed: redeemedPts, pointsEarned: earnedPts);
    }
  }

  /// Log a loyalty transaction to the audit trail
  Future<void> _logLoyaltyTransaction({
    required String customerId,
    required String type,
    required int points,
    required String saleId,
    required int balanceAfter,
  }) async {
    try {
      final db = DBHelper.instance;
      await db.insert('loyalty_transactions', {
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'customer_id': customerId,
        'type': type,
        'points': points,
        'sale_id': saleId,
        'balance_after': balanceAfter,
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('⚠️ Failed to log loyalty transaction: $e');
    }
  }

  void _showSuccessDialog(SaleModel sale, {double cashPaid = 0, double upiPaid = 0,
      int pointsRedeemed = 0, int pointsEarned = 0}) {
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
            // ─── Loyalty Points Summary ───
            if (pointsRedeemed > 0 || pointsEarned > 0) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.star_rounded, color: AppColors.warning, size: 18),
                    const SizedBox(width: 6),
                    Text(
                      [
                        if (pointsEarned > 0) '+$pointsEarned earned',
                        if (pointsRedeemed > 0) '$pointsRedeemed redeemed',
                      ].join(' · '),
                      style: TextStyle(
                        color: AppColors.warning,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
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
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  onPressed: () {
                    ReceiptPrinter.manualPrint(sale, cashPaid: cashPaid, upiPaid: upiPaid);
                  },
                  icon: Icon(Icons.print_rounded, size: 18, color: AppColors.accent),
                  label: const Text('Print'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.accent,
                    side: BorderSide(color: AppColors.accent),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(width: 10),
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
                Text(_isClearanceMode ? 'Stock Clearance' : 'Sales Terminal',
                    style: AppTypography.h1.copyWith(
                        color: _isClearanceMode ? AppColors.warning : AppColors.textPrimary(context))),
                const Spacer(),
                // ─── Clearance Mode Toggle ───
                GestureDetector(
                  onTap: () => setState(() {
                    _isClearanceMode = !_isClearanceMode;
                    _selectedCategory = 'All';
                    _searchQuery = '';
                    _searchCtrl.clear();
                  }),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: _isClearanceMode
                          ? AppColors.warning.withValues(alpha: 0.2)
                          : AppColors.surface(context),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _isClearanceMode ? AppColors.warning : AppColors.cardBorder(context),
                        width: _isClearanceMode ? 1.5 : 1),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _isClearanceMode ? Icons.local_offer_rounded : Icons.local_offer_outlined,
                          size: 16,
                          color: _isClearanceMode ? AppColors.warning : AppColors.textTertiary(context)),
                        const SizedBox(width: 6),
                        Text(
                          'Stock Clearance',
                          style: AppTypography.labelSmall.copyWith(
                            color: _isClearanceMode ? AppColors.warning : AppColors.textSecondary(context),
                            fontWeight: _isClearanceMode ? FontWeight.w700 : FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
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
            Text(_isClearanceMode ? 'Clearance Items' : 'Products',
                style: AppTypography.h4.copyWith(
                    color: _isClearanceMode ? AppColors.warning : AppColors.textPrimary(context))),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: (_isClearanceMode ? AppColors.warning : AppColors.accent).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text('${filteredItems.length}',
                  style: AppTypography.labelSmall.copyWith(
                      color: _isClearanceMode ? AppColors.warning : AppColors.accent,
                      fontWeight: FontWeight.w700)),
            ),
          ]),
          SizedBox(height: 12),

          // Search bar
          TextField(
            controller: _searchCtrl,
            focusNode: _searchFocus,
            autofocus: true,
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
    final isClearance = item.storageLocation.startsWith('CLEARANCE:');
    final accentColor = isClearance ? AppColors.warning : AppColors.accent;

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
            border: Border.all(color: isClearance
                ? AppColors.warning.withValues(alpha: 0.4)
                : AppColors.cardBorder(context)),
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
                      gradient: isClearance
                          ? LinearGradient(colors: [AppColors.warning, AppColors.warning.withValues(alpha: 0.7)])
                          : AppColors.primaryGradient,
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
                  if (isClearance)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(3)),
                      child: Text('SALE', style: TextStyle(
                          color: AppColors.warning, fontSize: 7, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                    ),
                ],
              ),
              // Bottom: Price + Stock
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(Formatters.currency(item.price),
                        style: AppTypography.mono.copyWith(color: accentColor, fontSize: 12, fontWeight: FontWeight.w700)),
                    if (isClearance && item.originalPrice > 0)
                      Text(Formatters.currency(item.originalPrice),
                          style: TextStyle(color: AppColors.textTertiary(context), fontSize: 9,
                              decoration: TextDecoration.lineThrough, decorationColor: AppColors.textTertiary(context))),
                  ]),
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
                child: _miniField(_customerPhoneCtrl, 'Phone (optional)',
                    keyboardType: TextInputType.phone,
                    onChanged: (_) => setState(() {})),
              ),
            ],
          ),
          // ─── Loyalty Points Badge ───
          _buildLoyaltyBadge(),
          const SizedBox(height: 10),

          // ─── Payment Split & Discount ───
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.surface(context),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Icon(Icons.payments_rounded, size: 14, color: AppColors.accent),
                  const SizedBox(width: 6),
                  Text('Payment Split', style: TextStyle(
                      color: AppColors.accent, fontSize: 11, fontWeight: FontWeight.w700)),
                ]),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _miniField(_cashPaidCtrl, 'Cash Paid (₹)',
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          onChanged: (_) => setState(() {})),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _miniField(_upiPaidCtrl, 'UPI/Card (₹)',
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          onChanged: (_) => setState(() {})),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 100,
                      child: _miniField(_discountCtrl, 'Discount %',
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          onChanged: (v) {
                            sales.setDiscount(double.tryParse(v) ?? 0);
                          }),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ─── Totals + Udhaar ───
          Builder(
            builder: (context) {
              final cashPaid = double.tryParse(_cashPaidCtrl.text) ?? 0;
              final upiPaid = double.tryParse(_upiPaidCtrl.text) ?? 0;
              final totalPaid = cashPaid + upiPaid;

              // Calculate loyalty discount for display
              final loyalty = context.read<LoyaltySettingsProvider>();
              double loyaltyDisc = 0;
              if (_usePoints && _availablePoints > 0 && loyalty.isEnabled) {
                loyaltyDisc = loyalty.valueOfPoints(_availablePoints).clamp(0.0, sales.total);
              }
              final payableTotal = (sales.total - loyaltyDisc).clamp(0.0, double.infinity);
              final pendingDue = (payableTotal - totalPaid).clamp(0.0, double.infinity);

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
                    // GST breakdown (only when enabled)
                    if (sales.gstEnabled && sales.gstAmount > 0) ...[
                      Divider(color: AppColors.cardBorder(context), height: 12),
                      _totalRow('CGST', '+ ${Formatters.currency(sales.cgst)}',
                          color: AppColors.accent),
                      _totalRow('SGST', '+ ${Formatters.currency(sales.sgst)}',
                          color: AppColors.accent),
                    ],
                    Divider(color: AppColors.cardBorder(context), height: 16),
                    _totalRow('Total', Formatters.currency(sales.grandTotal),
                        isBold: loyaltyDisc == 0, color: AppColors.accent),
                    // Loyalty points discount line
                    if (_usePoints && _availablePoints > 0 && loyalty.isEnabled) ...[
                      _totalRow('⭐ Points Redeemed ($_availablePoints pts)',
                          '- ${Formatters.currency(loyaltyDisc)}',
                          color: AppColors.warning),
                      Divider(color: AppColors.warning.withValues(alpha: 0.3), height: 12),
                      _totalRow('Payable', Formatters.currency(payableTotal),
                          isBold: true, color: AppColors.success),
                    ],
                    if (totalPaid > 0) ...[
                      const SizedBox(height: 4),
                      if (cashPaid > 0)
                        _totalRow('Cash Paid', Formatters.currency(cashPaid), color: AppColors.success),
                      if (upiPaid > 0)
                        _totalRow('UPI/Card Paid', Formatters.currency(upiPaid), color: AppColors.success),
                      if (pendingDue > 0) ...[
                        Divider(color: AppColors.warning.withValues(alpha: 0.3), height: 12),
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
  Widget _buildLoyaltyBadge() {
    final loyalty = context.watch<LoyaltySettingsProvider>();
    if (!loyalty.isEnabled) return const SizedBox.shrink();

    final customers = context.read<CustomerProvider>();
    final phone = _customerPhoneCtrl.text.trim();
    final name = _customerNameCtrl.text.trim();

    // Try to find customer — phone first (more unique), then name
    final customer = (phone.isNotEmpty ? customers.findByPhone(phone) : null) ??
        (name.isNotEmpty ? customers.findByName(name) : null);

    if (customer == null) {
      // No customer matched — clear state if needed
      if (_matchedCustomerId.isNotEmpty) {
        Future.microtask(() => setState(() {
          _matchedCustomerId = '';
          _availablePoints = 0;
          _usePoints = false;
        }));
      }
      return const SizedBox.shrink();
    }

    // Update matched customer
    if (_matchedCustomerId != customer.id) {
      Future.microtask(() => setState(() {
        _matchedCustomerId = customer.id;
        _availablePoints = customer.loyaltyPoints;
        if (customer.loyaltyPoints < loyalty.minRedeem) _usePoints = false;
      }));
    }

    final hasPoints = customer.loyaltyPoints > 0;
    final canRedeem = customer.loyaltyPoints >= loyalty.minRedeem;
    final pointsValue = loyalty.valueOfPoints(customer.loyaltyPoints);

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: hasPoints
            ? AppColors.warning.withValues(alpha: 0.08)
            : AppColors.accent.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: hasPoints
            ? AppColors.warning.withValues(alpha: 0.25)
            : AppColors.accent.withValues(alpha: 0.15)),
      ),
      child: Row(children: [
        Icon(Icons.star_rounded,
            color: hasPoints ? AppColors.warning : AppColors.textTertiary(context),
            size: 20),
        const SizedBox(width: 8),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (hasPoints)
            Text('${customer.loyaltyPoints} points (${Formatters.currency(pointsValue)} value)',
                style: TextStyle(color: AppColors.warning, fontWeight: FontWeight.w600, fontSize: 12))
          else
            Text('No points yet — earn with purchases!',
                style: TextStyle(color: AppColors.textSecondary(context), fontWeight: FontWeight.w500, fontSize: 12)),
          if (hasPoints && !canRedeem)
            Text('Min ${loyalty.minRedeem} pts to redeem',
                style: TextStyle(color: AppColors.textTertiary(context), fontSize: 10)),
        ])),
        if (canRedeem)
          Row(mainAxisSize: MainAxisSize.min, children: [
            Text('Use', style: TextStyle(color: AppColors.warning, fontSize: 11, fontWeight: FontWeight.w500)),
            const SizedBox(width: 4),
            SizedBox(
              height: 24,
              child: Switch.adaptive(
                value: _usePoints,
                onChanged: (v) => setState(() => _usePoints = v),
                activeColor: AppColors.warning,
                activeTrackColor: AppColors.warning.withValues(alpha: 0.4),
              ),
            ),
          ]),
      ]),
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
