-- ═══════════════════════════════════════════════════════
-- Billova Retail — Migration 008: Performance Indexes
-- Run this in Supabase SQL Editor (Dashboard → SQL Editor)
-- ═══════════════════════════════════════════════════════

-- Speed up date-based filtering on sales
CREATE INDEX IF NOT EXISTS idx_sales_created_at 
  ON sales(created_at);

CREATE INDEX IF NOT EXISTS idx_sales_user_created 
  ON sales(user_id, created_at DESC);

-- Speed up date-based filtering on expenses  
CREATE INDEX IF NOT EXISTS idx_expenses_created_at 
  ON expenses(created_at);

CREATE INDEX IF NOT EXISTS idx_expenses_user_created 
  ON expenses(user_id, created_at DESC);

-- Speed up vendor lookups
CREATE INDEX IF NOT EXISTS idx_vendors_user 
  ON vendors(user_id, is_deleted);

-- Speed up customer lookups
CREATE INDEX IF NOT EXISTS idx_customers_user 
  ON customers(user_id, is_deleted);

-- ═══════════════════════════════════════════════════════
-- ✅ Done! Added performance indexes for date filtering
-- ═══════════════════════════════════════════════════════
