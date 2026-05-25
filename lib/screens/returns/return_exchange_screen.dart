import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/formatters.dart';
import '../../providers/sales_provider.dart';
import '../../providers/inventory_provider.dart';
import '../../data/models/sale_model.dart';
import '../../data/models/item_model.dart';

class ReturnExchangeScreen extends StatefulWidget {
  const ReturnExchangeScreen({super.key});
  @override
  State<ReturnExchangeScreen> createState() => _ReturnExchangeScreenState();
}

class _ReturnExchangeScreenState extends State<ReturnExchangeScreen> {
  final _searchCtrl = TextEditingController();
  final _searchFocus = FocusNode();
  SaleModel? _foundSale;
  String _status = '';
  bool _isReturn = true;
  String _reason = 'Defective';
  String _refundMethod = 'Cash';
  final Map<int, int> _returnQty = {};
  // Exchange state
  final List<_ExchangeItem> _exchangeItems = [];
  final _exchSearchCtrl = TextEditingController();
  String _exchSearch = '';
  // Live search suggestions
  List<SaleModel> _filteredSales = [];
  bool _showSuggestions = false;

  static const _reasons = ['Defective', 'Wrong Size', 'Wrong Item', 'Changed Mind', 'Other'];
  static const _refundMethods = ['Cash', 'UPI', 'Store Credit'];
  static const int _returnWindowDays = 7;

  @override
  void dispose() {
    _searchCtrl.dispose();
    _searchFocus.dispose();
    _exchSearchCtrl.dispose();
    super.dispose();
  }

  bool get _isExpired {
    if (_foundSale == null) return false;
    return DateTime.now().difference(_foundSale!.createdAt).inDays > _returnWindowDays;
  }

  int get _daysLeft {
    if (_foundSale == null) return 0;
    return _returnWindowDays - DateTime.now().difference(_foundSale!.createdAt).inDays;
  }

  // ─── Discount-Aware Refund Calculation ───
  // Each item's effective paid price = item.total × (sale.total / sale.subtotal)
  // This proportionally distributes any bill-level discount across items.
  double _effectiveItemTotal(SaleItem item) {
    final sale = _foundSale!;
    if (sale.subtotal <= 0) return 0;
    // Proportional share: what fraction of the final bill does this item represent?
    return double.parse((item.total * (sale.total / sale.subtotal)).toStringAsFixed(2));
  }

  double _effectivePerUnit(SaleItem item) {
    if (item.quantity <= 0) return 0;
    return double.parse((_effectiveItemTotal(item) / item.quantity).toStringAsFixed(2));
  }

  double get _returnTotal => _returnQty.entries.fold(0.0, (sum, e) {
    final item = _foundSale!.items[e.key];
    return sum + (_effectivePerUnit(item) * e.value);
  });

  double get _exchangeTotal => _exchangeItems.fold(0.0, (s, e) => s + e.price * e.qty);

  double get _netSettlement => _exchangeTotal - _returnTotal;

  void _onSearchChanged(String q) {
    if (q.trim().isEmpty) {
      setState(() { _filteredSales = []; _showSuggestions = false; });
      return;
    }
    final sales = context.read<SalesProvider>();
    final upper = q.trim().toUpperCase();
    final lower = q.trim().toLowerCase();
    final matches = sales.allSales.where((s) =>
      s.invoiceNumber.toUpperCase().contains(upper) ||
      s.customerPhone.contains(q.trim()) ||
      s.customerName.toLowerCase().contains(lower)
    ).toList();
    setState(() { _filteredSales = matches; _showSuggestions = true; });
  }

  void _selectSale(SaleModel sale) {
    _searchCtrl.text = sale.invoiceNumber;
    setState(() {
      _foundSale = sale;
      _returnQty.clear();
      _exchangeItems.clear();
      _showSuggestions = false;
      _filteredSales = [];
      _status = _isExpired ? 'EXPIRED' : 'FOUND';
    });
  }

  void _lookupInvoice() {
    final sales = context.read<SalesProvider>();
    final q = _searchCtrl.text.trim();
    if (q.isEmpty) return;
    final upper = q.toUpperCase();
    final lower = q.toLowerCase();

    final match = sales.allSales.where((s) =>
      s.invoiceNumber.toUpperCase() == upper ||
      s.customerPhone == q ||
      s.customerName.toLowerCase().contains(lower)
    ).toList();

    setState(() {
      _returnQty.clear();
      _exchangeItems.clear();
      _showSuggestions = false;
      _filteredSales = [];
      if (match.isEmpty) {
        _foundSale = null;
        _status = 'No invoice found for "$q"';
      } else {
        _foundSale = match.first;
        if (_isExpired) {
          _status = 'EXPIRED';
        } else {
          _status = 'FOUND';
        }
      }
    });
  }

  Future<void> _processReturn() async {
    if (_foundSale == null || _returnQty.isEmpty) return;
    final inventory = context.read<InventoryProvider>();
    double refundTotal = 0;

    for (final entry in _returnQty.entries) {
      final item = _foundSale!.items[entry.key];
      // Use effective paid price (after discount), NOT original price
      refundTotal += _effectivePerUnit(item) * entry.value;
      await inventory.restockItem(item.itemId, entry.value);
    }

    if (!mounted) return;
    _showSuccess('Return processed — ${Formatters.currency(refundTotal)} refunded via $_refundMethod');
    _reset();
  }

  Future<void> _processExchange() async {
    if (_foundSale == null || _returnQty.isEmpty || _exchangeItems.isEmpty) return;
    final inventory = context.read<InventoryProvider>();

    // Restock returned items
    for (final entry in _returnQty.entries) {
      final item = _foundSale!.items[entry.key];
      await inventory.restockItem(item.itemId, entry.value);
    }
    // Deduct new items
    for (final ex in _exchangeItems) {
      await inventory.deductStock(ex.id, ex.qty);
    }

    if (!mounted) return;
    final net = _netSettlement;
    final msg = net > 0
        ? 'Exchange done — Customer pays ${Formatters.currency(net)}'
        : net < 0
            ? 'Exchange done — Refund ${Formatters.currency(net.abs())} to customer'
            : 'Exchange done — Even swap, no payment needed';
    _showSuccess(msg);
    _reset();
  }

  void _showSuccess(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: AppColors.success,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  /// Check if user has unsaved work in this session
  bool get _hasUnsavedWork =>
      _returnQty.isNotEmpty || _exchangeItems.isNotEmpty;

  /// Show confirmation dialog before resetting
  void _confirmAndReset() {
    if (!_hasUnsavedWork) {
      _resetAndFocus();
      return;
    }
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 22),
          const SizedBox(width: 10),
          Text('Close Session?', style: AppTypography.h4.copyWith(
              color: AppColors.textPrimary(context))),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('You have unsaved changes in this return session. Closing will discard all selections.',
              style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textSecondary(context), height: 1.5)),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.warning.withValues(alpha: 0.2)),
            ),
            child: Row(children: [
              Icon(Icons.info_outline_rounded, size: 16, color: AppColors.warning),
              const SizedBox(width: 8),
              Expanded(child: Text(
                '${_returnQty.length} item(s) selected${_exchangeItems.isNotEmpty ? ", ${_exchangeItems.length} exchange item(s)" : ""}',
                style: AppTypography.labelSmall.copyWith(
                    color: AppColors.warning, fontWeight: FontWeight.w600),
              )),
            ]),
          ),
        ]),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: AppColors.textSecondary(context))),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              _resetAndFocus();
            },
            icon: const Icon(Icons.close_rounded, size: 16),
            label: const Text('Close Session'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }

  void _reset() {
    setState(() {
      _foundSale = null;
      _status = '';
      _returnQty.clear();
      _exchangeItems.clear();
      _searchCtrl.clear();
      _exchSearchCtrl.clear();
      _exchSearch = '';
    });
  }

  void _resetAndFocus() {
    _reset();
    // Auto-focus search field after a frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _searchFocus.requestFocus();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return KeyboardListener(
      focusNode: FocusNode(),
      autofocus: true,
      onKeyEvent: (event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.escape &&
            _foundSale != null) {
          _confirmAndReset();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Header
            Row(children: [
              Text('Returns & Exchange', style: AppTypography.h1.copyWith(
                  color: isDark ? AppColors.textPrimary(context) : AppColors.textPrimaryLight)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.warning.withValues(alpha: 0.3))),
                child: Text('$_returnWindowDays Day Return Policy',
                    style: AppTypography.labelSmall.copyWith(
                        color: AppColors.warning, fontWeight: FontWeight.w700)),
              ),
            ]),
            const SizedBox(height: 16),
            // Toggle + Close Session button
            Row(children: [
              _toggleBtn('Return (Refund)', _isReturn, () => setState(() => _isReturn = true)),
              const SizedBox(width: 10),
              _toggleBtn('Exchange (Swap)', !_isReturn, () => setState(() => _isReturn = false)),
              if (_foundSale != null) ...[
                const Spacer(),
                _closeSessionButton(),
              ],
            ]),
            const SizedBox(height: 16),
            // Search
            Row(children: [
              Expanded(child: TextField(
                controller: _searchCtrl,
                focusNode: _searchFocus,
                style: TextStyle(color: AppColors.textPrimary(context), fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Search by Invoice No / Phone / Customer Name',
                  hintStyle: TextStyle(color: AppColors.textTertiary(context), fontSize: 13),
                  prefixIcon: Icon(Icons.search_rounded, color: AppColors.textTertiary(context)),
                  filled: true,
                  fillColor: isDark ? AppColors.surface(context) : Colors.grey.shade50,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.cardBorder(context))),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.cardBorder(context))),
                ),
                onSubmitted: (_) => _lookupInvoice(),
                onChanged: _onSearchChanged,
              )),
              const SizedBox(width: 10),
              SizedBox(height: 48, child: ElevatedButton.icon(
                onPressed: _lookupInvoice,
                icon: const Icon(Icons.receipt_long_rounded, size: 18),
                label: const Text('Lookup'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary, foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              )),
            ]),
            if (_status.isNotEmpty && _foundSale == null && !_showSuggestions) ...[
              const SizedBox(height: 8),
              Text(_status, style: AppTypography.labelSmall.copyWith(
                  color: AppColors.error, fontWeight: FontWeight.w600)),
            ],
            const SizedBox(height: 16),
            // Content — show suggestions, invoice, or empty state
            Expanded(child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              child: _showSuggestions && _foundSale == null
                  ? _buildSuggestionsList(isDark)
                  : _foundSale == null
                      ? _buildEmptyState()
                      : _buildInvoiceView(isDark),
            )),
          ]),
        ),
      ),
    );
  }

  /// Close Session button widget
  Widget _closeSessionButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _confirmAndReset,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.error.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.close_rounded, size: 16, color: AppColors.error),
            const SizedBox(width: 6),
            Text('Close Session', style: AppTypography.labelSmall.copyWith(
                color: AppColors.error, fontWeight: FontWeight.w700, fontSize: 12)),
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text('ESC', style: AppTypography.labelSmall.copyWith(
                  color: AppColors.error.withValues(alpha: 0.7), fontSize: 9, fontWeight: FontWeight.w600)),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _buildSuggestionsList(bool isDark) {
    if (_filteredSales.isEmpty) {
      return Center(child: Text('No invoices match your search',
          style: AppTypography.bodyMedium.copyWith(color: AppColors.textTertiary(context))));
    }
    return ListView.builder(
      itemCount: _filteredSales.length,
      itemBuilder: (ctx, i) {
        final sale = _filteredSales[i];
        final days = DateTime.now().difference(sale.createdAt).inDays;
        final eligible = days <= _returnWindowDays;
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: AppColors.card(context),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: eligible
                ? AppColors.success.withValues(alpha: 0.3)
                : AppColors.error.withValues(alpha: 0.2)),
          ),
          child: ListTile(
            onTap: () => _selectSale(sale),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            leading: Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10)),
              child: Icon(Icons.receipt_rounded, color: AppColors.primary, size: 20),
            ),
            title: Row(children: [
              Text(sale.invoiceNumber, style: AppTypography.mono.copyWith(
                  color: AppColors.accent, fontSize: 13, fontWeight: FontWeight.w700)),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: eligible ? AppColors.successBg : AppColors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4)),
                child: Text(eligible ? '${_returnWindowDays - days}d left' : 'Expired',
                    style: TextStyle(color: eligible ? AppColors.success : AppColors.error,
                        fontSize: 10, fontWeight: FontWeight.w700)),
              ),
            ]),
            subtitle: Text(
              '${sale.customerName.isNotEmpty ? sale.customerName : "Walk-in"} • ${sale.items.length} items • ${Formatters.currency(sale.total)}',
              style: TextStyle(color: AppColors.textTertiary(context), fontSize: 12)),
            trailing: Icon(Icons.chevron_right_rounded, color: AppColors.textTertiary(context)),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.swap_horiz_rounded, size: 64, color: AppColors.accent.withValues(alpha: 0.2)),
      const SizedBox(height: 12),
      Text('Search by invoice, phone, or name', style: AppTypography.bodyMedium.copyWith(
          color: AppColors.textTertiary(context))),
    ]));
  }

  Widget _buildInvoiceView(bool isDark) {
    final sale = _foundSale!;
    final expired = _isExpired;
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Left: Invoice + Items
      Expanded(flex: 3, child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.card(context), borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.cardBorder(context))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Invoice header
          Row(children: [
            Text(sale.invoiceNumber, style: AppTypography.mono.copyWith(
                color: AppColors.accent, fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: expired ? AppColors.error.withValues(alpha: 0.1) : AppColors.success.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6)),
              child: Text(expired ? '🔴 Expired' : '🟢 ${_daysLeft}d left',
                  style: AppTypography.labelSmall.copyWith(
                      color: expired ? AppColors.error : AppColors.success,
                      fontWeight: FontWeight.w700)),
            ),
            const Spacer(),
            Text(Formatters.currency(sale.total), style: AppTypography.monoLarge.copyWith(color: AppColors.accent)),
          ]),
          const SizedBox(height: 4),
          Row(children: [
            Icon(Icons.person_rounded, size: 14, color: AppColors.textTertiary(context)),
            const SizedBox(width: 4),
            Text(sale.customerName.isNotEmpty ? sale.customerName : 'Walk-in',
                style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary(context))),
            const SizedBox(width: 16),
            Icon(Icons.calendar_today_rounded, size: 14, color: AppColors.textTertiary(context)),
            const SizedBox(width: 4),
            Text(sale.createdAt.toIso8601String().substring(0, 10),
                style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary(context))),
            if (sale.customerPhone.isNotEmpty) ...[
              const SizedBox(width: 16),
              Icon(Icons.phone_rounded, size: 14, color: AppColors.textTertiary(context)),
              const SizedBox(width: 4),
              Text(sale.customerPhone, style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textSecondary(context))),
            ],
          ]),
          if (expired) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity, padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
              child: Row(children: [
                Icon(Icons.warning_rounded, size: 16, color: AppColors.error),
                const SizedBox(width: 8),
                Text('Return window expired. View only — no actions allowed.',
                    style: AppTypography.labelSmall.copyWith(color: AppColors.error)),
              ]),
            ),
          ],
          Divider(color: AppColors.cardBorder(context), height: 24),
          // Reason
          if (!expired) Row(children: [
            Text('Reason: ', style: AppTypography.labelMedium.copyWith(
                color: AppColors.textSecondary(context))),
            DropdownButton<String>(
              value: _reason, dropdownColor: AppColors.card(context),
              style: TextStyle(color: AppColors.textPrimary(context), fontSize: 13),
              items: _reasons.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
              onChanged: (v) => setState(() => _reason = v!),
            ),
            if (_isReturn) ...[
              const SizedBox(width: 20),
              Text('Refund via: ', style: AppTypography.labelMedium.copyWith(
                  color: AppColors.textSecondary(context))),
              DropdownButton<String>(
                value: _refundMethod, dropdownColor: AppColors.card(context),
                style: TextStyle(color: AppColors.textPrimary(context), fontSize: 13),
                items: _refundMethods.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                onChanged: (v) => setState(() => _refundMethod = v!),
              ),
            ],
          ]),
          const SizedBox(height: 8),
          Text('Select items & quantity to ${_isReturn ? "return" : "exchange"}:',
              style: AppTypography.labelMedium.copyWith(
                  color: AppColors.textSecondary(context), fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          // Items list
          Expanded(child: ListView.builder(
            itemCount: sale.items.length,
            itemBuilder: (_, i) {
              final item = sale.items[i];
              final qty = _returnQty[i] ?? 0;
              final maxQty = item.quantity;
              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: qty > 0 ? AppColors.error.withValues(alpha: 0.06) : AppColors.surface(context),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: qty > 0
                      ? AppColors.error.withValues(alpha: 0.4) : AppColors.cardBorder(context))),
                child: Row(children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(item.name, style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.textPrimary(context), fontWeight: FontWeight.w500)),
                    // Show effective paid price (after discount), not original catalog price
                    Text('Purchased: ${item.quantity} × ${Formatters.currency(_effectivePerUnit(item))}'
                        '${_foundSale!.discount > 0 ? " (MRP ${Formatters.currency(item.price)})" : ""}',
                        style: AppTypography.labelSmall.copyWith(color: AppColors.textTertiary(context))),
                  ])),
                  if (qty > 0)
                    Text(Formatters.currency(_effectivePerUnit(item) * qty),
                        style: AppTypography.mono.copyWith(color: AppColors.error, fontSize: 12, fontWeight: FontWeight.w700)),
                  const SizedBox(width: 12),
                  // Qty controls
                  if (!expired) ...[
                    IconButton(
                      icon: Icon(Icons.remove_circle_outline, size: 20,
                          color: qty > 0 ? AppColors.error : AppColors.textTertiary(context)),
                      onPressed: qty > 0 ? () => setState(() {
                        if (qty <= 1) { _returnQty.remove(i); } else { _returnQty[i] = qty - 1; }
                      }) : null,
                    ),
                    Container(
                      width: 32, alignment: Alignment.center,
                      child: Text('$qty', style: AppTypography.mono.copyWith(
                          color: AppColors.textPrimary(context), fontWeight: FontWeight.w700)),
                    ),
                    IconButton(
                      icon: Icon(Icons.add_circle_outline, size: 20,
                          color: qty < maxQty ? AppColors.success : AppColors.textTertiary(context)),
                      onPressed: qty < maxQty ? () => setState(() => _returnQty[i] = qty + 1) : null,
                    ),
                    Text('/ $maxQty', style: AppTypography.labelSmall.copyWith(
                        color: AppColors.textTertiary(context))),
                  ],
                ]),
              );
            },
          )),
        ]),
      )),
      const SizedBox(width: 16),
      // Right: Settlement panel
      Expanded(flex: 2, child: _buildSettlementPanel(isDark)),
    ]);
  }

  Widget _buildSettlementPanel(bool isDark) {
    final hasReturn = _returnQty.isNotEmpty;
    if (_isReturn) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.card(context), borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.cardBorder(context))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.keyboard_return_rounded, size: 20, color: AppColors.error),
            const SizedBox(width: 8),
            Text('Return Summary', style: AppTypography.h4.copyWith(color: AppColors.textPrimary(context))),
          ]),
          Divider(color: AppColors.cardBorder(context), height: 24),
          if (!hasReturn)
            Expanded(child: Center(child: Text('Select items to return',
                style: AppTypography.bodySmall.copyWith(color: AppColors.textTertiary(context)))))
          else ...[
            ..._returnQty.entries.map((e) {
              final item = _foundSale!.items[e.key];
              return Padding(padding: const EdgeInsets.only(bottom: 6), child: Row(children: [
                Expanded(child: Text('${item.name} × ${e.value}', style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textPrimary(context)))),
                // Use effective paid amount (discount-aware)
                Text(Formatters.currency(_effectivePerUnit(item) * e.value), style: AppTypography.mono.copyWith(
                    color: AppColors.error, fontSize: 12)),
              ]));
            }),
            const Spacer(),
            Divider(color: AppColors.cardBorder(context)),
            Row(children: [
              Text('Refund ($_refundMethod)', style: AppTypography.labelMedium.copyWith(
                  color: AppColors.textSecondary(context))),
              const Spacer(),
              Text(Formatters.currency(_returnTotal), style: AppTypography.monoLarge.copyWith(
                  color: AppColors.error, fontWeight: FontWeight.w700)),
            ]),
            const SizedBox(height: 12),
            SizedBox(width: double.infinity, height: 48, child: ElevatedButton.icon(
              onPressed: _isExpired ? null : _processReturn,
              icon: const Icon(Icons.keyboard_return_rounded, size: 18),
              label: Text('Process Return', style: AppTypography.button.copyWith(color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error, foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            )),
          ],
        ]),
      );
    }
    // Exchange panel
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card(context), borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder(context))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.swap_horiz_rounded, size: 20, color: AppColors.warning),
          const SizedBox(width: 8),
          Text('Exchange', style: AppTypography.h4.copyWith(color: AppColors.textPrimary(context))),
        ]),
        Divider(color: AppColors.cardBorder(context), height: 20),
        // Search new items
        if (!_isExpired) ...[
          TextField(
            controller: _exchSearchCtrl,
            style: TextStyle(color: AppColors.textPrimary(context), fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Search new item...',
              hintStyle: TextStyle(color: AppColors.textTertiary(context), fontSize: 12),
              prefixIcon: Icon(Icons.search, size: 18, color: AppColors.textTertiary(context)),
              filled: true, fillColor: AppColors.surface(context),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: AppColors.cardBorder(context))),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              isDense: true,
            ),
            onChanged: (v) => setState(() => _exchSearch = v.toLowerCase()),
          ),
          if (_exchSearch.isNotEmpty) _buildExchResults(),
          const SizedBox(height: 8),
        ],
        // Selected exchange items
        if (_exchangeItems.isNotEmpty) ...[
          Text('New Items:', style: AppTypography.labelSmall.copyWith(
              color: AppColors.success, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          ..._exchangeItems.asMap().entries.map((e) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(children: [
              Expanded(child: Text('${e.value.name} × ${e.value.qty}',
                  style: AppTypography.bodySmall.copyWith(color: AppColors.textPrimary(context)))),
              Text(Formatters.currency(e.value.price * e.value.qty),
                  style: AppTypography.mono.copyWith(color: AppColors.success, fontSize: 12)),
              IconButton(icon: Icon(Icons.close, size: 16, color: AppColors.error),
                  onPressed: () => setState(() => _exchangeItems.removeAt(e.key))),
            ]),
          )),
        ],
        const Spacer(),
        // Settlement
        Divider(color: AppColors.cardBorder(context)),
        _settlRow('Returned', Formatters.currency(_returnTotal), AppColors.error),
        _settlRow('New Items', Formatters.currency(_exchangeTotal), AppColors.success),
        Divider(color: AppColors.cardBorder(context)),
        Row(children: [
          Text(_netSettlement >= 0 ? 'Customer Pays' : 'Refund to Customer',
              style: AppTypography.labelMedium.copyWith(color: AppColors.textSecondary(context), fontWeight: FontWeight.w600)),
          const Spacer(),
          Text(Formatters.currency(_netSettlement.abs()), style: AppTypography.monoLarge.copyWith(
              color: _netSettlement >= 0 ? AppColors.warning : AppColors.success, fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 12),
        SizedBox(width: double.infinity, height: 48, child: ElevatedButton.icon(
          onPressed: (_isExpired || !hasReturn || _exchangeItems.isEmpty) ? null : _processExchange,
          icon: const Icon(Icons.swap_horiz_rounded, size: 18),
          label: Text('Process Exchange', style: AppTypography.button.copyWith(color: Colors.white)),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.warning, foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
        )),
      ]),
    );
  }

  Widget _buildExchResults() {
    final inventory = context.watch<InventoryProvider>();
    final results = inventory.items.where((i) =>
        i.quantity > 0 && i.name.toLowerCase().contains(_exchSearch)).take(5).toList();
    if (results.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(top: 4),
      decoration: BoxDecoration(
        color: AppColors.surface(context), borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.cardBorder(context))),
      child: Column(children: results.map((item) => InkWell(
        onTap: () {
          final existing = _exchangeItems.indexWhere((e) => e.id == item.id);
          setState(() {
            if (existing != -1) {
              _exchangeItems[existing] = _exchangeItems[existing].copyWith(
                  qty: _exchangeItems[existing].qty + 1);
            } else {
              _exchangeItems.add(_ExchangeItem(id: item.id, name: item.name, price: item.price, qty: 1));
            }
            _exchSearchCtrl.clear();
            _exchSearch = '';
          });
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(children: [
            Expanded(child: Text(item.name, style: AppTypography.bodySmall.copyWith(
                color: AppColors.textPrimary(context)))),
            Text(Formatters.currency(item.price), style: AppTypography.mono.copyWith(
                color: AppColors.accent, fontSize: 12)),
            Text(' (${item.quantity})', style: AppTypography.labelSmall.copyWith(
                color: AppColors.textTertiary(context))),
          ]),
        ),
      )).toList()),
    );
  }

  Widget _settlRow(String label, String value, Color color) {
    return Padding(padding: const EdgeInsets.symmetric(vertical: 2), child: Row(children: [
      Text(label, style: AppTypography.labelSmall.copyWith(color: AppColors.textTertiary(context))),
      const Spacer(),
      Text(value, style: AppTypography.mono.copyWith(color: color, fontSize: 12)),
    ]));
  }

  Widget _toggleBtn(String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: active ? AppColors.primary.withValues(alpha: 0.15) : AppColors.surface(context),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: active ? AppColors.primary : AppColors.cardBorder(context))),
        child: Text(label, style: AppTypography.labelMedium.copyWith(
            color: active ? AppColors.primary : AppColors.textSecondary(context),
            fontWeight: active ? FontWeight.w700 : FontWeight.w400)),
      ),
    );
  }
}

class _ExchangeItem {
  final String id;
  final String name;
  final double price;
  final int qty;
  _ExchangeItem({required this.id, required this.name, required this.price, required this.qty});
  _ExchangeItem copyWith({int? qty}) => _ExchangeItem(id: id, name: name, price: price, qty: qty ?? this.qty);
}
