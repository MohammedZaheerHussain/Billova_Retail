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
