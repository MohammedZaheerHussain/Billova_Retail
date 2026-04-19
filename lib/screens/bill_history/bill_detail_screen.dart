import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/sale_model.dart';

class BillDetailDialog extends StatelessWidget {
  final SaleModel sale;
  const BillDetailDialog({super.key, required this.sale});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.cardDark,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 600),
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
                    child: const Icon(Icons.receipt_long_rounded, color: Colors.white, size: 20),
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
                            color: AppColors.textTertiaryDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded, color: AppColors.textTertiaryDark),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // ─── Customer ───
              if (sale.customerName.isNotEmpty || sale.customerPhone.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceDark,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.person_rounded, color: AppColors.textTertiaryDark, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        sale.customerName.isNotEmpty ? sale.customerName : 'Walk-in',
                        style: AppTypography.bodyMedium.copyWith(color: AppColors.textPrimaryDark),
                      ),
                      if (sale.customerPhone.isNotEmpty) ...[
                        const SizedBox(width: 12),
                        Text(
                          Formatters.phone(sale.customerPhone),
                          style: AppTypography.mono.copyWith(
                            color: AppColors.textSecondaryDark,
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
                    color: AppColors.surfaceDark,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header row
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: Text('Item',
                                  style: AppTypography.labelSmall
                                      .copyWith(color: AppColors.textTertiaryDark)),
                            ),
                            Expanded(
                              child: Text('Qty',
                                  style: AppTypography.labelSmall
                                      .copyWith(color: AppColors.textTertiaryDark),
                                  textAlign: TextAlign.center),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text('Amount',
                                  style: AppTypography.labelSmall
                                      .copyWith(color: AppColors.textTertiaryDark),
                                  textAlign: TextAlign.right),
                            ),
                          ],
                        ),
                      ),
                      const Divider(color: AppColors.cardBorderDark, height: 1),
                      // Items
                      Flexible(
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: sale.items.length,
                          itemBuilder: (context, index) {
                            final item = sale.items[index];
                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              child: Row(
                                children: [
                                  Expanded(
                                    flex: 3,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(item.name,
                                            style: AppTypography.bodySmall.copyWith(
                                                color: AppColors.textPrimaryDark)),
                                        Text(
                                          '@ ${Formatters.currency(item.price)}',
                                          style: AppTypography.monoSmall.copyWith(
                                              color: AppColors.textTertiaryDark),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Expanded(
                                    child: Text('${item.quantity}',
                                        style: AppTypography.mono.copyWith(
                                            color: AppColors.textSecondaryDark, fontSize: 13),
                                        textAlign: TextAlign.center),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(Formatters.currency(item.total),
                                        style: AppTypography.mono.copyWith(
                                            color: AppColors.textPrimaryDark, fontSize: 13),
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
              const SizedBox(height: 16),

              // ─── Totals ───
              _row('Subtotal', Formatters.currency(sale.subtotal)),
              if (sale.discount > 0) _row('Discount', '- ${Formatters.currency(sale.discount)}', color: AppColors.error),
              const Divider(color: AppColors.cardBorderDark),
              _row('Total', Formatters.currency(sale.total), isBold: true, color: AppColors.success),
              _row('Payment', sale.paymentMode, fontSize: 12),
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
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(String label, String value, {bool isBold = false, Color? color, double? fontSize}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textSecondaryDark,
                  fontWeight: isBold ? FontWeight.w600 : FontWeight.w400)),
          Text(value,
              style: AppTypography.mono.copyWith(
                color: color ?? AppColors.textPrimaryDark,
                fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
                fontSize: fontSize ?? (isBold ? 18 : 14),
              )),
        ],
      ),
    );
  }

  void _shareViaWhatsApp(BuildContext context) async {
    final items = sale.items
        .map((i) => '${i.name} x${i.quantity} = ${Formatters.currency(i.total)}')
        .join('\n');

    final message = '''
🧾 *SKYWALK Billing*
━━━━━━━━━━━━━━
Invoice: *${sale.invoiceNumber}*
Date: ${Formatters.dateTime(sale.createdAt)}
${sale.customerName.isNotEmpty ? 'Customer: ${sale.customerName}\n' : ''}
$items
━━━━━━━━━━━━━━
Subtotal: ${Formatters.currency(sale.subtotal)}
${sale.discount > 0 ? 'Discount: -${Formatters.currency(sale.discount)}\n' : ''}*Total: ${Formatters.currency(sale.total)}*
Payment: ${sale.paymentMode}

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
}
