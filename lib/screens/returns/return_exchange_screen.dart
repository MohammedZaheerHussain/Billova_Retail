import 'package:flutter/material.dart';
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

  static const _reasons = ['Defective', 'Wrong Size', 'Wrong Item', 'Changed Mind', 'Other'];
  static const _refundMethods = ['Cash', 'UPI', 'Store Credit'];
  static const int _returnWindowDays = 7;

  @override
  void dispose() {
    _searchCtrl.dispose();
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

  double get _returnTotal => _returnQty.entries.fold(0.0, (sum, e) {
    final item = _foundSale!.items[e.key];
    return sum + (item.price * e.value);
  });

  double get _exchangeTotal => _exchangeItems.fold(0.0, (s, e) => s + e.price * e.qty);

  double get _netSettlement => _exchangeTotal - _returnTotal;

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
      refundTotal += item.price * entry.value;
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
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
          // Toggle
          Row(children: [
            _toggleBtn('Return (Refund)', _isReturn, () => setState(() => _isReturn = true)),
            const SizedBox(width: 10),
            _toggleBtn('Exchange (Swap)', !_isReturn, () => setState(() => _isReturn = false)),
          ]),
          const SizedBox(height: 16),
          // Search
          Row(children: [
            Expanded(child: TextField(
              controller: _searchCtrl,
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
          if (_status.isNotEmpty && _foundSale == null) ...[
            const SizedBox(height: 8),
            Text(_status, style: AppTypography.labelSmall.copyWith(
                color: AppColors.error, fontWeight: FontWeight.w600)),
          ],
          const SizedBox(height: 16),
          // Content
          Expanded(child: _foundSale == null ? _buildEmptyState() : _buildInvoiceView(isDark)),
        ]),
      ),
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
                    Text('Purchased: ${item.quantity} × ${Formatters.currency(item.price)}',
                        style: AppTypography.labelSmall.copyWith(color: AppColors.textTertiary(context))),
                  ])),
                  if (qty > 0)
                    Text(Formatters.currency(item.price * qty),
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
                Text(Formatters.currency(item.price * e.value), style: AppTypography.mono.copyWith(
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
