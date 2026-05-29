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
