import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/formatters.dart';
import '../../providers/sales_provider.dart';
import '../../providers/inventory_provider.dart';
import '../../data/models/sale_model.dart';

class ReturnExchangeScreen extends StatefulWidget {
  const ReturnExchangeScreen({super.key});

  @override
  State<ReturnExchangeScreen> createState() => _ReturnExchangeScreenState();
}

class _ReturnExchangeScreenState extends State<ReturnExchangeScreen> {
  final _invoiceCtrl = TextEditingController();
  SaleModel? _foundSale;
  String _status = '';
  bool _isReturn = true; // true = return, false = exchange
  final Set<int> _selectedItems = {};
  String _reason = 'Defective';

  static const _reasons = ['Defective', 'Wrong Size', 'Wrong Item', 'Customer Changed Mind', 'Other'];
  static const int _returnWindowDays = 7;

  @override
  void dispose() {
    _invoiceCtrl.dispose();
    super.dispose();
  }

  void _lookupInvoice() {
    final sales = context.read<SalesProvider>();
    final query = _invoiceCtrl.text.trim().toUpperCase();
    if (query.isEmpty) return;

    final match = sales.sales.where((s) =>
        s.invoiceNumber.toUpperCase() == query).toList();

    setState(() {
      if (match.isEmpty) {
        _foundSale = null;
        _status = 'Invoice not found';
        _selectedItems.clear();
      } else {
        _foundSale = match.first;
        _selectedItems.clear();
        // Check return window
        final saleDate = _foundSale!.createdAt;
        final daysSinceSale = DateTime.now().difference(saleDate).inDays;
        if (daysSinceSale > _returnWindowDays) {
          _status = 'WARNING: Sale is ${daysSinceSale} days old (return window: $_returnWindowDays days)';
        } else {
          _status = 'Invoice found • ${_returnWindowDays - daysSinceSale} days left for return';
        }
      }
    });
  }

  Future<void> _processReturn() async {
    if (_foundSale == null || _selectedItems.isEmpty) return;
    final inventory = context.read<InventoryProvider>();

    double refundTotal = 0;
    for (final idx in _selectedItems) {
      final item = _foundSale!.items[idx];
      refundTotal += item.total;
      // Restock
      await inventory.restockItem(item.itemId, item.quantity);
    }

    if (!mounted) return;
    setState(() {
      _status = _isReturn
          ? 'REFUND of ${Formatters.currency(refundTotal)} processed successfully'
          : 'EXCHANGE processed • ${Formatters.currency(refundTotal)} credit applied';
      _foundSale = null;
      _selectedItems.clear();
      _invoiceCtrl.clear();
    });

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(_isReturn
          ? 'Return processed — ${Formatters.currency(refundTotal)} refunded'
          : 'Exchange processed — items restocked'),
      backgroundColor: AppColors.success,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                  border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
                ),
                child: Text('$_returnWindowDays Day Return Policy',
                    style: AppTypography.labelSmall.copyWith(
                        color: AppColors.warning, fontWeight: FontWeight.w700)),
              ),
            ]),
            const SizedBox(height: 20),

            // Toggle Return/Exchange
            Row(children: [
              _toggleBtn('Return (Refund)', _isReturn, () => setState(() => _isReturn = true)),
              const SizedBox(width: 10),
              _toggleBtn('Exchange (Swap)', !_isReturn, () => setState(() => _isReturn = false)),
            ]),
            const SizedBox(height: 16),

            // Invoice Lookup
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _invoiceCtrl,
                  style: TextStyle(color: AppColors.textPrimary(context), fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Enter Invoice Number (e.g. SKY-0001)',
                    hintStyle: TextStyle(color: AppColors.textTertiary(context), fontSize: 13),
                    prefixIcon: Icon(Icons.receipt_long_rounded, color: AppColors.textTertiary(context)),
                    filled: true,
                    fillColor: isDark ? AppColors.surface(context) : Colors.grey.shade50,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AppColors.cardBorder(context))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AppColors.cardBorder(context))),
                  ),
                  onSubmitted: (_) => _lookupInvoice(),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: _lookupInvoice,
                  icon: const Icon(Icons.search_rounded, size: 18),
                  label: const Text('Lookup'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ]),
            if (_status.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(_status, style: AppTypography.labelSmall.copyWith(
                color: _status.contains('WARNING') ? AppColors.warning
                    : _status.contains('not found') ? AppColors.error
                    : AppColors.success,
                fontWeight: FontWeight.w600)),
            ],
            const SizedBox(height: 16),

            // Sale Details
            Expanded(
              child: _foundSale == null
                  ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.swap_horiz_rounded, size: 64,
                          color: AppColors.accent.withValues(alpha: 0.2)),
                      const SizedBox(height: 12),
                      Text('Enter an invoice number to start',
                          style: AppTypography.bodyMedium.copyWith(
                              color: AppColors.textTertiary(context))),
                    ]))
                  : Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.card(context) : AppColors.cardLight,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: isDark ? AppColors.cardBorder(context) : AppColors.cardBorderLight),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Sale info header
                          Row(children: [
                            Text(_foundSale!.invoiceNumber,
                                style: AppTypography.mono.copyWith(color: AppColors.accent, fontSize: 16)),
                            const Spacer(),
                            Text(_foundSale!.customerName.isNotEmpty
                                ? _foundSale!.customerName : 'Walk-in',
                                style: AppTypography.bodyMedium.copyWith(
                                    color: AppColors.textSecondary(context))),
                            const SizedBox(width: 16),
                            Text(Formatters.currency(_foundSale!.total),
                                style: AppTypography.monoLarge.copyWith(color: AppColors.accent)),
                          ]),
                          const SizedBox(height: 4),
                          Text('Date: ${_foundSale!.createdAt.toIso8601String().substring(0, 10)}',
                              style: AppTypography.labelSmall.copyWith(
                                  color: AppColors.textTertiary(context))),
                          Divider(color: AppColors.cardBorder(context), height: 24),

                          // Reason
                          Row(children: [
                            Text('Reason: ', style: AppTypography.labelMedium.copyWith(
                                color: AppColors.textSecondary(context))),
                            DropdownButton<String>(
                              value: _reason,
                              dropdownColor: AppColors.card(context),
                              style: TextStyle(color: AppColors.textPrimary(context), fontSize: 13),
                              items: _reasons.map((r) => DropdownMenuItem(
                                  value: r, child: Text(r))).toList(),
                              onChanged: (v) => setState(() => _reason = v!),
                            ),
                          ]),
                          const SizedBox(height: 12),

                          // Items list with checkboxes
                          Text('Select items to ${_isReturn ? 'return' : 'exchange'}:',
                              style: AppTypography.labelMedium.copyWith(
                                  color: AppColors.textSecondary(context), fontWeight: FontWeight.w600)),
                          const SizedBox(height: 8),
                          Expanded(
                            child: ListView.builder(
                              itemCount: _foundSale!.items.length,
                              itemBuilder: (_, i) {
                                final item = _foundSale!.items[i];
                                final selected = _selectedItems.contains(i);
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 6),
                                  decoration: BoxDecoration(
                                    color: selected
                                        ? AppColors.error.withValues(alpha: 0.08)
                                        : AppColors.surface(context),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: selected
                                        ? AppColors.error.withValues(alpha: 0.4)
                                        : AppColors.cardBorder(context)),
                                  ),
                                  child: CheckboxListTile(
                                    value: selected,
                                    onChanged: (v) {
                                      setState(() {
                                        if (v!) {
                                          _selectedItems.add(i);
                                        } else {
                                          _selectedItems.remove(i);
                                        }
                                      });
                                    },
                                    activeColor: AppColors.error,
                                    title: Text(item.name, style: AppTypography.bodyMedium.copyWith(
                                        color: AppColors.textPrimary(context), fontWeight: FontWeight.w500)),
                                    subtitle: Text(
                                        'Qty: ${item.quantity} × ${Formatters.currency(item.price)}',
                                        style: AppTypography.labelSmall.copyWith(
                                            color: AppColors.textTertiary(context))),
                                    secondary: Text(Formatters.currency(item.total),
                                        style: AppTypography.mono.copyWith(
                                            color: selected ? AppColors.error : AppColors.accent,
                                            fontWeight: FontWeight.w700)),
                                  ),
                                );
                              },
                            ),
                          ),

                          // Selected total + action
                          if (_selectedItems.isNotEmpty) ...[
                            Divider(color: AppColors.cardBorder(context)),
                            Row(children: [
                              Text('${_selectedItems.length} item(s) selected',
                                  style: AppTypography.labelMedium.copyWith(
                                      color: AppColors.textSecondary(context))),
                              const Spacer(),
                              Text(
                                '${_isReturn ? 'Refund' : 'Credit'}: ${Formatters.currency(
                                    _selectedItems.fold(0.0, (sum, i) => sum + _foundSale!.items[i].total))}',
                                style: AppTypography.mono.copyWith(
                                    color: _isReturn ? AppColors.error : AppColors.warning,
                                    fontWeight: FontWeight.w700, fontSize: 16),
                              ),
                            ]),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: ElevatedButton.icon(
                                onPressed: _processReturn,
                                icon: Icon(_isReturn
                                    ? Icons.keyboard_return_rounded
                                    : Icons.swap_horiz_rounded, size: 18),
                                label: Text(
                                  _isReturn ? 'Process Return & Refund' : 'Process Exchange',
                                  style: AppTypography.button.copyWith(color: Colors.white),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _isReturn ? AppColors.error : AppColors.warning,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _toggleBtn(String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: active ? AppColors.primary.withValues(alpha: 0.15) : AppColors.surface(context),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: active ? AppColors.primary : AppColors.cardBorder(context)),
        ),
        child: Text(label, style: AppTypography.labelMedium.copyWith(
            color: active ? AppColors.primary : AppColors.textSecondary(context),
            fontWeight: active ? FontWeight.w700 : FontWeight.w400)),
      ),
    );
  }
}
