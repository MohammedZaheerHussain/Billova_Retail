# Billova Retail — Project Summary

## Quick Start
```bash
flutter pub get
flutter run -d chrome
```

## Tech Stack
- **Framework**: Flutter Web / Multi-platform (Dart)
- **Backend**: Supabase (PostgreSQL + Auth)
- **State**: Provider pattern (ChangeNotifier)
- **Persistence**: Offline-first — in-memory `_WebDB` (Web) / SQLite (Desktop/Mobile) → Supabase cloud sync
- **DB Version**: 16

## Architecture

### Offline-First Flow
```
User Action → Provider → DBHelper (local) → syncRecord() → Supabase (cloud)
                                                ↓ (if offline)
                                          sync_queue table
                                                ↓ (when online)
                                    processSyncQueue() → Supabase
```
- **Auto-sync**: Timer in `AppShell` runs every 5 minutes
- **Manual backup**: Settings → Backup button pushes ALL data

### Key Files
| File | Purpose |
|------|---------|
| `lib/main.dart` | App entry, Provider setup |
| `lib/app.dart` | BillovaApp routes (splash → login → home) |
| `lib/screens/shell/app_shell.dart` | 15-tab sidebar, F-key shortcuts, auto-sync timer |
| `lib/data/local/db_helper.dart` | SQLite/WebDB, schema, migrations |
| `lib/data/remote/supabase_service.dart` | Auth, syncRecord, processSyncQueue, pullAllData |
| `lib/core/constants.dart` | DB version, invoice prefix (BIL), app name |
| `lib/core/theme/app_colors.dart` | Theme colors (dark/light) |
| `lib/core/theme/app_typography.dart` | Typography system |

### Providers (State Managers)
| Provider | Table | Sync |
|----------|-------|------|
| `InventoryProvider` | items | ✅ |
| `SalesProvider` | sales | ✅ |
| `CustomerProvider` | customers | ✅ |
| `VendorProvider` | vendors | ✅ |
| `PurchaseProvider` | purchases | ✅ |
| `StaffProvider` | staff, attendance | ✅ |
| `ExpenseProvider` | expenses | ✅ |
| `CashTillProvider` | cash_till | ✅ |
| `LoyaltySettingsProvider` | loyalty settings | ✅ |
| `ClearanceProvider` | clearance_items | ✅ |
| `ReturnProvider` | sales/returns | ✅ |
| `ThemeProvider` | SharedPreferences | N/A |
| `AuthProvider` | Supabase Auth | N/A |

## 15 Modules (Sidebar Tabs)

| # | Tab | Screen File | Status |
|---|-----|-------------|--------|
| 1 | Dashboard | `dashboard/dashboard_screen.dart` | ✅ |
| 2 | Sales Terminal | `sales/sales_terminal_screen.dart` | ✅ |
| 3 | Bill History | `bill_history/bill_history_screen.dart` | ✅ |
| 4 | Inventory | `inventory/inventory_screen.dart` | ✅ |
| 5 | Returns & Exchange | `returns/return_exchange_screen.dart` | ✅ |
| 6 | Stock Clearance | `clearance/stock_clearance_screen.dart` | ✅ |
| 7 | Customers | `customers/customer_screen.dart` | ✅ |
| 8 | Vendors | `vendors/vendor_screen.dart` | ✅ |
| 9 | Purchase Inward | `purchases/purchase_screen.dart` | ✅ |
| 10 | Cash Till | `cash_till/cash_till_screen.dart` | ✅ |
| 11 | Expenses | `expenses/expenses_screen.dart` | ✅ |
| 12 | Staff | `staff/staff_screen.dart` | ✅ |
| 13 | CRM Reports | `reports/crm_reports_screen.dart` | ✅ |
| 14 | Loans & Chits | `loans/loans_chits_screen.dart` | ✅ |
| 15 | Settings | `settings/settings_screen.dart` | ✅ |

## Environment Variables
```
SUPABASE_URL=https://auqapthcohowhjcchnia.supabase.co
SUPABASE_ANON_KEY=sb_publishable_WoVw7PKKbK8BpASXg2eA0w_LooCAyZs
GROQ_API_KEY=gsk_1R50...
```
Place in `.env` in the root directory.

## Coding Conventions
- **Every provider** must call `syncRecord()` on create/update/delete
- **Models** have `toMap()` / `fromMap()` / `copyWith()`
- **Colors**: Use `AppColors.xyz(context)` for theme-aware colors
- **Typography**: Use `AppTypography.h1`, `.bodyMedium`, `.mono`, etc.
- **IDs**: Generated via `Uuid().v4()`
- **Invoice numbers**: `BIL-YYYYMM-XXXX` format
