import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../data/models/item_model.dart';
import '../../providers/inventory_provider.dart';

class ItemFormDialog extends StatefulWidget {
  final ItemModel? item;
  const ItemFormDialog({super.key, this.item});

  @override
  State<ItemFormDialog> createState() => _ItemFormDialogState();
}

class _ItemFormDialogState extends State<ItemFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _vendorCtrl;
  late TextEditingController _nameCtrl;
  late TextEditingController _barcodeCtrl;
  late TextEditingController _categoryCtrl;
  late TextEditingController _sizeCtrl;
  late TextEditingController _colorCtrl;
  late TextEditingController _locationCtrl;
  late TextEditingController _priceCtrl;
  late TextEditingController _costPriceCtrl;
  late TextEditingController _qtyCtrl;
  late TextEditingController _lowStockCtrl;
  bool _isLoading = false;

  bool get isEditing => widget.item != null;

  @override
  void initState() {
    super.initState();
    _vendorCtrl = TextEditingController(text: widget.item?.vendor ?? '');
    _nameCtrl = TextEditingController(text: widget.item?.name ?? '');
    _barcodeCtrl = TextEditingController(text: widget.item?.barcode ?? '');
    _categoryCtrl = TextEditingController(text: widget.item?.category ?? '');
    _sizeCtrl = TextEditingController(text: widget.item?.size ?? '');
    _colorCtrl = TextEditingController(text: widget.item?.color ?? '');
    _locationCtrl = TextEditingController(text: widget.item?.storageLocation ?? '');
    _priceCtrl = TextEditingController(text: widget.item?.price.toString() ?? '');
    _costPriceCtrl = TextEditingController(text: widget.item?.costPrice.toString() ?? '0');
    _qtyCtrl = TextEditingController(text: widget.item?.quantity.toString() ?? '0');
    _lowStockCtrl = TextEditingController(text: widget.item?.lowStockThreshold.toString() ?? '5');
  }

  @override
  void dispose() {
    _vendorCtrl.dispose();
    _nameCtrl.dispose();
    _barcodeCtrl.dispose();
    _categoryCtrl.dispose();
    _sizeCtrl.dispose();
    _colorCtrl.dispose();
    _locationCtrl.dispose();
    _priceCtrl.dispose();
    _costPriceCtrl.dispose();
    _qtyCtrl.dispose();
    _lowStockCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final provider = context.read<InventoryProvider>();
    bool success;

    if (isEditing) {
      success = await provider.updateItem(widget.item!.copyWith(
        name: _nameCtrl.text.trim(),
        vendor: _vendorCtrl.text.trim(),
        barcode: _barcodeCtrl.text.trim(),
        category: _categoryCtrl.text.trim(),
        size: _sizeCtrl.text.trim(),
        color: _colorCtrl.text.trim(),
        storageLocation: _locationCtrl.text.trim(),
        price: double.parse(_priceCtrl.text.trim()),
        costPrice: double.tryParse(_costPriceCtrl.text.trim()) ?? 0,
        quantity: int.tryParse(_qtyCtrl.text.trim()) ?? 0,
        lowStockThreshold: int.tryParse(_lowStockCtrl.text.trim()) ?? 5,
      ));
    } else {
      success = await provider.addItem(
        name: _nameCtrl.text.trim(),
        vendor: _vendorCtrl.text.trim(),
        barcode: _barcodeCtrl.text.trim(),
        category: _categoryCtrl.text.trim(),
        size: _sizeCtrl.text.trim(),
        color: _colorCtrl.text.trim(),
        storageLocation: _locationCtrl.text.trim(),
        price: double.parse(_priceCtrl.text.trim()),
        costPrice: double.tryParse(_costPriceCtrl.text.trim()) ?? 0,
        quantity: int.tryParse(_qtyCtrl.text.trim()) ?? 0,
        lowStockThreshold: int.tryParse(_lowStockCtrl.text.trim()) ?? 5,
      );
    }

    setState(() => _isLoading = false);

    if (success && mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isEditing ? 'Item updated' : 'Item added'),
          backgroundColor: AppColors.card(context),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.card(context),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 620),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
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
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    SizedBox(width: 12),
                    Text(
                      isEditing ? 'Edit Item' : 'Add New Item',
                      style: AppTypography.h3.copyWith(color: AppColors.textPrimary(context)),
                    ),
                    Spacer(),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(Icons.close_rounded, color: AppColors.textTertiary(context)),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Scrollable form content
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // ─── Section: Basic Info ───
                        _sectionLabel('Basic Info'),
                        const SizedBox(height: 8),
                        _field('Item Name *', _nameCtrl, 'e.g. Nike Air Max 90',
                            icon: Icons.inventory_2_rounded,
                            validator: (v) => v!.trim().isEmpty ? 'Required' : null),
                        const SizedBox(height: 12),
                        Row(children: [
                          Expanded(child: _field('Brand / Vendor', _vendorCtrl, 'e.g. Nike, Adidas',
                              icon: Icons.store_rounded)),
                          const SizedBox(width: 10),
                          Expanded(child: _field('Category', _categoryCtrl, 'e.g. Shoes, Slippers',
                              icon: Icons.category_rounded)),
                        ]),
                        const SizedBox(height: 12),
                        Row(children: [
                          Expanded(child: _field('Size', _sizeCtrl, 'e.g. 42, XL, 10',
                              icon: Icons.straighten_rounded)),
                          const SizedBox(width: 10),
                          Expanded(child: _field('Color', _colorCtrl, 'e.g. Black, Red',
                              icon: Icons.palette_rounded)),
                        ]),
                        const SizedBox(height: 16),

                        // ─── Section: Identification ───
                        _sectionLabel('Identification & Location'),
                        const SizedBox(height: 8),
                        Row(children: [
                          Expanded(child: _field('Barcode / SKU', _barcodeCtrl, 'Scan or type barcode',
                              icon: Icons.qr_code_scanner_rounded)),
                          const SizedBox(width: 10),
                          Expanded(child: _field('Storage Location', _locationCtrl, 'e.g. Rack A / Shelf 3',
                              icon: Icons.location_on_rounded)),
                        ]),
                        const SizedBox(height: 16),

                        // ─── Section: Pricing ───
                        _sectionLabel('Pricing'),
                        const SizedBox(height: 8),
                        Row(children: [
                          Expanded(
                            child: _field('Selling Price (₹) *', _priceCtrl, '0.00',
                                icon: Icons.sell_rounded,
                                keyboardType: TextInputType.number,
                                validator: (v) {
                                  if (v!.trim().isEmpty) return 'Required';
                                  if (double.tryParse(v) == null) return 'Invalid';
                                  return null;
                                }),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _field('Cost Price (₹)', _costPriceCtrl, '0.00',
                                icon: Icons.payments_rounded,
                                keyboardType: TextInputType.number),
                          ),
                        ]),
                        const SizedBox(height: 16),

                        // ─── Section: Stock ───
                        _sectionLabel('Stock'),
                        const SizedBox(height: 8),
                        Row(children: [
                          Expanded(
                            child: _field('Quantity', _qtyCtrl, '0',
                                icon: Icons.inventory_rounded,
                                keyboardType: TextInputType.number),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _field('Low Stock Alert', _lowStockCtrl, '5',
                                icon: Icons.warning_amber_rounded,
                                keyboardType: TextInputType.number),
                          ),
                        ]),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Save Button
                SizedBox(
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _save,
                    icon: _isLoading
                        ? const SizedBox(
                            width: 18, height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Icon(isEditing ? Icons.save_rounded : Icons.add_rounded, size: 18),
                    label: Text(
                      isEditing ? 'Update Item' : 'Add Item',
                      style: AppTypography.button.copyWith(color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Row(children: [
      Container(width: 3, height: 14,
          decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(2))),
      SizedBox(width: 8),
      Text(text, style: AppTypography.labelMedium.copyWith(
          color: AppColors.accent, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
    ]);
  }

  Widget _field(String label, TextEditingController controller, String hint, {
    IconData? icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      style: TextStyle(color: AppColors.textPrimary(context), fontSize: 13),
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: TextStyle(color: AppColors.textSecondary(context), fontSize: 12),
        hintStyle: TextStyle(color: AppColors.textTertiary(context), fontSize: 12),
        prefixIcon: icon != null ? Icon(icon, size: 18, color: AppColors.textTertiary(context)) : null,
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
}
