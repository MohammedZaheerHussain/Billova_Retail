import 'dart:js' as js;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/whatsapp_helper.dart';
import '../../providers/purchase_provider.dart';
import '../../providers/vendor_provider.dart';
import '../../providers/inventory_provider.dart';
import '../../data/models/vendor_model.dart';
import '../../data/models/purchase_model.dart';
import '../../data/models/item_model.dart';

class VendorDetailScreen extends StatelessWidget {
  final VendorModel vendor;
  const VendorDetailScreen({super.key, required this.vendor});

  @override
  Widget build(BuildContext context) {
    final purchaseProvider = context.watch<PurchaseProvider>();
    final summary = purchaseProvider.getVendorSummary(vendor.id);
    final purchases = purchaseProvider.getVendorPurchases(vendor.id);

    final totalPurchase = summary['totalPurchase'] as double;
    final totalPaid = summary['totalPaid'] as double;
    final pending = summary['pending'] as double;
    final totalItems = summary['totalItems'] as int;

    return Scaffold(
      backgroundColor: AppColors.scaffold(context),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary(context)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(vendor.name,
            style: AppTypography.h3.copyWith(color: AppColors.textPrimary(context))),
        actions: [
          // WhatsApp Invoice
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: IconButton(
              tooltip: vendor.phone.isEmpty ? 'No phone number' : 'Send Invoice via WhatsApp',
              onPressed: vendor.phone.isEmpty ? null : () => _sendWhatsAppInvoice(context, purchaseProvider),
              icon: Icon(Icons.chat_rounded, size: 20,
                color: vendor.phone.isEmpty ? AppColors.textTertiary(context) : const Color(0xFF25D366)),
            ),
          ),
          // Print Invoice
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: IconButton(
              tooltip: 'Print Invoice',
              onPressed: () => _printInvoice(context, purchaseProvider),
              icon: Icon(Icons.print_rounded, size: 20, color: AppColors.textSecondary(context)),
            ),
          ),
          if (pending > 0)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ElevatedButton.icon(
                onPressed: () => _showPaymentDialog(context, pending),
                icon: const Icon(Icons.payment_rounded, size: 16),
                label: const Text('Pay'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.error,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  textStyle: const TextStyle(fontSize: 13),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ElevatedButton.icon(
              onPressed: () => _showAddPurchaseDialog(context),
              icon: const Icon(Icons.add_rounded, size: 16),
              label: const Text('New Purchase'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                textStyle: const TextStyle(fontSize: 13),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSummarySection(context, totalPurchase, totalPaid, pending, totalItems),
            const SizedBox(height: 20),

            // ─── Invoice / Ledger Section ───
            _buildLedgerSection(context, purchaseProvider, totalPurchase, totalPaid, pending, purchases),
            const SizedBox(height: 20),

            // Top Items Supplied
            if (purchases.isNotEmpty) ...[
              _buildTopItems(context, purchases),
              const SizedBox(height: 20),
            ],

            // ─── Payment History ───
            _buildPaymentHistory(context, purchases),
            const SizedBox(height: 20),

            _buildPurchaseHistory(context, purchases),
          ],
        ),
      ),
    );
  }

  // ─── Summary Section ───
  Widget _buildSummarySection(BuildContext context, double totalPurchase, double totalPaid, double pending, int totalItems) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: Text(
                    vendor.name.isNotEmpty ? vendor.name[0].toUpperCase() : '?',
                    style: AppTypography.h3.copyWith(color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(vendor.name,
                        style: AppTypography.h4.copyWith(color: AppColors.textPrimary(context))),
                    if (vendor.phone.isNotEmpty)
                      Text('📞 ${vendor.phone}',
                          style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary(context))),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              _statBox(context, '💰 Total Purchase', Formatters.currency(totalPurchase), AppColors.primary),
              const SizedBox(width: 12),
              _statBox(context, '✅ Total Paid', Formatters.currency(totalPaid), AppColors.success),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _statBox(context, '⚠️ Pending', Formatters.currency(pending),
                  pending > 0 ? AppColors.error : AppColors.success),
              const SizedBox(width: 12),
              _statBox(context, '📦 Items Bought', '$totalItems pcs', AppColors.accent),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statBox(BuildContext context, String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: AppTypography.labelSmall.copyWith(
                    color: AppColors.textTertiary(context), fontSize: 10)),
            const SizedBox(height: 4),
            Text(value,
                style: AppTypography.mono.copyWith(
                    color: color, fontWeight: FontWeight.w700, fontSize: 16)),
          ],
        ),
      ),
    );
  }

  // ─── Top Items Supplied ───
  Widget _buildTopItems(BuildContext context, List<PurchaseModel> purchases) {
    // Aggregate items across all purchases
    final Map<String, int> itemCounts = {};
    for (final p in purchases) {
      for (final item in p.itemsList) {
        final name = (item['name'] ?? item['item_name'] ?? 'Item') as String;
        final qty = ((item['quantity'] as num?) ?? 0).toInt();
        itemCounts[name] = (itemCounts[name] ?? 0) + qty;
      }
    }
    if (itemCounts.isEmpty) return const SizedBox.shrink();

    final sorted = itemCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top = sorted.take(5);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Top Items Supplied',
              style: AppTypography.h4.copyWith(color: AppColors.textPrimary(context))),
          const SizedBox(height: 12),
          ...top.map((e) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(child: Text('📦', style: TextStyle(fontSize: 14))),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(e.key,
                      style: AppTypography.bodySmall.copyWith(
                          color: AppColors.textPrimary(context), fontWeight: FontWeight.w500)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text('${e.value} units',
                      style: AppTypography.mono.copyWith(
                          color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }

  // ─── Purchase History ───
  Widget _buildPurchaseHistory(BuildContext context, List<PurchaseModel> purchases) {
    if (purchases.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: AppColors.card(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.cardBorder(context)),
        ),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.receipt_long_rounded, size: 48,
                  color: AppColors.textTertiary(context).withValues(alpha: 0.3)),
              const SizedBox(height: 12),
              Text('No purchases yet',
                  style: AppTypography.bodyMedium.copyWith(color: AppColors.textTertiary(context))),
              const SizedBox(height: 4),
              Text('Tap "+ New Purchase" to record your first purchase',
                  style: AppTypography.bodySmall.copyWith(color: AppColors.textTertiary(context))),
            ],
          ),
        ),
      );
    }

    final Map<String, List<PurchaseModel>> grouped = {};
    for (final p in purchases) {
      final dateKey = p.createdAt.toIso8601String().substring(0, 10);
      grouped.putIfAbsent(dateKey, () => []);
      grouped[dateKey]!.add(p);
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Purchase History',
                  style: AppTypography.h4.copyWith(color: AppColors.textPrimary(context))),
              const Spacer(),
              Text('${purchases.length} records',
                  style: AppTypography.labelSmall.copyWith(
                      color: AppColors.textTertiary(context), fontSize: 10)),
            ],
          ),
          const SizedBox(height: 16),
          ...grouped.entries.map((entry) {
            final date = entry.key;
            final dayPurchases = entry.value;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text('📅 $date',
                      style: AppTypography.labelSmall.copyWith(
                          color: AppColors.accent, fontWeight: FontWeight.w700, fontSize: 11)),
                ),
                const SizedBox(height: 8),
                ...dayPurchases.map((p) => _purchaseEntry(context, p)),
                Divider(color: AppColors.cardBorder(context), height: 20),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _purchaseEntry(BuildContext context, PurchaseModel purchase) {
    final items = purchase.itemsList;
    final isPaid = purchase.isFullyPaid;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface(context),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Item details table
            ...items.map((item) {
              final name = item['name'] ?? item['item_name'] ?? 'Item';
              final qty = item['quantity'] ?? 0;
              final cost = (item['cost_price'] as num?)?.toDouble() ?? 0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Icon(Icons.inventory_2_rounded, size: 14, color: AppColors.accent),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(name.toString(),
                          style: AppTypography.bodySmall.copyWith(
                              color: AppColors.textPrimary(context), fontSize: 13)),
                    ),
                    Text('×$qty',
                        style: AppTypography.mono.copyWith(
                            color: AppColors.textSecondary(context), fontSize: 12)),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 80,
                      child: Text(Formatters.currency(cost * (qty as num).toInt()),
                          textAlign: TextAlign.right,
                          style: AppTypography.mono.copyWith(
                              color: AppColors.textPrimary(context), fontSize: 12)),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 8),
            // Bottom summary
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: (isPaid ? AppColors.success : AppColors.error).withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: (isPaid ? AppColors.success : AppColors.error).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      isPaid ? '✅ Paid' : '⚠️ Due: ${Formatters.currency(purchase.dueAmount)}',
                      style: AppTypography.labelSmall.copyWith(
                        color: isPaid ? AppColors.success : AppColors.error,
                        fontWeight: FontWeight.w700, fontSize: 10,
                      ),
                    ),
                  ),
                  if (purchase.paymentMode.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Text(purchase.paymentMode,
                        style: AppTypography.labelSmall.copyWith(
                            color: AppColors.textTertiary(context), fontSize: 10)),
                  ],
                  const Spacer(),
                  Text('Total: ${Formatters.currency(purchase.totalAmount)}',
                      style: AppTypography.mono.copyWith(
                          color: AppColors.textPrimary(context), fontWeight: FontWeight.w700, fontSize: 13)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Vendor Ledger / Invoice Section ───
  Widget _buildLedgerSection(BuildContext context, PurchaseProvider pp, double total, double paid, double pending, List<PurchaseModel> purchases) {
    final invoiceNo = pp.generateVendorInvoiceNumber(vendor.id);
    final status = pp.getVendorPaymentStatus(vendor.id);
    final statusColor = status == 'Paid' ? AppColors.success : status == 'Unpaid' ? AppColors.error : AppColors.warning;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder(context)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.receipt_long_rounded, color: AppColors.accent, size: 20),
          const SizedBox(width: 8),
          Text('Vendor Invoice / Ledger', style: AppTypography.h4.copyWith(color: AppColors.textPrimary(context))),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
            child: Text(status, style: AppTypography.labelSmall.copyWith(color: statusColor, fontWeight: FontWeight.w700)),
          ),
        ]),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: AppColors.surface(context), borderRadius: BorderRadius.circular(12)),
          child: Column(children: [
            _ledgerRow(context, 'Invoice No', invoiceNo, AppColors.accent),
            _ledgerRow(context, 'Total Purchase', Formatters.currency(total), AppColors.primary),
            _ledgerRow(context, 'Total Paid', Formatters.currency(paid), AppColors.success),
            _ledgerRow(context, 'Pending Balance', Formatters.currency(pending), pending > 0 ? AppColors.error : AppColors.success),
            _ledgerRow(context, 'Transactions', '${purchases.length}', AppColors.textSecondary(context)),
          ]),
        ),
        const SizedBox(height: 14),
        // Action buttons
        Row(children: [
          Expanded(child: OutlinedButton.icon(
            onPressed: vendor.phone.isEmpty ? null : () => _sendWhatsAppInvoice(context, pp),
            icon: Icon(Icons.chat_rounded, size: 16, color: vendor.phone.isEmpty ? AppColors.textTertiary(context) : const Color(0xFF25D366)),
            label: Text('WhatsApp', style: TextStyle(fontSize: 12, color: vendor.phone.isEmpty ? AppColors.textTertiary(context) : const Color(0xFF25D366))),
            style: OutlinedButton.styleFrom(side: BorderSide(color: vendor.phone.isEmpty ? AppColors.cardBorder(context) : const Color(0xFF25D366).withValues(alpha: 0.4)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), padding: const EdgeInsets.symmetric(vertical: 10)),
          )),
          const SizedBox(width: 8),
          Expanded(child: OutlinedButton.icon(
            onPressed: () => _printInvoice(context, pp),
            icon: Icon(Icons.print_rounded, size: 16, color: AppColors.primary),
            label: Text('Print', style: TextStyle(fontSize: 12, color: AppColors.primary)),
            style: OutlinedButton.styleFrom(side: BorderSide(color: AppColors.primary.withValues(alpha: 0.4)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), padding: const EdgeInsets.symmetric(vertical: 10)),
          )),
          const SizedBox(width: 8),
          Expanded(child: OutlinedButton.icon(
            onPressed: () => _printInvoice(context, pp),
            icon: Icon(Icons.download_rounded, size: 16, color: AppColors.accent),
            label: Text('Download', style: TextStyle(fontSize: 12, color: AppColors.accent)),
            style: OutlinedButton.styleFrom(side: BorderSide(color: AppColors.accent.withValues(alpha: 0.4)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), padding: const EdgeInsets.symmetric(vertical: 10)),
          )),
        ]),
      ]),
    );
  }

  Widget _ledgerRow(BuildContext context, String label, String value, Color color) {
    return Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Row(children: [
      Expanded(child: Text(label, style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary(context)))),
      Text(value, style: AppTypography.mono.copyWith(color: color, fontWeight: FontWeight.w600, fontSize: 13)),
    ]));
  }

  // ─── Payment History Timeline ───
  Widget _buildPaymentHistory(BuildContext context, List<PurchaseModel> purchases) {
    if (purchases.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: AppColors.card(context), borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder(context))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.history_rounded, color: AppColors.accent, size: 20),
          const SizedBox(width: 8),
          Text('Payment History', style: AppTypography.h4.copyWith(color: AppColors.textPrimary(context))),
        ]),
        const SizedBox(height: 14),
        ...purchases.map((p) {
          final isPaid = p.isFullyPaid;
          final statusColor = isPaid ? AppColors.success : p.paidAmount > 0 ? AppColors.warning : AppColors.error;
          final statusText = isPaid ? 'Paid' : p.paidAmount > 0 ? 'Partial' : 'Unpaid';
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppColors.surface(context), borderRadius: BorderRadius.circular(10)),
            child: Row(children: [
              Container(width: 8, height: 40, decoration: BoxDecoration(color: statusColor, borderRadius: BorderRadius.circular(4))),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(p.createdAt.toIso8601String().substring(0, 10), style: AppTypography.labelSmall.copyWith(color: AppColors.textTertiary(context), fontSize: 10)),
                Text('${Formatters.currency(p.totalAmount)} — Paid: ${Formatters.currency(p.paidAmount)}',
                  style: AppTypography.bodySmall.copyWith(color: AppColors.textPrimary(context), fontWeight: FontWeight.w500)),
                if (p.dueAmount > 0) Text('Due: ${Formatters.currency(p.dueAmount)}', style: AppTypography.labelSmall.copyWith(color: AppColors.error, fontSize: 10)),
              ])),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                child: Text(statusText, style: AppTypography.labelSmall.copyWith(color: statusColor, fontWeight: FontWeight.w700, fontSize: 10)),
              ),
              const SizedBox(width: 8),
              Text(p.paymentMode, style: AppTypography.labelSmall.copyWith(color: AppColors.textTertiary(context), fontSize: 10)),
            ]),
          );
        }),
      ]),
    );
  }

  // ─── WhatsApp Invoice ───
  void _sendWhatsAppInvoice(BuildContext context, PurchaseProvider pp) {
    final summary = pp.getVendorSummary(vendor.id);
    final invoiceNo = pp.generateVendorInvoiceNumber(vendor.id);
    final message = WhatsAppHelper.vendorInvoiceMessage(
      vendorName: vendor.name,
      invoiceNumber: invoiceNo,
      totalAmount: summary['totalPurchase'] as double,
      paidAmount: summary['totalPaid'] as double,
      pendingAmount: summary['pending'] as double,
      paymentStatus: pp.getVendorPaymentStatus(vendor.id),
      purchases: pp.getVendorPurchasesList(vendor.id),
    );
    WhatsAppHelper.send(phone: vendor.phone, message: message);
  }

  // ─── Print Invoice ───
  void _printInvoice(BuildContext context, PurchaseProvider pp) {
    final summary = pp.getVendorSummary(vendor.id);
    final purchases = pp.getVendorPurchases(vendor.id);
    final invoiceNo = pp.generateVendorInvoiceNumber(vendor.id);
    final status = pp.getVendorPaymentStatus(vendor.id);
    final total = summary['totalPurchase'] as double;
    final paid = summary['totalPaid'] as double;
    final pending = summary['pending'] as double;

    final itemRows = StringBuffer();
    for (final p in purchases) {
      for (final item in p.itemsList) {
        final name = item['name'] ?? 'Item';
        final qty = item['quantity'] ?? 0;
        final cost = (item['cost_price'] as num?)?.toDouble() ?? 0;
        itemRows.write('<tr><td>$name</td><td style="text-align:center">$qty</td><td style="text-align:right">${Formatters.currency(cost)}</td><td style="text-align:right">${Formatters.currency(cost * (qty as num).toInt())}</td></tr>');
      }
    }

    final paymentRows = StringBuffer();
    for (final p in purchases) {
      final date = p.createdAt.toIso8601String().substring(0, 10);
      final pStatus = p.isFullyPaid ? 'Paid' : p.paidAmount > 0 ? 'Partial' : 'Unpaid';
      paymentRows.write('<tr><td>$date</td><td style="text-align:right">${Formatters.currency(p.totalAmount)}</td><td style="text-align:right">${Formatters.currency(p.paidAmount)}</td><td>${p.paymentMode}</td><td>$pStatus</td></tr>');
    }

    final escapedName = vendor.name.replaceAll("'", "\\'");
    js.context.callMethod('eval', ['''
      var w=window.open(\'\',\'_blank\',\'width=800,height=900\');
      if(w){w.document.write(\'<html><head><title>Invoice - $escapedName</title><style>\'
        +\'body{font-family:Arial,sans-serif;padding:30px;color:#1a1a2e}\'
        +\'.header{display:flex;justify-content:space-between;border-bottom:3px solid #0f3460;padding-bottom:16px;margin-bottom:20px}\'
        +\'.logo{font-size:28px;font-weight:800;color:#0f3460}\'
        +\'.badge{display:inline-block;padding:4px 12px;border-radius:6px;font-weight:700;font-size:13px}\'
        +\'table{width:100%;border-collapse:collapse;margin:12px 0}\'
        +\'th{background:#0f3460;color:#fff;padding:8px 12px;text-align:left;font-size:12px}\'
        +\'td{padding:8px 12px;border-bottom:1px solid #eee;font-size:12px}\'
        +\'.summary{display:grid;grid-template-columns:1fr 1fr;gap:12px;margin:16px 0}\'
        +\'.summary-box{padding:14px;border-radius:10px;background:#f0f4ff}\'
        +\'.summary-box.green{background:#e6f9f0}.summary-box.red{background:#fde8e8}\'
        +\'.summary-label{font-size:11px;color:#666}.summary-value{font-size:18px;font-weight:700;margin-top:4px}\'
        +\'.footer{text-align:center;margin-top:30px;padding-top:16px;border-top:2px solid #eee;color:#999;font-size:12px}\'
        +\'@media print{body{padding:10px}}\'
        +\'</style></head><body>\'
        +\'<div class="header"><div><div class="logo">SKYWALK</div><div style="font-size:12px;color:#666">Professional Billing System</div></div>\'
        +\'<div style="text-align:right"><div style="font-size:14px;font-weight:700">VENDOR INVOICE</div>\'
        +\'<div style="font-size:12px;color:#666">$invoiceNo</div>\'
        +\'<div style="font-size:11px;color:#999">${DateTime.now().toIso8601String().substring(0, 10)}</div></div></div>\'
        +\'<div style="background:#f8f9ff;padding:14px;border-radius:10px;margin-bottom:16px">\'
        +\'<div style="font-size:11px;color:#666">BILL TO</div>\'
        +\'<div style="font-size:16px;font-weight:700">${vendor.name}</div>\'
        +\'<div style="font-size:12px;color:#666">${vendor.phone}</div></div>\'
        +\'<div class="summary">\'
        +\'<div class="summary-box"><div class="summary-label">Total Purchase</div><div class="summary-value" style="color:#0f3460">${Formatters.currency(total)}</div></div>\'
        +\'<div class="summary-box green"><div class="summary-label">Total Paid</div><div class="summary-value" style="color:#0f9b58">${Formatters.currency(paid)}</div></div>\'
        +\'<div class="summary-box red"><div class="summary-label">Pending Balance</div><div class="summary-value" style="color:#d32f2f">${Formatters.currency(pending)}</div></div>\'
        +\'<div class="summary-box"><div class="summary-label">Status</div><div class="summary-value" style="color:${status == 'Paid' ? '#0f9b58' : '#d32f2f'}">$status</div></div></div>\'
        +\'<h3 style="color:#0f3460;margin:20px 0 8px">Purchase Items</h3>\'
        +\'<table><thead><tr><th>Item</th><th style="text-align:center">Qty</th><th style="text-align:right">Rate</th><th style="text-align:right">Total</th></tr></thead>\'
        +\'<tbody>$itemRows</tbody></table>\'
        +\'<h3 style="color:#0f3460;margin:20px 0 8px">Payment History</h3>\'
        +\'<table><thead><tr><th>Date</th><th style="text-align:right">Amount</th><th style="text-align:right">Paid</th><th>Method</th><th>Status</th></tr></thead>\'
        +\'<tbody>$paymentRows</tbody></table>\'
        +\'<div class="footer">Thank you for doing business with us!<br>Generated by SKYWALK Billing System</div>\'
        +\'</body></html>\');w.document.close();setTimeout(function(){w.print()},600);}
    ''']);
  }

  // ─── Add Purchase Dialog ───
  void _showAddPurchaseDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => _AddPurchaseDialog(vendor: vendor),
    );
  }

  // ─── Payment Dialog ───
  void _showPaymentDialog(BuildContext context, double maxDue) {
    final amountCtrl = TextEditingController();
    String paymentMode = 'Cash';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Dialog(
          backgroundColor: AppColors.card(context),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          gradient: AppColors.primaryGradient,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.payment_rounded, color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Text('Record Payment',
                          style: AppTypography.h3.copyWith(color: AppColors.textPrimary(context))),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('Pending: ${Formatters.currency(maxDue)}',
                      style: AppTypography.bodySmall.copyWith(color: AppColors.error)),
                  const SizedBox(height: 20),
                  TextField(
                    controller: amountCtrl,
                    keyboardType: TextInputType.number,
                    autofocus: true,
                    style: TextStyle(color: AppColors.textPrimary(context)),
                    decoration: InputDecoration(
                      labelText: 'Amount (₹)',
                      labelStyle: TextStyle(color: AppColors.textSecondary(context)),
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
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    children: ['Cash', 'UPI', 'Card'].map((mode) {
                      final isActive = paymentMode == mode;
                      return ChoiceChip(
                        label: Text(mode),
                        selected: isActive,
                        selectedColor: AppColors.primary.withValues(alpha: 0.15),
                        labelStyle: TextStyle(
                          color: isActive ? AppColors.primary : AppColors.textSecondary(context),
                          fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
                        ),
                        onSelected: (_) => setDialogState(() => paymentMode = mode),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () async {
                      final amount = double.tryParse(amountCtrl.text) ?? 0;
                      if (amount <= 0 || amount > maxDue) return;
                      final pp = context.read<PurchaseProvider>();
                      final vp = context.read<VendorProvider>();
                      await pp.recordVendorPayment(
                        vendorId: vendor.id, amount: amount,
                        paymentMode: paymentMode, vendorProvider: vp,
                      );
                      if (ctx.mounted) Navigator.pop(ctx);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text('₹${amount.toStringAsFixed(0)} paid to ${vendor.name}'),
                          backgroundColor: AppColors.success,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ));
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Record Payment'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Add Purchase Dialog (inline, lightweight) ───
class _AddPurchaseDialog extends StatefulWidget {
  final VendorModel vendor;
  const _AddPurchaseDialog({required this.vendor});

  @override
  State<_AddPurchaseDialog> createState() => _AddPurchaseDialogState();
}

class _PurchaseItem {
  String name;
  int quantity;
  double costPrice;
  String? itemId;
  _PurchaseItem({required this.name, this.quantity = 1, this.costPrice = 0, this.itemId});
  double get total => quantity * costPrice;
}

class _AddPurchaseDialogState extends State<_AddPurchaseDialog> {
  final List<_PurchaseItem> _items = [];
  final _paidCtrl = TextEditingController(text: '0');
  String _paymentMode = 'Cash';
  bool _submitting = false;
  String _inventorySearch = '';

  // Manual entry
  final _nameCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController(text: '1');
  final _priceCtrl = TextEditingController();

  double get _total => _items.fold(0, (s, i) => s + i.total);
  double get _paid => double.tryParse(_paidCtrl.text) ?? 0;
  double get _due => (_total - _paid).clamp(0, double.infinity);

  void _addManualItem() {
    final name = _nameCtrl.text.trim();
    final qty = int.tryParse(_qtyCtrl.text) ?? 1;
    final price = double.tryParse(_priceCtrl.text) ?? 0;
    if (name.isEmpty || price <= 0) return;
    setState(() {
      _items.add(_PurchaseItem(name: name, quantity: qty, costPrice: price));
      _nameCtrl.clear();
      _qtyCtrl.text = '1';
      _priceCtrl.clear();
    });
  }

  void _addFromInventory(ItemModel item) {
    final existing = _items.indexWhere((e) => e.itemId == item.id);
    if (existing != -1) {
      setState(() => _items[existing].quantity++);
    } else {
      setState(() => _items.add(_PurchaseItem(
        name: item.name,
        quantity: 1,
        costPrice: item.costPrice > 0 ? item.costPrice : item.price,
        itemId: item.id,
      )));
    }
  }

  Future<void> _submit() async {
    if (_items.isEmpty) return;
    setState(() => _submitting = true);
    final itemMaps = _items.map((i) => {
      'item_id': i.itemId ?? '',
      'name': i.name,
      'quantity': i.quantity,
      'cost_price': i.costPrice,
    }).toList();
    final pp = context.read<PurchaseProvider>();
    final vp = context.read<VendorProvider>();
    final ip = context.read<InventoryProvider>();
    await pp.addPurchase(
      vendorId: widget.vendor.id,
      vendorName: widget.vendor.name,
      items: itemMaps,
      totalAmount: _total,
      paidAmount: _paid,
      paymentMode: _paymentMode,
      inventoryProvider: ip,
      vendorProvider: vp,
    );
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Purchase of ${Formatters.currency(_total)} recorded'),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));
    }
  }

  @override
  void dispose() {
    _paidCtrl.dispose();
    _nameCtrl.dispose();
    _qtyCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final inventory = context.watch<InventoryProvider>();
    final filteredInventory = _inventorySearch.isEmpty
        ? inventory.items
        : inventory.items.where((i) =>
            i.name.toLowerCase().contains(_inventorySearch.toLowerCase())).toList();

    return Dialog(
      backgroundColor: AppColors.card(context),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 680),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ─── Header ───
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.add_shopping_cart_rounded, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Record Purchase',
                            style: AppTypography.h3.copyWith(color: AppColors.textPrimary(context))),
                        Text('From ${widget.vendor.name}',
                            style: AppTypography.labelSmall.copyWith(
                                color: AppColors.textTertiary(context), fontSize: 10)),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close_rounded, color: AppColors.textTertiary(context)),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // ─── Inventory Search + Chips ───
              if (inventory.items.isNotEmpty) ...[
                TextField(
                  onChanged: (v) => setState(() => _inventorySearch = v),
                  style: TextStyle(color: AppColors.textPrimary(context), fontSize: 12),
                  decoration: InputDecoration(
                    hintText: '🔍 Search inventory to add...',
                    hintStyle: TextStyle(color: AppColors.textTertiary(context), fontSize: 11),
                    isDense: true,
                    filled: true,
                    fillColor: AppColors.surface(context),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: AppColors.cardBorder(context)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: AppColors.cardBorder(context)),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 34,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: filteredInventory.length > 15 ? 15 : filteredInventory.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 6),
                    itemBuilder: (_, i) {
                      final item = filteredInventory[i];
                      final already = _items.any((e) => e.itemId == item.id);
                      return ActionChip(
                        label: Text(
                          already
                              ? '${item.name} ✓'
                              : '${item.name} (₹${item.costPrice > 0 ? item.costPrice.toStringAsFixed(0) : item.price.toStringAsFixed(0)})',
                          style: TextStyle(fontSize: 10, color: already ? AppColors.success : AppColors.textPrimary(context)),
                        ),
                        avatar: Icon(Icons.add_rounded, size: 14,
                            color: already ? AppColors.success : AppColors.primary),
                        backgroundColor: already
                            ? AppColors.success.withValues(alpha: 0.08)
                            : AppColors.surface(context),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(color: already ? AppColors.success.withValues(alpha: 0.3) : AppColors.cardBorder(context)),
                        ),
                        onPressed: () => _addFromInventory(item),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 10),
              ],

              // ─── Manual Entry Row ───
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.surface(context),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.cardBorder(context)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Or add manually:',
                        style: AppTypography.labelSmall.copyWith(
                            color: AppColors.textTertiary(context), fontSize: 10)),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(flex: 3, child: _miniField(_nameCtrl, 'Item Name')),
                        const SizedBox(width: 6),
                        Expanded(child: _miniField(_qtyCtrl, 'Qty', isNumber: true)),
                        const SizedBox(width: 6),
                        Expanded(flex: 2, child: _miniField(_priceCtrl, 'Cost ₹/unit', isNumber: true)),
                        const SizedBox(width: 6),
                        Material(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(8),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: _addManualItem,
                            child: const Padding(
                              padding: EdgeInsets.all(8),
                              child: Icon(Icons.add_rounded, color: Colors.white, size: 18),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // ─── Item table header ───
              if (_items.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Row(
                    children: [
                      Expanded(flex: 3, child: Text('ITEM',
                          style: AppTypography.labelSmall.copyWith(
                              color: AppColors.textTertiary(context), fontSize: 9, fontWeight: FontWeight.w700))),
                      SizedBox(width: 90, child: Text('QTY',
                          textAlign: TextAlign.center,
                          style: AppTypography.labelSmall.copyWith(
                              color: AppColors.textTertiary(context), fontSize: 9, fontWeight: FontWeight.w700))),
                      SizedBox(width: 70, child: Text('COST',
                          textAlign: TextAlign.center,
                          style: AppTypography.labelSmall.copyWith(
                              color: AppColors.textTertiary(context), fontSize: 9, fontWeight: FontWeight.w700))),
                      SizedBox(width: 70, child: Text('TOTAL',
                          textAlign: TextAlign.right,
                          style: AppTypography.labelSmall.copyWith(
                              color: AppColors.textTertiary(context), fontSize: 9, fontWeight: FontWeight.w700))),
                      const SizedBox(width: 24),
                    ],
                  ),
                ),

              // ─── Items List (editable) ───
              Flexible(
                child: _items.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.shopping_bag_outlined, size: 36,
                                  color: AppColors.textTertiary(context).withValues(alpha: 0.3)),
                              const SizedBox(height: 8),
                              Text('Tap a product above or enter manually',
                                  style: AppTypography.bodySmall.copyWith(
                                      color: AppColors.textTertiary(context))),
                            ],
                          ),
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: _items.length,
                        itemBuilder: (_, i) => _buildItemRow(i),
                      ),
              ),

              // ─── Totals & Payment ───
              if (_items.isNotEmpty) ...[
                Divider(color: AppColors.cardBorder(context)),

                // Grand total
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Grand Total (${_items.length} items)',
                        style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary(context))),
                    Text(Formatters.currency(_total),
                        style: AppTypography.mono.copyWith(
                            color: AppColors.textPrimary(context), fontWeight: FontWeight.w700, fontSize: 18)),
                  ],
                ),
                const SizedBox(height: 12),

                // Payment row
                Row(
                  children: [
                    // Paid field
                    Expanded(
                      child: TextField(
                        controller: _paidCtrl,
                        keyboardType: TextInputType.number,
                        onChanged: (_) => setState(() {}),
                        style: TextStyle(color: AppColors.textPrimary(context), fontSize: 13),
                        decoration: InputDecoration(
                          labelText: 'Paid ₹',
                          labelStyle: TextStyle(color: AppColors.textSecondary(context), fontSize: 11),
                          isDense: true, filled: true,
                          fillColor: AppColors.surface(context),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: AppColors.cardBorder(context)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: AppColors.cardBorder(context)),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Pay Full button
                    SizedBox(
                      height: 38,
                      child: OutlinedButton(
                        onPressed: () => setState(() => _paidCtrl.text = _total.toStringAsFixed(0)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.success,
                          side: BorderSide(color: AppColors.success),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Text('Pay Full', style: TextStyle(fontSize: 11)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Payment mode chips
                    ...['Cash', 'UPI', 'Card'].map((m) => Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: ChoiceChip(
                        label: Text(m, style: TextStyle(fontSize: 10)),
                        selected: _paymentMode == m,
                        visualDensity: VisualDensity.compact,
                        selectedColor: AppColors.primary.withValues(alpha: 0.15),
                        labelStyle: TextStyle(
                          color: _paymentMode == m ? AppColors.primary : AppColors.textSecondary(context),
                          fontWeight: _paymentMode == m ? FontWeight.w700 : FontWeight.w400,
                        ),
                        onSelected: (_) => setState(() => _paymentMode = m),
                      ),
                    )),
                  ],
                ),

                // Due amount
                if (_due > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, size: 14, color: AppColors.error),
                        const SizedBox(width: 4),
                        Text('Due: ${Formatters.currency(_due)} (will be added to vendor balance)',
                            style: AppTypography.labelSmall.copyWith(color: AppColors.error, fontSize: 10)),
                      ],
                    ),
                  ),

                const SizedBox(height: 14),

                // Submit
                ElevatedButton(
                  onPressed: _submitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _submitting
                      ? const SizedBox(width: 20, height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text('Record Purchase — ${Formatters.currency(_total)}',
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildItemRow(int index) {
    final item = _items[index];
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          // Item name
          Expanded(
            flex: 3,
            child: Text(item.name,
                style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textPrimary(context), fontSize: 12, fontWeight: FontWeight.w500)),
          ),

          // Qty controls: - [qty] +
          SizedBox(
            width: 90,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _qtyButton(Icons.remove_rounded, () {
                  if (item.quantity > 1) setState(() => item.quantity--);
                }),
                Container(
                  width: 32,
                  alignment: Alignment.center,
                  child: Text('${item.quantity}',
                      style: AppTypography.mono.copyWith(
                          color: AppColors.textPrimary(context), fontSize: 13, fontWeight: FontWeight.w700)),
                ),
                _qtyButton(Icons.add_rounded, () {
                  setState(() => item.quantity++);
                }),
              ],
            ),
          ),

          // Cost per unit (editable)
          SizedBox(
            width: 70,
            child: GestureDetector(
              onTap: () => _editCostPrice(index),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.cardBorder(context)),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text('₹${item.costPrice.toStringAsFixed(0)}',
                    textAlign: TextAlign.center,
                    style: AppTypography.mono.copyWith(
                        color: AppColors.accent, fontSize: 11)),
              ),
            ),
          ),

          // Line total
          SizedBox(
            width: 70,
            child: Text(Formatters.currency(item.total),
                textAlign: TextAlign.right,
                style: AppTypography.mono.copyWith(
                    color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w600)),
          ),

          // Delete
          SizedBox(
            width: 24,
            child: GestureDetector(
              onTap: () => setState(() => _items.removeAt(index)),
              child: Icon(Icons.close_rounded, size: 16, color: AppColors.error.withValues(alpha: 0.6)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _qtyButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 24, height: 24,
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(icon, size: 14, color: AppColors.primary),
      ),
    );
  }

  void _editCostPrice(int index) {
    final item = _items[index];
    final ctrl = TextEditingController(text: item.costPrice.toStringAsFixed(0));
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card(context),
        title: Text('Edit Cost — ${item.name}',
            style: AppTypography.h4.copyWith(color: AppColors.textPrimary(context))),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          autofocus: true,
          style: TextStyle(color: AppColors.textPrimary(context)),
          decoration: InputDecoration(
            labelText: 'Cost per unit (₹)',
            labelStyle: TextStyle(color: AppColors.textSecondary(context)),
            filled: true,
            fillColor: AppColors.surface(context),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: AppColors.textSecondary(context))),
          ),
          ElevatedButton(
            onPressed: () {
              final newPrice = double.tryParse(ctrl.text) ?? item.costPrice;
              setState(() => item.costPrice = newPrice);
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Widget _miniField(TextEditingController ctrl, String hint, {bool isNumber = false}) {
    return TextField(
      controller: ctrl,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      style: TextStyle(color: AppColors.textPrimary(context), fontSize: 12),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: AppColors.textTertiary(context), fontSize: 11),
        isDense: true, filled: true,
        fillColor: AppColors.card(context),
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: AppColors.cardBorder(context)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: AppColors.cardBorder(context)),
        ),
      ),
    );
  }
}
