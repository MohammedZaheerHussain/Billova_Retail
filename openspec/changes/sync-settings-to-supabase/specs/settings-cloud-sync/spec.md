## ADDED Requirements

### Requirement: Settings persist to Supabase on save
The system SHALL save all user settings to a `user_settings` Supabase table whenever the user saves settings in the Settings screen or changes loyalty configuration.

#### Scenario: User saves shop settings
- **WHEN** user edits shop name, address, phone, logo, or receipt footer and taps Save
- **THEN** all settings are written to local storage AND synced to Supabase `user_settings` table with the user's `user_id`

#### Scenario: User changes GST configuration
- **WHEN** user toggles GST enabled, or updates GST number, business name, or state code
- **THEN** all GST settings are persisted to Supabase `user_settings` table

#### Scenario: User changes loyalty settings
- **WHEN** user changes loyalty enabled, earn rate, redeem value, or minimum redeem threshold
- **THEN** all loyalty settings are persisted to Supabase `user_settings` table (not just SharedPreferences)

#### Scenario: Settings sync fails
- **WHEN** Supabase is unreachable during settings save
- **THEN** settings are saved locally AND added to `sync_queue` for retry on next app launch

### Requirement: Settings restore on login
The system SHALL restore user settings from Supabase when a user logs in on a new device or after clearing browser data.

#### Scenario: User logs in on new device
- **WHEN** user logs in and `pullAllData()` runs
- **THEN** all settings from `user_settings` table are pulled and written to local `settings` table and SharedPreferences

#### Scenario: Local settings already exist
- **WHEN** user logs in and local settings already have values
- **THEN** local values are NOT overwritten (local takes precedence to preserve device-specific customization)

#### Scenario: No cloud settings exist yet
- **WHEN** user logs in for the first time (pre-update user with no cloud settings)
- **THEN** app uses existing local settings and syncs them to Supabase on next save

### Requirement: Settings table uses RLS for data isolation
The system SHALL enforce row-level security on `user_settings` so each user can only read/write their own settings.

#### Scenario: Multi-tenant isolation
- **WHEN** two different users share the same Supabase project
- **THEN** each user sees only their own settings, enforced by `auth.uid() = user_id` RLS policy

### Requirement: Bulk initial sync of existing settings
The system SHALL perform a one-time bulk upload of all local settings to Supabase when the app detects settings have never been synced.

#### Scenario: First launch after update
- **WHEN** user opens the app after the update and settings have never been synced
- **THEN** all local settings (shop, GST, loyalty, receipt, auto-print) are uploaded to Supabase
