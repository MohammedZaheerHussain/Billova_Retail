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
