## Context

SKYWALK Billing uses a dual-write architecture: all business data writes to local SQLite first, then syncs to Supabase via `SupabaseService.syncRecord()` / `guaranteedSave()`. On login, `pullAllData()` restores all cloud data to local DB. This ensures offline-first operation with cloud backup.

**Current gap:** The `settings` table and `SharedPreferences` keys used for shop configuration, GST info, and loyalty program settings are **never synced to Supabase**. The `settings` table is not in the pull list, and `LoyaltySettingsProvider` writes only to `SharedPreferences`.

Additionally, `expenses.payment_mode` is actively stripped in `_stripLocalOnlyColumns()` before Supabase sync, meaning expense payment breakdown data (Cash/UPI/Card) is lost in cloud.

## Goals / Non-Goals

**Goals:**
- Sync all user settings to Supabase via a `user_settings` key-value table
- Restore settings on login (new device/browser) via `pullAllData()`
- Sync `expenses.payment_mode` to Supabase for accurate financial reports
- Maintain backward compatibility — existing clients get settings synced on next save

**Non-Goals:**
- UI redesign of Settings screen (no visual changes)
- Syncing ephemeral UI state (scroll position, expanded panels)
- Syncing theme preference (low priority, stays in SharedPreferences)

## Decisions

### 1. Key-value `user_settings` table vs individual columns
**Decision:** Key-value table (`key TEXT, value TEXT`)  
**Rationale:** Settings are diverse (strings, bools, numbers) and grow over time. A KV table avoids schema migrations for every new setting. Other tables (items, sales) use fixed columns because they have relational integrity needs — settings do not.  
**Alternative rejected:** Adding a `settings` JSONB column to a `user_profiles` table. This would require custom merge logic for partial updates.

### 2. Write-through sync (not queued)
**Decision:** Use `syncRecord()` (async with queue fallback) for settings writes  
**Rationale:** Settings changes are infrequent (configured once, rarely changed). The sync queue provides resilience without blocking the UI. Not using `guaranteedSave()` because settings loss is recoverable (user can re-enter), unlike sales data.

### 3. Expense payment_mode — add column to Supabase
**Decision:** Run migration to add `payment_mode TEXT DEFAULT 'Cash'` to Supabase `expenses` table, then remove from `_stripLocalOnlyColumns`.  
**Rationale:** The column already exists locally. The strip was likely added because the Supabase table didn't have it yet. Adding the column is a 1-line migration. No app code change needed beyond removing the strip.

## Risks / Trade-offs

- **[Risk] Existing clients have settings in SharedPreferences only** → On first app load after update, bulk-sync all local settings to Supabase. This is a one-time migration.
- **[Risk] Key collisions across devices** → `user_id` scoping via RLS prevents cross-user conflicts. Same-user multi-device: latest `updated_at` wins (consistent with existing conflict resolution).
- **[Risk] `pullAllData()` overwrites local settings** → Pull only populates if local key is missing. Existing local values take precedence (user may have customized on this device).
