-- ─── Expense Payment Mode Column ───
-- Previously stripped before Supabase sync, making cloud expense reports
-- unable to distinguish Cash vs UPI vs Card expenses.

ALTER TABLE expenses ADD COLUMN IF NOT EXISTS payment_mode TEXT DEFAULT 'Cash';
