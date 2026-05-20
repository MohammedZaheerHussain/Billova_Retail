-- ═══════════════════════════════════════════════════════════════
-- 019: Add gst_number column to customers — CRITICAL FIX
-- 
-- HOW TO APPLY:
--   1. Go to Supabase Dashboard → SQL Editor
--   2. Paste this ENTIRE file
--   3. Click "Run"
--
-- ROOT CAUSE: CustomerModel.toMap() sends 'gst_number' to Supabase,
-- but the column was never created. This causes guaranteedSave to
-- throw a 400 error → addCustomer returns false → customer data
-- is silently lost for EVERY new customer.
-- ═══════════════════════════════════════════════════════════════

-- ─── Customers: Add gst_number (B2B GSTIN) ───
ALTER TABLE customers ADD COLUMN IF NOT EXISTS gst_number TEXT DEFAULT '';

-- ═══════════════════════════════════════════════════════════════
-- ✅ Done! Customer creation will now succeed.
-- All existing customers keep gst_number = '' (empty).
-- ═══════════════════════════════════════════════════════════════
