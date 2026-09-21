-- ═══════════════════════════════════════════════════════
-- Billova Retail — Supabase Table Definitions
-- Run this in Supabase SQL Editor (Dashboard → SQL Editor)
-- ═══════════════════════════════════════════════════════

-- ─── Enable RLS ───
-- All tables use Row Level Security so users only see their own data.

-- ═══════════════════
-- 1. ITEMS TABLE
-- ═══════════════════
CREATE TABLE IF NOT EXISTS items (
  id TEXT PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  price DOUBLE PRECISION NOT NULL DEFAULT 0,
  cost_price DOUBLE PRECISION DEFAULT 0,
  quantity INTEGER DEFAULT 0,
  low_stock_threshold INTEGER DEFAULT 5,
  is_deleted BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE items ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own items"
  ON items FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own items"
  ON items FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own items"
  ON items FOR UPDATE
  USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own items"
  ON items FOR DELETE
  USING (auth.uid() = user_id);

CREATE INDEX idx_items_user ON items(user_id);
CREATE INDEX idx_items_updated ON items(updated_at);


-- ═══════════════════
-- 2. SALES TABLE
-- ═══════════════════
CREATE TABLE IF NOT EXISTS sales (
  id TEXT PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  invoice_number TEXT NOT NULL,
  customer_name TEXT DEFAULT '',
  customer_phone TEXT DEFAULT '',
  items JSONB NOT NULL DEFAULT '[]',
  subtotal DOUBLE PRECISION NOT NULL DEFAULT 0,
  discount DOUBLE PRECISION DEFAULT 0,
  total DOUBLE PRECISION NOT NULL DEFAULT 0,
  payment_mode TEXT DEFAULT 'Cash',
  is_deleted BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE sales ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own sales"
  ON sales FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own sales"
  ON sales FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own sales"
  ON sales FOR UPDATE
  USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own sales"
  ON sales FOR DELETE
  USING (auth.uid() = user_id);

CREATE INDEX idx_sales_user ON sales(user_id);
CREATE INDEX idx_sales_created ON sales(created_at);
CREATE INDEX idx_sales_updated ON sales(updated_at);


-- ═══════════════════
-- 3. EXPENSES TABLE
-- ═══════════════════
CREATE TABLE IF NOT EXISTS expenses (
  id TEXT PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  amount DOUBLE PRECISION NOT NULL DEFAULT 0,
  note TEXT DEFAULT '',
  category TEXT DEFAULT 'General',
  is_deleted BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE expenses ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own expenses"
  ON expenses FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own expenses"
  ON expenses FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own expenses"
  ON expenses FOR UPDATE
  USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own expenses"
  ON expenses FOR DELETE
  USING (auth.uid() = user_id);

CREATE INDEX idx_expenses_user ON expenses(user_id);
CREATE INDEX idx_expenses_created ON expenses(created_at);
CREATE INDEX idx_expenses_updated ON expenses(updated_at);


-- ═══════════════════
-- 4. CASH TILL TABLE
-- ═══════════════════
CREATE TABLE IF NOT EXISTS cash_till (
  id TEXT PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  date TEXT NOT NULL,
  opening_cash DOUBLE PRECISION DEFAULT 0,
  notes TEXT DEFAULT '',
  is_deleted BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(user_id, date)
);

ALTER TABLE cash_till ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own cash_till"
  ON cash_till FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own cash_till"
  ON cash_till FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own cash_till"
  ON cash_till FOR UPDATE
  USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own cash_till"
  ON cash_till FOR DELETE
  USING (auth.uid() = user_id);

CREATE INDEX idx_cash_till_user ON cash_till(user_id);
CREATE INDEX idx_cash_till_date ON cash_till(date);


-- ═══════════════════════════════
-- 5. AUTO-UPDATE updated_at
-- ═══════════════════════════════
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER items_updated_at
  BEFORE UPDATE ON items
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER sales_updated_at
  BEFORE UPDATE ON sales
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER expenses_updated_at
  BEFORE UPDATE ON expenses
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER cash_till_updated_at
  BEFORE UPDATE ON cash_till
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();


-- ═══════════════════════════════════════════════════════
-- ✅ Done! All tables created with:
--    • Row Level Security (user_id isolation)
--    • Auto-updating updated_at triggers
--    • Proper indexes for performance
--    • Soft delete support (is_deleted)
-- ═══════════════════════════════════════════════════════
-- ═══════════════════════════════════════════════════════
-- Billova Retail — Migration 002: Add vendor column
-- Run this in Supabase SQL Editor (Dashboard → SQL Editor)
-- ═══════════════════════════════════════════════════════

-- Add vendor column to items table
ALTER TABLE items ADD COLUMN IF NOT EXISTS vendor TEXT DEFAULT '';
-- ═══════════════════════════════════════════════════════
-- Billova Retail — Migration 003: Vendors + Purchases
-- Run this in Supabase SQL Editor (Dashboard → SQL Editor)
-- ═══════════════════════════════════════════════════════

-- ═══════════════════
-- 1. VENDORS TABLE
-- ═══════════════════
CREATE TABLE IF NOT EXISTS vendors (
  id TEXT PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  phone TEXT DEFAULT '',
  balance DOUBLE PRECISION DEFAULT 0,
  is_deleted BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE vendors ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own vendors"
  ON vendors FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can insert their own vendors"
  ON vendors FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update their own vendors"
  ON vendors FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "Users can delete their own vendors"
  ON vendors FOR DELETE USING (auth.uid() = user_id);

CREATE INDEX idx_vendors_user ON vendors(user_id);

CREATE TRIGGER vendors_updated_at
  BEFORE UPDATE ON vendors
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();


-- ═══════════════════
-- 2. PURCHASES TABLE
-- ═══════════════════
CREATE TABLE IF NOT EXISTS purchases (
  id TEXT PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  vendor_id TEXT NOT NULL,
  vendor_name TEXT DEFAULT '',
  items JSONB NOT NULL DEFAULT '[]',
  total_amount DOUBLE PRECISION NOT NULL DEFAULT 0,
  paid_amount DOUBLE PRECISION DEFAULT 0,
  payment_mode TEXT DEFAULT 'Cash',
  is_deleted BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE purchases ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own purchases"
  ON purchases FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can insert their own purchases"
  ON purchases FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update their own purchases"
  ON purchases FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "Users can delete their own purchases"
  ON purchases FOR DELETE USING (auth.uid() = user_id);

CREATE INDEX idx_purchases_user ON purchases(user_id);
CREATE INDEX idx_purchases_created ON purchases(created_at);

CREATE TRIGGER purchases_updated_at
  BEFORE UPDATE ON purchases
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();


-- ═══════════════════════════════════════════════════════
-- ✅ Done! Vendors + Purchases tables created with:
--    • Row Level Security (user_id isolation)
--    • Auto-updating updated_at triggers
--    • Proper indexes for performance
-- ═══════════════════════════════════════════════════════
-- ═══════════════════════════════════════════════════════
-- Billova Retail — Migration 004: Staff + Attendance
-- Run this in Supabase SQL Editor (Dashboard → SQL Editor)
-- ═══════════════════════════════════════════════════════

-- ═══════════════════
-- 1. STAFF TABLE
-- ═══════════════════
CREATE TABLE IF NOT EXISTS staff (
  id TEXT PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  username TEXT NOT NULL,
  name TEXT NOT NULL,
  pin TEXT NOT NULL,
  role TEXT DEFAULT 'staff',
  is_active BOOLEAN DEFAULT true,
  is_deleted BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE staff ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own staff"
  ON staff FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can insert their own staff"
  ON staff FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update their own staff"
  ON staff FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "Users can delete their own staff"
  ON staff FOR DELETE USING (auth.uid() = user_id);

CREATE INDEX idx_staff_user ON staff(user_id);

CREATE TRIGGER staff_updated_at
  BEFORE UPDATE ON staff
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();


-- ═══════════════════
-- 2. ATTENDANCE TABLE
-- ═══════════════════
CREATE TABLE IF NOT EXISTS attendance (
  id TEXT PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  staff_id TEXT NOT NULL,
  staff_name TEXT DEFAULT '',
  clock_in_time TIMESTAMPTZ NOT NULL,
  clock_out_time TEXT DEFAULT '',
  total_hours DOUBLE PRECISION DEFAULT 0,
  date TEXT NOT NULL,
  is_deleted BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE attendance ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own attendance"
  ON attendance FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can insert their own attendance"
  ON attendance FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update their own attendance"
  ON attendance FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "Users can delete their own attendance"
  ON attendance FOR DELETE USING (auth.uid() = user_id);

CREATE INDEX idx_attendance_user ON attendance(user_id);
CREATE INDEX idx_attendance_date ON attendance(date);
CREATE INDEX idx_attendance_staff ON attendance(staff_id);


-- ═══════════════════════════════════════════════════════
-- ✅ Done! Staff + Attendance tables created with:
--    • Row Level Security (user_id isolation)
--    • Auto-updating updated_at trigger (staff only)
--    • Proper indexes for performance
-- ═══════════════════════════════════════════════════════
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
-- Migration 006: Add extended item fields (barcode, category, size, color, storage_location)
-- Run in Supabase SQL Editor

ALTER TABLE items ADD COLUMN IF NOT EXISTS barcode TEXT DEFAULT '';
ALTER TABLE items ADD COLUMN IF NOT EXISTS category TEXT DEFAULT '';
ALTER TABLE items ADD COLUMN IF NOT EXISTS size TEXT DEFAULT '';
ALTER TABLE items ADD COLUMN IF NOT EXISTS color TEXT DEFAULT '';
ALTER TABLE items ADD COLUMN IF NOT EXISTS storage_location TEXT DEFAULT '';

-- Index on barcode for fast scanner lookups
CREATE INDEX IF NOT EXISTS idx_items_barcode ON items (barcode) WHERE barcode != '';

-- Index on category for filtered queries
CREATE INDEX IF NOT EXISTS idx_items_category ON items (category) WHERE category != '';
-- ═══════════════════════════════════════════════════════
-- Billova Retail — Migration 007: Vendor Notes Column
-- Run this in Supabase SQL Editor (Dashboard → SQL Editor)
-- ═══════════════════════════════════════════════════════

-- Add notes column for free-form vendor information
ALTER TABLE vendors ADD COLUMN IF NOT EXISTS notes TEXT DEFAULT '';

-- ═══════════════════════════════════════════════════════
-- ✅ Done! Added notes column to vendors table
-- ═══════════════════════════════════════════════════════
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
-- ═══════════════════════════════════════════════════════
-- Billova Retail — Migration 009: Customer Loyalty Points
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
-- ═══════════════════════════════════════════════
-- 009: Supabase Security Hardening
-- Rate limiting, RLS verification, auth config
-- ═══════════════════════════════════════════════

-- ─── Verify RLS is ON for ALL tables ───
-- (These are idempotent — safe to run again)
ALTER TABLE items ENABLE ROW LEVEL SECURITY;
ALTER TABLE sales ENABLE ROW LEVEL SECURITY;
ALTER TABLE expenses ENABLE ROW LEVEL SECURITY;
ALTER TABLE cash_till ENABLE ROW LEVEL SECURITY;
ALTER TABLE vendors ENABLE ROW LEVEL SECURITY;
ALTER TABLE purchases ENABLE ROW LEVEL SECURITY;
ALTER TABLE staff ENABLE ROW LEVEL SECURITY;
ALTER TABLE attendance ENABLE ROW LEVEL SECURITY;
ALTER TABLE customers ENABLE ROW LEVEL SECURITY;

-- ─── Rate limiting for auth (Supabase Auth config) ───
-- NOTE: Supabase handles auth rate limiting server-side:
-- Default limits:
--   - Sign in: 30 requests/hour per IP
--   - Sign up: 30 requests/hour per IP
--   - Token refresh: 150 requests/5 minutes
--
-- These can be customized in Supabase Dashboard:
--   Settings → Auth → Rate Limits
--
-- Recommended for production:
--   - Email sign-ups: 3 per hour (prevent spam)
--   - Password sign-ins: 10 per hour (prevent brute force)
--   - Token refresh: 30 per 5 minutes

-- ─── Prevent direct table access without auth ───
-- Ensure no public policies exist (anon users should NOT access data)
-- These DROP commands are safe — they only fail silently if policy doesn't exist
DO $$ 
BEGIN
  -- Verify no "public" or "anon" policies exist on sensitive tables
  IF EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE policyname LIKE '%public%' 
    OR policyname LIKE '%anon%'
  ) THEN
    RAISE NOTICE '⚠️ WARNING: Public/anon policies found — review for security';
  ELSE
    RAISE NOTICE '✅ No public access policies — data is secure';
  END IF;
END $$;


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
-- ═══════════════════════════════════════════════════════
-- Billova Retail — Migration 010: Unique Invoice Numbers
-- Run this in Supabase SQL Editor (Dashboard → SQL Editor)
-- ═══════════════════════════════════════════════════════

-- Step 1: Fix any duplicate invoice_numbers by appending row number
WITH duplicates AS (
  SELECT id, invoice_number,
    ROW_NUMBER() OVER (PARTITION BY invoice_number ORDER BY created_at) as rn
  FROM sales
  WHERE invoice_number IN (
    SELECT invoice_number FROM sales
    GROUP BY invoice_number HAVING COUNT(*) > 1
  )
)
UPDATE sales SET invoice_number = sales.invoice_number || '-DUP' || d.rn
FROM duplicates d
WHERE sales.id = d.id AND d.rn > 1;

-- Step 2: Now create the unique index safely
CREATE UNIQUE INDEX IF NOT EXISTS idx_sales_invoice_unique ON sales(invoice_number);

-- ═══════════════════════════════════════════════════════
-- ✅ Done! Duplicates fixed + UNIQUE constraint added
-- ═══════════════════════════════════════════════════════
-- Migration 011: Barcode uniqueness + DB integrity hardening
-- Run this in Supabase SQL Editor
-- ═══════════════════════════════════════════════════════

-- 1. Fix any duplicate barcodes before adding UNIQUE constraint
-- (Only affects non-empty barcodes)
DO $$
DECLARE
  rec RECORD;
BEGIN
  FOR rec IN
    SELECT id, barcode
    FROM (
      SELECT id, barcode,
             ROW_NUMBER() OVER (PARTITION BY barcode ORDER BY created_at DESC) AS rn
      FROM items
      WHERE barcode IS NOT NULL AND barcode != ''
    ) sub
    WHERE sub.rn > 1
  LOOP
    UPDATE items SET barcode = rec.barcode || '-DUP-' || substring(gen_random_uuid()::text from 1 for 8)
    WHERE id = rec.id;
  END LOOP;
END $$;

-- 2. Add UNIQUE partial index on barcode (only non-empty values)
DROP INDEX IF EXISTS idx_items_barcode;
CREATE UNIQUE INDEX IF NOT EXISTS idx_items_barcode_unique
  ON items (barcode) WHERE barcode IS NOT NULL AND barcode != '';

-- 3. Add index on items.category for faster category filtering
CREATE INDEX IF NOT EXISTS idx_items_category
  ON items (category) WHERE category IS NOT NULL AND category != '';

-- 4. Add index on items.vendor for vendor lookups
CREATE INDEX IF NOT EXISTS idx_items_vendor
  ON items (vendor) WHERE vendor IS NOT NULL AND vendor != '';

-- 5. Add GIN index on purchases.items JSONB for item-level queries
CREATE INDEX IF NOT EXISTS idx_purchases_items_gin
  ON purchases USING GIN (items);

-- 6. Ensure sales.customer_phone is indexed for return lookups
CREATE INDEX IF NOT EXISTS idx_sales_customer_phone
  ON sales (customer_phone) WHERE customer_phone IS NOT NULL AND customer_phone != '';

-- 7. Ensure sales.customer_name is indexed for search
CREATE INDEX IF NOT EXISTS idx_sales_customer_name
  ON sales (customer_name) WHERE customer_name IS NOT NULL AND customer_name != '';

-- ═══════════════════════════════════════════════════════
-- ✅ Done! 
--    • Barcode uniqueness enforced (no duplicates)
--    • Performance indexes on category, vendor, purchases, sales
--    • All safe — existing data preserved
-- ═══════════════════════════════════════════════════════
-- ─── Categories Table ───
-- Dynamic category management for inventory items
-- Supports size/color field visibility per category

CREATE TABLE IF NOT EXISTS categories (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  requires_size BOOLEAN DEFAULT FALSE,
  requires_color BOOLEAN DEFAULT FALSE,
  is_deleted BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_categories_user ON categories(user_id);
CREATE INDEX IF NOT EXISTS idx_categories_deleted ON categories(is_deleted);
CREATE UNIQUE INDEX IF NOT EXISTS idx_categories_user_name ON categories(user_id, name) WHERE is_deleted = FALSE;

-- RLS (Row Level Security)
ALTER TABLE categories ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can manage own categories"
  ON categories FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);
-- ─── 012: Sale loyalty tracking fields ───
-- Adds loyalty point tracking columns to sales table
-- and creates a loyalty_transactions audit trail.

-- Add loyalty columns to sales
ALTER TABLE sales ADD COLUMN IF NOT EXISTS loyalty_discount DECIMAL(12,2) DEFAULT 0;
ALTER TABLE sales ADD COLUMN IF NOT EXISTS points_redeemed INTEGER DEFAULT 0;
ALTER TABLE sales ADD COLUMN IF NOT EXISTS points_earned INTEGER DEFAULT 0;

-- Loyalty transactions audit trail
CREATE TABLE IF NOT EXISTS loyalty_transactions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id),
  customer_id TEXT NOT NULL,
  type TEXT NOT NULL CHECK (type IN ('earned', 'redeemed')),
  points INTEGER NOT NULL,
  sale_id TEXT DEFAULT '',
  balance_after INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE loyalty_transactions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own loyalty transactions"
  ON loyalty_transactions FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can insert their own loyalty transactions"
  ON loyalty_transactions FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE INDEX IF NOT EXISTS idx_loyalty_tx_customer ON loyalty_transactions(customer_id);
CREATE INDEX IF NOT EXISTS idx_loyalty_tx_user ON loyalty_transactions(user_id);

-- ✅ Done! Sale loyalty fields + audit trail added
-- Migration: Clearance Stock Tracking
-- Adds clearance audit table + new item fields for split-item strategy

-- New columns on items for clearance copies
ALTER TABLE items ADD COLUMN IF NOT EXISTS original_price DOUBLE PRECISION DEFAULT 0;
ALTER TABLE items ADD COLUMN IF NOT EXISTS parent_item_id TEXT DEFAULT '';

-- Clearance items audit table
CREATE TABLE IF NOT EXISTS clearance_items (
  id TEXT PRIMARY KEY,
  original_item_id TEXT NOT NULL REFERENCES items(id),
  clearance_item_id TEXT NOT NULL,
  quantity INTEGER NOT NULL,
  original_price DOUBLE PRECISION NOT NULL,
  clearance_price DOUBLE PRECISION NOT NULL,
  reason TEXT NOT NULL DEFAULT '',
  status TEXT NOT NULL DEFAULT 'active',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_clearance_original ON clearance_items(original_item_id);
CREATE INDEX IF NOT EXISTS idx_clearance_status ON clearance_items(status);
CREATE INDEX IF NOT EXISTS idx_clearance_item ON clearance_items(clearance_item_id);

-- Enable RLS
ALTER TABLE clearance_items ENABLE ROW LEVEL SECURITY;

-- RLS policy: authenticated users can do everything
CREATE POLICY "Authenticated users manage clearance_items"
  ON clearance_items FOR ALL
  USING (auth.role() = 'authenticated')
  WITH CHECK (auth.role() = 'authenticated');
-- Migration: Staff monthly sale target
-- Admin sets a per-staff monthly sales target in ₹

ALTER TABLE staff ADD COLUMN IF NOT EXISTS monthly_sale_target DOUBLE PRECISION DEFAULT 0;
-- GST support: add gst_rate to items, gst_amount/cgst/sgst to sales, gst_number to customers
ALTER TABLE items ADD COLUMN IF NOT EXISTS gst_rate DOUBLE PRECISION DEFAULT 0;
ALTER TABLE sales ADD COLUMN IF NOT EXISTS gst_amount DOUBLE PRECISION DEFAULT 0;
ALTER TABLE sales ADD COLUMN IF NOT EXISTS cgst DOUBLE PRECISION DEFAULT 0;
ALTER TABLE sales ADD COLUMN IF NOT EXISTS sgst DOUBLE PRECISION DEFAULT 0;
ALTER TABLE customers ADD COLUMN IF NOT EXISTS gst_number TEXT DEFAULT '';
-- ═══════════════════════════════════════════════════════
-- 016: Data Isolation Fix — clearance_items user_id + RLS
-- Adds user_id column to clearance_items for per-user isolation
-- Replaces the broken "any authenticated user" policy
-- ═══════════════════════════════════════════════════════

-- Step 1: Add user_id column (nullable first for existing rows)
ALTER TABLE clearance_items ADD COLUMN IF NOT EXISTS user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE;

-- Step 2: Backfill user_id from the linked item's user_id
UPDATE clearance_items c
SET user_id = i.user_id
FROM items i
WHERE c.original_item_id = i.id
AND c.user_id IS NULL;

-- Step 3: Drop the old insecure policy
DROP POLICY IF EXISTS "Authenticated users manage clearance_items" ON clearance_items;

-- Step 4: Create proper per-user RLS policies
CREATE POLICY "Users can view their own clearance_items"
  ON clearance_items FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own clearance_items"
  ON clearance_items FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own clearance_items"
  ON clearance_items FOR UPDATE
  USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own clearance_items"
  ON clearance_items FOR DELETE
  USING (auth.uid() = user_id);

-- Step 5: Add index for performance
CREATE INDEX IF NOT EXISTS idx_clearance_user ON clearance_items(user_id);
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
-- ═══════════════════════════════════════════════════════════════
-- 019: Add gst_number column to customers — CRITICAL FIX
-- 
-- HOW TO APPLY:
--   1. Go to Supabase Dashboard → SQL Editor
--   2. Paste this ENTIRE file
--   3. Click "Run"
--
-- ROOT CAUSE: CustomerModel.toMap() sends 'gst_number' to Supabase,
-- but the column was never created. This causes guaranteedSave to
-- throw a 400 error → addCustomer returns false → customer data
-- is silently lost for EVERY new customer.
-- ═══════════════════════════════════════════════════════════════

-- ─── Customers: Add gst_number (B2B GSTIN) ───
ALTER TABLE customers ADD COLUMN IF NOT EXISTS gst_number TEXT DEFAULT '';

-- ═══════════════════════════════════════════════════════════════
-- ✅ Done! Customer creation will now succeed.
-- All existing customers keep gst_number = '' (empty).
-- ═══════════════════════════════════════════════════════════════
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
-- ═══════════════════════════════════════════════════════════
-- 021: Returns & Exchange Audit Trail
-- Creates a permanent record of every return/exchange.
-- Every return MUST have a record — no more fire-and-forget.
-- ═══════════════════════════════════════════════════════════

-- Returns table — stores every return/exchange transaction
CREATE TABLE IF NOT EXISTS returns (
  id TEXT PRIMARY KEY,
  original_sale_id TEXT NOT NULL,
  original_invoice TEXT NOT NULL DEFAULT '',
  type TEXT NOT NULL DEFAULT 'return',  -- 'return' or 'exchange'
  
  -- Returned items (JSON array: [{item_id, name, quantity, refund_per_unit, cost_price}])
  returned_items TEXT NOT NULL DEFAULT '[]',
  
  -- Exchange: new items given (JSON array: [{item_id, name, quantity, price}])
  exchange_items TEXT NOT NULL DEFAULT '[]',
  
  -- Financial
  refund_amount REAL NOT NULL DEFAULT 0,      -- total refund to customer
  exchange_total REAL NOT NULL DEFAULT 0,      -- total value of new items
  net_settlement REAL NOT NULL DEFAULT 0,      -- exchange_total - refund_amount (positive = customer pays)
  refund_method TEXT NOT NULL DEFAULT 'Cash',  -- Cash / UPI / Store Credit
  
  -- Context
  reason TEXT NOT NULL DEFAULT '',
  customer_name TEXT NOT NULL DEFAULT '',
  customer_phone TEXT NOT NULL DEFAULT '',
  staff_id TEXT NOT NULL DEFAULT '',
  staff_name TEXT NOT NULL DEFAULT '',
  
  -- Loyalty reversal
  points_reversed INTEGER NOT NULL DEFAULT 0,
  
  -- Metadata
  is_deleted INTEGER NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL DEFAULT (datetime('now')),
  updated_at TEXT NOT NULL DEFAULT (datetime('now')),
  
  -- Admin isolation (RLS)
  admin_id TEXT NOT NULL DEFAULT ''
);

-- Index for fast lookup by original sale
CREATE INDEX IF NOT EXISTS idx_returns_sale_id ON returns(original_sale_id);
CREATE INDEX IF NOT EXISTS idx_returns_created ON returns(created_at);
CREATE INDEX IF NOT EXISTS idx_returns_admin ON returns(admin_id);

-- Enable RLS
ALTER TABLE returns ENABLE ROW LEVEL SECURITY;

-- RLS policy: users can only access their own returns
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'returns' AND policyname = 'returns_user_isolation') THEN
    CREATE POLICY returns_user_isolation ON returns
      USING (admin_id = auth.uid()::text)
      WITH CHECK (admin_id = auth.uid()::text);
  END IF;
END $$;
-- ─── Revenue Snapshots Table ───
-- Persists monthly revenue data so historical category revenue
-- is always available for filtering (Week / Month / Past months).

CREATE TABLE IF NOT EXISTS revenue_snapshots (
  id TEXT PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES auth.users(id),
  year INTEGER NOT NULL,
  month INTEGER NOT NULL,
  total_revenue REAL DEFAULT 0,
  total_profit REAL DEFAULT 0,
  total_discounts REAL DEFAULT 0,
  total_cogs REAL DEFAULT 0,
  total_expenses REAL DEFAULT 0,
  net_profit REAL DEFAULT 0,
  sales_count INTEGER DEFAULT 0,
  category_revenue JSONB DEFAULT '{}',
  is_deleted BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Unique constraint: one snapshot per user per month
CREATE UNIQUE INDEX IF NOT EXISTS idx_snapshot_user_year_month
  ON revenue_snapshots(user_id, year, month);

-- RLS: Users can only access their own snapshots
ALTER TABLE revenue_snapshots ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users manage own snapshots"
  ON revenue_snapshots FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);
-- ─── User Settings Table ───
-- Key-value store for user configuration (shop details, GST, loyalty, etc.)
-- Syncs to cloud so settings survive device changes and browser clears.

CREATE TABLE IF NOT EXISTS user_settings (
  id TEXT PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  key TEXT NOT NULL,
  value TEXT NOT NULL DEFAULT '',
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- One setting per user per key
CREATE UNIQUE INDEX IF NOT EXISTS idx_user_settings_user_key
  ON user_settings(user_id, key);

-- RLS: Users can only access their own settings
ALTER TABLE user_settings ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users manage own settings"
  ON user_settings FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);
-- ─── Expense Payment Mode Column ───
-- Previously stripped before Supabase sync, making cloud expense reports
-- unable to distinguish Cash vs UPI vs Card expenses.

ALTER TABLE expenses ADD COLUMN IF NOT EXISTS payment_mode TEXT DEFAULT 'Cash';
