# Udhar Bill History Fixes — Design Document

## Problem Statement

Udhar (credit) sales are not properly visible in Bill History. The "Credit"
filter doesn't match saved payment modes, Udhar bills have no visual badge,
and due amounts aren't shown on bill cards.

## Fixes

### Fix 1: Bill History filter mismatch
- Filter chip says "Credit" but bills are saved as `paymentMode = "Udhar"` or `"Partial"`
- **Solution:** Change filter chip label from "Credit" to "Udhar" and match both "Udhar" and "Partial" modes

### Fix 2: Udhar badge color in Bill History
- Bill cards show color-coded badges (green=Cash, blue=UPI, cyan=Card) but Udhar has no distinct color
- **Solution:** Add orange for "Udhar" and amber for "Partial" in `_paymentColor()`

### Fix 3: Round dueAmount to whole rupees
- `saleDueAmount` in completeSale() still uses toStringAsFixed(2) — can store paise
- **Solution:** Round to whole rupees like the discount/total fix

### Fix 4: Show due amount on Udhar bills in Bill History
- Owner can't see at a glance which bills have unpaid amounts
- **Solution:** Show "Due: ₹X" in orange on bill cards where dueAmount > 0

## Files Changed

| File | Change |
|------|--------|
| `lib/screens/bill_history/bill_history_screen.dart` | Filter label, badge colors, due amount display |
| `lib/providers/sales_provider.dart` | Round dueAmount, filter matching |
