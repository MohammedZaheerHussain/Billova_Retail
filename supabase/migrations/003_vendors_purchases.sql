-- ═══════════════════════════════════════════════════════
-- SKYWALK Billing — Migration 003: Vendors + Purchases
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
