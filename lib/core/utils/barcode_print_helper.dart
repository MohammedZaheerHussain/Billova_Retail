// ignore: avoid_web_libraries_in_flutter
import 'dart:js' as js;
import 'package:flutter/material.dart';
import '../../data/models/item_model.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import 'formatters.dart';

/// Item payload for batch barcode printing
class BarcodePrintItem {
  final String name;
  final String barcode;
  final double price;
  final String size;
  final String color;
  final int quantity;

  const BarcodePrintItem({
    required this.name,
    required this.barcode,
    required this.price,
    this.size = '',
    this.color = '',
    required this.quantity,
  });

  factory BarcodePrintItem.fromItemModel(ItemModel item, {int? count}) {
    return BarcodePrintItem(
      name: item.name,
      barcode: item.barcode,
      price: item.price,
      size: item.size,
      color: item.color,
      quantity: count ?? (item.quantity > 0 ? item.quantity : 1),
    );
  }
}

/// Centralized Barcode Printing Engine supporting Single & Bulk Inward Batches
class BarcodePrintHelper {
  BarcodePrintHelper._();

  /// Show dialog and print labels for a single item
  static void printSingleItem(BuildContext context, ItemModel item) {
    if (item.barcode.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⚠️ This item does not have a barcode')),
      );
      return;
    }

    int count = item.quantity > 0 ? item.quantity : 10;
    String selectedFormat = 'zebra2up'; // 'zebra2up' | 'zebra1up' | 'zebra4x2' | 'a4'
    final qtyCtrl = TextEditingController(text: '$count');

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppColors.card(dialogCtx),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.qr_code_2_rounded, color: AppColors.accent, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Print Barcode Labels',
                      style: AppTypography.h4.copyWith(color: AppColors.textPrimary(dialogCtx), fontSize: 16)),
                  Text('${item.name} (${item.barcode})',
                      style: AppTypography.labelSmall.copyWith(color: AppColors.textTertiary(dialogCtx)),
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ]),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Number of Labels',
                      style: TextStyle(color: AppColors.textSecondary(dialogCtx), fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(
                      child: TextField(
                        controller: qtyCtrl,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.w700, fontSize: 18),
                        onChanged: (val) {
                          final parsed = int.tryParse(val);
                          if (parsed != null && parsed > 0) count = parsed;
                        },
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: AppColors.surface(dialogCtx),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: AppColors.cardBorder(dialogCtx)),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _quickQtyChip('2', 2, () { setDialogState(() { count = 2; qtyCtrl.text = '2'; }); }),
                    const SizedBox(width: 4),
                    _quickQtyChip('10', 10, () { setDialogState(() { count = 10; qtyCtrl.text = '10'; }); }),
                    const SizedBox(width: 4),
                    _quickQtyChip('Stock (${item.quantity})', item.quantity > 0 ? item.quantity : 1, () {
                      setDialogState(() {
                        count = item.quantity > 0 ? item.quantity : 1;
                        qtyCtrl.text = '$count';
                      });
                    }),
                  ]),
                  const SizedBox(height: 16),

                  Text('Printer & Label Format',
                      style: TextStyle(color: AppColors.textSecondary(dialogCtx), fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface(dialogCtx),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.cardBorder(dialogCtx)),
                    ),
                    child: Column(
                      children: [
                        _formatRadioTile(
                          value: 'zebra2up',
                          groupValue: selectedFormat,
                          title: 'Zebra 2-Up Roll (50×25mm × 2 across)',
                          subtitle: '⭐ Default for ZD220 Dual Sticker Roll',
                          onChanged: (v) => setDialogState(() => selectedFormat = v!),
                        ),
                        const Divider(height: 1),
                        _formatRadioTile(
                          value: 'zebra1up',
                          groupValue: selectedFormat,
                          title: 'Zebra 1-Up Roll (50×25mm / 2"×1")',
                          subtitle: 'Single column continuous sticker roll',
                          onChanged: (v) => setDialogState(() => selectedFormat = v!),
                        ),
                        const Divider(height: 1),
                        _formatRadioTile(
                          value: 'zebra4x2',
                          groupValue: selectedFormat,
                          title: 'Zebra 1-Up Large (100×50mm / 4"×2")',
                          subtitle: 'Full width 4-inch shipping/box label',
                          onChanged: (v) => setDialogState(() => selectedFormat = v!),
                        ),
                        const Divider(height: 1),
                        _formatRadioTile(
                          value: 'a4',
                          groupValue: selectedFormat,
                          title: 'A4 Sheet (3×8 Grid - 24 Labels)',
                          subtitle: 'Standard desktop laser/inkjet sheet paper',
                          onChanged: (v) => setDialogState(() => selectedFormat = v!),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: Text('Cancel', style: TextStyle(color: AppColors.textTertiary(dialogCtx))),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(dialogCtx);
                final finalQty = (int.tryParse(qtyCtrl.text) ?? count).clamp(1, 500);
                doPrintBatch([
                  BarcodePrintItem.fromItemModel(item, count: finalQty)
                ], title: '${item.name} ($finalQty labels)', format: selectedFormat);
              },
              icon: const Icon(Icons.print_rounded, size: 16),
              label: const Text('Print Labels'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Show dialog and print labels for a batch of items (e.g., from Purchase Inwarding)
  static void printBatchItems(BuildContext context, {required String title, required List<BarcodePrintItem> items}) {
    final validItems = items.where((i) => i.barcode.isNotEmpty && i.quantity > 0).toList();
    if (validItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⚠️ No items with valid barcodes to print in this batch')),
      );
      return;
    }

    final totalLabels = validItems.fold<int>(0, (sum, i) => sum + i.quantity);
    String selectedFormat = 'zebra2up';

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppColors.card(dialogCtx),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.receipt_long_rounded, color: AppColors.accent, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Print Inward Barcodes',
                      style: AppTypography.h4.copyWith(color: AppColors.textPrimary(dialogCtx), fontSize: 16)),
                  Text('$title • $totalLabels stickers across ${validItems.length} items',
                      style: AppTypography.labelSmall.copyWith(color: AppColors.textTertiary(dialogCtx)),
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ]),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surface(dialogCtx),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.cardBorder(dialogCtx)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Items in this Batch', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                            Text('$totalLabels Labels Total', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.accent)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ...validItems.map((it) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  it.size.isNotEmpty ? '${it.name} (SZ: ${it.size})' : it.name,
                                  style: TextStyle(color: AppColors.textPrimary(dialogCtx), fontSize: 12),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.accent.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '×${it.quantity}',
                                  style: const TextStyle(color: AppColors.accent, fontSize: 11, fontWeight: FontWeight.w700),
                                ),
                              ),
                            ],
                          ),
                        )),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  Text('Printer & Label Format',
                      style: TextStyle(color: AppColors.textSecondary(dialogCtx), fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface(dialogCtx),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.cardBorder(dialogCtx)),
                    ),
                    child: Column(
                      children: [
                        _formatRadioTile(
                          value: 'zebra2up',
                          groupValue: selectedFormat,
                          title: 'Zebra 2-Up Roll (50×25mm × 2 across)',
                          subtitle: '⭐ Default for ZD220 Dual Sticker Roll',
                          onChanged: (v) => setDialogState(() => selectedFormat = v!),
                        ),
                        const Divider(height: 1),
                        _formatRadioTile(
                          value: 'zebra1up',
                          groupValue: selectedFormat,
                          title: 'Zebra 1-Up Roll (50×25mm / 2"×1")',
                          subtitle: 'Single column continuous sticker roll',
                          onChanged: (v) => setDialogState(() => selectedFormat = v!),
                        ),
                        const Divider(height: 1),
                        _formatRadioTile(
                          value: 'zebra4x2',
                          groupValue: selectedFormat,
                          title: 'Zebra 1-Up Large (100×50mm / 4"×2")',
                          subtitle: 'Full width 4-inch shipping/box label',
                          onChanged: (v) => setDialogState(() => selectedFormat = v!),
                        ),
                        const Divider(height: 1),
                        _formatRadioTile(
                          value: 'a4',
                          groupValue: selectedFormat,
                          title: 'A4 Sheet (3×8 Grid - 24 Labels)',
                          subtitle: 'Standard desktop laser/inkjet sheet paper',
                          onChanged: (v) => setDialogState(() => selectedFormat = v!),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: Text('Cancel', style: TextStyle(color: AppColors.textTertiary(dialogCtx))),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(dialogCtx);
                doPrintBatch(validItems, title: title, format: selectedFormat);
              },
              icon: const Icon(Icons.print_rounded, size: 16),
              label: Text('Print All ($totalLabels) Labels'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Internal print execution engine
  static void doPrintBatch(List<BarcodePrintItem> items, {required String title, String format = 'zebra2up'}) {
    // Flatten all items into expanded list of single label representations
    final List<BarcodePrintItem> labelQueue = [];
    for (final it in items) {
      for (int q = 0; q < it.quantity; q++) {
        labelQueue.add(it);
      }
    }

    if (labelQueue.isEmpty) return;

    final totalCount = labelQueue.length;
    final labelsHtml = StringBuffer();
    final barcodeJs = StringBuffer();

    final barWidth = format == 'zebra4x2' ? 2.5 : 1.6;
    final barHeight = format == 'zebra4x2' ? 52 : 36;
    final fontSize = format == 'zebra4x2' ? 14 : 10;

    if (format == 'zebra2up') {
      // 2 labels per row on 104mm roll (50x25mm each)
      for (int i = 0; i < totalCount; i += 2) {
        final left = labelQueue[i];
        final leftName = left.name.replaceAll('\\', '\\\\').replaceAll("'", "\\'").replaceAll('"', '&quot;').replaceAll('\n', ' ');
        final leftBarcode = left.barcode.replaceAll('\\', '\\\\').replaceAll("'", "\\'").replaceAll('"', '\\"');
        final leftPrice = Formatters.currency(left.price).replaceAll("'", "\\'").replaceAll('"', '\\"');
        final leftSize = (left.size.toLowerCase() == 'multi') ? '' : left.size.replaceAll("'", "\\'").replaceAll('"', '\\"');

        labelsHtml.write('<div class="row-2up">');
        // Left label
        labelsHtml.write(
          '<div class="label-2up">'
          '<div class="shop">SKYWALK</div>'
          '<div class="item-name">$leftName</div>'
          '<div class="bc-wrap"><svg id="bc$i" class="barcode-svg"></svg></div>'
          '<div class="footer-row">'
          '${leftSize.isNotEmpty ? '<span class="size">$leftSize</span>' : '<span></span>'}'
          '<span class="price">MRP: $leftPrice</span>'
          '</div></div>'
        );
        barcodeJs.write('JsBarcode("#bc$i","$leftBarcode",{format:"CODE128",width:$barWidth,height:$barHeight,displayValue:true,fontSize:$fontSize,fontOptions:"bold",font:"monospace",textMargin:1,margin:0,background:"#ffffff",lineColor:"#000000"});');

        // Right label (if exists)
        if (i + 1 < totalCount) {
          final nextIdx = i + 1;
          final right = labelQueue[nextIdx];
          final rightName = right.name.replaceAll('\\', '\\\\').replaceAll("'", "\\'").replaceAll('"', '&quot;').replaceAll('\n', ' ');
          final rightBarcode = right.barcode.replaceAll('\\', '\\\\').replaceAll("'", "\\'").replaceAll('"', '\\"');
          final rightPrice = Formatters.currency(right.price).replaceAll("'", "\\'").replaceAll('"', '\\"');
          final rightSize = (right.size.toLowerCase() == 'multi') ? '' : right.size.replaceAll("'", "\\'").replaceAll('"', '\\"');

          labelsHtml.write(
            '<div class="label-2up">'
            '<div class="shop">SKYWALK</div>'
            '<div class="item-name">$rightName</div>'
            '<div class="bc-wrap"><svg id="bc$nextIdx" class="barcode-svg"></svg></div>'
            '<div class="footer-row">'
            '${rightSize.isNotEmpty ? '<span class="size">$rightSize</span>' : '<span></span>'}'
            '<span class="price">MRP: $rightPrice</span>'
            '</div></div>'
          );
          barcodeJs.write('JsBarcode("#bc$nextIdx","$rightBarcode",{format:"CODE128",width:$barWidth,height:$barHeight,displayValue:true,fontSize:$fontSize,fontOptions:"bold",font:"monospace",textMargin:1,margin:0,background:"#ffffff",lineColor:"#000000"});');
        } else {
          // Empty slot placeholder for odd count
          labelsHtml.write('<div class="label-2up empty-slot"></div>');
        }
        labelsHtml.write('</div>');
      }
    } else {
      // Single continuous roll or A4
      for (int i = 0; i < totalCount; i++) {
        final item = labelQueue[i];
        final itemName = item.name.replaceAll('\\', '\\\\').replaceAll("'", "\\'").replaceAll('"', '&quot;').replaceAll('\n', ' ');
        final itemBarcode = item.barcode.replaceAll('\\', '\\\\').replaceAll("'", "\\'").replaceAll('"', '\\"');
        final itemPrice = Formatters.currency(item.price).replaceAll("'", "\\'").replaceAll('"', '\\"');
        final itemSize = (item.size.toLowerCase() == 'multi') ? '' : item.size.replaceAll("'", "\\'").replaceAll('"', '\\"');

        if (format == 'zebra1up') {
          labelsHtml.write(
            '<div class="label-1up">'
            '<div class="shop">SKYWALK</div>'
            '<div class="item-name">$itemName</div>'
            '<div class="bc-wrap"><svg id="bc$i" class="barcode-svg"></svg></div>'
            '<div class="footer-row">'
            '${itemSize.isNotEmpty ? '<span class="size">$itemSize</span>' : '<span></span>'}'
            '<span class="price">MRP: $itemPrice</span>'
            '</div></div>'
          );
          barcodeJs.write('JsBarcode("#bc$i","$itemBarcode",{format:"CODE128",width:$barWidth,height:$barHeight,displayValue:true,fontSize:$fontSize,fontOptions:"bold",font:"monospace",textMargin:1,margin:0,background:"#ffffff",lineColor:"#000000"});');
        } else if (format == 'zebra4x2') {
          labelsHtml.write(
            '<div class="label-4x2">'
            '<div class="shop-lg">SKYWALK</div>'
            '<div class="item-name-lg">$itemName</div>'
            '<div class="bc-wrap-lg"><svg id="bc$i" class="barcode-svg-lg"></svg></div>'
            '<div class="footer-row-lg">'
            '${itemSize.isNotEmpty ? '<span class="size-lg">Size: $itemSize</span>' : '<span></span>'}'
            '<span class="price-lg">MRP: $itemPrice</span>'
            '</div></div>'
          );
          barcodeJs.write('JsBarcode("#bc$i","$itemBarcode",{format:"CODE128",width:$barWidth,height:$barHeight,displayValue:true,fontSize:$fontSize,fontOptions:"bold",font:"monospace",textMargin:1,margin:0,background:"#ffffff",lineColor:"#000000"});');
        } else {
          // A4 Sheet Grid
          labelsHtml.write(
            '<div class="label-a4">'
            '<div class="shop">SKYWALK</div>'
            '<div class="item-name">$itemName</div>'
            '<div class="bc-wrap"><svg id="bc$i" class="barcode-svg"></svg></div>'
            '<div class="footer-row">'
            '${itemSize.isNotEmpty ? '<span class="size">$itemSize</span>' : '<span></span>'}'
            '<span class="price">MRP: $itemPrice</span>'
            '</div></div>'
          );
          barcodeJs.write('JsBarcode("#bc$i","$itemBarcode",{format:"CODE128",width:$barWidth,height:$barHeight,displayValue:true,fontSize:$fontSize,fontOptions:"bold",font:"monospace",textMargin:1,margin:0,background:"#ffffff",lineColor:"#000000"});');
        }
      }
    }

    String cssRules = '';
    if (format == 'zebra2up') {
      cssRules = '''
        @page { size: 104mm 25mm; margin: 0; }
        @media print { body { margin: 0; padding: 0; background: #fff; } .no-print { display: none !important; } }
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Arial, sans-serif; background: #f0f2f5; color: #000; }
        .sheet { width: 104mm; margin: 0 auto; background: #fff; }
        .row-2up { width: 104mm; height: 25mm; display: flex; flex-direction: row; justify-content: space-between; align-items: stretch; page-break-after: always; break-after: page; padding: 0.5mm 1.5mm; overflow: hidden; }
        .label-2up { width: 49.5mm; height: 24mm; display: flex; flex-direction: column; align-items: center; justify-content: space-between; text-align: center; padding: 0.8mm 1mm; overflow: hidden; }
        .empty-slot { visibility: hidden; }
        .shop { font-size: 8.5px; font-weight: 900; letter-spacing: 0.6px; line-height: 1; text-transform: uppercase; }
        .item-name { font-size: 7.5px; font-weight: 700; max-width: 96%; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; line-height: 1; }
        .bc-wrap { width: 100%; display: flex; justify-content: center; align-items: center; }
        svg.barcode-svg { max-width: 100%; height: 13.5mm; display: block; margin: 0 auto; shape-rendering: crispEdges; }
        .footer-row { width: 96%; display: flex; justify-content: space-between; align-items: center; font-size: 8px; line-height: 1; }
        .size { font-size: 7.5px; font-weight: 700; line-height: 1; }
        .price { font-size: 8.5px; font-weight: 900; letter-spacing: 0.6px; line-height: 1; text-transform: uppercase; }
      ''';
    } else if (format == 'zebra1up') {
      cssRules = '''
        @page { size: 50mm 25mm; margin: 0; }
        @media print { body { margin: 0; padding: 0; background: #fff; } .no-print { display: none !important; } }
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Arial, sans-serif; background: #f0f2f5; color: #000; }
        .sheet { width: 50mm; margin: 0 auto; background: #fff; }
        .label-1up { width: 50mm; height: 25mm; display: flex; flex-direction: column; align-items: center; justify-content: space-between; text-align: center; padding: 0.8mm 1.5mm; page-break-after: always; break-after: page; overflow: hidden; }
        .shop { font-size: 8.5px; font-weight: 900; letter-spacing: 0.6px; line-height: 1; text-transform: uppercase; }
        .item-name { font-size: 7.5px; font-weight: 700; max-width: 96%; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; line-height: 1; }
        .bc-wrap { width: 100%; display: flex; justify-content: center; align-items: center; }
        svg.barcode-svg { max-width: 100%; height: 13.5mm; display: block; margin: 0 auto; shape-rendering: crispEdges; }
        .footer-row { width: 96%; display: flex; justify-content: space-between; align-items: center; font-size: 8px; line-height: 1; }
        .size { font-size: 7.5px; font-weight: 700; line-height: 1; }
        .price { font-size: 8.5px; font-weight: 900; letter-spacing: 0.6px; line-height: 1; text-transform: uppercase; }
      ''';
    } else if (format == 'zebra4x2') {
      cssRules = '''
        @page { size: 100mm 50mm; margin: 0; }
        @media print { body { margin: 0; padding: 0; background: #fff; } .no-print { display: none !important; } }
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Arial, sans-serif; background: #f0f2f5; color: #000; }
        .sheet { width: 100mm; margin: 0 auto; background: #fff; }
        .label-4x2 { width: 100mm; height: 50mm; display: flex; flex-direction: column; align-items: center; justify-content: space-between; text-align: center; padding: 2mm 3mm; page-break-after: always; break-after: page; overflow: hidden; }
        .shop-lg { font-size: 14px; font-weight: 900; letter-spacing: 1px; line-height: 1.1; text-transform: uppercase; }
        .item-name-lg { font-size: 12px; font-weight: 700; max-width: 96%; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; line-height: 1.1; }
        .bc-wrap-lg { width: 100%; display: flex; justify-content: center; align-items: center; }
        svg.barcode-svg-lg { max-width: 100%; height: 28mm; display: block; margin: 0 auto; shape-rendering: crispEdges; }
        .footer-row-lg { width: 96%; display: flex; justify-content: space-between; align-items: center; font-size: 13px; line-height: 1.1; }
        .size-lg { font-size: 12px; font-weight: 700; }
        .price-lg { font-size: 14px; font-weight: 900; letter-spacing: 1px; line-height: 1.1; text-transform: uppercase; }
      ''';
    } else {
      cssRules = '''
        @page { size: A4; margin: 8mm 6mm; }
        @media print { body { margin: 0; padding: 0; background: #fff; } .no-print { display: none !important; } }
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Arial, sans-serif; background: #f0f2f5; color: #000; }
        .sheet { max-width: 100%; margin: 0 auto; background: #fff; }
        .grid-a4 { display: grid; grid-template-columns: repeat(3, 1fr); gap: 2mm 3mm; padding: 4mm; }
        .label-a4 { border: 1px dashed #bbb; padding: 2mm; height: 32mm; display: flex; flex-direction: column; align-items: center; justify-content: space-between; text-align: center; }
        .shop { font-size: 8.5px; font-weight: 900; letter-spacing: 0.6px; line-height: 1; text-transform: uppercase; }
        .item-name { font-size: 7.5px; font-weight: 700; max-width: 96%; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; line-height: 1; }
        .bc-wrap { width: 100%; display: flex; justify-content: center; align-items: center; }
        svg.barcode-svg { max-width: 100%; height: 13.5mm; display: block; margin: 0 auto; shape-rendering: crispEdges; }
        .footer-row { width: 96%; display: flex; justify-content: space-between; align-items: center; font-size: 8px; line-height: 1; }
        .size { font-size: 7.5px; font-weight: 700; line-height: 1; }
        .price { font-size: 8.5px; font-weight: 900; letter-spacing: 0.6px; line-height: 1; text-transform: uppercase; }
      ''';
    }

    final containerClass = format == 'a4' ? 'grid-a4' : 'sheet';
    final safeTitle = title.replaceAll('\\', '\\\\').replaceAll("'", "\\'").replaceAll('"', '\\"').replaceAll('\n', ' ');

    js.context.callMethod('eval', [
      '''
      var w = window.open('', '_blank', 'width=840,height=900');
      if (w) {
        var html = '<!DOCTYPE html><html><head><meta charset="utf-8"><title>$totalCount Labels - $safeTitle</title>';
        html += '<script src="https://cdn.jsdelivr.net/npm/jsbarcode@3.11.6/dist/JsBarcode.all.min.js"></script>';
        html += '<style>';
        html += '${cssRules.replaceAll('\n', ' ').replaceAll("'", "\\'")}';
        html += '.no-print{text-align:center;padding:12px;background:#1E293B;color:#fff;border-bottom:1px solid #334155;display:flex;justify-content:center;gap:12px;align-items:center}';
        html += '.print-btn{background:#06B6D4;color:#fff;border:none;padding:10px 24px;border-radius:8px;font-size:14px;font-weight:bold;cursor:pointer;display:inline-flex;align-items:center;gap:6px;}';
        html += '.print-btn:hover{background:#0891B2}';
        html += '.badge{background:#0F172A;color:#94A3B8;padding:6px 14px;border-radius:8px;font-size:12px;font-weight:600;border:1px solid #334155;}';
        html += '</style></head><body>';
        html += '<div class="no-print"><span class="badge">$totalCount labels • Zebra 203 DPI Optimized</span><button class="print-btn" onclick="window.print()">🖨 Print All Labels</button></div>';
        html += '<div class="$containerClass">';
        html += '${labelsHtml.toString().replaceAll("'", "\\'")}';
        html += '</div>';
        html += '<script>';
        html += '${barcodeJs.toString().replaceAll("'", "\\'")}';
        html += 'setTimeout(function(){window.print();},600);';
        html += '</script>';
        html += '</body></html>';
        w.document.write(html);
        w.document.close();
      }
      '''
    ]);
  }

  static Widget _quickQtyChip(String label, int val, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
        ),
        child: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.accent)),
      ),
    );
  }

  static Widget _formatRadioTile({
    required String value,
    required String groupValue,
    required String title,
    required String subtitle,
    required ValueChanged<String?> onChanged,
  }) {
    final isSelected = value == groupValue;
    return InkWell(
      onTap: () => onChanged(value),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          children: [
            Radio<String>(
              value: value,
              groupValue: groupValue,
              onChanged: onChanged,
              activeColor: AppColors.accent,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontSize: 12, fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500)),
                  Text(subtitle, style: TextStyle(fontSize: 10, color: isSelected ? AppColors.accent : Colors.grey)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
