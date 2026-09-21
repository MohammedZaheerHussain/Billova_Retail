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
