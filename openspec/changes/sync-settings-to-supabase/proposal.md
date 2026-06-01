## Why

The Supabase data audit revealed that **all business-critical transactional data** (sales, customers, inventory, vendors, staff, expenses, purchases) is fully synced to Supabase — but **business configuration settings are not**. Shop details (name, address, GST info), loyalty program configuration, and receipt preferences exist only in local `SharedPreferences` or the local-only `settings` SQLite table. If a client clears browser data or switches devices, they lose all configuration while retaining all business data. Additionally, `expenses.payment_mode` is actively stripped before Supabase sync, making cloud expense reports inaccurate.

## What Changes

- **New Supabase table** `user_settings`: Key-value store for all user configuration, with RLS for data isolation
- **Settings sync pipeline**: `SettingsScreen` and `LoyaltySettingsProvider` save to both local storage AND Supabase on every change
- **Settings pull on login**: `pullAllData()` loads settings from Supabase so they restore on new devices
- **Expense payment_mode sync fix**: Remove `payment_mode` from `_stripLocalOnlyColumns` so it syncs to cloud
- **Supabase migration**: Add `payment_mode` column to `expenses` table in Supabase + create `user_settings` table

## Capabilities

### New Capabilities
- `settings-cloud-sync`: Sync all user configuration (shop details, GST, loyalty, receipt footer, auto-print) to Supabase via a `user_settings` key-value table, with pull-on-login restore
- `expense-payment-mode-sync`: Ensure expense payment mode (Cash/UPI/Card) is persisted to Supabase for accurate financial reports

### Modified Capabilities
_(none — no existing spec-level requirements are changing)_

## Impact

- **Providers affected**: `LoyaltySettingsProvider` (needs Supabase write), `SettingsScreen` (needs sync calls)
- **Supabase service**: `pullAllData()` updated, `_stripLocalOnlyColumns` modified
- **Database**: New `user_settings` table, `expenses` table gets `payment_mode` column
- **Migration**: `022_user_settings.sql` + `023_expense_payment_mode.sql`
- **Data isolation**: All settings scoped by `user_id` via RLS — multi-tenant safe
