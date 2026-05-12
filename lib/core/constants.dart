import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConstants {
  AppConstants._();

  // ─── App Info ───
  static const String appName = 'SKYWALK Billing';
  static const String appVersion = '1.0.0';
  static const String appTagline = 'Professional Billing, Simplified';

  // ─── Supabase (loaded from .env) ───
  static String get supabaseUrl => dotenv.env['SUPABASE_URL'] ?? '';
  static String get supabaseAnonKey => dotenv.env['SUPABASE_ANON_KEY'] ?? '';

  // ─── Database ───
  static const String dbName = 'skywalk_billing.db';
  static const int dbVersion = 11;

  // ─── Invoice ───
  static const String invoicePrefix = 'SKY';
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
