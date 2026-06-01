## 1. Supabase Migrations

- [x] 1.1 Create `022_user_settings.sql` — `user_settings` table with `id`, `user_id`, `key`, `value`, `updated_at`, unique index on `(user_id, key)`, RLS policy
- [x] 1.2 Create `023_expense_payment_mode.sql` — add `payment_mode TEXT DEFAULT 'Cash'` column to `expenses` table in Supabase
- [ ] 1.3 🔧 Run both migrations in Supabase SQL Editor and verify `Success`

## 2. Local DB Schema Update

- [x] 2.1 Bump `AppConstants.dbVersion` from 15 to 16 in `lib/core/constants.dart`
- [x] 2.2 Add `user_settings` table to `_WebDB.init()` in `db_helper.dart` (web in-memory table)
- [x] 2.3 Add `user_settings` table to `_onCreate()` in `db_helper.dart` (SQLite)
- [x] 2.4 Add v16 migration to `_onUpgrade()` — `CREATE TABLE IF NOT EXISTS user_settings`

## 3. Settings Sync — DBHelper Methods

- [x] 3.1 Add `saveCloudSetting(key, value)` method to `DBHelper` — upserts into `user_settings` table
- [x] 3.2 Add `getCloudSetting(key)` method to `DBHelper` — reads from `user_settings` table
- [x] 3.3 Add `getAllCloudSettings()` method to `DBHelper` — returns all user_settings rows
- [x] 3.4 Add `bulkSaveCloudSettings(Map<String, String>)` method for initial migration

## 4. Supabase Service — Settings Pull & Sync

- [x] 4.1 Add `user_settings` to `pullAllData()` pull list in `supabase_service.dart`
- [x] 4.2 Add `pullSettings()` method — pulls settings from Supabase and writes to local `settings` table + SharedPreferences (only if local value is missing)
- [x] 4.3 Add `syncSetting(key, value)` method — syncs a single setting to Supabase `user_settings` table via `syncRecord()`
- [x] 4.4 Remove `'expenses': ['payment_mode']` from `_stripLocalOnlyColumns()` so expense payment_mode syncs

## 5. Settings Screen — Cloud Sync Integration

- [x] 5.1 Update `_saveSettings()` in `settings_screen.dart` to call `syncSetting()` for each setting after local save
- [x] 5.2 Add one-time bulk sync check: if `getSetting('settings_synced')` is null, bulk-upload all local settings to Supabase and set flag

## 6. Loyalty Settings Provider — Cloud Sync

- [x] 6.1 Add Supabase sync to `LoyaltySettingsProvider` — on every `setEnabled/setEarnRate/setRedeemValue/setMinRedeem`, also call `syncSetting()`
- [x] 6.2 Update `_load()` in `LoyaltySettingsProvider` — after loading from SharedPreferences, also check cloud settings if local values are defaults

## 7. Verification

- [x] 7.1 Run `flutter analyze` — zero errors
- [ ] 7.2 Verify settings save to Supabase by checking `user_settings` table in Supabase dashboard after saving settings
- [ ] 7.3 Verify expense payment_mode appears in Supabase `expenses` table after creating a new expense
- [ ] 7.4 Verify settings restore on fresh login — clear browser data, log in, confirm shop name/GST/loyalty settings are restored
- [x] 7.5 Git commit, push to main, sync all branches (main, Ashiq, zaheer)
