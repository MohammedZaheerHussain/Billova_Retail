# Tasks — Round-Off Paise Fix

## Task 1: Round discount to whole rupees in SalesProvider
- **File:** `lib/providers/sales_provider.dart`
- **Change:** `discountAmount` getter → round to nearest whole rupee (`.roundToDouble()`)
- **Change:** `completeSale()` → round `saleGrandTotal` to whole rupee as safety net
- **Status:** [ ] Not started

## Task 2: Round display amounts in Bill History for old bills
- **File:** `lib/screens/bill_history/bill_history_screen.dart`
- **Change:** Wrap `sale.total` and `sale.discount` display with `.roundToDouble()` 
- **Status:** [ ] Not started

## Task 3: Round display amounts in Bill Detail dialog
- **File:** `lib/screens/bill_history/bill_detail_screen.dart`
- **Change:** Round subtotal/discount/total display values
- **Status:** [ ] Not started

## Task 4: Verify receipt printer uses stored values
- **File:** `lib/core/utils/receipt_printer.dart`
- **Change:** Verify no recalculation — already uses stored values ✅
- **Status:** [ ] Not started

## Task 5: Build, test, deploy
- Verify `flutter build web --release` passes
- Push to all 3 branches
- **Status:** [ ] Not started
