import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/whatsapp_helper.dart';
import '../../providers/customer_provider.dart';
import '../../providers/sales_provider.dart';
import '../../providers/loyalty_settings_provider.dart';
import '../../data/models/customer_model.dart';

class CustomerScreen extends StatefulWidget {
  const CustomerScreen({super.key});

  @override
  State<CustomerScreen> createState() => _CustomerScreenState();
}

class _CustomerScreenState extends State<CustomerScreen> {
  final _searchCtrl = TextEditingController();
  String _search = '';
  final Set<String> _selectedIds = {};
  bool _isSelectMode = false;

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
        backgroundColor: AppColors.card(context),
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
                        padding: EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          gradient: AppColors.primaryGradient,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(isEditing ? Icons.edit_rounded : Icons.person_add_rounded,
                            color: Colors.white, size: 20),
                      ),
                      SizedBox(width: 12),
                      Text(isEditing ? 'Edit Customer' : 'Add Customer',
                          style: AppTypography.h3.copyWith(color: AppColors.textPrimary(context))),
                      Spacer(),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: Icon(Icons.close_rounded, color: AppColors.textTertiary(context)),
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
      style: TextStyle(color: AppColors.textPrimary(context)),
      decoration: InputDecoration(
        labelText: label, hintText: hint,
        labelStyle: TextStyle(color: AppColors.textSecondary(context), fontSize: 13),
        hintStyle: TextStyle(color: AppColors.textTertiary(context)),
        filled: true, fillColor: AppColors.surface(context),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: AppColors.cardBorder(context))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: AppColors.cardBorder(context))),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final salesProvider = context.watch<SalesProvider>();
    final customerSummaries = salesProvider.getCustomerSummaries();

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
            padding: EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('Customers', style: AppTypography.h1.copyWith(color: AppColors.textPrimary(context))),
                    const Spacer(),
                    // Select mode toggle
                    if (!_isSelectMode)
                      IconButton(
                        onPressed: () => setState(() => _isSelectMode = true),
                        tooltip: 'Select for offer',
                        icon: Icon(Icons.checklist_rounded, color: AppColors.textSecondary(context)),
                      ),
                    if (_isSelectMode) ...[
                      TextButton(
                        onPressed: () {
                          final allIds = filtered.where((c) => c.phone.isNotEmpty).map((c) => c.id).toSet();
                          setState(() {
                            if (_selectedIds.length == allIds.length) {
                              _selectedIds.clear();
                            } else {
                              _selectedIds.addAll(allIds);
                            }
                          });
                        },
                        child: Text(
                          _selectedIds.length == filtered.where((c) => c.phone.isNotEmpty).length ? 'Deselect All' : 'Select All',
                          style: TextStyle(color: AppColors.accent, fontSize: 12),
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: _selectedIds.isEmpty ? null : () => _showOfferDialog(provider),
                        icon: Icon(Icons.campaign_rounded, size: 16),
                        label: Text('Send Offer (${_selectedIds.length})'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFF25D366),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: () => setState(() { _isSelectMode = false; _selectedIds.clear(); }),
                        icon: Icon(Icons.close_rounded, color: AppColors.textTertiary(context)),
                      ),
                    ],
                    if (!_isSelectMode) ...[
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
                        icon: Icon(Icons.person_add_rounded, size: 18),
                        label: const Text('Add Customer'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary, foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ],
                  ],
                ),
                SizedBox(height: 16),
                TextField(
                  controller: _searchCtrl,
                  onChanged: (v) => setState(() => _search = v),
                  style: TextStyle(color: AppColors.textPrimary(context)),
                  decoration: InputDecoration(
                    hintText: 'Search customers...',
                    hintStyle: TextStyle(color: AppColors.textTertiary(context)),
                    prefixIcon: Icon(Icons.search_rounded, color: AppColors.textTertiary(context)),
                    filled: true, fillColor: AppColors.card(context),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AppColors.cardBorder(context))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AppColors.cardBorder(context))),
                  ),
                ),
                SizedBox(height: 16),
                Expanded(
                  child: provider.isLoading
                      ? Center(child: CircularProgressIndicator(color: AppColors.accent))
                      : filtered.isEmpty
                          ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                              Icon(Icons.people_rounded, size: 64, color: AppColors.textTertiary(context).withValues(alpha: 0.3)),
                              SizedBox(height: 12),
                              Text('No customers yet', style: AppTypography.bodyMedium.copyWith(color: AppColors.textTertiary(context))),
                            ]))
                          : ListView.separated(
                              itemCount: filtered.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 8),
                              itemBuilder: (_, i) => _customerTile(filtered[i], provider, customerSummaries),
                            ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _customerTile(CustomerModel customer, CustomerProvider provider, Map<String, Map<String, dynamic>> summaries) {
    // Match by phone first, then by name
    final key = customer.phone.isNotEmpty
        ? customer.phone
        : customer.name.toLowerCase().trim();
    final s = summaries[key];
    final totalOrders = (s?['totalOrders'] as int?) ?? customer.totalOrders;
    final totalSpent = (s?['totalSpent'] as double?) ?? customer.totalSpent;
    final lastDate = (s?['lastPurchaseDate'] as DateTime?) ?? customer.lastPurchaseDate;
    final lastPurchase = lastDate != null
        ? '${lastDate.day} ${_monthName(lastDate.month)}'
        : 'Never';

    return Container(
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardBorder(context)),
      ),
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        onTap: () => _showCustomerDetail(customer, totalOrders, totalSpent, lastPurchase),
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
            style: AppTypography.bodyLarge.copyWith(color: AppColors.textPrimary(context), fontWeight: FontWeight.w600)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (customer.phone.isNotEmpty)
              Padding(
                padding: EdgeInsets.only(top: 2),
                child: Row(children: [
                  Icon(Icons.phone_rounded, size: 12, color: AppColors.textTertiary(context)),
                  SizedBox(width: 4),
                  Text(customer.phone, style: AppTypography.labelSmall.copyWith(color: AppColors.textTertiary(context))),
                ]),
              ),
            SizedBox(height: 6),
            Row(children: [
              _statBadge(Icons.receipt_rounded, '$totalOrders', 'Orders'),
              const SizedBox(width: 10),
              _statBadge(Icons.currency_rupee_rounded, Formatters.currency(totalSpent), 'Spent'),
              const SizedBox(width: 10),
              _statBadge(Icons.star_rounded, '${customer.loyaltyPoints}', 'Points'),
              const SizedBox(width: 10),
              _statBadge(Icons.calendar_today_rounded, lastPurchase, 'Last'),
            ]),
          ],
        ),
        trailing: _isSelectMode
            ? (customer.phone.isEmpty
                ? Tooltip(
                    message: 'No phone number',
                    child: Icon(Icons.phone_disabled_rounded, size: 18, color: AppColors.textTertiary(context).withValues(alpha: 0.3)),
                  )
                : Checkbox(
                    value: _selectedIds.contains(customer.id),
                    onChanged: (_) => setState(() {
                      if (_selectedIds.contains(customer.id)) {
                        _selectedIds.remove(customer.id);
                      } else {
                        _selectedIds.add(customer.id);
                      }
                    }),
                    activeColor: Color(0xFF25D366),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                  ))
            : PopupMenuButton(
                icon: Icon(Icons.more_vert_rounded, color: AppColors.textSecondary(context)),
                color: AppColors.surface(context),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                itemBuilder: (_) => [
                  PopupMenuItem(
                    onTap: () => Future.microtask(() => _showCustomerDialog(customer: customer)),
                    child: const Row(children: [Icon(Icons.edit_rounded, size: 18), SizedBox(width: 8), Text('Edit')]),
                  ),
                  if (customer.phone.isNotEmpty)
                    PopupMenuItem(
                      onTap: () => WhatsAppHelper.send(
                        phone: customer.phone,
                        message: 'Hi ${customer.name}!\nThank you for shopping at SKYWALK.\nVisit us again for exciting offers!',
                      ),
                      child: Row(children: [
                        Icon(Icons.chat_rounded, size: 18, color: Color(0xFF25D366)),
                        const SizedBox(width: 8),
                        Text('WhatsApp', style: TextStyle(color: Color(0xFF25D366))),
                      ]),
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

  void _showCustomerDetail(CustomerModel customer, int totalOrders, double totalSpent, String lastPurchase) {
    final sales = context.read<SalesProvider>().sales.where((s) =>
        s.customerPhone == customer.phone ||
        s.customerName.toLowerCase() == customer.name.toLowerCase()).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: AppColors.card(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480, maxHeight: 580),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              // Header
              Row(children: [
                Container(
                  width: 48, height: 48,
                  decoration: BoxDecoration(gradient: AppColors.primaryGradient, borderRadius: BorderRadius.circular(14)),
                  child: Center(child: Text(
                    customer.name.isNotEmpty ? customer.name[0].toUpperCase() : '?',
                    style: AppTypography.h2.copyWith(color: Colors.white),
                  )),
                ),
                const SizedBox(width: 14),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(customer.name, style: AppTypography.h3.copyWith(color: AppColors.textPrimary(context))),
                  if (customer.phone.isNotEmpty)
                    Row(children: [
                      Icon(Icons.phone_rounded, size: 13, color: AppColors.textTertiary(context)),
                      const SizedBox(width: 4),
                      Text(customer.phone, style: AppTypography.labelSmall.copyWith(color: AppColors.textTertiary(context))),
                    ]),
                ])),
                IconButton(onPressed: () => Navigator.pop(ctx),
                    icon: Icon(Icons.close_rounded, color: AppColors.textTertiary(context))),
              ]),
              const SizedBox(height: 16),

              // Stats row
              Builder(builder: (_) {
                final loyalty = context.read<LoyaltySettingsProvider>();
                final pointsLabel = loyalty.isEnabled && customer.loyaltyPoints > 0
                    ? '${customer.loyaltyPoints} (${Formatters.currency(loyalty.valueOfPoints(customer.loyaltyPoints))})'
                    : '${customer.loyaltyPoints}';
                return Row(children: [
                  _detailStat(context, '$totalOrders', 'Orders', Icons.receipt_rounded, AppColors.accent),
                  const SizedBox(width: 8),
                  _detailStat(context, Formatters.currency(totalSpent), 'Total Spent', Icons.currency_rupee_rounded, AppColors.success),
                  const SizedBox(width: 8),
                  _detailStat(context, pointsLabel, 'Points', Icons.star_rounded,
                      customer.loyaltyPoints > 0 ? AppColors.warning : AppColors.primary),
                  const SizedBox(width: 8),
                  _detailStat(context, lastPurchase, 'Last Visit', Icons.calendar_today_rounded, AppColors.primary),
                ]);
              }),
              const SizedBox(height: 16),

              // Purchase history
              Align(alignment: Alignment.centerLeft,
                child: Text('Purchase History', style: AppTypography.labelMedium.copyWith(
                    color: AppColors.accent, fontWeight: FontWeight.w600))),
              const SizedBox(height: 8),
              Expanded(
                child: sales.isEmpty
                  ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.receipt_long_rounded, size: 40, color: AppColors.textTertiary(context).withValues(alpha: 0.3)),
                      const SizedBox(height: 8),
                      Text('No purchases recorded', style: AppTypography.bodyMedium.copyWith(color: AppColors.textTertiary(context))),
                    ]))
                  : ListView.separated(
                      itemCount: sales.length,
                      separatorBuilder: (_, __) => Divider(color: AppColors.cardBorder(context), height: 1),
                      itemBuilder: (_, i) {
                        final sale = sales[i];
                        final date = '${sale.createdAt.day}/${sale.createdAt.month}/${sale.createdAt.year}';
                        final time = '${sale.createdAt.hour.toString().padLeft(2,'0')}:${sale.createdAt.minute.toString().padLeft(2,'0')}';
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(color: AppColors.accent.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
                              child: Icon(Icons.receipt_rounded, size: 18, color: AppColors.accent),
                            ),
                            const SizedBox(width: 12),
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(sale.invoiceNumber, style: TextStyle(
                                  color: AppColors.textPrimary(context), fontWeight: FontWeight.w600, fontSize: 13,
                                  fontFamily: 'Courier')),
                              Text('${sale.items.length} item${sale.items.length != 1 ? 's' : ''} • $date $time',
                                  style: AppTypography.labelSmall.copyWith(color: AppColors.textTertiary(context))),
                              if (sale.items.isNotEmpty)
                                Text(sale.items.map((it) => it.name).take(3).join(', ') + (sale.items.length > 3 ? '…' : ''),
                                    style: AppTypography.labelSmall.copyWith(color: AppColors.textSecondary(context)),
                                    overflow: TextOverflow.ellipsis),
                            ])),
                            Text(Formatters.currency(sale.total), style: AppTypography.mono.copyWith(
                                color: AppColors.success, fontWeight: FontWeight.w700, fontSize: 14)),
                          ]),
                        );
                      }),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _detailStat(BuildContext context, String value, String label, IconData icon, Color color) {
    return Expanded(child: Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2))),
      child: Column(children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12), textAlign: TextAlign.center),
        Text(label, style: TextStyle(color: AppColors.textTertiary(context), fontSize: 9)),
      ]),
    ));
  }

  // ─── Offer Broadcast Dialog ───

  void _showOfferDialog(CustomerProvider provider) {
    final msgCtrl = TextEditingController();
    int selectedTemplate = -1;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => Dialog(
          backgroundColor: AppColors.card(context),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480, maxHeight: 560),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Color(0xFF25D366).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(Icons.campaign_rounded, color: Color(0xFF25D366), size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Send Offer', style: AppTypography.h3.copyWith(color: AppColors.textPrimary(context))),
                            Text('To ${_selectedIds.length} customers via WhatsApp',
                                style: AppTypography.labelSmall.copyWith(color: AppColors.textTertiary(context), fontSize: 10)),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: Icon(Icons.close_rounded, color: AppColors.textTertiary(context)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Quick Templates
                  Text('Quick Templates', style: AppTypography.labelSmall.copyWith(
                      color: AppColors.textTertiary(context), fontSize: 10, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 36,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: WhatsAppHelper.offerTemplates.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 6),
                      itemBuilder: (_, i) {
                        final t = WhatsAppHelper.offerTemplates[i];
                        final isActive = selectedTemplate == i;
                        return ActionChip(
                          label: Text(t['title']!, style: TextStyle(fontSize: 11,
                              color: isActive ? Colors.white : AppColors.textPrimary(context))),
                          backgroundColor: isActive ? Color(0xFF25D366) : AppColors.surface(context),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: BorderSide(color: isActive ? Color(0xFF25D366) : AppColors.cardBorder(context)),
                          ),
                          onPressed: () {
                            setDlgState(() {
                              selectedTemplate = i;
                              msgCtrl.text = t['message']!;
                            });
                          },
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Custom message
                  Flexible(
                    child: TextField(
                      controller: msgCtrl,
                      maxLines: 6,
                      style: TextStyle(color: AppColors.textPrimary(context), fontSize: 13),
                      decoration: InputDecoration(
                        labelText: 'Message',
                        hintText: 'Type your offer message...',
                        labelStyle: TextStyle(color: AppColors.textSecondary(context), fontSize: 12),
                        hintStyle: TextStyle(color: AppColors.textTertiary(context), fontSize: 12),
                        filled: true,
                        fillColor: AppColors.surface(context),
                        alignLabelWithHint: true,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: AppColors.cardBorder(context))),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: AppColors.cardBorder(context))),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Info
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline_rounded, size: 14, color: AppColors.accent),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'WhatsApp will open for each customer. Tap Send in WhatsApp to deliver.',
                            style: AppTypography.labelSmall.copyWith(color: AppColors.textSecondary(context), fontSize: 10),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Send
                  ElevatedButton.icon(
                    onPressed: msgCtrl.text.trim().isEmpty ? null : () {
                      Navigator.pop(ctx);
                      _sendOfferToSelected(provider, msgCtrl.text.trim());
                    },
                    icon: Icon(Icons.send_rounded, size: 18),
                    label: Text('Send via WhatsApp (${_selectedIds.length})'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF25D366),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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

  void _sendOfferToSelected(CustomerProvider provider, String message) async {
    final selected = provider.customers.where((c) => _selectedIds.contains(c.id) && c.phone.isNotEmpty).toList();
    if (selected.isEmpty) return;

    // Open WhatsApp for each customer sequentially
    for (int i = 0; i < selected.length; i++) {
      final c = selected[i];
      final personalMsg = message.replaceAll('{name}', c.name);
      await WhatsAppHelper.send(phone: c.phone, message: personalMsg);
      // Small delay between opens so user can send each one
      if (i < selected.length - 1) {
        await Future.delayed(const Duration(milliseconds: 500));
      }
    }

    setState(() {
      _isSelectMode = false;
      _selectedIds.clear();
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Opened WhatsApp for ${selected.length} customers'),
        backgroundColor: Color(0xFF25D366),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));
    }
  }

  Widget _statBadge(IconData icon, String value, String label) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 10, color: AppColors.accent),
        SizedBox(width: 4),
        Text(value, style: AppTypography.mono.copyWith(fontSize: 11, color: AppColors.textPrimary(context))),
      ]),
    );
  }

  String _monthName(int month) {
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return months[month - 1];
  }
}
