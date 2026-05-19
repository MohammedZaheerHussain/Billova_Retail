-- Migration 018: Add payment split columns to sales table
-- Fixes: all transactions showing as Cash in dashboard/reports
-- NEW APPROACH: Store actual amounts, not just payment mode label

ALTER TABLE sales
  ADD COLUMN IF NOT EXISTS cash_amount DECIMAL(10,2) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS upi_amount  DECIMAL(10,2) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS card_amount DECIMAL(10,2) DEFAULT 0;

-- Backfill existing records from payment_mode (backward compat)
UPDATE sales
SET
  cash_amount = CASE
    WHEN LOWER(payment_mode) = 'cash' THEN total
    ELSE 0
  END,
  upi_amount = CASE
    WHEN LOWER(payment_mode) IN ('upi', 'upi/card') THEN total
    ELSE 0
  END,
  card_amount = CASE
    WHEN LOWER(payment_mode) = 'card' THEN total
    ELSE 0
  END
WHERE
  cash_amount = 0 AND upi_amount = 0 AND card_amount = 0;

-- Performance index for payment analytics
CREATE INDEX IF NOT EXISTS idx_sales_cash_amount ON sales(cash_amount);
CREATE INDEX IF NOT EXISTS idx_sales_upi_amount  ON sales(upi_amount);
