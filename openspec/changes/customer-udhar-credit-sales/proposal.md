## Why

Customers sometimes take products without paying the full amount ("Udhar" / credit). Currently the system has no way to track this — the sale completes as if fully paid, and the outstanding balance is lost. The vendor section already supports Udhar (`VendorModel.balance`), but customers lack this feature. This is a critical business need — the store needs to know exactly who owes money and how much.

## What Changes

- **Sales Terminal**: Add "Udhar / Pay Later" toggle button. When enabled, the sale is saved with a `due_amount` equal to the unpaid portion. Require customer name+phone for Udhar sales (block walk-in credit).
- **SaleModel**: Add `due_amount` field to track unpaid balance per sale.
- **CustomerModel**: Add `balance` field to track cumulative outstanding amount (mirrors `VendorModel.balance`).
- **Customer Screen**: Add "Collect Payment" button for customers with `balance > 0`. Track collection as Cash or UPI. Reduce customer balance on collection.
- **Dashboard**: Add "Customer Dues (Udhar)" stat card + list card (mirrors existing Vendor Dues section).
- **CRM Reports**: Add customer balance column. Add filter for customers with outstanding balance.
- **Supabase Migration**: Add `balance` column to `customers` table, `due_amount` to `sales` table.

## Capabilities

### New Capabilities
- `customer-credit`: Customer Udhar/credit sales with balance tracking, payment collection, dashboard visibility, and CRM reporting

### Modified Capabilities
_(none — no existing specs)_

## Impact

- **Providers affected**: `SalesProvider` (Udhar toggle, due_amount), `CustomerProvider` (balance field, collection)
- **Models affected**: `SaleModel` (due_amount), `CustomerModel` (balance)
- **Screens affected**: `SalesTerminalScreen` (Udhar toggle), `CustomerScreen` (Collect button), `DashboardScreen` (Customer Dues card), `CrmReportsScreen` (balance column/filter)
- **Database**: Migration adds `balance` to `customers`, `due_amount` to `sales`
- **Cloud sync**: Both new columns must sync to Supabase
