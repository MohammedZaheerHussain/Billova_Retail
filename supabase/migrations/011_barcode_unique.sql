-- Migration 011: Barcode uniqueness + DB integrity hardening
-- Run this in Supabase SQL Editor

-- 1. Add UNIQUE constraint on barcode (skip empty barcodes)
-- First, deduplicate any existing conflicts
WITH dupes AS (
  SELECT id, barcode, ROW_NUMBER() OVER (PARTITION BY barcode ORDER BY created_at DESC) AS rn
  FROM items
  WHERE barcode IS NOT NULL AND barcode != ''
)
UPDATE items SET barcode = barcode || '-DUP-' || gen_random_uuid()::text
WHERE id IN (SELECT id FROM dupes WHERE rn > 1);

-- Now add unique partial index (only non-empty barcodes)
CREATE UNIQUE INDEX IF NOT EXISTS idx_items_barcode_unique
  ON items (barcode) WHERE barcode IS NOT NULL AND barcode != '';

-- 2. Add index on items.category for faster category filtering
CREATE INDEX IF NOT EXISTS idx_items_category ON items (category) WHERE category != '';

-- 3. Add index on items.vendor for vendor lookups
CREATE INDEX IF NOT EXISTS idx_items_vendor ON items (vendor) WHERE vendor != '';

-- 4. Add index on purchase_items for faster purchase queries
CREATE INDEX IF NOT EXISTS idx_purchase_items_purchase_id ON purchase_items (purchase_id);

-- 5. Ensure sales.customer_phone is indexed for return lookups
CREATE INDEX IF NOT EXISTS idx_sales_customer_phone ON sales (customer_phone) WHERE customer_phone != '';

-- 6. Ensure sales.customer_name is indexed for search
CREATE INDEX IF NOT EXISTS idx_sales_customer_name ON sales (customer_name) WHERE customer_name != '';

-- ✅ Done! Barcode uniqueness enforced + performance indexes added
