-- Migration: Staff monthly sale target
-- Admin sets a per-staff monthly sales target in ₹

ALTER TABLE staff ADD COLUMN IF NOT EXISTS monthly_sale_target DOUBLE PRECISION DEFAULT 0;
