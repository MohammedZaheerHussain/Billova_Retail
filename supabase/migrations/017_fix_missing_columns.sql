-- ═══════════════════════════════════════════════════════════════
-- 017: Fix Missing Columns — CRITICAL
-- 
-- HOW TO APPLY:
--   1. Go to Supabase Dashboard → SQL Editor
--   2. Paste this ENTIRE file
--   3. Click "Run"
--
-- This fixes the error:
--   "Could not find the 'loyalty_points' column of 'customers'"
--   causing ALL customer sync operations to fail with 400.
-- ═══════════════════════════════════════════════════════════════

-- ─── Customers: Add loyalty_points + last_purchase_date ───
ALTER TABLE customers ADD COLUMN IF NOT EXISTS loyalty_points INTEGER DEFAULT 0;
ALTER TABLE customers ADD COLUMN IF NOT EXISTS last_purchase_date TIMESTAMPTZ;

-- ─── Staff: Add monthly_sale_target ───
ALTER TABLE staff ADD COLUMN IF NOT EXISTS monthly_sale_target DECIMAL(12,2) DEFAULT 0;

-- ─── Items: Add clearance fields ───
ALTER TABLE items ADD COLUMN IF NOT EXISTS original_price DECIMAL(12,2) DEFAULT 0;
ALTER TABLE items ADD COLUMN IF NOT EXISTS parent_item_id TEXT DEFAULT '';

-- ═══════════════════════════════════════════════════════════════
-- ✅ Done! All missing columns added.
-- After running, refresh your app — customer sync will work.
-- ═══════════════════════════════════════════════════════════════
