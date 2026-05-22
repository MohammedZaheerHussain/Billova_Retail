-- ═══════════════════════════════════════════════════════════════
-- Migration 020: Customer Udhar (Credit Sales)
-- ═══════════════════════════════════════════════════════════════
-- Adds credit/Udhar tracking for customer sales:
-- 1. customers.balance = running total of what customer owes us
-- 2. sales.due_amount = unpaid portion of a specific sale
-- ═══════════════════════════════════════════════════════════════

-- Customers: Add balance (outstanding amount owed BY customer)
ALTER TABLE customers ADD COLUMN IF NOT EXISTS balance REAL DEFAULT 0;

-- Sales: Add due_amount (unpaid portion of this sale)
ALTER TABLE sales ADD COLUMN IF NOT EXISTS due_amount REAL DEFAULT 0;

-- ═══════════════════════════════════════════════════════════════
-- ✅ Done! Customer Udhar tracking is now available.
-- All existing customers get balance = 0 (no outstanding).
-- All existing sales get due_amount = 0 (fully paid).
-- ═══════════════════════════════════════════════════════════════
