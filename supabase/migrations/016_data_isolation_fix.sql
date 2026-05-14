-- ═══════════════════════════════════════════════════════
-- 016: Data Isolation Fix — clearance_items user_id + RLS
-- Adds user_id column to clearance_items for per-user isolation
-- Replaces the broken "any authenticated user" policy
-- ═══════════════════════════════════════════════════════

-- Step 1: Add user_id column (nullable first for existing rows)
ALTER TABLE clearance_items ADD COLUMN IF NOT EXISTS user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE;

-- Step 2: Backfill user_id from the linked item's user_id
UPDATE clearance_items c
SET user_id = i.user_id
FROM items i
WHERE c.original_item_id = i.id
AND c.user_id IS NULL;

-- Step 3: Drop the old insecure policy
DROP POLICY IF EXISTS "Authenticated users manage clearance_items" ON clearance_items;

-- Step 4: Create proper per-user RLS policies
CREATE POLICY "Users can view their own clearance_items"
  ON clearance_items FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own clearance_items"
  ON clearance_items FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own clearance_items"
  ON clearance_items FOR UPDATE
  USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own clearance_items"
  ON clearance_items FOR DELETE
  USING (auth.uid() = user_id);

-- Step 5: Add index for performance
CREATE INDEX IF NOT EXISTS idx_clearance_user ON clearance_items(user_id);
