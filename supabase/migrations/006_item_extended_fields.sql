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
