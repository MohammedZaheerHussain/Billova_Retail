## 1. Fix Discount Rounding in SalesProvider

- [x] 1.1 Round `discountAmount` getter to 2 decimal places in `SalesProvider` (`lib/providers/sales_provider.dart` line 100)
- [x] 1.2 Round `discountAmount` passed to `SaleModel` in `completeSale()` to 2 decimal places

## 2. Fix Payment Amount Auto-Calculation

- [x] 2.1 In `completeSale()`, auto-set payment amounts for single-method payments: if only UPI, set `upiAmount = sale.total`; if only Cash, set `cashAmount = sale.total`; if only Card, set `cardAmount = sale.total`
- [x] 2.2 For split payments, validate that `cashAmount + upiAmount + cardAmount` equals `sale.total` — adjust proportionally if they don't match

## 3. Fix Dashboard Payment Distribution

- [x] 3.1 In `_getPaymentDistribution()` (`dashboard_screen.dart` line 216), cap per-sale payment contributions to `sale.total` to prevent legacy data overshoot
- [x] 3.2 Verify `todaySalesTotal()` and weekly revenue calculations use `sale.total` (post-discount) — confirmed, no changes needed

## 4. Build, Test & Deploy

- [x] 4.1 Build web release and verify no compilation errors
- [x] 4.2 Commit, push to main/zaheer/Ashiq branches
