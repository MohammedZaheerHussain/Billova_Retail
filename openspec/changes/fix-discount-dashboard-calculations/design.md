## Context

The Billova Retail system has a discount flow where the user enters a flat rupee amount (e.g., ₹100), which is internally converted to a percentage of the subtotal. This percentage is then used to compute `discountAmount`. The `sale.total` is correctly stored as `subtotal - discountAmount + GST`. However, the **dashboard payment distribution** reads raw `cash_amount`/`upi_amount`/`card_amount` fields which may not reflect the discount. Additionally, `todaySalesTotal()` and weekly revenue DB queries sum `sale.total` directly, which is correct — but the payment fields create an inconsistency in the "Sales by Payment" chart.

**Current data flow:**
```
User enters ₹100 discount for ₹1150 bill
→ discountPercent = (100/1150)*100 = 8.6957% (stored)
→ discountAmount = 1150 * 8.6957/100 = 100.0005 (displayed as 100.05)
→ sale.total = 1150 - 100.0005 = 1049.9995 (correct, stored)
→ upiAmount = 1150 (WRONG — user entered pre-discount amount)
→ Dashboard UPI = 1150 (WRONG — should be ~1050)
```

## Goals / Non-Goals

**Goals:**
- Eliminate floating-point rounding errors in flat discount conversion
- Auto-set payment amounts to match `sale.total` for single-method payments
- Ensure dashboard "Sales by Payment" reflects post-discount amounts
- Ensure all dashboard metrics (Total Sales, Weekly Sales, Today's Profit) use post-discount totals consistently

**Non-Goals:**
- Changing the database schema (no migrations needed)
- Modifying the split-payment UI flow for multi-method payments
- Changing how GST is calculated

## Decisions

### Decision 1: Round discount to 2 decimal places
**Choice:** Apply `double.parse(amount.toStringAsFixed(2))` after computing `discountAmount` from the percentage.
**Rationale:** The root cause is double→percent→double conversion. Rounding at the final step eliminates drift. This is simpler than storing the flat amount separately and avoids schema changes.

### Decision 2: Auto-set payment amount for single-method payments
**Choice:** In `completeSale()`, when only one payment method is used (e.g., UPI-only), set `upiAmount = sale.total` instead of using the user-entered value.
**Rationale:** For single-method payments, the payment amount MUST equal the bill total — there's no other source. For split payments, the user-entered amounts are still used but validated.

### Decision 3: Cap payment amounts in the dashboard
**Choice:** In `_getPaymentDistribution()`, cap `cash + upi + card` to `sale.total` to prevent overshoot from legacy data.
**Rationale:** Legacy records may have `upi_amount > total`. The dashboard must never show more collected than billed. This is a defense-in-depth measure alongside Decision 2.

## Risks / Trade-offs

- **[Risk] Legacy records with wrong payment amounts** → Mitigation: Dashboard caps to `sale.total`; legacy data isn't modified (safe).
- **[Risk] Split payment totals might not add up** → Mitigation: Validate that `cash + upi + card == total` before saving; adjust proportionally if needed.
- **[Risk] Rounding edge case on very small bills** → Mitigation: `toStringAsFixed(2)` handles amounts down to ₹0.01 correctly.
