## ADDED Requirements

### Requirement: Discount amounts SHALL be rounded to 2 decimal places
The system SHALL round computed discount amounts to exactly 2 decimal places before applying them to the bill total, eliminating floating-point drift from percentage conversion.

#### Scenario: Flat discount of ₹100 on ₹1150 bill
- **WHEN** user enters ₹100 flat discount on a ₹1150 subtotal
- **THEN** the discount amount displayed and stored SHALL be exactly ₹100.00, not ₹100.05

#### Scenario: Percentage discount with fractional result
- **WHEN** user enters 15% discount on a ₹999 subtotal
- **THEN** the discount amount SHALL be ₹149.85 (rounded to 2 decimals)

### Requirement: Single-method payment amounts SHALL equal bill total
The system SHALL auto-set the payment amount to match `sale.total` when only one payment method is used (Cash-only, UPI-only, or Card-only). The user-entered amount SHALL be ignored for single-method payments.

#### Scenario: UPI-only payment on discounted bill
- **WHEN** bill total is ₹1050 after discount and payment mode is UPI
- **THEN** `upi_amount` stored SHALL be ₹1050, regardless of what the user typed

#### Scenario: Cash-only payment
- **WHEN** bill total is ₹800 after discount and payment mode is Cash
- **THEN** `cash_amount` stored SHALL be ₹800

#### Scenario: Split payment (Cash + UPI)
- **WHEN** payment is split between Cash (₹500) and UPI (₹550) for a ₹1050 bill
- **THEN** `cash_amount` SHALL be ₹500 and `upi_amount` SHALL be ₹550

### Requirement: Dashboard payment distribution SHALL reflect post-discount amounts
The dashboard "Sales by Payment" chart SHALL display payment totals that match the actual billed amounts (post-discount), never exceeding `sale.total` per transaction.

#### Scenario: UPI payment on discounted bill in dashboard
- **WHEN** a sale has `total=1050` and `upi_amount=1150` (legacy data)
- **THEN** dashboard SHALL display UPI contribution as ₹1050 (capped to total)

#### Scenario: New sale with correct payment amounts
- **WHEN** a new sale has `total=1050` and `upi_amount=1050`
- **THEN** dashboard SHALL display UPI contribution as ₹1050

### Requirement: All dashboard metrics SHALL use post-discount totals
Total Sales, Weekly Sales, and Today's Profit SHALL be computed from the stored `sale.total` (which is already post-discount). No metric SHALL use `subtotal` or raw payment amounts for revenue calculations.

#### Scenario: Today's sales with discounted bills
- **WHEN** today has 3 sales: ₹1050 (discounted from ₹1150), ₹500, ₹800
- **THEN** Today Sales SHALL display ₹2350 (sum of post-discount totals)

#### Scenario: Today's profit with discounted bills
- **WHEN** a sale has subtotal ₹1150, discount ₹100, cost ₹700
- **THEN** profit SHALL be (₹1150 - ₹700) - ₹100 = ₹350 (grossProfit already deducts discount)
