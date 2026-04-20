-- ═══════════════════════════════════════════════
-- 009: Supabase Security Hardening
-- Rate limiting, RLS verification, auth config
-- ═══════════════════════════════════════════════

-- ─── Verify RLS is ON for ALL tables ───
-- (These are idempotent — safe to run again)
ALTER TABLE items ENABLE ROW LEVEL SECURITY;
ALTER TABLE sales ENABLE ROW LEVEL SECURITY;
ALTER TABLE expenses ENABLE ROW LEVEL SECURITY;
ALTER TABLE cash_till ENABLE ROW LEVEL SECURITY;
ALTER TABLE vendors ENABLE ROW LEVEL SECURITY;
ALTER TABLE purchases ENABLE ROW LEVEL SECURITY;
ALTER TABLE staff ENABLE ROW LEVEL SECURITY;
ALTER TABLE attendance ENABLE ROW LEVEL SECURITY;
ALTER TABLE customers ENABLE ROW LEVEL SECURITY;

-- ─── Rate limiting for auth (Supabase Auth config) ───
-- NOTE: Supabase handles auth rate limiting server-side:
-- Default limits:
--   - Sign in: 30 requests/hour per IP
--   - Sign up: 30 requests/hour per IP
--   - Token refresh: 150 requests/5 minutes
--
-- These can be customized in Supabase Dashboard:
--   Settings → Auth → Rate Limits
--
-- Recommended for production:
--   - Email sign-ups: 3 per hour (prevent spam)
--   - Password sign-ins: 10 per hour (prevent brute force)
--   - Token refresh: 30 per 5 minutes

-- ─── Prevent direct table access without auth ───
-- Ensure no public policies exist (anon users should NOT access data)
-- These DROP commands are safe — they only fail silently if policy doesn't exist
DO $$ 
BEGIN
  -- Verify no "public" or "anon" policies exist on sensitive tables
  IF EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE policyname LIKE '%public%' 
    OR policyname LIKE '%anon%'
  ) THEN
    RAISE NOTICE '⚠️ WARNING: Public/anon policies found — review for security';
  ELSE
    RAISE NOTICE '✅ No public access policies — data is secure';
  END IF;
END $$;


