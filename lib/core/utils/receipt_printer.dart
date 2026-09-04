// ignore: avoid_web_libraries_in_flutter
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
    // GST settings
    final gstEnabled = (await _db.getSetting('gst_enabled') ?? 'false') == 'true';
    final gstNumber = await _db.getSetting('gst_number') ?? '';
    final gstStateCode = await _db.getSetting('gst_state_code') ?? '';

    final receiptHtml = _buildReceiptHtml(
      sale: sale, shopName: shopName, shopAddress: shopAddress,
      shopPhone: shopPhone, shopLogo: shopLogo, footerText: footerText,
      cashPaid: cashPaid, upiPaid: upiPaid,
      gstEnabled: gstEnabled, gstNumber: gstNumber, gstStateCode: gstStateCode,
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
    bool gstEnabled = false,
    String gstNumber = '',
    String gstStateCode = '',
  }) {
    final date = sale.createdAt;
    final dateStr = '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    final timeStr = '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    final totalPaid = (cashPaid + upiPaid).roundToDouble();
    final pendingDue = (sale.total.roundToDouble() - totalPaid).clamp(0.0, double.infinity).roundToDouble();
    final discountAmt = sale.discount.roundToDouble();
    final discountPct = sale.discountPercent;

    // CRITICAL: Use stored item.total — do NOT recalculate price*qty (floating-point drift)
    // Round to whole rupees for clean thermal receipt
    final itemRows = sale.items.map((item) =>
      '<tr class="item-row"><td style="text-align:left;padding:2.5px 0;">${item.name}</td>'
      '<td style="text-align:center;padding:2.5px 0;">${item.quantity}</td>'
      '<td style="text-align:right;padding:2.5px 0;">${Formatters.currency(item.total.roundToDouble())}</td></tr>'
    ).join('');

    final logoHtml = shopLogo.isNotEmpty
        ? '<img src="$shopLogo" style="max-width:60px;max-height:60px;margin-bottom:4px;filter:contrast(150%);" />'
        : '';

    final discountRow = discountAmt > 0
        ? '<tr><td>Discount (${discountPct.toStringAsFixed(discountPct.truncateToDouble() == discountPct ? 0 : 1)}%)</td><td style="text-align:right;">-${Formatters.currency(discountAmt)}</td></tr>'
        : '';

    // GST rows — show only when enabled and GST amount > 0
    final gstRows = StringBuffer();
    if (gstEnabled && sale.gstAmount > 0) {
      gstRows.write('<tr><td>CGST</td><td style="text-align:right;">+${Formatters.currency(sale.cgst)}</td></tr>');
      gstRows.write('<tr><td>SGST</td><td style="text-align:right;">+${Formatters.currency(sale.sgst)}</td></tr>');
    }

    // GSTIN line in header
    final gstinHtml = (gstEnabled && gstNumber.isNotEmpty)
        ? '<div class="header-info">GSTIN: $gstNumber${gstStateCode.isNotEmpty ? ' | State: $gstStateCode' : ''}</div>'
        : '';

    final paymentRows = StringBuffer();
    if (totalPaid > 0) {
      paymentRows.write('<div class="divider"></div><table class="payment-table">');
      if (cashPaid > 0) paymentRows.write('<tr><td>Cash Paid</td><td style="text-align:right;">${Formatters.currency(cashPaid)}</td></tr>');
      if (upiPaid > 0) paymentRows.write('<tr><td>UPI/Card</td><td style="text-align:right;">${Formatters.currency(upiPaid)}</td></tr>');
      if (pendingDue > 0) paymentRows.write('<tr style="font-weight:900;"><td>Pending Due</td><td style="text-align:right;">${Formatters.currency(pendingDue)}</td></tr>');
      paymentRows.write('</table>');
    }

    return '<!DOCTYPE html><html><head><meta charset="UTF-8"><title>Receipt</title>'
        '<style>'
        '@page{size:80mm auto;margin:0;}'
        '@media print{'
        '  body{margin:0;-webkit-print-color-adjust:exact!important;print-color-adjust:exact!important;}'
        '}'
        '*{margin:0;padding:0;box-sizing:border-box;}'
        'body{'
        '  font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,Arial,sans-serif;'
        '  font-size:13px;'
        '  font-weight:700;'
        '  line-height:1.35;'
        '  width:80mm;'
        '  padding:5mm 4mm;'
        '  color:#000000!important;'
        '  background:#ffffff;'
        '  -webkit-text-stroke:0.35px #000000;'
        '  text-rendering:geometricPrecision;'
        '  -webkit-font-smoothing:antialiased;'
        '}'
        '.center{text-align:center;}'
        '.bold{font-weight:900;-webkit-text-stroke:0.45px #000000;}'
        '.divider{border-top:1.5px dashed #000000;margin:6px 0;}'
        'table{width:100%;border-collapse:collapse;}'
        'td{color:#000000!important;font-weight:700;}'
        '.shop-name{font-size:18px;font-weight:900;letter-spacing:0.5px;text-transform:uppercase;-webkit-text-stroke:0.5px #000000;line-height:1.2;margin-bottom:2px;}'
        '.header-info{font-size:11.5px;font-weight:700;line-height:1.3;}'
        '.invoice-info{font-size:12px;font-weight:700;line-height:1.35;}'
        '.table-header{font-weight:900;font-size:12.5px;-webkit-text-stroke:0.45px #000000;}'
        '.item-row td{font-size:12.5px;font-weight:700;padding:2.5px 0;}'
        '.summary-table td{font-size:12.5px;font-weight:700;padding:2px 0;}'
        '.total-row td{font-size:16px;font-weight:900;-webkit-text-stroke:0.55px #000000;padding:4px 0 2px 0;}'
        '.payment-table td{font-size:12.5px;font-weight:700;padding:2px 0;}'
        '.footer{font-size:10.5px;font-weight:700;line-height:1.35;margin-top:6px;-webkit-text-stroke:0.25px #000000;}'
        '</style></head><body>'
        '<div class="center">$logoHtml<div class="shop-name">$shopName</div>'
        '${shopAddress.isNotEmpty ? "<div class=\"header-info\">$shopAddress</div>" : ""}'
        '${shopPhone.isNotEmpty ? "<div class=\"header-info\">Ph: $shopPhone</div>" : ""}'
        '$gstinHtml</div>'
        '<div class="divider"></div>'
        '<div><div class="bold">${sale.invoiceNumber}</div>'
        '<div class="invoice-info">Date: $dateStr $timeStr</div>'
        '${sale.customerName.isNotEmpty ? "<div class=\"invoice-info\">Customer: ${sale.customerName}</div>" : ""}'
        '${sale.customerPhone.isNotEmpty ? "<div class=\"invoice-info\">Phone: ${sale.customerPhone}</div>" : ""}</div>'
        '<div class="divider"></div>'
        '<table><tr class="table-header"><td>Item</td><td style="text-align:center;">Qty</td><td style="text-align:right;">Amt</td></tr>$itemRows</table>'
        '<div class="divider"></div>'
        '<table class="summary-table"><tr><td>Subtotal</td><td style="text-align:right;">${Formatters.currency(sale.subtotal.roundToDouble())}</td></tr>'
        '$discountRow'
        '${gstRows.toString()}'
        '<tr class="total-row"><td>TOTAL</td><td style="text-align:right;">${Formatters.currency(sale.total.roundToDouble())}</td></tr></table>'
        '${paymentRows.toString()}'
        '<div class="divider"></div>'
        '<div class="center footer"><div>$footerText</div><div>Returns within 7 days with invoice</div></div>'
        '</body></html>';
  }
}
