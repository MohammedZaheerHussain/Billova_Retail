## ADDED Requirements

### Requirement: Expense payment mode syncs to Supabase
The system SHALL persist the `payment_mode` field of each expense record to the Supabase `expenses` table so cloud reports can distinguish between Cash, UPI, and Card expense payments.

#### Scenario: New expense with payment mode
- **WHEN** user creates a new expense with payment mode "UPI"
- **THEN** the `payment_mode` value "UPI" is stored in both local SQLite AND Supabase `expenses` table

#### Scenario: Existing expenses sync on retry
- **WHEN** a previously failed expense sync is retried via `processSyncQueue()`
- **THEN** the `payment_mode` field is included in the synced data (not stripped)

#### Scenario: Cloud expense reports
- **WHEN** CRM Reports screen shows expense breakdown by payment method
- **THEN** the breakdown data is accurate because `payment_mode` exists in Supabase
