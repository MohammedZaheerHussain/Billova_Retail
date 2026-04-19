-- ═══════════════════════════════════════════════════════
-- SKYWALK Billing — Migration 002: Add vendor column
-- Run this in Supabase SQL Editor (Dashboard → SQL Editor)
-- ═══════════════════════════════════════════════════════

-- Add vendor column to items table
ALTER TABLE items ADD COLUMN IF NOT EXISTS vendor TEXT DEFAULT '';
