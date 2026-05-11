// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:js' as js;
import '../../data/models/sale_model.dart';
import '../../data/local/db_helper.dart';
import 'formatters.dart';

class ReceiptPrinter {
  static final _db = DBHelper.instance;

  /// Auto-print receipt after sale completion
  static Future<void> printReceipt(SaleModel sale, {double cashPaid = 0, double upiPaid = 0}) async {
    final autoPrint = await _db.getSetting('auto_print') ?? 'false';
    if (autoPrint != 'true') return;
    await _doPrint(sale, cashPaid: cashPaid, upiPaid: upiPaid);
  }

  /// Manual print (always prints)
  static Future<void> manualPrint(SaleModel sale, {double cashPaid = 0, double upiPaid = 0}) async {
    await _doPrint(sale, cashPaid: cashPaid, upiPaid: upiPaid);
  }

  static Future<void> _doPrint(SaleModel sale, {double cashPaid = 0, double upiPaid = 0}) async {
    final shopName = await _db.getSetting('shop_name') ?? 'SKYWALK STORE';
    final shopAddress = await _db.getSetting('shop_address') ?? '';
    final shopPhone = await _db.getSetting('shop_phone') ?? '';
    final shopLogo = await _db.getSetting('shop_logo') ?? '';
    final footerText = await _db.getSetting('receipt_footer') ?? 'Thank you! Visit again';

    final receiptHtml = _buildReceiptHtml(
      sale: sale, shopName: shopName, shopAddress: shopAddress,
      shopPhone: shopPhone, shopLogo: shopLogo, footerText: footerText,
      cashPaid: cashPaid, upiPaid: upiPaid,
    );

    // Use JavaScript to open popup, write, print, close
    js.context.callMethod('eval', ['''
      var w = window.open('', '_blank', 'width=320,height=600');
      if (w) {
        w.document.write(${_jsEscape(receiptHtml)});
        w.document.close();
        setTimeout(function() { w.print(); }, 600);
        setTimeout(function() { w.close(); }, 2000);
      }
    ''']);
  }

  static String _jsEscape(String html) {
    final escaped = html
        .replaceAll('\\', '\\\\')
        .replaceAll("'", "\\'")
        .replaceAll('\n', '\\n')
        .replaceAll('\r', '');
    return "'$escaped'";
  }

  static String _buildReceiptHtml({
    required SaleModel sale,
    required String shopName,
    required String shopAddress,
    required String shopPhone,
    required String shopLogo,
    required String footerText,
    required double cashPaid,
    required double upiPaid,
  }) {
    final date = sale.createdAt;
    final dateStr = '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    final timeStr = '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    final totalPaid = cashPaid + upiPaid;
    final pendingDue = (sale.total - totalPaid).clamp(0.0, double.infinity);
    final discountAmt = sale.discount;
    final discountPct = sale.discountPercent;

    final itemRows = sale.items.map((item) =>
      '<tr><td style="text-align:left;padding:2px 0;">${item.name}</td>'
      '<td style="text-align:center;padding:2px 0;">${item.quantity}</td>'
      '<td style="text-align:right;padding:2px 0;">${Formatters.currency(item.price * item.quantity)}</td></tr>'
    ).join('');

    final logoHtml = shopLogo.isNotEmpty
        ? '<img src="$shopLogo" style="max-width:60px;max-height:60px;margin-bottom:4px;" />'
        : '';

    final discountRow = discountAmt > 0
        ? '<tr><td>Discount (${discountPct.toStringAsFixed(discountPct.truncateToDouble() == discountPct ? 0 : 1)}%)</td><td style="text-align:right;">-${Formatters.currency(discountAmt)}</td></tr>'
        : '';

    final paymentRows = StringBuffer();
    if (totalPaid > 0) {
      paymentRows.write('<div class="divider"></div><table>');
      if (cashPaid > 0) paymentRows.write('<tr><td>Cash Paid</td><td style="text-align:right;">${Formatters.currency(cashPaid)}</td></tr>');
      if (upiPaid > 0) paymentRows.write('<tr><td>UPI/Card</td><td style="text-align:right;">${Formatters.currency(upiPaid)}</td></tr>');
      if (pendingDue > 0) paymentRows.write('<tr style="font-weight:bold;"><td>Pending Due</td><td style="text-align:right;">${Formatters.currency(pendingDue)}</td></tr>');
      paymentRows.write('</table>');
    }

    return '<!DOCTYPE html><html><head><meta charset="UTF-8"><title>Receipt</title>'
        '<style>@page{size:80mm auto;margin:0;}@media print{body{margin:0;}}'
        '*{margin:0;padding:0;box-sizing:border-box;}'
        'body{font-family:"Courier New",monospace;font-size:12px;width:80mm;padding:8px;color:#000;}'
        '.center{text-align:center;}.bold{font-weight:bold;}'
        '.divider{border-top:1px dashed #000;margin:6px 0;}'
        'table{width:100%;border-collapse:collapse;}'
        '.shop-name{font-size:16px;font-weight:bold;}'
        '.total-row{font-size:14px;font-weight:bold;}'
        '.footer{font-size:10px;margin-top:8px;}'
        '</style></head><body>'
        '<div class="center">$logoHtml<div class="shop-name">$shopName</div>'
        '${shopAddress.isNotEmpty ? "<div>$shopAddress</div>" : ""}'
        '${shopPhone.isNotEmpty ? "<div>Ph: $shopPhone</div>" : ""}</div>'
        '<div class="divider"></div>'
        '<div><div class="bold">${sale.invoiceNumber}</div>'
        '<div>Date: $dateStr $timeStr</div>'
        '${sale.customerName.isNotEmpty ? "<div>Customer: ${sale.customerName}</div>" : ""}'
        '${sale.customerPhone.isNotEmpty ? "<div>Phone: ${sale.customerPhone}</div>" : ""}</div>'
        '<div class="divider"></div>'
        '<table><tr style="font-weight:bold;"><td>Item</td><td style="text-align:center;">Qty</td><td style="text-align:right;">Amt</td></tr>$itemRows</table>'
        '<div class="divider"></div>'
        '<table><tr><td>Subtotal</td><td style="text-align:right;">${Formatters.currency(sale.subtotal)}</td></tr>'
        '$discountRow'
        '<tr class="total-row"><td>TOTAL</td><td style="text-align:right;">${Formatters.currency(sale.total)}</td></tr></table>'
        '${paymentRows.toString()}'
        '<div class="divider"></div>'
        '<div class="center footer"><div>$footerText</div><div>Returns within 7 days with invoice</div></div>'
        '</body></html>';
  }
}
