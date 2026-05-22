import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../data/models/item_model.dart';
import '../../providers/inventory_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/category_provider.dart';
import '../../data/models/category_model.dart';

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
  bool _autoBarcode = false;
  double _gstRate = 0;

  // Category system
  String? _selectedCategory;
  bool _showSize = true;
  bool _showColor = true;

  bool get isEditing => widget.item != null;

  @override
  void initState() {
    super.initState();
    _vendorCtrl = TextEditingController(text: widget.item?.vendor ?? '');
    _nameCtrl = TextEditingController(text: widget.item?.name ?? '');
    _barcodeCtrl = TextEditingController(text: widget.item?.barcode ?? '');
    _autoBarcode = widget.item?.barcode.isEmpty ?? true;
    _categoryCtrl = TextEditingController(text: widget.item?.category ?? '');
    _sizeCtrl = TextEditingController(text: widget.item?.size ?? '');
    _colorCtrl = TextEditingController(text: widget.item?.color ?? '');
    _locationCtrl = TextEditingController(text: widget.item?.storageLocation ?? '');
    _priceCtrl = TextEditingController(text: widget.item?.price.toString() ?? '');
    _costPriceCtrl = TextEditingController(text: widget.item?.costPrice.toString() ?? '0');
    _qtyCtrl = TextEditingController(text: widget.item?.quantity.toString() ?? '0');
    _lowStockCtrl = TextEditingController(text: widget.item?.lowStockThreshold.toString() ?? '5');
    _selectedCategory = widget.item?.category;
    _gstRate = widget.item?.gstRate ?? 0;

    // Ensure categories are loaded, then set dynamic fields
    Future.microtask(() {
      final catProvider = context.read<CategoryProvider>();
      if (catProvider.categories.isEmpty) {
        catProvider.loadCategories().then((_) => _initCategoryFields());
      } else {
        _initCategoryFields();
      }
    });
  }

  void _initCategoryFields() {
    if (_selectedCategory != null && _selectedCategory!.isNotEmpty) {
      _updateCategoryFields(_selectedCategory!);
    }
  }

  void _updateCategoryFields(String categoryName) {
    final catProvider = context.read<CategoryProvider>();
    final match = catProvider.getCategoryByName(categoryName);
    if (match != null) {
      setState(() {
        _showSize = match.requiresSize;
        _showColor = match.requiresColor;
      });
    } else {
      // If category not found in DB, show both fields (fallback)
      setState(() { _showSize = true; _showColor = true; });
    }
  }

  void _generateBarcode() {
    final cat = _selectedCategory ?? _categoryCtrl.text.trim();
    final code = cat.isNotEmpty
        ? cat.substring(0, min(3, cat.length)).toUpperCase()
        : 'GEN';
    final num = (10000 + Random().nextInt(90000)).toString();
    setState(() => _barcodeCtrl.text = 'SKY-$code-$num');
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
    final category = _selectedCategory ?? _categoryCtrl.text.trim();
    bool success;

    if (isEditing) {
      final userRole = context.read<AuthProvider>().userType;
      success = await provider.updateItem(widget.item!.copyWith(
        name: _nameCtrl.text.trim(),
        vendor: _vendorCtrl.text.trim(),
        barcode: _barcodeCtrl.text.trim(),
        category: category,
        size: _showSize ? _sizeCtrl.text.trim() : '',
        color: _showColor ? _colorCtrl.text.trim() : '',
        storageLocation: _locationCtrl.text.trim(),
        price: double.parse(_priceCtrl.text.trim()),
        costPrice: double.tryParse(_costPriceCtrl.text.trim()) ?? 0,
        gstRate: _gstRate,
        quantity: int.tryParse(_qtyCtrl.text.trim()) ?? 0,
        lowStockThreshold: int.tryParse(_lowStockCtrl.text.trim()) ?? 5,
      ), userRole: userRole);
    } else {
      success = await provider.addItem(
        name: _nameCtrl.text.trim(),
        vendor: _vendorCtrl.text.trim(),
        barcode: _barcodeCtrl.text.trim(),
        category: category,
        size: _showSize ? _sizeCtrl.text.trim() : '',
        color: _showColor ? _colorCtrl.text.trim() : '',
        storageLocation: _locationCtrl.text.trim(),
        price: double.parse(_priceCtrl.text.trim()),
        costPrice: double.tryParse(_costPriceCtrl.text.trim()) ?? 0,
        gstRate: _gstRate,
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
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
                          // Dynamic category dropdown from CategoryProvider
                          Expanded(
                            child: Consumer<CategoryProvider>(
                              builder: (context, catProvider, _) {
                                final categories = catProvider.categories;
                                if (categories.isEmpty) {
                                  return _field('Category', _categoryCtrl, 'e.g. Shoes',
                                      icon: Icons.category_rounded);
                                }
                                return DropdownButtonFormField<String>(
                                  value: _selectedCategory != null &&
                                      categories.any((c) => c.name == _selectedCategory)
                                      ? _selectedCategory : null,
                                  items: categories.map((c) => DropdownMenuItem(
                                    value: c.name,
                                    child: Text(c.name, style: TextStyle(fontSize: 13)),
                                  )).toList(),
                                  onChanged: (v) {
                                    setState(() {
                                      _selectedCategory = v;
                                      _categoryCtrl.text = v ?? '';
                                    });
                                    if (v != null) _updateCategoryFields(v);
                                    // Regenerate barcode with new category prefix
                                    if (_autoBarcode) _generateBarcode();
                                  },
                                  style: TextStyle(color: AppColors.textPrimary(context), fontSize: 13),
                                  dropdownColor: AppColors.card(context),
                                  decoration: InputDecoration(
                                    labelText: 'Category',
                                    labelStyle: TextStyle(color: AppColors.textSecondary(context), fontSize: 12),
                                    prefixIcon: Icon(Icons.category_rounded, size: 18, color: AppColors.textTertiary(context)),
                                    filled: true,
                                    fillColor: AppColors.surface(context),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                                      borderSide: BorderSide(color: AppColors.cardBorder(context))),
                                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                                      borderSide: BorderSide(color: AppColors.cardBorder(context))),
                                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                                      borderSide: BorderSide(color: AppColors.primary, width: 1.5)),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                  ),
                                );
                              },
                            ),
                          ),
                        ]),
                        const SizedBox(height: 12),
                        // Dynamic Size/Color based on selected category
                        if (_showSize || _showColor)
                          Row(children: [
                            if (_showSize)
                              Expanded(child: _field('Size', _sizeCtrl, 'e.g. 42, XL, 10',
                                  icon: Icons.straighten_rounded)),
                            if (_showSize && _showColor) const SizedBox(width: 10),
                            if (_showColor)
                              Expanded(child: _field('Color', _colorCtrl, 'e.g. Black, Red',
                                  icon: Icons.palette_rounded)),
                          ]),
                        if (_showSize || _showColor) const SizedBox(height: 16),

                        // ─── Section: Identification ───
                        _sectionLabel('Identification & Location'),
                        const SizedBox(height: 8),
                        Row(children: [
                          Checkbox(
                            value: _autoBarcode,
                            activeColor: AppColors.accent,
                            onChanged: (v) {
                              setState(() => _autoBarcode = v ?? false);
                              if (v == true) _generateBarcode();
                            },
                          ),
                          Text('Auto Barcode', style: TextStyle(
                              color: AppColors.textSecondary(context), fontSize: 12)),
                          const SizedBox(width: 8),
                          Expanded(child: _field('Barcode / SKU', _barcodeCtrl,
                              _autoBarcode ? 'Will be auto-generated' : 'Enter existing barcode',
                              icon: Icons.qr_code_scanner_rounded,
                              enabled: !_autoBarcode)),
                          if (!_autoBarcode) ...[
                            const SizedBox(width: 8),
                            SizedBox(
                              height: 48,
                              child: ElevatedButton.icon(
                                onPressed: _generateBarcode,
                                icon: Icon(Icons.qr_code_rounded, size: 16),
                                label: Text('Generate', style: TextStyle(fontSize: 11)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.accent,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  padding: EdgeInsets.symmetric(horizontal: 12),
                                ),
                              ),
                            ),
                          ],
                        ]),
                        const SizedBox(height: 8),
                        _field('Storage Location', _locationCtrl, 'e.g. Rack A / Shelf 3',
                            icon: Icons.location_on_rounded),
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
                        const SizedBox(height: 12),
                        // GST Rate dropdown
                        DropdownButtonFormField<double>(
                          value: _gstRate,
                          items: const [
                            DropdownMenuItem(value: 0, child: Text('No GST (0%)', style: TextStyle(fontSize: 13))),
                            DropdownMenuItem(value: 5, child: Text('GST 5%', style: TextStyle(fontSize: 13))),
                            DropdownMenuItem(value: 12, child: Text('GST 12%', style: TextStyle(fontSize: 13))),
                            DropdownMenuItem(value: 18, child: Text('GST 18%', style: TextStyle(fontSize: 13))),
                            DropdownMenuItem(value: 28, child: Text('GST 28%', style: TextStyle(fontSize: 13))),
                          ],
                          onChanged: (v) => setState(() => _gstRate = v ?? 0),
                          style: TextStyle(color: AppColors.textPrimary(context), fontSize: 13),
                          dropdownColor: AppColors.card(context),
                          decoration: InputDecoration(
                            labelText: 'GST Rate',
                            labelStyle: TextStyle(color: AppColors.textSecondary(context), fontSize: 12),
                            prefixIcon: Icon(Icons.percent_rounded, size: 18, color: AppColors.textTertiary(context)),
                            filled: true,
                            fillColor: AppColors.surface(context),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(color: AppColors.cardBorder(context))),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(color: AppColors.cardBorder(context))),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(color: AppColors.primary, width: 1.5)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          ),
                        ),
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
    bool enabled = true,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      enabled: enabled,
      style: TextStyle(color: enabled ? AppColors.textPrimary(context) : AppColors.textTertiary(context), fontSize: 13),
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: TextStyle(color: AppColors.textSecondary(context), fontSize: 12),
        hintStyle: TextStyle(color: AppColors.textTertiary(context), fontSize: 12),
        prefixIcon: icon != null ? Icon(icon, size: 18, color: AppColors.textTertiary(context)) : null,
        filled: true,
        fillColor: enabled ? AppColors.surface(context) : AppColors.surface(context).withValues(alpha: 0.5),
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
