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
  bool _isUdhar = false;  // Udhar/Pay Later toggle

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
  double get filteredTotal => _filteredSales.fold(0.0, (sum, s) => sum + s.total.roundToDouble());
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

  /// Single-pass customer summary from ALL sales — keyed by phone (primary unique key)
  /// Name fallback only used when phone is genuinely missing from sale record
  Map<String, Map<String, dynamic>> getCustomerSummaries() {
    final Map<String, Map<String, dynamic>> summaries = {};
    for (final sale in _allSales) {
      if (sale.customerName.isEmpty || sale.customerName == 'Walk-in Customer') continue;
      // PHONE is the primary customer key — name only as last resort
      final key = sale.customerPhone.isNotEmpty
          ? sale.customerPhone
          : 'name:${sale.customerName.toLowerCase().trim()}'; // prefix avoids key collision
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

  /// Per-staff sales analytics — computed from in-memory sales data.
  /// Returns a map keyed by staffId with today/weekly/monthly stats.
  Map<String, Map<String, dynamic>> getStaffSalesStats() {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final weekStart = todayStart.subtract(const Duration(days: 7));
    final monthStart = DateTime(now.year, now.month, 1);

    final Map<String, Map<String, dynamic>> stats = {};
    for (final sale in _allSales) {
      if (sale.staffId.isEmpty) continue;
      stats.putIfAbsent(sale.staffId, () => {
        'staffName': sale.staffName,
        'todaySales': 0.0,
        'weeklySales': 0.0,
        'monthlySales': 0.0,
        'todayBills': 0,
        'weeklyBills': 0,
        'monthlyBills': 0,
        'totalSales': 0.0,
        'totalBills': 0,
        'lastSaleTime': sale.createdAt,
      });
      final s = stats[sale.staffId]!;
      // Always track the most recent staff name
      if (sale.staffName.isNotEmpty) s['staffName'] = sale.staffName;

      final saleDate = sale.createdAt;
      // Today
      if (saleDate.isAfter(todayStart) || saleDate.isAtSameMomentAs(todayStart)) {
        s['todaySales'] = (s['todaySales'] as double) + sale.total;
        s['todayBills'] = (s['todayBills'] as int) + 1;
      }
      // This week (last 7 days)
      if (saleDate.isAfter(weekStart)) {
        s['weeklySales'] = (s['weeklySales'] as double) + sale.total;
        s['weeklyBills'] = (s['weeklyBills'] as int) + 1;
      }
      // This month
      if (saleDate.isAfter(monthStart) || saleDate.isAtSameMomentAs(monthStart)) {
        s['monthlySales'] = (s['monthlySales'] as double) + sale.total;
        s['monthlyBills'] = (s['monthlyBills'] as int) + 1;
      }
      // Lifetime
      s['totalSales'] = (s['totalSales'] as double) + sale.total;
      s['totalBills'] = (s['totalBills'] as int) + 1;
      // Last sale time
      if (saleDate.isAfter(s['lastSaleTime'] as DateTime)) {
        s['lastSaleTime'] = saleDate;
      }
    }
    return stats;
  }

  /// Per-staff sales analytics for a specific historical month.
  /// Filters sales where sale.createdAt >= startOfMonth and < startOfNextMonth.
  Map<String, Map<String, dynamic>> getStaffSalesStatsForMonth(DateTime selectedMonth) {
    final startOfMonth = DateTime(selectedMonth.year, selectedMonth.month, 1);
    final startOfNextMonth = DateTime(selectedMonth.year, selectedMonth.month + 1, 1);

    final Map<String, Map<String, dynamic>> stats = {};
    for (final sale in _allSales) {
      if (sale.staffId.isEmpty) continue;
      final saleDate = sale.createdAt.toLocal();
      if (saleDate.isBefore(startOfMonth) || !saleDate.isBefore(startOfNextMonth)) continue;

      stats.putIfAbsent(sale.staffId, () => {
        'staffName': sale.staffName,
        'monthlySales': 0.0,
        'monthlyBills': 0,
        'lastSaleTime': saleDate,
      });
      final s = stats[sale.staffId]!;
      if (sale.staffName.isNotEmpty) s['staffName'] = sale.staffName;

      s['monthlySales'] = (s['monthlySales'] as double) + sale.total;
      s['monthlyBills'] = (s['monthlyBills'] as int) + 1;
      if (saleDate.isAfter(s['lastSaleTime'] as DateTime)) {
        s['lastSaleTime'] = saleDate;
      }
    }
    return stats;
  }

  // Getters — Cart
  List<SaleItem> get cart => _cart;
  String get customerName => _customerName;
  String get customerPhone => _customerPhone;
  String get paymentMode => _paymentMode;
  double get discountPercent => _discountPercent;
  /// Discount amount — rounded to WHOLE RUPEES (Indian retail standard).
  /// This prevents paise amounts like ₹499.50 from percentage discounts.
  double get discountAmount {
    final raw = subtotal * (_discountPercent / 100);
    return raw.roundToDouble();  // Always whole rupees — no paise
  }
  bool get isUdhar => _isUdhar;
  void setUdhar(bool v) { _isUdhar = v; notifyListeners(); }

  // ─── Rounded Financial Getters (prevent floating-point paise drift) ───
  double get subtotal => double.parse(
      _cart.fold(0.0, (sum, item) => sum + item.total).toStringAsFixed(2));
  double get total => (subtotal - discountAmount).clamp(0, double.infinity).roundToDouble();

  // ─── GST Getters (rounded to prevent odd-number split paise) ───
  bool get gstEnabled => _gstEnabled;
  /// Total GST across all cart items (only when enabled)
  double get gstAmount => _gstEnabled
      ? double.parse(_cart.fold(0.0, (sum, item) => sum + item.gstAmount).toStringAsFixed(2))
      : 0;
  double get cgst => double.parse((gstAmount / 2).toStringAsFixed(2));
  double get sgst => double.parse((gstAmount - cgst).toStringAsFixed(2)); // remainder avoids 1-paise gap
  /// Grand total = subtotal - discount + GST
  double get grandTotal => double.parse((total + gstAmount).toStringAsFixed(2));

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
        costPrice: existing.costPrice,  // Preserve cost captured at first add
        quantity: existing.quantity + qty,
        total: existing.price * (existing.quantity + qty),
        gstRate: existing.gstRate,
      );
    } else {
      _cart.add(SaleItem(
        itemId: item.id,
        name: item.name,
        price: item.price,
        costPrice: item.costPrice,  // Capture cost at time of sale
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
        costPrice: item.costPrice,  // Preserve cost price on qty change
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

  /// Set discount by fixed rupee amount — converts to percentage internally
  void setDiscountAmount(double amount) {
    if (subtotal <= 0) {
      _discountPercent = 0;
    } else {
      final clampedAmount = amount.clamp(0.0, subtotal);
      _discountPercent = (clampedAmount / subtotal * 100).clamp(0, 100);
    }
    notifyListeners();
  }

  void clearCart() {
    _cart = [];
    _customerName = '';
    _customerPhone = '';
    _paymentMode = 'Cash';
    _discountPercent = 0;
    _isUdhar = false;
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

      // Payment mode filter — for split payments, check actual amounts too
      if (_paymentFilter != 'All') {
        final filterLower = _paymentFilter.toLowerCase();
        final modeLower = s.paymentMode.toLowerCase();
        if (modeLower != filterLower) {
          // Also match split payments by their actual amounts
          if (filterLower == 'cash' && s.cashAmount > 0) {
            // include — this sale has cash component
          } else if (filterLower == 'upi' && s.upiAmount > 0) {
            // include — this sale has UPI component
          } else if (filterLower == 'card' && s.cardAmount > 0) {
            // include — this sale has card component
          } else if (filterLower == 'udhar' && s.dueAmount > 0) {
            // include — this sale has unpaid Udhar amount
          } else {
            return false;
          }
        }
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
    double cashAmount = 0,
    double upiAmount = 0,
    double cardAmount = 0,
  }) async {
    if (_cart.isEmpty) return null;

    // ═══════════════════════════════════════════════════════════
    // UDHAR GUARD: Block credit sales for walk-in (unnamed) customers
    // ═══════════════════════════════════════════════════════════
    if (_isUdhar && (_customerName.trim().isEmpty || _customerPhone.trim().isEmpty)) {
      _error = 'Customer name and phone required for Udhar sales';
      notifyListeners();
      return null;
    }

    try {
      final invoiceNumber = await _db.nextInvoiceNumber();

      // Discount already rounded to whole rupees by getter
      final roundedDiscount = discountAmount;

      // Apply loyalty discount — round to whole rupees
      final finalTotal = (total - loyaltyDiscount).clamp(0.0, double.infinity).roundToDouble();

      // Calculate GST on the final total after discount
      final saleGstAmount = _gstEnabled ? gstAmount : 0.0;
      final saleCgst = double.parse((saleGstAmount / 2).toStringAsFixed(2));
      final saleSgst = double.parse((saleGstAmount - saleCgst).toStringAsFixed(2));
      // Grand total: round to whole rupees (safety net)
      final saleGrandTotal = (finalTotal + saleGstAmount).roundToDouble();

      // ═══════════════════════════════════════════════════════════
      // AUTO-SET PAYMENT AMOUNTS: For single-method payments,
      // the payment amount MUST equal the bill total.
      // This prevents UPI showing ₹1150 when bill is ₹1050.
      // ═══════════════════════════════════════════════════════════
      double finalCash = cashAmount;
      double finalUpi = upiAmount;
      double finalCard = cardAmount;

      final isSplit = (cashAmount > 0 && upiAmount > 0) ||
                      (cashAmount > 0 && cardAmount > 0) ||
                      (upiAmount > 0 && cardAmount > 0);

      if (!isSplit && !_isUdhar) {
        // Single payment method — force amount to match bill total
        if (upiAmount > 0 || _paymentMode.toLowerCase() == 'upi') {
          finalCash = 0;
          finalUpi = saleGrandTotal;
          finalCard = 0;
        } else if (cardAmount > 0 || _paymentMode.toLowerCase() == 'card') {
          finalCash = 0;
          finalUpi = 0;
          finalCard = saleGrandTotal;
        } else {
          // Default: Cash
          finalCash = saleGrandTotal;
          finalUpi = 0;
          finalCard = 0;
        }
      } else if (!_isUdhar) {
        // Split payment — validate total matches bill
        final paymentSum = finalCash + finalUpi + finalCard;
        if ((paymentSum - saleGrandTotal).abs() > 0.01 && paymentSum > 0) {
          final ratio = saleGrandTotal / paymentSum;
          finalCash = double.parse((finalCash * ratio).toStringAsFixed(2));
          finalUpi = double.parse((finalUpi * ratio).toStringAsFixed(2));
          finalCard = double.parse((saleGrandTotal - finalCash - finalUpi).toStringAsFixed(2));
        }
      }
      // For Udhar: keep user-entered payment amounts as-is (partial/zero)

      // Calculate due amount for Udhar sales
      final double saleDueAmount;
      if (_isUdhar) {
        saleDueAmount = (saleGrandTotal - finalCash - finalUpi - finalCard).clamp(0.0, double.infinity).roundToDouble();
      } else {
        saleDueAmount = 0;
      }

      // Derive a smart paymentMode label
      final String paymentLabel;
      if (saleDueAmount > 0 && saleDueAmount >= saleGrandTotal) {
        paymentLabel = 'Udhar';
      } else if (saleDueAmount > 0) {
        paymentLabel = 'Partial';
      } else if (finalCash > 0 && (finalUpi > 0 || finalCard > 0)) {
        paymentLabel = 'Split';
      } else if (finalUpi > 0) {
        paymentLabel = 'UPI';
      } else if (finalCard > 0) {
        paymentLabel = 'Card';
      } else {
        paymentLabel = 'Cash';
      }

      final sale = SaleModel(
        id: _uuid.v4(),
        invoiceNumber: invoiceNumber,
        customerName: _customerName,
        customerPhone: _customerPhone,
        items: List.from(_cart),
        subtotal: subtotal,
        discount: roundedDiscount,
        total: saleGrandTotal,
        gstAmount: saleGstAmount,
        cgst: saleCgst,
        sgst: saleSgst,
        paymentMode: paymentLabel,
        cashAmount: finalCash,
        upiAmount: finalUpi,
        cardAmount: finalCard,
        staffId: staffId,
        staffName: staffName,
        loyaltyDiscount: loyaltyDiscount,
        pointsRedeemed: pointsRedeemed,
        pointsEarned: pointsEarned,
        dueAmount: saleDueAmount,
      );

      // ═══════════════════════════════════════════════════════════
      // CLOUD-FIRST: Save to Supabase BEFORE local cache (web)
      // If cloud save fails → BLOCK the sale (no silent data loss)
      // ═══════════════════════════════════════════════════════════
      if (kIsWeb) {
        try {
          await _supabase.guaranteedSave('sales', sale.toMap());
          debugPrint('✅ Sale ${sale.invoiceNumber} saved to cloud FIRST');
        } catch (e) {
          _error = 'Cannot save bill — check your internet connection and try again.';
          debugPrint('❌ BLOCKED: Sale ${sale.invoiceNumber} cloud save failed: $e');
          notifyListeners();
          return null; // BLOCK — do not complete sale
        }
      }

      // Save to local DB (cache on web, primary on mobile)
      await _db.insert('sales', sale.toMap());

      // Add to in-memory list + re-filter
      _allSales.insert(0, sale);
      _applyFilter();

      // Clear cart
      clearCart();

      notifyListeners();

      // Mobile: sync in background (SQLite persists, so safe)
      if (!kIsWeb) {
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
