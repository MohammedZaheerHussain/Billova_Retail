import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/formatters.dart';
import '../../providers/vendor_provider.dart';
import '../../data/models/vendor_model.dart';

class VendorScreen extends StatefulWidget {
  const VendorScreen({super.key});

  @override
  State<VendorScreen> createState() => _VendorScreenState();
}

class _VendorScreenState extends State<VendorScreen> {
  final _searchCtrl = TextEditingController();
  String _search = '';

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
        backgroundColor: AppColors.cardDark,
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
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          gradient: AppColors.primaryGradient,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          isEditing ? Icons.edit_rounded : Icons.add_rounded,
                          color: Colors.white, size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        isEditing ? 'Edit Vendor' : 'Add Vendor',
                        style: AppTypography.h3.copyWith(color: AppColors.textPrimaryDark),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close_rounded, color: AppColors.textTertiaryDark),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _field('Vendor Name', nameCtrl, 'e.g. Nike India Pvt Ltd',
                      validator: (v) => v!.trim().isEmpty ? 'Required' : null),
                  const SizedBox(height: 14),
                  _field('Phone Number', phoneCtrl, 'e.g. 9876543210',
                      keyboardType: TextInputType.phone),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: notesCtrl,
                    maxLines: 3,
                    style: const TextStyle(color: AppColors.textPrimaryDark),
                    decoration: InputDecoration(
                      labelText: 'Notes (Optional)',
                      hintText: 'e.g. Deals in sports shoes, delivers on Mondays, contact person: Ravi...',
                      labelStyle: const TextStyle(color: AppColors.textSecondaryDark, fontSize: 13),
                      hintStyle: const TextStyle(color: AppColors.textTertiaryDark, fontSize: 12),
                      filled: true,
                      fillColor: AppColors.surfaceDark,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: AppColors.cardBorderDark),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: AppColors.cardBorderDark),
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
                            backgroundColor: AppColors.cardDark,
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
      style: const TextStyle(color: AppColors.textPrimaryDark),
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: const TextStyle(color: AppColors.textSecondaryDark, fontSize: 13),
        hintStyle: const TextStyle(color: AppColors.textTertiaryDark),
        filled: true,
        fillColor: AppColors.surfaceDark,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.cardBorderDark),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.cardBorderDark),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<VendorProvider>(
      builder: (context, provider, _) {
        final filtered = _search.isEmpty
            ? provider.vendors
            : provider.vendors.where((v) =>
                v.name.toLowerCase().contains(_search.toLowerCase()) ||
                v.phone.contains(_search)).toList();

        return Scaffold(
          backgroundColor: Colors.transparent,
          body: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Text('Vendors', style: AppTypography.h1.copyWith(color: AppColors.textPrimaryDark)),
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
                      icon: const Icon(Icons.add_rounded, size: 18),
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
                const SizedBox(height: 16),

                // Search
                TextField(
                  controller: _searchCtrl,
                  onChanged: (v) => setState(() => _search = v),
                  style: const TextStyle(color: AppColors.textPrimaryDark),
                  decoration: InputDecoration(
                    hintText: 'Search vendors...',
                    hintStyle: const TextStyle(color: AppColors.textTertiaryDark),
                    prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textTertiaryDark),
                    filled: true,
                    fillColor: AppColors.cardDark,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.cardBorderDark),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.cardBorderDark),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // List
                Expanded(
                  child: provider.isLoading
                      ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
                      : filtered.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.store_rounded, size: 64, color: AppColors.textTertiaryDark.withValues(alpha: 0.3)),
                                  const SizedBox(height: 12),
                                  Text('No vendors yet', style: AppTypography.bodyMedium.copyWith(color: AppColors.textTertiaryDark)),
                                  const SizedBox(height: 4),
                                  Text('Add your suppliers to track purchases', style: AppTypography.labelSmall.copyWith(color: AppColors.textTertiaryDark)),
                                ],
                              ),
                            )
                          : ListView.separated(
                              itemCount: filtered.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 8),
                              itemBuilder: (context, i) => _vendorTile(filtered[i], provider),
                            ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _vendorTile(VendorModel vendor, VendorProvider provider) {
    final hasBalance = vendor.balance > 0;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: hasBalance ? AppColors.error.withValues(alpha: 0.3) : AppColors.cardBorderDark),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              vendor.name.isNotEmpty ? vendor.name[0].toUpperCase() : '?',
              style: AppTypography.h3.copyWith(color: AppColors.accent),
            ),
          ),
        ),
        title: Text(vendor.name,
            style: AppTypography.bodyLarge.copyWith(color: AppColors.textPrimaryDark, fontWeight: FontWeight.w600)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (vendor.phone.isNotEmpty)
              Text(vendor.phone,
                  style: AppTypography.labelSmall.copyWith(color: AppColors.textTertiaryDark)),
            if (vendor.notes.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(vendor.notes,
                    maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: AppTypography.labelSmall.copyWith(color: AppColors.textSecondaryDark, fontStyle: FontStyle.italic)),
              ),
            if (hasBalance)
              Text('Due: ${Formatters.currency(vendor.balance)}',
                  style: AppTypography.mono.copyWith(color: AppColors.error, fontSize: 12, fontWeight: FontWeight.w600)),
          ],
        ),
        trailing: PopupMenuButton(
          icon: const Icon(Icons.more_vert_rounded, color: AppColors.textSecondaryDark),
          color: AppColors.surfaceDark,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          itemBuilder: (_) => [
            PopupMenuItem(
              onTap: () => Future.microtask(() => _showVendorDialog(vendor: vendor)),
              child: const Row(children: [Icon(Icons.edit_rounded, size: 18), SizedBox(width: 8), Text('Edit')]),
            ),
            PopupMenuItem(
              onTap: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    backgroundColor: AppColors.cardDark,
                    title: Text('Delete Vendor?', style: TextStyle(color: AppColors.textPrimaryDark)),
                    content: Text('Are you sure you want to delete "${vendor.name}"?',
                        style: TextStyle(color: AppColors.textSecondaryDark)),
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
      ),
    );
  }
}
