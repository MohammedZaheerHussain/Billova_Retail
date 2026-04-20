import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/formatters.dart';
import '../../providers/customer_provider.dart';
import '../../data/models/customer_model.dart';

class CustomerScreen extends StatefulWidget {
  const CustomerScreen({super.key});

  @override
  State<CustomerScreen> createState() => _CustomerScreenState();
}

class _CustomerScreenState extends State<CustomerScreen> {
  final _searchCtrl = TextEditingController();
  String _search = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CustomerProvider>().loadCustomers();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _showCustomerDialog({CustomerModel? customer}) {
    final nameCtrl = TextEditingController(text: customer?.name ?? '');
    final phoneCtrl = TextEditingController(text: customer?.phone ?? '');
    final formKey = GlobalKey<FormState>();
    final isEditing = customer != null;

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: AppColors.cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
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
                        child: Icon(isEditing ? Icons.edit_rounded : Icons.person_add_rounded,
                            color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Text(isEditing ? 'Edit Customer' : 'Add Customer',
                          style: AppTypography.h3.copyWith(color: AppColors.textPrimaryDark)),
                      const Spacer(),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close_rounded, color: AppColors.textTertiaryDark),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _field('Customer Name', nameCtrl, 'e.g. Rahul Kumar',
                      validator: (v) => v!.trim().isEmpty ? 'Required' : null),
                  const SizedBox(height: 14),
                  _field('Phone Number', phoneCtrl, 'e.g. 9876543210',
                      keyboardType: TextInputType.phone),
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () async {
                        if (!formKey.currentState!.validate()) return;
                        final provider = context.read<CustomerProvider>();
                        bool success;
                        if (isEditing) {
                          success = await provider.updateCustomer(customer!.copyWith(
                            name: nameCtrl.text.trim(),
                            phone: phoneCtrl.text.trim(),
                          ));
                        } else {
                          success = await provider.addCustomer(
                            name: nameCtrl.text.trim(),
                            phone: phoneCtrl.text.trim(),
                          );
                        }
                        if (success && ctx.mounted) Navigator.pop(ctx);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(isEditing ? 'Update' : 'Add Customer',
                          style: AppTypography.button.copyWith(color: Colors.white)),
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
    TextInputType? keyboardType, String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller, keyboardType: keyboardType, validator: validator,
      style: const TextStyle(color: AppColors.textPrimaryDark),
      decoration: InputDecoration(
        labelText: label, hintText: hint,
        labelStyle: const TextStyle(color: AppColors.textSecondaryDark, fontSize: 13),
        hintStyle: const TextStyle(color: AppColors.textTertiaryDark),
        filled: true, fillColor: AppColors.surfaceDark,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.cardBorderDark)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.cardBorderDark)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<CustomerProvider>(
      builder: (context, provider, _) {
        final filtered = _search.isEmpty
            ? provider.customers
            : provider.customers.where((c) =>
                c.name.toLowerCase().contains(_search.toLowerCase()) ||
                c.phone.contains(_search)).toList();

        return Scaffold(
          backgroundColor: Colors.transparent,
          body: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('Customers', style: AppTypography.h1.copyWith(color: AppColors.textPrimaryDark)),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text('${provider.customers.length} customers',
                          style: AppTypography.mono.copyWith(color: AppColors.accent, fontSize: 13)),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: () => _showCustomerDialog(),
                      icon: const Icon(Icons.person_add_rounded, size: 18),
                      label: const Text('Add Customer'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary, foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _searchCtrl,
                  onChanged: (v) => setState(() => _search = v),
                  style: const TextStyle(color: AppColors.textPrimaryDark),
                  decoration: InputDecoration(
                    hintText: 'Search customers...',
                    hintStyle: const TextStyle(color: AppColors.textTertiaryDark),
                    prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textTertiaryDark),
                    filled: true, fillColor: AppColors.cardDark,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.cardBorderDark)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.cardBorderDark)),
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: provider.isLoading
                      ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
                      : filtered.isEmpty
                          ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                              Icon(Icons.people_rounded, size: 64, color: AppColors.textTertiaryDark.withValues(alpha: 0.3)),
                              const SizedBox(height: 12),
                              Text('No customers yet', style: AppTypography.bodyMedium.copyWith(color: AppColors.textTertiaryDark)),
                            ]))
                          : ListView.separated(
                              itemCount: filtered.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 8),
                              itemBuilder: (_, i) => _customerTile(filtered[i], provider),
                            ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _customerTile(CustomerModel customer, CustomerProvider provider) {
    final lastPurchase = customer.lastPurchaseDate != null
        ? '${customer.lastPurchaseDate!.day} ${_monthName(customer.lastPurchaseDate!.month)}'
        : 'Never';

    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardBorderDark),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            color: AppColors.accent.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(child: Text(
            customer.name.isNotEmpty ? customer.name[0].toUpperCase() : '?',
            style: AppTypography.h3.copyWith(color: AppColors.accent),
          )),
        ),
        title: Text(customer.name,
            style: AppTypography.bodyLarge.copyWith(color: AppColors.textPrimaryDark, fontWeight: FontWeight.w600)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (customer.phone.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Row(children: [
                  const Icon(Icons.phone_rounded, size: 12, color: AppColors.textTertiaryDark),
                  const SizedBox(width: 4),
                  Text(customer.phone, style: AppTypography.labelSmall.copyWith(color: AppColors.textTertiaryDark)),
                ]),
              ),
            const SizedBox(height: 6),
            Row(children: [
              _statBadge(Icons.receipt_rounded, '${customer.totalOrders}', 'Orders'),
              const SizedBox(width: 10),
              _statBadge(Icons.currency_rupee_rounded, Formatters.currency(customer.totalSpent), 'Spent'),
              const SizedBox(width: 10),
              _statBadge(Icons.calendar_today_rounded, lastPurchase, 'Last'),
            ]),
          ],
        ),
        trailing: PopupMenuButton(
          icon: const Icon(Icons.more_vert_rounded, color: AppColors.textSecondaryDark),
          color: AppColors.surfaceDark,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          itemBuilder: (_) => [
            PopupMenuItem(
              onTap: () => Future.microtask(() => _showCustomerDialog(customer: customer)),
              child: const Row(children: [Icon(Icons.edit_rounded, size: 18), SizedBox(width: 8), Text('Edit')]),
            ),
            PopupMenuItem(
              onTap: () => provider.deleteCustomer(customer.id),
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

  Widget _statBadge(IconData icon, String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 10, color: AppColors.accent),
        const SizedBox(width: 4),
        Text(value, style: AppTypography.mono.copyWith(fontSize: 11, color: AppColors.textPrimaryDark)),
      ]),
    );
  }

  String _monthName(int month) {
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return months[month - 1];
  }
}
