## Why

Discount amounts entered during billing are not reflected in dashboard analytics (Total Sales, Weekly Sales, Today's Profit, Sales by Payment). The system stores `sale.total` correctly as the post-discount amount, but the **payment distribution** (`_getPaymentDistribution`) uses raw `cash_amount`/`upi_amount` fields which contain pre-discount values entered by the user. Additionally, the flat-to-percentage discount conversion introduces floating-point rounding errors (e.g., ₹100 becomes ₹100.05).

## What Changes

- **Fix discount rounding**: Round flat discount amounts to 2 decimal places before applying, eliminating ₹100 → ₹100.05 drift
- **Fix payment amount auto-calculation**: When payment mode is single (Cash-only or UPI-only), auto-set the payment amount to `sale.total` instead of relying on user input
- **Fix payment distribution dashboard**: Use `sale.total` as the source of truth for payment distribution instead of raw `cash_amount + upi_amount` (which may exceed the actual bill)
- **Fix weekly sales calculation**: Ensure weekly revenue sums use `sale.total` (post-discount) consistently
- **Add payment amount validation**: Ensure `cash_amount + upi_amount + card_amount` never exceeds `sale.total`

## Capabilities

### New Capabilities
- `discount-accuracy`: Ensures discount calculations use precise 2-decimal rounding and payment amounts are auto-calculated from the post-discount total

### Modified Capabilities
_(none — no existing specs)_

## Impact

- **Providers affected**: `SalesProvider` (discount rounding, payment amount calculation)
- **Screens affected**: `DashboardScreen` (_getPaymentDistribution, weekly revenue), `SalesTerminalScreen` (auto-fill payment fields)
- **Database**: No schema changes — `sale.total` is already stored correctly as post-discount
- **Cloud sync**: No impact — the fix is in calculation/display logic only
- **Data isolation**: No impact
