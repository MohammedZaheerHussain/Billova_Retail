-- ═══════════════════════════════════════════════════════
-- SKYWALK Billing — Migration 004: Staff + Attendance
-- Run this in Supabase SQL Editor (Dashboard → SQL Editor)
-- ═══════════════════════════════════════════════════════

-- ═══════════════════
-- 1. STAFF TABLE
-- ═══════════════════
CREATE TABLE IF NOT EXISTS staff (
  id TEXT PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  username TEXT NOT NULL,
  name TEXT NOT NULL,
  pin TEXT NOT NULL,
  role TEXT DEFAULT 'staff',
  is_active BOOLEAN DEFAULT true,
  is_deleted BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE staff ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own staff"
  ON staff FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can insert their own staff"
  ON staff FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update their own staff"
  ON staff FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "Users can delete their own staff"
  ON staff FOR DELETE USING (auth.uid() = user_id);

CREATE INDEX idx_staff_user ON staff(user_id);

CREATE TRIGGER staff_updated_at
  BEFORE UPDATE ON staff
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();


-- ═══════════════════
-- 2. ATTENDANCE TABLE
-- ═══════════════════
CREATE TABLE IF NOT EXISTS attendance (
  id TEXT PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  staff_id TEXT NOT NULL,
  staff_name TEXT DEFAULT '',
  clock_in_time TIMESTAMPTZ NOT NULL,
  clock_out_time TEXT DEFAULT '',
  total_hours DOUBLE PRECISION DEFAULT 0,
  date TEXT NOT NULL,
  is_deleted BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE attendance ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own attendance"
  ON attendance FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can insert their own attendance"
  ON attendance FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update their own attendance"
  ON attendance FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "Users can delete their own attendance"
  ON attendance FOR DELETE USING (auth.uid() = user_id);

CREATE INDEX idx_attendance_user ON attendance(user_id);
CREATE INDEX idx_attendance_date ON attendance(date);
CREATE INDEX idx_attendance_staff ON attendance(staff_id);


-- ═══════════════════════════════════════════════════════
-- ✅ Done! Staff + Attendance tables created with:
--    • Row Level Security (user_id isolation)
--    • Auto-updating updated_at trigger (staff only)
--    • Proper indexes for performance
-- ═══════════════════════════════════════════════════════
