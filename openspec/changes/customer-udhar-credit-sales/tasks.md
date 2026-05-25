## 1. Database & Model Layer

- [x] 1.1 Create migration `020_customer_udhar.sql`: add `balance REAL DEFAULT 0` to `customers`, add `due_amount REAL DEFAULT 0` to `sales`
- [x] 1.2 Add `balance` field to `CustomerModel` (toMap, fromMap, copyWith)
- [x] 1.3 Add `dueAmount` field to `SaleModel` (toMap, fromMap, copyWith) + `isUdhar` getter

## 2. Sales Terminal — Udhar Toggle

- [x] 2.1 Add `_isUdhar` toggle state to `SalesProvider` with getter/setter
- [x] 2.2 Add Udhar toggle button UI in `SalesTerminalScreen` payment section (animated toggle with warning color)
- [x] 2.3 On `completeSale()`: if Udhar is ON, calculate `dueAmount = grandTotal - cashPaid - upiPaid - cardPaid`, save to SaleModel
- [x] 2.4 On `completeSale()`: if Udhar is ON and no customer name/phone, block sale with error message
- [x] 2.5 On `completeSale()`: if Udhar is ON and `dueAmount > 0`, increment `customer.balance` by `dueAmount`

## 3. Customer Screen — Collect Payment

- [x] 3.1 Add `collectPayment(customerId, amount, method)` to `CustomerProvider` — reduces `balance`, syncs to Supabase
- [x] 3.2 Add "Collect" button on Customer Screen for customers with `balance > 0` (in popup menu, green styled)
- [x] 3.3 Build collection dialog: amount field + Cash/UPI radio + confirm button. Validate amount <= balance.
- [x] 3.4 Add Udhar balance badge on customer tiles (warning orange, shows outstanding amount)

## 4. Dashboard — Customer Dues Card

- [x] 4.1 Add `customersWithDues` getter + `totalCustomerDues` to `CustomerProvider`
- [x] 4.2 Load customer dues in `_loadDashboardData()` (mirrors vendor dues pattern)
- [x] 4.3 Add "Customer Dues (Udhar)" card with stat + list (warning/orange theme, top 5 customers by balance)

## 5. CRM Reports — Balance Column & Filter

- [x] 5.1 Add `Balance` badge in CRM customer list (shows Udhar amount per customer)
- [x] 5.2 Add "Dues" filter toggle to show only customers with `balance > 0`
- [x] 5.3 Enhanced `_panelCard` to support `headerAction` for filter widget

## 6. Build, Test & Deploy

- [x] 6.1 Build web release — verified no compilation errors (52.8s clean build)
- [x] 6.2 Committed with OpenSpec reference, pushed to main/zaheer/Ashiq
- [ ] 6.3 **USER ACTION**: Run migration 020 on Supabase SQL Editor (see `supabase/migrations/020_customer_udhar.sql`)
