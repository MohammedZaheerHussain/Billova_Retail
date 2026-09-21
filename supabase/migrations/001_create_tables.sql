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
