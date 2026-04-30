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
