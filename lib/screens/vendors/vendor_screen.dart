import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/formatters.dart';
import '../../providers/vendor_provider.dart';
import '../../providers/purchase_provider.dart';
import '../../core/utils/whatsapp_helper.dart';
import '../../data/models/vendor_model.dart';
import 'vendor_detail_screen.dart';

class VendorScreen extends StatefulWidget {
  const VendorScreen({super.key});

  @override
  State<VendorScreen> createState() => _VendorScreenState();
}

class _VendorScreenState extends State<VendorScreen> {
  final _searchCtrl = TextEditingController();
  String _search = '';
  String _filter = 'All'; // All, Paid, Pending, Partial

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<VendorProvider>().loadVendors();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _showVendorDialog({VendorModel? vendor}) {
    final nameCtrl = TextEditingController(text: vendor?.name ?? '');
    final phoneCtrl = TextEditingController(text: vendor?.phone ?? '');
    final notesCtrl = TextEditingController(text: vendor?.notes ?? '');
    final formKey = GlobalKey<FormState>();
    final isEditing = vendor != null;

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: AppColors.card(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          gradient: AppColors.primaryGradient,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          isEditing ? Icons.edit_rounded : Icons.add_rounded,
                          color: Colors.white, size: 20,
                        ),
                      ),
                      SizedBox(width: 12),
                      Text(
                        isEditing ? 'Edit Vendor' : 'Add Vendor',
                        style: AppTypography.h3.copyWith(color: AppColors.textPrimary(context)),
                      ),
                      Spacer(),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: Icon(Icons.close_rounded, color: AppColors.textTertiary(context)),
                      ),
                    ],
                  ),
                  SizedBox(height: 24),
                  _field('Vendor Name', nameCtrl, 'e.g. Nike India Pvt Ltd',
                      validator: (v) => v!.trim().isEmpty ? 'Required' : null),
                  SizedBox(height: 14),
                  _field('Phone Number', phoneCtrl, 'e.g. 9876543210',
                      keyboardType: TextInputType.phone),
                  SizedBox(height: 14),
                  TextFormField(
                    controller: notesCtrl,
                    maxLines: 3,
                    style: TextStyle(color: AppColors.textPrimary(context)),
                    decoration: InputDecoration(
                      labelText: 'Notes (Optional)',
                      hintText: 'e.g. Deals in sports shoes, delivers on Mondays, contact person: Ravi...',
                      labelStyle: TextStyle(color: AppColors.textSecondary(context), fontSize: 13),
                      hintStyle: TextStyle(color: AppColors.textTertiary(context), fontSize: 12),
                      filled: true,
                      fillColor: AppColors.surface(context),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: AppColors.cardBorder(context)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: AppColors.cardBorder(context)),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () async {
                        if (!formKey.currentState!.validate()) return;
                        final provider = context.read<VendorProvider>();
                        bool success;
                        if (isEditing) {
                          success = await provider.updateVendor(vendor!.copyWith(
                            name: nameCtrl.text.trim(),
                            phone: phoneCtrl.text.trim(),
                            notes: notesCtrl.text.trim(),
                          ));
                        } else {
                          success = await provider.addVendor(
                            name: nameCtrl.text.trim(),
                            phone: phoneCtrl.text.trim(),
                            notes: notesCtrl.text.trim(),
                          );
                        }
                        if (success && ctx.mounted) {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text(isEditing ? 'Vendor updated' : 'Vendor added'),
                            backgroundColor: AppColors.card(context),
                          ));
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(
                        isEditing ? 'Update Vendor' : 'Add Vendor',
                        style: AppTypography.button.copyWith(color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _field(String label, TextEditingController controller, String hint, {
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      style: TextStyle(color: AppColors.textPrimary(context)),
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: TextStyle(color: AppColors.textSecondary(context), fontSize: 13),
        hintStyle: TextStyle(color: AppColors.textTertiary(context)),
        filled: true,
        fillColor: AppColors.surface(context),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: AppColors.cardBorder(context)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: AppColors.cardBorder(context)),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final purchaseProvider = context.watch<PurchaseProvider>();
    final summaries = purchaseProvider.getAllVendorSummaries();

    return Consumer<VendorProvider>(
      builder: (context, provider, _) {
        var filtered = _search.isEmpty
            ? provider.vendors.toList()
            : provider.vendors.where((v) =>
                v.name.toLowerCase().contains(_search.toLowerCase()) ||
                v.phone.contains(_search)).toList();
        // Sort by pending DESC — most important vendors first
        filtered.sort((a, b) {
          final aPending = (summaries[a.id]?['pending'] as double?) ?? a.balance;
          final bPending = (summaries[b.id]?['pending'] as double?) ?? b.balance;
          return bPending.compareTo(aPending);
        });

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
                    Text('Vendors', style: AppTypography.h1.copyWith(color: AppColors.textPrimary(context))),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text('${provider.vendors.length} vendors',
                          style: AppTypography.mono.copyWith(color: AppColors.accent, fontSize: 13)),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: () => _showVendorDialog(),
                      icon: Icon(Icons.add_rounded, size: 18),
                      label: const Text('Add Vendor'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16),

                // Search
                TextField(
                  controller: _searchCtrl,
                  onChanged: (v) => setState(() => _search = v),
                  style: TextStyle(color: AppColors.textPrimary(context)),
                  decoration: InputDecoration(
                    hintText: 'Search vendors...',
                    hintStyle: TextStyle(color: AppColors.textTertiary(context)),
                    prefixIcon: Icon(Icons.search_rounded, color: AppColors.textTertiary(context)),
                    filled: true,
                    fillColor: AppColors.card(context),
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
                SizedBox(height: 10),

                // Filter Chips
                SizedBox(
                  height: 34,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: ['All', 'Pending', 'Partial', 'Paid'].map((f) {
                      final isActive = _filter == f;
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ChoiceChip(
                          label: Text(f, style: TextStyle(fontSize: 11,
                            color: isActive ? Colors.white : AppColors.textSecondary(context))),
                          selected: isActive,
                          selectedColor: AppColors.primary,
                          backgroundColor: AppColors.card(context),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8),
                            side: BorderSide(color: isActive ? AppColors.primary : AppColors.cardBorder(context))),
                          onSelected: (_) => setState(() => _filter = f),
                          visualDensity: VisualDensity.compact,
                        ),
                      );
                    }).toList(),
                  ),
                ),
                SizedBox(height: 12),

                // List
                Expanded(
                  child: provider.isLoading
                      ? Center(child: CircularProgressIndicator(color: AppColors.accent))
                      : filtered.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.store_rounded, size: 64, color: AppColors.textTertiary(context).withValues(alpha: 0.3)),
                                  SizedBox(height: 12),
                                  Text('No vendors yet', style: AppTypography.bodyMedium.copyWith(color: AppColors.textTertiary(context))),
                                  SizedBox(height: 4),
                                  Text('Add your suppliers to track purchases', style: AppTypography.labelSmall.copyWith(color: AppColors.textTertiary(context))),
                                ],
                              ),
                            )
                          : ListView.separated(
                              itemCount: filtered.where((v) {
                                if (_filter == 'All') return true;
                                final s = summaries[v.id];
                                final p = (s?['pending'] as double?) ?? v.balance;
                                final pd = (s?['totalPaid'] as double?) ?? 0;
                                if (_filter == 'Paid') return p <= 0 && pd > 0;
                                if (_filter == 'Pending') return p > 0;
                                if (_filter == 'Partial') return p > 0 && pd > 0;
                                return true;
                              }).length,
                              separatorBuilder: (_, __) => const SizedBox(height: 8),
                              itemBuilder: (context, i) {
                                final list = filtered.where((v) {
                                  if (_filter == 'All') return true;
                                  final s = summaries[v.id];
                                  final p = (s?['pending'] as double?) ?? v.balance;
                                  final pd = (s?['totalPaid'] as double?) ?? 0;
                                  if (_filter == 'Paid') return p <= 0 && pd > 0;
                                  if (_filter == 'Pending') return p > 0;
                                  if (_filter == 'Partial') return p > 0 && pd > 0;
                                  return true;
                                }).toList();
                                return _vendorTile(list[i], provider, summaries, purchaseProvider);
                              },
                            ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _vendorTile(VendorModel vendor, VendorProvider provider, Map<String, Map<String, dynamic>> summaries, PurchaseProvider pp) {
    final s = summaries[vendor.id];
    final totalPurchase = (s?['totalPurchase'] as double?) ?? 0;
    final totalItems = (s?['totalItems'] as int?) ?? 0;
    final pending = (s?['pending'] as double?) ?? vendor.balance;
    final hasBalance = pending > 0;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => VendorDetailScreen(vendor: vendor)),
      ),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.card(context),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: hasBalance ? AppColors.error.withValues(alpha: 0.3) : AppColors.cardBorder(context)),
        ),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  vendor.name.isNotEmpty ? vendor.name[0].toUpperCase() : '?',
                  style: AppTypography.h3.copyWith(color: Colors.white),
                ),
              ),
            ),
            const SizedBox(width: 14),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(vendor.name,
                            style: AppTypography.bodyLarge.copyWith(
                                color: AppColors.textPrimary(context), fontWeight: FontWeight.w600)),
                      ),
                      if (vendor.phone.isNotEmpty)
                        Text('📞 ${vendor.phone}',
                            style: AppTypography.labelSmall.copyWith(
                                color: AppColors.textTertiary(context), fontSize: 10)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  // Stats row
                  Row(
                    children: [
                      Text('₹${_compact(totalPurchase)}',
                          style: AppTypography.mono.copyWith(
                              color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w700)),
                      Text(' • ',
                          style: TextStyle(color: AppColors.textTertiary(context), fontSize: 10)),
                      Text('$totalItems items',
                          style: AppTypography.labelSmall.copyWith(
                              color: AppColors.textSecondary(context), fontSize: 11)),
                      if (hasBalance) ...[
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.error.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text('Due: ${Formatters.currency(pending)}',
                              style: AppTypography.mono.copyWith(
                                  color: AppColors.error, fontSize: 11, fontWeight: FontWeight.w700)),
                        ),
                      ] else if (totalPurchase > 0) ...[
                        const Spacer(),
                        Icon(Icons.check_circle_rounded, size: 14, color: AppColors.success),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(width: 4),
            // WhatsApp quick-send
            if (vendor.phone.isNotEmpty && totalPurchase > 0)
              IconButton(
                tooltip: 'Send Invoice via WhatsApp',
                icon: const Icon(Icons.chat_rounded, size: 18, color: Color(0xFF25D366)),
                onPressed: () {
                  final summary = pp.getVendorSummary(vendor.id);
                  final msg = WhatsAppHelper.vendorInvoiceMessage(
                    vendorName: vendor.name,
                    invoiceNumber: pp.generateVendorInvoiceNumber(vendor.id),
                    totalAmount: summary['totalPurchase'] as double,
                    paidAmount: summary['totalPaid'] as double,
                    pendingAmount: summary['pending'] as double,
                    paymentStatus: pp.getVendorPaymentStatus(vendor.id),
                    purchases: pp.getVendorPurchasesList(vendor.id),
                  );
                  WhatsAppHelper.send(phone: vendor.phone, message: msg);
                },
                constraints: const BoxConstraints(),
                padding: const EdgeInsets.all(6),
              ),
            // Menu
            PopupMenuButton(
              icon: Icon(Icons.more_vert_rounded, color: AppColors.textSecondary(context), size: 20),
              color: AppColors.surface(context),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              itemBuilder: (ctx) => [
                PopupMenuItem(
                  onTap: () => Future.microtask(() => _showVendorDialog(vendor: vendor)),
                  child: Row(children: [Icon(Icons.edit_rounded, size: 18), SizedBox(width: 8), Text('Edit')]),
                ),
                PopupMenuItem(
                  onTap: () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: AppColors.card(context),
                        title: Text('Delete Vendor?', style: TextStyle(color: AppColors.textPrimary(context))),
                        content: Text('Are you sure you want to delete "${vendor.name}"?',
                            style: TextStyle(color: AppColors.textSecondary(context))),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('Delete', style: TextStyle(color: AppColors.error)),
                          ),
                        ],
                      ),
                    );
                    if (confirmed == true) {
                      await provider.deleteVendor(vendor.id);
                    }
                  },
                  child: Row(children: [
                    Icon(Icons.delete_rounded, size: 18, color: AppColors.error),
                    const SizedBox(width: 8),
                    Text('Delete', style: TextStyle(color: AppColors.error)),
                  ]),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _compact(double v) {
    if (v >= 100000) return '${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
    return v.toStringAsFixed(0);
  }
}
