import 'package:url_launcher/url_launcher.dart';
import 'formatters.dart';

/// Lightweight WhatsApp deep-link helper — no API, no server, just wa.me links
class WhatsAppHelper {
  WhatsAppHelper._();

  /// Open WhatsApp with pre-filled message for a specific phone number
  static Future<void> send({required String phone, required String message}) async {
    // Ensure phone starts with country code (default India)
    String cleaned = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleaned.length == 10) cleaned = '91$cleaned';
    final url = 'https://wa.me/$cleaned?text=${Uri.encodeComponent(message)}';
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  /// Format invoice message for WhatsApp
  static String invoiceMessage({
    required String invoiceNumber,
    required double total,
    required double discount,
    required String paymentMode,
    required List<Map<String, dynamic>> items,
    String customerName = '',
  }) {
    final buf = StringBuffer();
    buf.writeln('*SKYWALK BILL*');
    buf.writeln('');
    if (customerName.isNotEmpty) buf.writeln('Hi $customerName,');
    buf.writeln('Invoice: *$invoiceNumber*');
    buf.writeln('');
    buf.writeln('Items:');
    for (final item in items) {
      buf.writeln('  - ${item['name']} x ${item['qty']} = ${Formatters.currency(item['total'] as double)}');
    }
    buf.writeln('');
    if (discount > 0) {
      buf.writeln('Discount: -${Formatters.currency(discount)}');
    }
    buf.writeln('*Total: ${Formatters.currency(total)}*');
    buf.writeln('Payment: $paymentMode');
    buf.writeln('');
    buf.writeln('Thank you for shopping with us!');
    buf.writeln('Visit again! - Team SKYWALK');
    return buf.toString();
  }

  // ─── Offer Templates ───

  static const List<Map<String, String>> offerTemplates = [
    {
      'title': 'Festival Offer',
      'message': '*Festival Special from SKYWALK!*\n\nFlat *20% OFF* on all products!\n\nHurry - offer valid for limited time only!\n\nVisit now!',
    },
    {
      'title': 'Clearance Sale',
      'message': '*SKYWALK Clearance Sale!*\n\nUp to *50% OFF* on selected styles!\n\nLimited stock - first come, first served!\n\nVisit today!',
    },
    {
      'title': 'New Arrivals',
      'message': '*New Arrivals at SKYWALK!*\n\nFresh styles just dropped!\n\nBe the first to grab them!\n\nVisit now or miss out!',
    },
    {
      'title': 'VIP/Loyalty',
      'message': '*Exclusive VIP Offer - SKYWALK*\n\nAs a valued customer, you get *EXTRA 10% OFF*!\n\nUse this message to claim at store.\n\nThank you for your loyalty!',
    },
    {
      'title': 'Weekend Special',
      'message': '*Weekend Special - SKYWALK*\n\nBuy 2 pairs, get *Rs.500 OFF*!\n\nThis Saturday & Sunday only!\n\nSee you there!',
    },
  ];

  /// Format vendor purchase invoice for WhatsApp sharing
  static String vendorInvoiceMessage({
    required String vendorName,
    required String invoiceNumber,
    required double totalAmount,
    required double paidAmount,
    required double pendingAmount,
    required String paymentStatus,
    required List<Map<String, dynamic>> purchases,
    String companyName = 'SKYWALK',
  }) {
    String status;
    if (pendingAmount <= 0) {
      status = 'Fully Paid';
    } else if (paidAmount > 0) {
      status = 'Partial Payment';
    } else {
      status = 'Pending';
    }

    final date = DateTime.now().toIso8601String().substring(0, 10);
    final buf = StringBuffer();

    buf.writeln('*$companyName - VENDOR INVOICE*');
    buf.writeln('');
    buf.writeln('Hello *$vendorName*,');
    buf.writeln('Please find your updated purchase ledger.');
    buf.writeln('');
    buf.writeln('Invoice No: *$invoiceNumber*');
    buf.writeln('Date: *$date*');
    buf.writeln('');
    buf.writeln('*Purchase Summary*');
    buf.writeln('');

    int index = 1;
    for (final p in purchases) {
      final pDate = (p['date'] as String?) ?? '';
      final amount = Formatters.currency((p['amount'] as num?)?.toDouble() ?? 0);
      final paid = Formatters.currency((p['paid'] as num?)?.toDouble() ?? 0);
      buf.writeln('$index. $pDate');
      buf.writeln('   Amount: $amount');
      buf.writeln('   Paid: $paid');
      buf.writeln('');
      index++;
    }

    buf.writeln('*Payment Details*');
    buf.writeln('');
    buf.writeln('Total Amount: *${Formatters.currency(totalAmount)}*');
    buf.writeln('Paid Amount: *${Formatters.currency(paidAmount)}*');
    buf.writeln('Pending Balance: *${Formatters.currency(pendingAmount)}*');
    buf.writeln('Status: *$status*');
    buf.writeln('');
    buf.writeln('Thank you for your business.');
    buf.writeln('- Team $companyName');
    return buf.toString();
  }

  /// Format a single payment receipt for WhatsApp sharing
  static String vendorPaymentMessage({
    required String vendorName,
    required String date,
    required double totalAmount,
    required double paidAmount,
    required double dueAmount,
    required String paymentMode,
    required double overallPending,
    String companyName = 'SKYWALK',
  }) {
    String status;
    if (dueAmount <= 0) {
      status = 'Fully Paid';
    } else if (paidAmount > 0) {
      status = 'Partial Payment';
    } else {
      status = 'Pending';
    }

    final buf = StringBuffer();
    buf.writeln('*$companyName - PAYMENT RECEIPT*');
    buf.writeln('');
    buf.writeln('Hello *$vendorName*,');
    buf.writeln('Here is your recent payment update.');
    buf.writeln('');
    buf.writeln('Date: *$date*');
    buf.writeln('Purchase Amount: *${Formatters.currency(totalAmount)}*');
    buf.writeln('Paid: *${Formatters.currency(paidAmount)}*');
    buf.writeln('Due on this purchase: *${Formatters.currency(dueAmount)}*');
    buf.writeln('Payment Mode: *$paymentMode*');
    buf.writeln('Status: *$status*');
    buf.writeln('');
    buf.writeln('Overall Pending Balance: *${Formatters.currency(overallPending)}*');
    buf.writeln('');
    buf.writeln('Thank you for your business.');
    buf.writeln('- Team $companyName');
    return buf.toString();
  }
}
