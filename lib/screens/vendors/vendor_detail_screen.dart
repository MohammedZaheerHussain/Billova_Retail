import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/formatters.dart';
import '../../providers/purchase_provider.dart';
import '../../providers/vendor_provider.dart';
import '../../data/models/vendor_model.dart';
import '../../data/models/purchase_model.dart';

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
          // Record Payment button
          if (pending > 0)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: ElevatedButton.icon(
                onPressed: () => _showPaymentDialog(context, pending),
                icon: const Icon(Icons.payment_rounded, size: 18),
                label: const Text('Pay'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
            // ─── Summary Cards ───
            _buildSummarySection(context, totalPurchase, totalPaid, pending, totalItems),
            const SizedBox(height: 24),

            // ─── Purchase History ───
            _buildPurchaseHistory(context, purchases),
          ],
        ),
      ),
    );
  }

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
          // Vendor info
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

          // Stats grid
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
              Text('Record a purchase from the Purchases tab',
                  style: AppTypography.bodySmall.copyWith(color: AppColors.textTertiary(context))),
            ],
          ),
        ),
      );
    }

    // Group purchases by date
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
          Text('Purchase History',
              style: AppTypography.h4.copyWith(color: AppColors.textPrimary(context))),
          const SizedBox(height: 16),

          ...grouped.entries.map((entry) {
            final date = entry.key;
            final dayPurchases = entry.value;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Date header
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

                // Purchase entries
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
            // Items
            ...items.map((item) {
              final name = item['name'] ?? item['item_name'] ?? 'Item';
              final qty = item['quantity'] ?? 0;
              final cost = (item['cost_price'] as num?)?.toDouble() ?? 0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text('$name × $qty',
                          style: AppTypography.bodySmall.copyWith(
                              color: AppColors.textPrimary(context), fontSize: 13)),
                    ),
                    Text(Formatters.currency(cost * qty),
                        style: AppTypography.mono.copyWith(
                            color: AppColors.textSecondary(context), fontSize: 12)),
                  ],
                ),
              );
            }),

            const SizedBox(height: 6),

            // Totals row
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isPaid
                        ? AppColors.success.withValues(alpha: 0.1)
                        : AppColors.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    isPaid ? '✅ Paid' : '⚠️ Due: ${Formatters.currency(purchase.dueAmount)}',
                    style: AppTypography.labelSmall.copyWith(
                      color: isPaid ? AppColors.success : AppColors.error,
                      fontWeight: FontWeight.w700,
                      fontSize: 10,
                    ),
                  ),
                ),
                const Spacer(),
                Text('Total: ${Formatters.currency(purchase.totalAmount)}',
                    style: AppTypography.mono.copyWith(
                        color: AppColors.textPrimary(context), fontWeight: FontWeight.w700, fontSize: 13)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showPaymentDialog(BuildContext context, double maxDue) {
    final amountCtrl = TextEditingController();
    String paymentMode = 'Cash';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Dialog(
          backgroundColor: AppColors.card(context),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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

                // Amount field
                TextField(
                  controller: amountCtrl,
                  keyboardType: TextInputType.number,
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

                // Payment mode chips
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

                // Submit
                ElevatedButton(
                  onPressed: () async {
                    final amount = double.tryParse(amountCtrl.text) ?? 0;
                    if (amount <= 0 || amount > maxDue) return;

                    final purchaseProvider = context.read<PurchaseProvider>();
                    final vendorProvider = context.read<VendorProvider>();

                    await purchaseProvider.recordVendorPayment(
                      vendorId: vendor.id,
                      amount: amount,
                      paymentMode: paymentMode,
                      vendorProvider: vendorProvider,
                    );

                    if (ctx.mounted) Navigator.pop(ctx);

                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('₹${amount.toStringAsFixed(0)} paid to ${vendor.name}'),
                          backgroundColor: AppColors.success,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      );
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
    );
  }
}
