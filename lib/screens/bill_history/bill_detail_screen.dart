import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/receipt_printer.dart';
import '../../data/models/sale_model.dart';

class BillDetailDialog extends StatelessWidget {
  final SaleModel sale;
  const BillDetailDialog({super.key, required this.sale});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.card(context),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 640),
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
                    child: Icon(Icons.receipt_long_rounded, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          sale.invoiceNumber,
                          style: AppTypography.mono.copyWith(
                            color: AppColors.accent,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          Formatters.dateTime(sale.createdAt),
                          style: AppTypography.labelSmall.copyWith(
                            color: AppColors.textTertiary(context),
                          ),
                        ),
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

              // ─── Customer ───
              if (sale.customerName.isNotEmpty || sale.customerPhone.isNotEmpty)
                Container(
                  padding: EdgeInsets.all(12),
                  margin: EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppColors.surface(context),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.person_rounded, color: AppColors.textTertiary(context), size: 18),
                      SizedBox(width: 8),
                      Text(
                        sale.customerName.isNotEmpty ? sale.customerName : 'Walk-in',
                        style: AppTypography.bodyMedium.copyWith(color: AppColors.textPrimary(context)),
                      ),
                      if (sale.customerPhone.isNotEmpty) ...[
                        SizedBox(width: 12),
                        Text(
                          Formatters.phone(sale.customerPhone),
                          style: AppTypography.mono.copyWith(
                            color: AppColors.textSecondary(context),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

              // ─── Items ───
              Flexible(
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface(context),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header row
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: Text('Item',
                                  style: AppTypography.labelSmall
                                      .copyWith(color: AppColors.textTertiary(context))),
                            ),
                            Expanded(
                              child: Text('Qty',
                                  style: AppTypography.labelSmall
                                      .copyWith(color: AppColors.textTertiary(context)),
                                  textAlign: TextAlign.center),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text('Amount',
                                  style: AppTypography.labelSmall
                                      .copyWith(color: AppColors.textTertiary(context)),
                                  textAlign: TextAlign.right),
                            ),
                          ],
                        ),
                      ),
                      Divider(color: AppColors.cardBorder(context), height: 1),
                      // Items
                      Flexible(
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: sale.items.length,
                          itemBuilder: (context, index) {
                            final item = sale.items[index];
                            return Padding(
                              padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              child: Row(
                                children: [
                                  Expanded(
                                    flex: 3,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(item.name,
                                            style: AppTypography.bodySmall.copyWith(
                                                color: AppColors.textPrimary(context))),
                                        Text(
                                          '@ ${Formatters.currency(item.price)}',
                                          style: AppTypography.monoSmall.copyWith(
                                              color: AppColors.textTertiary(context)),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Expanded(
                                    child: Text('${item.quantity}',
                                        style: AppTypography.mono.copyWith(
                                            color: AppColors.textSecondary(context), fontSize: 13),
                                        textAlign: TextAlign.center),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(Formatters.currency(item.total),
                                        style: AppTypography.mono.copyWith(
                                            color: AppColors.textPrimary(context), fontSize: 13),
                                        textAlign: TextAlign.right),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 16),

              // ─── Totals (round to whole rupees for clean display) ───
              _row(context, 'Subtotal', Formatters.currency(sale.subtotal.roundToDouble())),
              if (sale.discount > 0) _row(context, 'Discount', '- ${Formatters.currency(sale.discount.roundToDouble())}', color: AppColors.error),
              if (sale.gstAmount > 0) ...[
                _row(context, 'CGST', '+ ${Formatters.currency(sale.cgst)}', color: AppColors.accent),
                _row(context, 'SGST', '+ ${Formatters.currency(sale.sgst)}', color: AppColors.accent),
              ],
              Divider(color: AppColors.cardBorder(context)),
              _row(context, 'Total', Formatters.currency(sale.total.roundToDouble()), isBold: true, color: AppColors.success),
              // Show payment breakdown — if split, show both amounts
              if (sale.cashAmount > 0 && sale.upiAmount > 0) ...[
                _row(context, 'Cash Paid', Formatters.currency(sale.cashAmount.roundToDouble()), fontSize: 12),
                _row(context, 'UPI Paid', Formatters.currency(sale.upiAmount.roundToDouble()), fontSize: 12),
              ] else
                _row(context, 'Payment', sale.paymentMode, fontSize: 12),
              if (sale.dueAmount > 0)
                _row(context, '⚠️ Due Amount', Formatters.currency(sale.dueAmount.roundToDouble()), color: AppColors.warning, isBold: true),
              const SizedBox(height: 16),

              // ─── Actions ───
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _shareViaWhatsApp(context),
                      icon: const Icon(Icons.share_rounded, size: 18),
                      label: const Text('WhatsApp'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.success,
                        side: const BorderSide(color: AppColors.success),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.check_rounded, size: 18),
                      label: const Text('Close'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () => _printBill(context),
                icon: const Icon(Icons.print_rounded, size: 18, color: AppColors.accent),
                label: const Text('Print Bill'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.accent,
                  side: BorderSide(color: AppColors.accent.withValues(alpha: 0.6)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(BuildContext context, String label, String value, {bool isBold = false, Color? color, double? fontSize}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textSecondary(context),
                  fontWeight: isBold ? FontWeight.w600 : FontWeight.w400)),
          Text(value,
              style: AppTypography.mono.copyWith(
                color: color ?? AppColors.textPrimary(context),
                fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
                fontSize: fontSize ?? (isBold ? 18 : 14),
              )),
        ],
      ),
    );
  }

  void _shareViaWhatsApp(BuildContext context) async {
    final items = sale.items
        .map((i) => '${i.name} x${i.quantity} = ${Formatters.currency(i.total.roundToDouble())}')
        .join('\n');

    final message = '''
🧾 *SKYWALK Billing*
━━━━━━━━━━━━━━
Invoice: *${sale.invoiceNumber}*
Date: ${Formatters.dateTime(sale.createdAt)}
${sale.customerName.isNotEmpty ? 'Customer: ${sale.customerName}\n' : ''}
$items
━━━━━━━━━━━━━━
Subtotal: ${Formatters.currency(sale.subtotal.roundToDouble())}
${sale.discount > 0 ? 'Discount: -${Formatters.currency(sale.discount.roundToDouble())}\n' : ''}${sale.gstAmount > 0 ? 'CGST: +${Formatters.currency(sale.cgst)}\nSGST: +${Formatters.currency(sale.sgst)}\n' : ''}*Total: ${Formatters.currency(sale.total.roundToDouble())}*
Payment: ${sale.cashAmount > 0 && sale.upiAmount > 0 ? 'Cash ${Formatters.currency(sale.cashAmount.roundToDouble())} + UPI ${Formatters.currency(sale.upiAmount.roundToDouble())}' : sale.paymentMode}

Thank you for your purchase! 🙏
''';

    final phone = sale.customerPhone.isNotEmpty
        ? sale.customerPhone.replaceAll(RegExp(r'[^0-9]'), '')
        : '';

    final url = phone.isNotEmpty
        ? 'https://wa.me/91$phone?text=${Uri.encodeComponent(message)}'
        : 'https://wa.me/?text=${Uri.encodeComponent(message)}';

    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open WhatsApp'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _printBill(BuildContext context) {
    double cashPaid = sale.cashAmount;
    double upiPaid = sale.upiAmount;
    if (cashPaid == 0 && upiPaid == 0) {
      final mode = sale.paymentMode.toLowerCase();
      if (mode == 'cash') {
        cashPaid = sale.total;
      } else if (mode == 'upi' || mode == 'card' || mode == 'upi/card') {
        upiPaid = sale.total;
      }
    }
    ReceiptPrinter.manualPrint(sale, cashPaid: cashPaid, upiPaid: upiPaid);
  }
}
