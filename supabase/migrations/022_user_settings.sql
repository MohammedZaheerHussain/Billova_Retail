-- ─── User Settings Table ───
-- Key-value store for user configuration (shop details, GST, loyalty, etc.)
-- Syncs to cloud so settings survive device changes and browser clears.

CREATE TABLE IF NOT EXISTS user_settings (
  id TEXT PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  key TEXT NOT NULL,
  value TEXT NOT NULL DEFAULT '',
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- One setting per user per key
CREATE UNIQUE INDEX IF NOT EXISTS idx_user_settings_user_key
  ON user_settings(user_id, key);

-- RLS: Users can only access their own settings
ALTER TABLE user_settings ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users manage own settings"
  ON user_settings FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);
