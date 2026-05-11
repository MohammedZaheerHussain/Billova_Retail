-- ═══════════════════════════════════════════════
-- 010: Customer Tracking & Attendance Cleanup
-- ═══════════════════════════════════════════════

-- ─── Add last_purchase_date to customers ───
ALTER TABLE customers ADD COLUMN IF NOT EXISTS last_purchase_date TIMESTAMPTZ;
ALTER TABLE customers ADD COLUMN IF NOT EXISTS total_orders INTEGER DEFAULT 0;
ALTER TABLE customers ADD COLUMN IF NOT EXISTS total_spent DECIMAL(12,2) DEFAULT 0;

-- ─── Auto-cleanup old attendance (keep 60 days) ───
DELETE FROM attendance
WHERE created_at < NOW() - INTERVAL '60 days';

-- ─── Index for attendance date queries ───
CREATE INDEX IF NOT EXISTS idx_attendance_created_at ON attendance(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_customers_total_spent ON customers(total_spent DESC);
