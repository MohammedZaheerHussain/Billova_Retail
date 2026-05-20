import 'dart:convert';
import '../../data/models/sale_model.dart';
import '../../data/models/item_model.dart';

/// Priority levels for insight cards
enum InsightPriority { critical, warning, success, info }

/// A single business insight with priority and data
class BusinessInsight {
  final String title;
  final String description;
  final InsightPriority priority;
  final String emoji;
  final String category; // 'sales','inventory','customer','financial','product'

  const BusinessInsight({
    required this.title,
    required this.description,
    required this.priority,
    required this.emoji,
    required this.category,
  });
}

/// Pure analytics engine — computes all metrics from raw data.
/// No UI, no providers — just calculations.
class BusinessAnalytics {
  final List<SaleModel> allSales;
  final List<ItemModel> allItems;
  final List<Map<String, dynamic>> allExpenses;
  final List<Map<String, dynamic>> allPurchases;
  final List<Map<String, dynamic>> allCustomers;

  BusinessAnalytics({
    required this.allSales,
    required this.allItems,
    this.allExpenses = const [],
    this.allPurchases = const [],
    this.allCustomers = const [],
  });

  // ─── Time Helpers ───
  DateTime get _now => DateTime.now();
  DateTime get _todayStart => DateTime(_now.year, _now.month, _now.day);
  DateTime get _weekStart => _todayStart.subtract(Duration(days: 7));
  DateTime get _monthStart => DateTime(_now.year, _now.month, 1);
  DateTime get _lastMonthStart => DateTime(_now.year, _now.month - 1, 1);
  DateTime get _lastMonthEnd => _monthStart;
  DateTime get _lastWeekStart => _todayStart.subtract(Duration(days: 14));
  DateTime get _lastWeekEnd => _weekStart;

  List<SaleModel> _salesInRange(DateTime start, DateTime end) =>
      allSales.where((s) {
        final t = s.createdAt.toLocal();
        return !t.isBefore(start) && t.isBefore(end);
      }).toList();

  // ─── Core Financial Metrics ───

  double get todayRevenue => _salesInRange(_todayStart, _now).fold(0.0, (s, e) => s + e.total);
  double get weekRevenue => _salesInRange(_weekStart, _now).fold(0.0, (s, e) => s + e.total);
  double get monthRevenue => _salesInRange(_monthStart, _now).fold(0.0, (s, e) => s + e.total);
  double get lastMonthRevenue => _salesInRange(_lastMonthStart, _lastMonthEnd).fold(0.0, (s, e) => s + e.total);
  double get lastWeekRevenue => _salesInRange(_lastWeekStart, _lastWeekEnd).fold(0.0, (s, e) => s + e.total);

  int get todaySalesCount => _salesInRange(_todayStart, _now).length;
  int get weekSalesCount => _salesInRange(_weekStart, _now).length;

  /// Gross profit: (selling - cost) * qty - discount, for a date range
  double _grossProfitInRange(DateTime start, DateTime end) =>
      _salesInRange(start, end).fold(0.0, (s, e) => s + e.grossProfit);

  double get todayGrossProfit => _grossProfitInRange(_todayStart, _now);
  double get weekGrossProfit => _grossProfitInRange(_weekStart, _now);
  double get monthGrossProfit => _grossProfitInRange(_monthStart, _now);
  double get lastMonthGrossProfit => _grossProfitInRange(_lastMonthStart, _lastMonthEnd);

  /// Expenses in range
  double _expensesInRange(DateTime start, DateTime end) {
    return allExpenses.fold(0.0, (sum, e) {
      final t = DateTime.parse(e['created_at'] as String).toLocal();
      if (!t.isBefore(start) && t.isBefore(end)) {
        return sum + ((e['amount'] as num?)?.toDouble() ?? 0);
      }
      return sum;
    });
  }

  double get todayExpenses => _expensesInRange(_todayStart, _now);
  double get monthExpenses => _expensesInRange(_monthStart, _now);

  /// Total discounts in range
  double _discountsInRange(DateTime start, DateTime end) =>
      _salesInRange(start, end).fold(0.0, (s, e) => s + e.discount);

  double get todayDiscounts => _discountsInRange(_todayStart, _now);
  double get monthDiscounts => _discountsInRange(_monthStart, _now);

  /// Total GST in range
  double _gstInRange(DateTime start, DateTime end) =>
      _salesInRange(start, end).fold(0.0, (s, e) => s + e.gstAmount);

  double get todayGST => _gstInRange(_todayStart, _now);
  double get monthGST => _gstInRange(_monthStart, _now);

  /// NET PROFIT = Gross Profit - Expenses
  double get todayNetProfit => todayGrossProfit - todayExpenses;
  double get monthNetProfit => monthGrossProfit - monthExpenses;

  /// Growth percentages
  double get weekGrowthPct {
    if (lastWeekRevenue == 0) return weekRevenue > 0 ? 100 : 0;
    return ((weekRevenue - lastWeekRevenue) / lastWeekRevenue) * 100;
  }

  double get monthGrowthPct {
    if (lastMonthRevenue == 0) return monthRevenue > 0 ? 100 : 0;
    return ((monthRevenue - lastMonthRevenue) / lastMonthRevenue) * 100;
  }

  double get profitMarginPct {
    if (monthRevenue == 0) return 0;
    return (monthNetProfit / monthRevenue) * 100;
  }

  // ─── Product Performance ───

  /// Returns sorted list: [{name, qty, revenue, profit, category}]
  List<Map<String, dynamic>> get productPerformance {
    final Map<String, Map<String, dynamic>> products = {};
    for (final sale in allSales) {
      for (final item in sale.items) {
        final key = item.name;
        products.putIfAbsent(key, () => {
          'name': key, 'qty': 0, 'revenue': 0.0, 'profit': 0.0, 'costTotal': 0.0,
        });
        products[key]!['qty'] = (products[key]!['qty'] as int) + item.quantity;
        products[key]!['revenue'] = (products[key]!['revenue'] as double) + item.total;
        products[key]!['profit'] = (products[key]!['profit'] as double) + item.profit;
      }
    }
    final list = products.values.toList()
      ..sort((a, b) => (b['qty'] as int).compareTo(a['qty'] as int));
    return list;
  }

  List<Map<String, dynamic>> get topSellingProducts => productPerformance.take(5).toList();

  /// Dead stock: items with zero sales in last 30 days
  List<ItemModel> get deadStockItems {
    final sold30 = <String>{};
    final cutoff = _now.subtract(Duration(days: 30));
    for (final sale in allSales) {
      if (sale.createdAt.toLocal().isAfter(cutoff)) {
        for (final item in sale.items) {
          sold30.add(item.itemId);
        }
      }
    }
    return allItems.where((i) => !sold30.contains(i.id) && i.quantity > 0).toList();
  }

  /// Slow movers: items with < 3 sales in last 30 days
  List<Map<String, dynamic>> get slowMovingProducts {
    final cutoff = _now.subtract(Duration(days: 30));
    final salesCount = <String, int>{};
    for (final sale in allSales) {
      if (sale.createdAt.toLocal().isAfter(cutoff)) {
        for (final item in sale.items) {
          salesCount[item.itemId] = (salesCount[item.itemId] ?? 0) + item.quantity;
        }
      }
    }
    return allItems
        .where((i) => (salesCount[i.id] ?? 0) < 3 && (salesCount[i.id] ?? 0) > 0)
        .map((i) => {'item': i, 'soldQty': salesCount[i.id] ?? 0})
        .toList();
  }

  /// Fast selling: items with > 10 sales in last 7 days
  List<Map<String, dynamic>> get fastSellingProducts {
    final salesCount = <String, int>{};
    final cutoff = _weekStart;
    for (final sale in allSales) {
      if (sale.createdAt.toLocal().isAfter(cutoff)) {
        for (final item in sale.items) {
          salesCount[item.itemId] = (salesCount[item.itemId] ?? 0) + item.quantity;
        }
      }
    }
    return allItems
        .where((i) => (salesCount[i.id] ?? 0) >= 5)
        .map((i) => {'item': i, 'soldQty': salesCount[i.id] ?? 0})
        .toList()
      ..sort((a, b) => (b['soldQty'] as int).compareTo(a['soldQty'] as int));
  }

  // ─── Inventory Intelligence ───

  List<ItemModel> get lowStockItems => allItems.where((i) => i.isLowStock).toList();
  List<ItemModel> get outOfStockItems => allItems.where((i) => i.isOutOfStock).toList();
  double get totalStockValue => allItems.fold(0.0, (s, i) => s + i.stockValue);

  /// Overstock: items with qty > 50 and < 2 sold in 30 days
  List<ItemModel> get overstockItems {
    final cutoff = _now.subtract(Duration(days: 30));
    final salesCount = <String, int>{};
    for (final sale in allSales) {
      if (sale.createdAt.toLocal().isAfter(cutoff)) {
        for (final item in sale.items) {
          salesCount[item.itemId] = (salesCount[item.itemId] ?? 0) + item.quantity;
        }
      }
    }
    return allItems.where((i) => i.quantity > 50 && (salesCount[i.id] ?? 0) < 2).toList();
  }

  // ─── Category Analytics ───

  /// Revenue by category: {categoryName: totalRevenue}
  Map<String, double> get categoryRevenue {
    final Map<String, double> result = {};
    // Build item-id to category map
    final catMap = <String, String>{};
    for (final item in allItems) {
      catMap[item.id] = item.category.isEmpty ? 'Uncategorized' : item.category;
    }
    for (final sale in allSales) {
      for (final item in sale.items) {
        final cat = catMap[item.itemId] ?? 'Uncategorized';
        result[cat] = (result[cat] ?? 0) + item.total;
      }
    }
    return result;
  }

  /// Profit by category
  Map<String, double> get categoryProfit {
    final Map<String, double> result = {};
    final catMap = <String, String>{};
    for (final item in allItems) {
      catMap[item.id] = item.category.isEmpty ? 'Uncategorized' : item.category;
    }
    for (final sale in allSales) {
      for (final item in sale.items) {
        final cat = catMap[item.itemId] ?? 'Uncategorized';
        result[cat] = (result[cat] ?? 0) + item.profit;
      }
    }
    return result;
  }

  // ─── Peak Sales Intelligence ───

  /// Best selling day of week (0=Mon, 6=Sun)
  Map<String, dynamic> get peakSalesDay {
    final dayTotals = List.filled(7, 0.0);
    final dayCounts = List.filled(7, 0);
    for (final sale in allSales) {
      final weekday = sale.createdAt.toLocal().weekday - 1; // 0-6
      dayTotals[weekday] += sale.total;
      dayCounts[weekday]++;
    }
    int bestDay = 0;
    for (int i = 1; i < 7; i++) {
      if (dayTotals[i] > dayTotals[bestDay]) bestDay = i;
    }
    const dayNames = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    return {'day': dayNames[bestDay], 'total': dayTotals[bestDay], 'count': dayCounts[bestDay]};
  }

  /// Best selling hour
  Map<String, dynamic> get peakSalesHour {
    final hourTotals = List.filled(24, 0.0);
    for (final sale in allSales) {
      final hour = sale.createdAt.toLocal().hour;
      hourTotals[hour] += sale.total;
    }
    int bestHour = 0;
    for (int i = 1; i < 24; i++) {
      if (hourTotals[i] > hourTotals[bestHour]) bestHour = i;
    }
    final period = bestHour >= 12 ? 'PM' : 'AM';
    final h12 = bestHour == 0 ? 12 : (bestHour > 12 ? bestHour - 12 : bestHour);
    return {'hour': bestHour, 'label': '$h12 $period', 'total': hourTotals[bestHour]};
  }

  // ─── Customer Intelligence ───

  /// Top customers by spending
  List<Map<String, dynamic>> get topCustomers {
    final Map<String, Map<String, dynamic>> customers = {};
    for (final sale in allSales) {
      final key = sale.customerPhone.isNotEmpty ? sale.customerPhone : sale.customerName;
      if (key.isEmpty || key == 'Walk-in') continue;
      customers.putIfAbsent(key, () => {
        'name': sale.customerName, 'phone': sale.customerPhone,
        'totalSpent': 0.0, 'orders': 0, 'lastPurchase': sale.createdAt,
      });
      customers[key]!['totalSpent'] = (customers[key]!['totalSpent'] as double) + sale.total;
      customers[key]!['orders'] = (customers[key]!['orders'] as int) + 1;
      if ((sale.createdAt).isAfter(customers[key]!['lastPurchase'] as DateTime)) {
        customers[key]!['lastPurchase'] = sale.createdAt;
      }
    }
    final list = customers.values.toList()
      ..sort((a, b) => (b['totalSpent'] as double).compareTo(a['totalSpent'] as double));
    return list.take(10).toList();
  }

  /// Inactive customers: haven't purchased in 15+ days
  List<Map<String, dynamic>> get inactiveCustomers {
    final Map<String, Map<String, dynamic>> customers = {};
    for (final sale in allSales) {
      final key = sale.customerPhone.isNotEmpty ? sale.customerPhone : sale.customerName;
      if (key.isEmpty || key == 'Walk-in') continue;
      customers.putIfAbsent(key, () => {
        'name': sale.customerName, 'phone': sale.customerPhone,
        'totalSpent': 0.0, 'lastPurchase': sale.createdAt,
      });
      customers[key]!['totalSpent'] = (customers[key]!['totalSpent'] as double) + sale.total;
      if ((sale.createdAt).isAfter(customers[key]!['lastPurchase'] as DateTime)) {
        customers[key]!['lastPurchase'] = sale.createdAt;
      }
    }
    return customers.values.where((c) {
      final daysSince = _now.difference((c['lastPurchase'] as DateTime).toLocal()).inDays;
      c['daysSince'] = daysSince;
      return daysSince > 15;
    }).toList()
      ..sort((a, b) => (b['daysSince'] as int).compareTo(a['daysSince'] as int));
  }

  // ─── Daily Trend Data (for charts) ───

  /// Last 7 days: [{date, revenue, profit, count}]
  List<Map<String, dynamic>> get dailyTrend7Days {
    final result = <Map<String, dynamic>>[];
    for (int i = 6; i >= 0; i--) {
      final day = _todayStart.subtract(Duration(days: i));
      final nextDay = day.add(Duration(days: 1));
      final daySales = _salesInRange(day, nextDay);
      result.add({
        'date': '${day.day}/${day.month}',
        'revenue': daySales.fold(0.0, (s, e) => s + e.total),
        'profit': daySales.fold(0.0, (s, e) => s + e.grossProfit),
        'count': daySales.length,
      });
    }
    return result;
  }

  // ─── Generate Smart Insights ───

  List<BusinessInsight> generateInsights() {
    final insights = <BusinessInsight>[];

    // 1. Sales growth/decline
    if (weekGrowthPct > 10) {
      insights.add(BusinessInsight(
        title: 'Sales Growing',
        description: 'Sales grew ${weekGrowthPct.toStringAsFixed(1)}% vs last week. Keep the momentum!',
        priority: InsightPriority.success, emoji: '📈', category: 'sales',
      ));
    } else if (weekGrowthPct < -10) {
      insights.add(BusinessInsight(
        title: 'Sales Declining',
        description: 'Sales dropped ${weekGrowthPct.abs().toStringAsFixed(1)}% vs last week. Review pricing or promotions.',
        priority: InsightPriority.warning, emoji: '📉', category: 'sales',
      ));
    }

    // 2. Out of stock critical
    if (outOfStockItems.isNotEmpty) {
      final names = outOfStockItems.take(3).map((i) => i.name).join(', ');
      insights.add(BusinessInsight(
        title: '${outOfStockItems.length} Items Out of Stock',
        description: 'Customers cannot buy: $names. Restock immediately to avoid lost sales.',
        priority: InsightPriority.critical, emoji: '🚨', category: 'inventory',
      ));
    }

    // 3. Low stock
    if (lowStockItems.isNotEmpty) {
      insights.add(BusinessInsight(
        title: '${lowStockItems.length} Items Running Low',
        description: 'Stock running low on ${lowStockItems.take(3).map((i) => "${i.name} (${i.quantity})").join(", ")}.',
        priority: InsightPriority.warning, emoji: '⚠️', category: 'inventory',
      ));
    }

    // 4. Fast sellers need restock
    for (final fs in fastSellingProducts.take(2)) {
      final item = fs['item'] as ItemModel;
      final soldQty = fs['soldQty'] as int;
      if (item.isLowStock) {
        insights.add(BusinessInsight(
          title: '${item.name} Selling Fast — Low Stock!',
          description: 'Sold $soldQty units this week but only ${item.quantity} left. Restock urgently.',
          priority: InsightPriority.critical, emoji: '🔥', category: 'product',
        ));
      }
    }

    // 5. Dead stock
    if (deadStockItems.isNotEmpty) {
      insights.add(BusinessInsight(
        title: '${deadStockItems.length} Dead Stock Items',
        description: '${deadStockItems.take(3).map((i) => i.name).join(", ")} had zero sales in 30 days. Consider discounts.',
        priority: InsightPriority.warning, emoji: '📦', category: 'inventory',
      ));
    }

    // 6. Profit margin check
    if (profitMarginPct < 15 && monthRevenue > 0) {
      insights.add(BusinessInsight(
        title: 'Low Profit Margin',
        description: 'Monthly margin is ${profitMarginPct.toStringAsFixed(1)}%. Review pricing or reduce expenses.',
        priority: InsightPriority.warning, emoji: '💰', category: 'financial',
      ));
    } else if (profitMarginPct >= 25 && monthRevenue > 0) {
      insights.add(BusinessInsight(
        title: 'Strong Profit Margin',
        description: 'Monthly margin at ${profitMarginPct.toStringAsFixed(1)}% — excellent performance!',
        priority: InsightPriority.success, emoji: '💰', category: 'financial',
      ));
    }

    // 7. Inactive customers
    if (inactiveCustomers.isNotEmpty) {
      final top = inactiveCustomers.first;
      insights.add(BusinessInsight(
        title: '${inactiveCustomers.length} Inactive Customers',
        description: '${top['name']} hasn\'t purchased in ${top['daysSince']} days. Send a WhatsApp offer!',
        priority: InsightPriority.info, emoji: '👥', category: 'customer',
      ));
    }

    // 8. Peak sales intelligence
    if (allSales.length >= 10) {
      final peak = peakSalesDay;
      final peakH = peakSalesHour;
      insights.add(BusinessInsight(
        title: 'Peak Sales: ${peak['day']}s at ${peakH['label']}',
        description: 'Your busiest time. Ensure full staff coverage and stock availability.',
        priority: InsightPriority.info, emoji: '🕐', category: 'sales',
      ));
    }

    // 9. Best category
    if (categoryRevenue.isNotEmpty) {
      final sorted = categoryRevenue.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      insights.add(BusinessInsight(
        title: '${sorted.first.key} — Top Category',
        description: 'Generating ₹${sorted.first.value.toStringAsFixed(0)} in revenue. Focus marketing here.',
        priority: InsightPriority.success, emoji: '🏆', category: 'product',
      ));
    }

    // 10. Overstock warning
    if (overstockItems.isNotEmpty) {
      insights.add(BusinessInsight(
        title: '${overstockItems.length} Overstocked Items',
        description: '${overstockItems.take(2).map((i) => "${i.name} (${i.quantity} units)").join(", ")} — high stock, low sales.',
        priority: InsightPriority.warning, emoji: '📊', category: 'inventory',
      ));
    }

    return insights;
  }

  /// Build comprehensive data map for Groq AI
  Map<String, dynamic> buildAIDataPayload() {
    return {
      // Financial
      'today_revenue': todayRevenue,
      'today_gross_profit': todayGrossProfit,
      'today_net_profit': todayNetProfit,
      'today_expenses': todayExpenses,
      'today_discounts': todayDiscounts,
      'today_gst': todayGST,
      'today_sales_count': todaySalesCount,
      'week_revenue': weekRevenue,
      'week_gross_profit': weekGrossProfit,
      'week_growth_pct': weekGrowthPct,
      'month_revenue': monthRevenue,
      'month_gross_profit': monthGrossProfit,
      'month_net_profit': monthNetProfit,
      'month_expenses': monthExpenses,
      'month_discounts': monthDiscounts,
      'month_growth_pct': monthGrowthPct,
      'profit_margin_pct': profitMarginPct,
      // Inventory
      'total_stock_value': totalStockValue,
      'total_items': allItems.length,
      'low_stock_count': lowStockItems.length,
      'out_of_stock_count': outOfStockItems.length,
      'low_stock_items': lowStockItems.take(8).map((i) => {'name': i.name, 'qty': i.quantity}).toList(),
      'dead_stock_count': deadStockItems.length,
      'dead_stock_items': deadStockItems.take(5).map((i) => {'name': i.name, 'qty': i.quantity}).toList(),
      'overstock_count': overstockItems.length,
      // Products
      'top_products': topSellingProducts.take(5).toList(),
      'fast_sellers': fastSellingProducts.take(5).map((fs) => {
        'name': (fs['item'] as ItemModel).name,
        'sold_this_week': fs['soldQty'],
        'remaining': (fs['item'] as ItemModel).quantity,
      }).toList(),
      // Categories
      'category_revenue': categoryRevenue,
      'category_profit': categoryProfit,
      // Peak
      'peak_day': peakSalesDay,
      'peak_hour': peakSalesHour,
      // Customers
      'top_customers': topCustomers.take(5).map((c) => {
        'name': c['name'], 'phone': c['phone'],
        'total_spent': c['totalSpent'], 'orders': c['orders'],
      }).toList(),
      'inactive_customers': inactiveCustomers.take(5).map((c) => {
        'name': c['name'], 'phone': c['phone'],
        'days_since': c['daysSince'], 'total_spent': c['totalSpent'],
      }).toList(),
    };
  }
}
