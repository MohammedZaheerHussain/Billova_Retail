## 1. Database & Model Layer

- [ ] 1.1 Create migration `020_customer_udhar.sql`: add `balance REAL DEFAULT 0` to `customers`, add `due_amount REAL DEFAULT 0` to `sales`
- [ ] 1.2 Add `balance` field to `CustomerModel` (toMap, fromMap, copyWith)
- [ ] 1.3 Add `dueAmount` field to `SaleModel` (toMap, fromMap, copyWith)

## 2. Sales Terminal — Udhar Toggle

- [ ] 2.1 Add `_isUdhar` toggle state to `SalesProvider` with getter/setter
- [ ] 2.2 Add Udhar toggle button UI in `SalesTerminalScreen` payment section (between discount and payment split)
- [ ] 2.3 On `completeSale()`: if Udhar is ON, calculate `dueAmount = grandTotal - cashPaid - upiPaid - cardPaid`, save to SaleModel
- [ ] 2.4 On `completeSale()`: if Udhar is ON and no customer name/phone, block sale with error message
- [ ] 2.5 On `completeSale()`: if Udhar is ON and `dueAmount > 0`, increment `customer.balance` by `dueAmount`

## 3. Customer Screen — Collect Payment

- [ ] 3.1 Add `collectPayment(customerId, amount, method)` to `CustomerProvider` — reduces `balance`, syncs to Supabase
- [ ] 3.2 Add "Collect" button on Customer Screen for customers with `balance > 0` (styled with accent/warning color)
- [ ] 3.3 Build collection dialog: amount field + Cash/UPI radio + confirm button. Validate amount <= balance.

## 4. Dashboard — Customer Dues Card

- [ ] 4.1 Query customers with `balance > 0` in `_loadDashboardData()` (mirrors vendor dues pattern)
- [ ] 4.2 Add "Customer Dues (Udhar)" stat card showing total receivables
- [ ] 4.3 Add customer dues list card (top 5 customers by balance, mirrors `_buildVendorAlerts()`)

## 5. CRM Reports — Balance Column & Filter

- [ ] 5.1 Add `Balance` column to CRM customer table
- [ ] 5.2 Add "Outstanding Balance" filter toggle to show only customers with `balance > 0`

## 6. Build, Test & Deploy

- [ ] 6.1 Build web release — verify no compilation errors
- [ ] 6.2 Commit with OpenSpec reference, push to main/zaheer/Ashiq
