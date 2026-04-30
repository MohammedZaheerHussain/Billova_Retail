-- ═══════════════════════════════════════════════════════
-- SKYWALK Billing — Migration 010: Unique Invoice Numbers
-- Run this in Supabase SQL Editor (Dashboard → SQL Editor)
-- ═══════════════════════════════════════════════════════

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_indexes 
    WHERE indexname = 'idx_sales_invoice_unique') THEN
    CREATE UNIQUE INDEX idx_sales_invoice_unique ON sales(invoice_number);
  END IF;
END $$;

-- ═══════════════════════════════════════════════════════
-- ✅ Done! UNIQUE constraint on invoice_number
-- ═══════════════════════════════════════════════════════
