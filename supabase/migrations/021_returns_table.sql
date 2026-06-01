-- ═══════════════════════════════════════════════════════════
-- 021: Returns & Exchange Audit Trail
-- Creates a permanent record of every return/exchange.
-- Every return MUST have a record — no more fire-and-forget.
-- ═══════════════════════════════════════════════════════════

-- Returns table — stores every return/exchange transaction
CREATE TABLE IF NOT EXISTS returns (
  id TEXT PRIMARY KEY,
  original_sale_id TEXT NOT NULL,
  original_invoice TEXT NOT NULL DEFAULT '',
  type TEXT NOT NULL DEFAULT 'return',  -- 'return' or 'exchange'
  
  -- Returned items (JSON array: [{item_id, name, quantity, refund_per_unit, cost_price}])
  returned_items TEXT NOT NULL DEFAULT '[]',
  
  -- Exchange: new items given (JSON array: [{item_id, name, quantity, price}])
  exchange_items TEXT NOT NULL DEFAULT '[]',
  
  -- Financial
  refund_amount REAL NOT NULL DEFAULT 0,      -- total refund to customer
  exchange_total REAL NOT NULL DEFAULT 0,      -- total value of new items
  net_settlement REAL NOT NULL DEFAULT 0,      -- exchange_total - refund_amount (positive = customer pays)
  refund_method TEXT NOT NULL DEFAULT 'Cash',  -- Cash / UPI / Store Credit
  
  -- Context
  reason TEXT NOT NULL DEFAULT '',
  customer_name TEXT NOT NULL DEFAULT '',
  customer_phone TEXT NOT NULL DEFAULT '',
  staff_id TEXT NOT NULL DEFAULT '',
  staff_name TEXT NOT NULL DEFAULT '',
  
  -- Loyalty reversal
  points_reversed INTEGER NOT NULL DEFAULT 0,
  
  -- Metadata
  is_deleted INTEGER NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL DEFAULT (datetime('now')),
  updated_at TEXT NOT NULL DEFAULT (datetime('now')),
  
  -- Admin isolation (RLS)
  admin_id TEXT NOT NULL DEFAULT ''
);

-- Index for fast lookup by original sale
CREATE INDEX IF NOT EXISTS idx_returns_sale_id ON returns(original_sale_id);
CREATE INDEX IF NOT EXISTS idx_returns_created ON returns(created_at);
CREATE INDEX IF NOT EXISTS idx_returns_admin ON returns(admin_id);

-- Enable RLS
ALTER TABLE returns ENABLE ROW LEVEL SECURITY;

-- RLS policy: users can only access their own returns
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'returns' AND policyname = 'returns_user_isolation') THEN
    CREATE POLICY returns_user_isolation ON returns
      USING (admin_id = auth.uid()::text)
      WITH CHECK (admin_id = auth.uid()::text);
  END IF;
END $$;
