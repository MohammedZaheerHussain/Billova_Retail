-- ═══════════════════════════════════════════════════════
-- Billova Retail — Migration 005: Customers Table
-- Run this in Supabase SQL Editor (Dashboard → SQL Editor)
-- ═══════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS customers (
  id TEXT PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  phone TEXT DEFAULT '',
  total_orders INTEGER DEFAULT 0,
  total_spent DOUBLE PRECISION DEFAULT 0,
  is_deleted BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE customers ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own customers"
  ON customers FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can insert their own customers"
  ON customers FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update their own customers"
  ON customers FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "Users can delete their own customers"
  ON customers FOR DELETE USING (auth.uid() = user_id);

CREATE INDEX idx_customers_user ON customers(user_id);

CREATE TRIGGER customers_updated_at
  BEFORE UPDATE ON customers
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- Also add staff columns to sales table if not exists
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'sales' AND column_name = 'staff_id') THEN
    ALTER TABLE sales ADD COLUMN staff_id TEXT DEFAULT '';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'sales' AND column_name = 'staff_name') THEN
    ALTER TABLE sales ADD COLUMN staff_name TEXT DEFAULT '';
  END IF;
END $$;

-- ═══════════════════════════════════════════════════════
-- ✅ Done! Customers table + sales staff columns added
-- ═══════════════════════════════════════════════════════
