import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../data/local/db_helper.dart';
import '../data/remote/supabase_service.dart';
import '../data/models/sale_model.dart';
import '../data/models/item_model.dart';
import '../core/utils/date_filter.dart';

class SalesProvider extends ChangeNotifier {
  final DBHelper _db = DBHelper.instance;
  final SupabaseService _supabase = SupabaseService.instance;
  final _uuid = const Uuid();

  // ─── Bill History ───
  List<SaleModel> _allSales = [];
  List<SaleModel> _filteredSales = [];
  bool _isLoading = false;
  String _error = '';

  // Date filter state
  DateFilterType _filterType = DateFilterType.today;
  DateTime? _customStart;
  DateTime? _customEnd;

  // Payment mode filter
  String _paymentFilter = 'All';

  // ─── Cart (active bill) ───
  List<SaleItem> _cart = [];
  String _customerName = '';
  String _customerPhone = '';
  String _paymentMode = 'Cash';
  double _discountPercent = 0;
  bool _gstEnabled = false;

  /// Load GST setting from DB
  Future<void> loadGstSetting() async {
    _gstEnabled = (await _db.getSetting('gst_enabled') ?? 'false') == 'true';
    notifyListeners();
  }

  // Getters — History
  List<SaleModel> get sales => _filteredSales;
  List<SaleModel> get allSales => _allSales;
  bool get isLoading => _isLoading;
  String get error => _error;
  DateFilterType get filterType => _filterType;
  DateTime? get customStart => _customStart;
  DateTime? get customEnd => _customEnd;
  String get paymentFilter => _paymentFilter;

  // Summary getters (based on filtered data)
  double get filteredTotal => _filteredSales.fold(0, (sum, s) => sum + s.total);
  int get filteredCount => _filteredSales.length;
  int get filteredItemCount => _filteredSales.fold(0, (sum, s) => sum + s.totalItems);

  /// Grouped sales by date (for UI rendering)
  Map<String, List<SaleModel>> get groupedSales {
    final Map<String, List<SaleModel>> groups = {};
    for (final sale in _filteredSales) {
      final dateKey = DateFilterHelper.groupLabel(sale.createdAt);
      groups.putIfAbsent(dateKey, () => []);
      groups[dateKey]!.add(sale);
    }
    return groups;
  }

  /// Single-pass customer summary from ALL sales — keyed by phone, fallback name
  Map<String, Map<String, dynamic>> getCustomerSummaries() {
    final Map<String, Map<String, dynamic>> summaries = {};
    for (final sale in _allSales) {
      if (sale.customerName.isEmpty || sale.customerName == 'Walk-in Customer') continue;
      // Use phone as key if available, else lowercase name
      final key = sale.customerPhone.isNotEmpty
          ? sale.customerPhone
          : sale.customerName.toLowerCase().trim();
      summaries.putIfAbsent(key, () => {
        'totalOrders': 0,
        'totalSpent': 0.0,
        'lastPurchaseDate': sale.createdAt,
      });
      final s = summaries[key]!;
      s['totalOrders'] = (s['totalOrders'] as int) + 1;
      s['totalSpent'] = (s['totalSpent'] as double) + sale.total;
      if (sale.createdAt.isAfter(s['lastPurchaseDate'] as DateTime)) {
        s['lastPurchaseDate'] = sale.createdAt;
      }
    }
    return summaries;
  }


  // Getters — Cart
  List<SaleItem> get cart => _cart;
  String get customerName => _customerName;
  String get customerPhone => _customerPhone;
  String get paymentMode => _paymentMode;
  double get discountPercent => _discountPercent;
  double get discountAmount => subtotal * (_discountPercent / 100);

  double get subtotal => _cart.fold(0, (sum, item) => sum + item.total);
  double get total => (subtotal - discountAmount).clamp(0, double.infinity);

  // ─── GST Getters ───
  bool get gstEnabled => _gstEnabled;
  /// Total GST across all cart items (only when enabled)
  double get gstAmount => _gstEnabled
      ? _cart.fold(0.0, (sum, item) => sum + item.gstAmount)
      : 0;
  double get cgst => gstAmount / 2;
  double get sgst => gstAmount / 2;
  /// Grand total = subtotal - discount + GST
  double get grandTotal => total + gstAmount;

  int get cartItemCount => _cart.fold(0, (sum, item) => sum + item.quantity);
  bool get isCartEmpty => _cart.isEmpty;

  // ─── Cart Operations ───

  void addToCart(ItemModel item, {int qty = 1}) {
    final existingIndex = _cart.indexWhere((c) => c.itemId == item.id);

    if (existingIndex != -1) {
      final existing = _cart[existingIndex];
      _cart[existingIndex] = SaleItem(
        itemId: existing.itemId,
        name: existing.name,
        price: existing.price,
        quantity: existing.quantity + qty,
        total: existing.price * (existing.quantity + qty),
        gstRate: existing.gstRate,
      );
    } else {
      _cart.add(SaleItem(
        itemId: item.id,
        name: item.name,
        price: item.price,
        quantity: qty,
        total: item.price * qty,
        gstRate: item.gstRate,
      ));
    }

    notifyListeners();
  }

  void updateCartItemQty(int index, int qty) {
    if (index < 0 || index >= _cart.length) return;
    if (qty <= 0) {
      _cart.removeAt(index);
    } else {
      final item = _cart[index];
      _cart[index] = SaleItem(
        itemId: item.itemId,
        name: item.name,
        price: item.price,
        quantity: qty,
        total: item.price * qty,
        gstRate: item.gstRate,
      );
    }
    notifyListeners();
  }

  void removeFromCart(int index) {
    if (index >= 0 && index < _cart.length) {
      _cart.removeAt(index);
      notifyListeners();
    }
  }

  void setCustomerInfo(String name, String phone) {
    _customerName = name;
    _customerPhone = phone;
    notifyListeners();
  }

  void setPaymentMode(String mode) {
    _paymentMode = mode;
    notifyListeners();
  }

  void setDiscount(double percent) {
    _discountPercent = percent.clamp(0, 100);
    notifyListeners();
  }

  void clearCart() {
    _cart = [];
    _customerName = '';
    _customerPhone = '';
    _paymentMode = 'Cash';
    _discountPercent = 0;
    notifyListeners();
  }

  // ─── Date/Payment Filter ───

  void setFilter(DateFilterType type, {DateTime? customStart, DateTime? customEnd}) {
    _filterType = type;
    if (type == DateFilterType.custom) {
      _customStart = customStart;
      _customEnd = customEnd;
    }
    _applyFilter();
    notifyListeners();
  }

  void setPaymentFilter(String mode) {
    _paymentFilter = mode;
    _applyFilter();
    notifyListeners();
  }

  void _applyFilter() {
    final range = DateFilterHelper.getRange(
      _filterType,
      customStart: _customStart,
      customEnd: _customEnd,
    );

    _filteredSales = _allSales.where((s) {
      // Convert to local time for comparison (Supabase stores UTC)
      final localTime = s.createdAt.toLocal();
      
      // Date filter
      final inRange = !localTime.isBefore(range.start) && localTime.isBefore(range.end);
      if (!inRange) return false;

      // Payment mode filter
      if (_paymentFilter != 'All' &&
          s.paymentMode.toLowerCase() != _paymentFilter.toLowerCase()) {
        return false;
      }

      return true;
    }).toList();
  }

  // ─── Save Sale ───

  Future<SaleModel?> completeSale({
    String staffId = '',
    String staffName = '',
    double loyaltyDiscount = 0,
    int pointsRedeemed = 0,
    int pointsEarned = 0,
  }) async {
    if (_cart.isEmpty) return null;

    try {
      final invoiceNumber = await _db.nextInvoiceNumber();

      // Apply loyalty discount to the final total
      final finalTotal = (total - loyaltyDiscount).clamp(0.0, double.infinity);

      // Calculate GST on the final total after discount
      final saleGstAmount = _gstEnabled ? gstAmount : 0.0;
      final saleCgst = saleGstAmount / 2;
      final saleSgst = saleGstAmount / 2;
      final saleGrandTotal = finalTotal + saleGstAmount;

      final sale = SaleModel(
        id: _uuid.v4(),
        invoiceNumber: invoiceNumber,
        customerName: _customerName,
        customerPhone: _customerPhone,
        items: List.from(_cart),
        subtotal: subtotal,
        discount: discountAmount,
        total: saleGrandTotal,
        gstAmount: saleGstAmount,
        cgst: saleCgst,
        sgst: saleSgst,
        paymentMode: _paymentMode,
        staffId: staffId,
        staffName: staffName,
        loyaltyDiscount: loyaltyDiscount,
        pointsRedeemed: pointsRedeemed,
        pointsEarned: pointsEarned,
      );

      // Save locally first
      await _db.insert('sales', sale.toMap());

      // Add to full list + re-filter
      _allSales.insert(0, sale);
      _applyFilter();

      // Clear cart
      clearCart();

      notifyListeners();

      // Sync to cloud
      if (kIsWeb) {
        await _supabase.syncRecord('sales', sale.id, 'insert', sale.toMap());
      } else {
        _supabase.syncRecord('sales', sale.id, 'insert', sale.toMap());
      }

      return sale;
    } catch (e) {
      _error = 'Failed to save sale: $e';
      notifyListeners();
      return null;
    }
  }

  // ─── Load Sales History ───

  Future<void> loadSales() async {
    _isLoading = true;
    _error = '';
    notifyListeners();

    try {
      final maps = await _db.getAll('sales', orderBy: 'created_at DESC');
      debugPrint('📋 SalesProvider: got ${maps.length} raw records from DB');
      
      // Parse each record individually — one bad record shouldn't kill the list
      final parsed = <SaleModel>[];
      for (int i = 0; i < maps.length; i++) {
        try {
          parsed.add(SaleModel.fromMap(maps[i]));
        } catch (e) {
          debugPrint('⚠️ SalesProvider: failed to parse sale[$i]: $e');
          debugPrint('   Raw data: ${maps[i]}');
        }
      }
      _allSales = parsed;
      _applyFilter();
      debugPrint('📋 SalesProvider: loaded ${_allSales.length} sales, filtered to ${_filteredSales.length}');
    } catch (e) {
      _error = 'Failed to load sales: $e';
      debugPrint('❌ SalesProvider: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<List<SaleModel>> salesForDate(String dateStr) async {
    final maps = await _db.query(
      'sales',
      where: "is_deleted = 0 AND created_at LIKE ?",
      whereArgs: ['$dateStr%'],
      orderBy: 'created_at DESC',
    );
    return maps.map((m) => SaleModel.fromMap(m)).toList();
  }

  Future<double> totalSalesForDate(String dateStr) async {
    return await _db.sum(
      'sales',
      'total',
      where: "is_deleted = 0 AND created_at LIKE ?",
      whereArgs: ['$dateStr%'],
    );
  }

  Future<bool> deleteSale(String id) async {
    try {
      await _db.softDelete('sales', id);
      final sale = _allSales.firstWhere((s) => s.id == id);

      _allSales.removeWhere((s) => s.id == id);
      _applyFilter();
      notifyListeners();

      if (kIsWeb) {
        await _supabase.syncRecord('sales', id, 'delete', sale.toMap());
      } else {
        _supabase.syncRecord('sales', id, 'delete', sale.toMap());
      }
      return true;
    } catch (e) {
      _error = 'Failed to delete sale: $e';
      notifyListeners();
      return false;
    }
  }

  void clearError() {
    _error = '';
    notifyListeners();
  }
}
