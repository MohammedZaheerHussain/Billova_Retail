## Context

The Billova Retail system already has a working Udhar pattern for vendors (`VendorModel.balance`, `PurchaseModel.dueAmount`). We mirror this exact pattern for customers to keep the codebase consistent. The vendor pattern stores a running `balance` on the vendor model and per-purchase `due_amount`. Collections reduce the balance.

**Existing payment flow:**
```
Sales Terminal → cashAmount + upiAmount → completeSale() → SaleModel saved
```

**New flow with Udhar:**
```
Sales Terminal → [Udhar ON] → cashAmount + upiAmount (partial/zero)
→ due_amount = grandTotal - cashPaid - upiPaid
→ customer.balance += due_amount
→ SaleModel saved with due_amount
```

## Goals / Non-Goals

**Goals:**
- Add Udhar toggle to sales terminal (simple on/off)
- Track per-sale `due_amount` and per-customer running `balance`
- Collect payments from Customer Screen (Cash/UPI tracking)
- Show customer dues on Dashboard (mirrors vendor dues)
- Add balance column + filter in CRM Reports

**Non-Goals:**
- No separate "Udhar Ledger" screen (too complex — keep it in Customer Screen)
- No interest/penalty on overdue amounts
- No partial collection history log (just reduce balance — keep simple)
- No automated reminders/notifications

## Decisions

### Decision 1: Mirror the Vendor Udhar Pattern exactly
**Choice:** Add `balance` to `CustomerModel` and `due_amount` to `SaleModel`, same as `VendorModel.balance` and `PurchaseModel.dueAmount`.
**Rationale:** Consistent patterns reduce bugs. The vendor pattern is proven and working.

### Decision 2: Udhar toggle (not auto-detect)
**Choice:** Explicit "Udhar / Pay Later" toggle button rather than auto-detecting from underpayment.
**Rationale:** User asked for a toggle. This is clearer UX — the staff makes a conscious decision. Also prevents accidental credit sales when someone forgets to enter the payment amount.

### Decision 3: Block Walk-in Udhar
**Choice:** If Udhar is ON and no customer name+phone is entered, block the sale with a message.
**Rationale:** Cannot collect from unknown customers. This is a business protection measure.

### Decision 4: Collection on Customer Screen (not separate screen)
**Choice:** Add a "Collect" button on the existing Customer Screen/detail. Simple dialog: enter amount, choose Cash/UPI.
**Rationale:** No new screens = fewer bugs. Reuses existing UI patterns.

### Decision 5: Collection updates customer balance directly
**Choice:** On collection, simply reduce `customer.balance` by the collected amount. No separate collection table.
**Rationale:** Simplest approach. If we need a payment history later, we can add it — but for now, just track the running balance like vendors.

## Risks / Trade-offs

- **[Risk] No collection history** → Mitigation: The running balance is sufficient for now. A full ledger can be added in a future iteration if needed.
- **[Risk] Udhar toggle forgotten** → Mitigation: Toggle is OFF by default. Staff must actively enable it.
- **[Risk] Floating point on balance** → Mitigation: Round all amounts to 2 decimal places (same fix as discount PR).
