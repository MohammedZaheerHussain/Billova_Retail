import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConstants {
  AppConstants._();

  // ─── App Info ───
  static const String appName = 'Billova Retail';
  static const String appVersion = '1.0.0';
  static const String appTagline = 'Professional Billing, Simplified';

  // ─── Supabase (loaded from environment / .env / fallback) ───
  static const String _defaultSupabaseUrl = 'https://auqapthcohowhjcchnia.supabase.co';
  static const String _defaultSupabaseAnonKey = 'sb_publishable_WoVw7PKKbK8BpASXg2eA0w_LooCAyZs';

  static String get supabaseUrl {
    const envUrl = String.fromEnvironment('SUPABASE_URL');
    if (envUrl.isNotEmpty) return envUrl;
    final dotVal = dotenv.env['SUPABASE_URL'];
    if (dotVal != null && dotVal.isNotEmpty) return dotVal;
    return _defaultSupabaseUrl;
  }

  static String get supabaseAnonKey {
    const envKey = String.fromEnvironment('SUPABASE_ANON_KEY');
    if (envKey.isNotEmpty) return envKey;
    final dotVal = dotenv.env['SUPABASE_ANON_KEY'];
    if (dotVal != null && dotVal.isNotEmpty) return dotVal;
    return _defaultSupabaseAnonKey;
  }

  // ─── Database ───
  static const String dbName = 'billova_retail.db';
  static const int dbVersion = 16;

  // ─── Invoice ───
  static const String invoicePrefix = 'BIL';
  static const String currencySymbol = '₹';
  static const String currencyCode = 'INR';

  // ─── Defaults ───
  static const int lowStockThreshold = 5;
  static const double defaultTaxRate = 0.0;

  // ─── Pagination ───
  static const int pageSize = 20;

  // ─── Date Formats ───
  static const String dateFormat = 'dd MMM yyyy';
  static const String dateTimeFormat = 'dd MMM yyyy, hh:mm a';
  static const String invoiceDateFormat = 'dd/MM/yyyy';

  // ─── Payment Modes ───
  static const List<String> paymentModes = [
    'Cash',
    'UPI',
    'Card',
    'Bank Transfer',
    'Credit',
  ];

  // ─── Expense Categories ───
  static const List<String> expenseCategories = [
    'General',
    'Rent',
    'Salary',
    'Utilities',
    'Transport',
    'Maintenance',
    'Supplies',
    'Other',
  ];
}
