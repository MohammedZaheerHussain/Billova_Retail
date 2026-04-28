-- ═══════════════════════════════════════════════════════
-- SKYWALK Billing — Migration 009: Customer Loyalty Points
-- Run this in Supabase SQL Editor (Dashboard → SQL Editor)
-- ═══════════════════════════════════════════════════════

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'customers' AND column_name = 'loyalty_points') THEN
    ALTER TABLE customers ADD COLUMN loyalty_points INTEGER DEFAULT 0;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'customers' AND column_name = 'last_purchase_date') THEN
    ALTER TABLE customers ADD COLUMN last_purchase_date TIMESTAMPTZ;
  END IF;
END $$;

-- ═══════════════════════════════════════════════════════
-- ✅ Done! loyalty_points + last_purchase_date added
-- ═══════════════════════════════════════════════════════
