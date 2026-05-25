import 'package:intl/intl.dart';

class Formatters {
  Formatters._();

  // ─── Currency ───
  static final _currencyFormat = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 2,
  );

  static final _currencyWholeFormat = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 0,
  );

  static final _compactCurrency = NumberFormat.compactCurrency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 1,
  );

  /// Smart currency: shows ₹500 for whole amounts, ₹499.50 for fractional
  /// Rounds to 2 decimal places first to eliminate floating-point dust
  static String currency(double amount) {
    final rounded = double.parse(amount.toStringAsFixed(2));
    if (rounded == rounded.truncateToDouble()) {
      return _currencyWholeFormat.format(rounded);
    }
    return _currencyFormat.format(rounded);
  }
  static String currencyCompact(double amount) => _compactCurrency.format(amount);

  // ─── Numbers ───
  static String number(int value) => NumberFormat('#,##,###').format(value);
  static String decimal(double value) => NumberFormat('#,##,##0.00').format(value);

  // ─── Dates (always convert to local for display) ───
  static String date(DateTime dt) => DateFormat('dd MMM yyyy').format(dt.toLocal());
  static String dateShort(DateTime dt) => DateFormat('dd/MM/yy').format(dt.toLocal());
  static String dateTime(DateTime dt) => DateFormat('dd MMM yyyy, hh:mm a').format(dt.toLocal());
  static String time(DateTime dt) => DateFormat('hh:mm a').format(dt.toLocal());
  static String invoiceDate(DateTime dt) => DateFormat('dd/MM/yyyy').format(dt.toLocal());
  static String monthYear(DateTime dt) => DateFormat('MMMM yyyy').format(dt.toLocal());
  static String dayOfWeek(DateTime dt) => DateFormat('EEEE').format(dt.toLocal());

  // ─── Invoice Number ───
  static String invoiceNumber(int sequence) {
    final now = DateTime.now();
    final prefix = 'SKY';
    final datePart = DateFormat('yyMM').format(now);
    final seqPart = sequence.toString().padLeft(4, '0');
    return '$prefix-$datePart-$seqPart';
  }

  // ─── Phone ───
  static String phone(String number) {
    if (number.length == 10) {
      return '${number.substring(0, 5)} ${number.substring(5)}';
    }
    return number;
  }

  // ─── Percentage ───
  static String percent(double value) => '${value.toStringAsFixed(1)}%';

  // ─── Quantity with unit ───
  static String quantity(double qty, [String unit = 'pcs']) {
    if (qty == qty.roundToDouble()) {
      return '${qty.toInt()} $unit';
    }
    return '${qty.toStringAsFixed(2)} $unit';
  }
}
