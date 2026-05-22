## ADDED Requirements

### Requirement: Sales terminal SHALL have an Udhar toggle
The sales terminal SHALL provide an "Udhar / Pay Later" toggle button. When enabled, the sale is treated as a credit sale and the unpaid portion is recorded as `due_amount`.

#### Scenario: Udhar toggle OFF (default)
- **WHEN** a sale is completed with Udhar toggle OFF
- **THEN** the sale behaves as today — full payment required via Cash/UPI/Card

#### Scenario: Udhar toggle ON with partial payment
- **WHEN** Udhar toggle is ON, bill total is ₹1000, and staff enters Cash ₹400
- **THEN** `due_amount` SHALL be ₹600 and `customer.balance` SHALL increase by ₹600

#### Scenario: Udhar toggle ON with zero payment
- **WHEN** Udhar toggle is ON and staff enters no payment amount
- **THEN** `due_amount` SHALL equal the full bill total

### Requirement: Udhar sales SHALL require identified customer
The system SHALL block Udhar sales for walk-in (unnamed) customers. A customer name AND phone number MUST be provided.

#### Scenario: Udhar without customer info
- **WHEN** Udhar toggle is ON and no customer name or phone is entered
- **THEN** the system SHALL show an error: "Customer name and phone required for Udhar sales"

#### Scenario: Udhar with customer info
- **WHEN** Udhar toggle is ON and customer name "Ravi" and phone "9876543210" are entered
- **THEN** the sale SHALL proceed and the due amount SHALL be linked to customer "Ravi"

### Requirement: Customer model SHALL track outstanding balance
`CustomerModel` SHALL have a `balance` field representing total amount the customer owes. This mirrors `VendorModel.balance`.

#### Scenario: New customer has zero balance
- **WHEN** a new customer is created
- **THEN** `balance` SHALL default to 0

#### Scenario: Balance accumulates across Udhar sales
- **WHEN** customer has balance ₹600 and makes another Udhar sale with due ₹400
- **THEN** customer balance SHALL become ₹1000

### Requirement: Customer screen SHALL allow payment collection
The Customer Screen SHALL show a "Collect Payment" button for customers with `balance > 0`. The collection dialog SHALL capture amount and payment method (Cash or UPI).

#### Scenario: Collect full balance
- **WHEN** customer has balance ₹1000 and staff collects ₹1000 via Cash
- **THEN** customer balance SHALL become ₹0

#### Scenario: Collect partial balance
- **WHEN** customer has balance ₹1000 and staff collects ₹400 via UPI
- **THEN** customer balance SHALL become ₹600

#### Scenario: Collection amount exceeds balance
- **WHEN** customer has balance ₹500 and staff tries to collect ₹600
- **THEN** the system SHALL show an error: "Amount exceeds outstanding balance"

### Requirement: Dashboard SHALL show Customer Dues
The dashboard SHALL display a "Customer Dues (Udhar)" section with a stat card showing total receivables and a list of customers with outstanding balances, sorted by highest balance first. This mirrors the existing Vendor Dues section.

#### Scenario: Dashboard with customer dues
- **WHEN** 3 customers have outstanding balances: ₹1000, ₹600, ₹200
- **THEN** the stat card SHALL show "₹1,800" total and the list SHALL show all 3 customers sorted by balance descending

#### Scenario: No customer dues
- **WHEN** no customers have outstanding balances
- **THEN** the Customer Dues section SHALL be hidden

### Requirement: CRM Reports SHALL include customer balance
The CRM Reports screen SHALL show a `Balance` column for each customer and provide a filter to show only customers with outstanding balances.

#### Scenario: CRM report with balance filter
- **WHEN** staff enables "Outstanding Balance" filter
- **THEN** only customers with `balance > 0` SHALL be displayed

### Requirement: Payment distribution SHALL track Udhar collections
When a customer collection is recorded as Cash or UPI, the dashboard payment distribution SHALL include these amounts in the respective Cash/UPI totals.

#### Scenario: Udhar collection via Cash reflected in dashboard
- **WHEN** ₹500 is collected from a customer via Cash
- **THEN** the Cash total in payment distribution SHALL increase by ₹500
