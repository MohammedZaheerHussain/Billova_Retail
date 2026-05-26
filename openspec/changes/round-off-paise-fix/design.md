# Round-Off Paise Fix — Design Document

## Problem Statement

When a percentage discount produces a fractional rupee amount, the discount and
bill total end up with paise (e.g., ₹1,000.50 instead of ₹1,000). This is
non-standard for Indian retail where all transactions are in whole rupees.

### Root Cause Analysis

The previous "paise drift fix" solved floating-point **dust** (e.g., 499.999999),
but did NOT solve **legitimate fractional amounts** from percentage math:

```
Subtotal = ₹1,500
Discount % = 33.3%
discountAmount = 1500 × 33.3 / 100 = ₹499.50  ← legitimate .50 paise
total = 1500 - 499.50 = ₹1,000.50  ← fractional total saved to DB
```

The discount getter currently rounds to **2 decimal places**, but the business
needs rounding to **whole rupees** (0 decimal places).

### Data Flow (Current — BUGGY for percentages)

```
User enters % discount
  → discountAmount = subtotal × pct / 100  → round to 2dp  ← CAN HAVE PAISE
  → total = subtotal - discountAmount → round to 2dp  ← CAN HAVE PAISE
  → completeSale() stores total/discount as-is in DB
  → Bill History reads from DB and displays the stored paise values
  → Receipt printer reads from DB and prints the stored paise values
```

### Data Flow (Fixed)

```
User enters % discount
  → discountAmount = subtotal × pct / 100  → round to WHOLE RUPEE  ← ALWAYS WHOLE
  → total = subtotal - discountAmount  ← ALWAYS WHOLE (since both operands are whole)
  → completeSale() stores whole-rupee values in DB
  → Bill History shows clean whole-rupee amounts
  → Receipt printer prints clean whole-rupee amounts
```

## Solution

### 1. Round discount to whole rupees (root cause fix)

**File:** `lib/providers/sales_provider.dart`

Change `discountAmount` getter from 2dp rounding to whole-rupee rounding.
Add a final `round()` on `saleGrandTotal` in `completeSale()` as safety net.

### 2. Round displayed amounts in Bill History (cosmetic fix for OLD bills)

**File:** `lib/screens/bill_history/bill_history_screen.dart`

For old bills already stored with paise, round at display time so the list
looks clean. The stored data is not modified (audit trail preserved).

### 3. Receipt printer uses stored values (already correct)

**File:** `lib/core/utils/receipt_printer.dart`

The receipt already uses `sale.total` and `sale.discount` (stored values).
New bills will have whole values. No code change needed here — the fix in
step 1 ensures new values are whole at source.

## Files Changed

| File | Change |
|------|--------|
| `lib/providers/sales_provider.dart` | Round discount to whole ₹, safety-round grandTotal |
| `lib/screens/bill_history/bill_history_screen.dart` | Round display for old bills |
| `lib/screens/bill_history/bill_detail_screen.dart` | Round display in detail view |

## Validation Scenario

```
Subtotal = ₹1,500, Discount = 33.3%

BEFORE: discount = ₹499.50, total = ₹1,000.50  ❌
AFTER:  discount = ₹500,    total = ₹1,000     ✅

Subtotal = ₹999, Discount = 10%

BEFORE: discount = ₹99.90, total = ₹899.10  ❌
AFTER:  discount = ₹100,   total = ₹899     ✅
```
