-- ═══════════════════════════════════════════════════════
-- SKYWALK Billing — Migration 007: Vendor Notes Column
-- Run this in Supabase SQL Editor (Dashboard → SQL Editor)
-- ═══════════════════════════════════════════════════════

-- Add notes column for free-form vendor information
ALTER TABLE vendors ADD COLUMN IF NOT EXISTS notes TEXT DEFAULT '';

-- ═══════════════════════════════════════════════════════
-- ✅ Done! Added notes column to vendors table
-- ═══════════════════════════════════════════════════════
