# SKYWALK Billing — Project Summary for Teammates

## Quick Start
```bash
cd "/Users/zoro/Downloads/SKYWALK Billing"
flutter build web --release
# Serve: cd build/web && python3 -m http.server 8090
# Open: http://localhost:8090
# Login: mohammedzaheerhussain2002@gmail.com / hello@123
```

## Tech Stack
- **Framework**: Flutter Web (Dart)
- **Backend**: Supabase (PostgreSQL + Auth)
- **State**: Provider pattern (ChangeNotifier)
- **Persistence**: Offline-first — in-memory `_WebDB` → Supabase sync
- **DB Version**: 7 (SQLite schema)

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
| `lib/app.dart` | Routes (splash → login → home) |
| `lib/screens/shell/app_shell.dart` | 15-tab sidebar, F-key shortcuts, auto-sync timer |
| `lib/data/local/db_helper.dart` | SQLite/WebDB, schema, migrations |
| `lib/data/remote/supabase_service.dart` | Auth, syncRecord, processSyncQueue, pullAllData |
| `lib/core/constants.dart` | DB version, invoice prefix, app name |
| `lib/core/theme/app_colors.dart` | All colors (dark/light) |
| `lib/core/theme/app_typography.dart` | Text styles |

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
| `ThemeProvider` | SharedPreferences | N/A |
| `AuthProvider` | Supabase Auth | N/A |

### Data Models
| Model | File |
|-------|------|
| `ItemModel` | `lib/data/models/item_model.dart` |
| `SaleModel` + `SaleItem` | `lib/data/models/sale_model.dart` |
| `CustomerModel` | `lib/data/models/customer_model.dart` |
| `VendorModel` | `lib/data/models/vendor_model.dart` |
| `PurchaseModel` | `lib/data/models/purchase_model.dart` |
| `StaffModel` | `lib/data/models/staff_model.dart` |
| `AttendanceModel` | `lib/data/models/attendance_model.dart` |
| `ExpenseModel` | `lib/data/models/expense_model.dart` |
| `CashTillModel` | `lib/data/models/cash_till_model.dart` |

## 10 Modules (Sidebar Tabs)

| # | Tab | Screen File | Status |
|---|-----|-------------|--------|
| 1 | Dashboard | `dashboard/dashboard_screen.dart` | ✅ |
| 2 | Sales Terminal | `sales/sales_terminal_screen.dart` | ✅ |
| 3 | Bill History | `bill_history/bill_history_screen.dart` | ✅ |
| 4 | Inventory | `inventory/inventory_screen.dart` | ✅ |
| 5 | Returns & Exchange | `returns/return_exchange_screen.dart` | ✅ Upgraded |
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

## Supabase Migrations
Run in order in Supabase SQL Editor:
1. `001_create_tables.sql` — items, sales, expenses, sync_queue
2. `002_add_vendor_column.sql` — vendor field on items
3. `003_vendors_purchases.sql` — vendors + purchases tables
4. `004_staff_attendance.sql` — staff + attendance tables
5. `005_customers.sql` — customers table
6. `006_extended_item_fields.sql` — barcode, category, size, color
7. `007_vendor_notes.sql` — notes field on vendors
8. `008_performance_indexes.sql` — composite indexes
9. `009_customer_loyalty.sql` — loyalty_points + last_purchase_date

## Environment Variables
```
SUPABASE_URL=https://zwljxbljabikmrcmhmdd.supabase.co
SUPABASE_ANON_KEY=eyJhbGci...
GROQ_API_KEY=gsk_1R50...
```
Place in `build/web/assets/.env` after each build.

## Coding Conventions
- **Every provider** must call `syncRecord()` on create/update/delete
- **Models** have `toMap()` / `fromMap()` / `copyWith()`
- **Colors**: Use `AppColors.xyz(context)` for theme-aware colors
- **Typography**: Use `AppTypography.h1`, `.bodyMedium`, `.mono`, etc.
- **IDs**: Generated via `Uuid().v4()`
- **Invoice numbers**: `SKY-XXXX` format

## Branch Info
- `main` — production, all 10 phases complete
- `Ashiq` — synced with main, ready for new tasks
