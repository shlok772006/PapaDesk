# Smart Business Manager — Product Requirements Document (PRD)

## 1. Overview

A mobile app that replaces notebooks, WhatsApp messages, and memory as the way a small electronics-accessories retail/wholesale business tracks inventory, sales, credit, and payments. Built for one specific business, with a design philosophy that prioritizes simplicity over feature completeness.

## 2. Problem statement

The business currently runs on manual tracking: notebooks, bills, WhatsApp messages, and memory. This causes, in order of severity:

1. **Forgotten or disputed pending payments** — the single biggest source of financial loss. Both parties simply forget what's owed.
2. **No fast answer to "how much does X owe me"** or **"how many of Y do I have"** — requires manually searching notebooks or physically counting stock.
3. **Partial payments tracked across multiple notebook entries over weeks or months**, with no running total.
4. **No visibility into what sells, what's profitable, or which customers matter most.**
5. **Occasional duplicate ordering** because current stock isn't known at a glance.

## 3. Users

| Role | Who | Needs |
|---|---|---|
| **Operator** | Father — full-time salesman running this business alongside his job | Record a sale or payment in under 30 seconds; see stock and pending dues at a glance; large buttons, minimal typing; must work with no internet |
| **Admin (remote)** | Son — builds and maintains the app, lives in a different city | Read-only visibility into the business's data and the app's health, without physical access to the phone |

## 4. Goals

- Replace notebooks and memory as the source of truth for inventory, sales, and dues.
- Every transaction (sale, payment, purchase) takes under 30 seconds to record.
- Works fully offline; nothing is lost or delayed by lack of signal.
- Operable entirely by someone with no prior experience with business software.
- Supportable and debuggable remotely, without physical access to the device.

## 5. Non-goals (out of scope for v1)

- GST/tax computation or compliance features.
- Barcode scanning (no current supplier barcodes exist products to scan).
- Payroll, employee management, or multi-warehouse support.
- Multiple simultaneous operator accounts (only one operator for now — the data model allows for more later, see `system-design.md`).
- AI features (voice entry, invoice OCR, predictive reordering) — deferred to a later phase and never a dependency for core recording of a transaction.

## 6. Functional requirements by module

### 6.1 Dashboard
- On open, show without any taps: today's sales total, total pending payments across all customers, current stock value, count of low-stock products, total customer count.
- All values reflect on-device data immediately, even if not yet synced to the server.

### 6.2 Inventory
- Each product has: name, category, purchase price, selling price, current stock, minimum stock threshold, supplier.
- Stock decreases automatically when a sale is recorded, increases automatically when a purchase is recorded — never edited by hand in normal use.
- A product below its minimum stock threshold is flagged (feeds Dashboard and Notifications).

### 6.3 Customer Ledger
- Each customer has: name, phone number, address, running pending balance, lifetime total purchases, and a chronological history of sales and payments.
- Pending balance is always correct and current — never requires the operator to manually total anything.

### 6.4 Sales
- Flow: select customer → add one or more products with quantities → optional discount → enter amount paid now (can be partial or zero) → save.
- On save: stock decrements for every product in the sale, the customer's pending balance and lifetime total update, and the dashboard reflects the change — all without a separate step.
- Must complete and feel "saved" with no internet connection.

### 6.5 Payments
- Flow: open a customer → enter amount received → save.
- Reduces that customer's pending balance immediately.
- Optionally reference a specific past sale, for the operator's own reference — not required, and never blocks saving.

### 6.6 Purchases
- Flow: select supplier → add products and quantities → enter cost → save.
- Increases stock for each product automatically.

### 6.7 Reports
- Weekly, monthly, and yearly views of: revenue, profit, pending totals, best-selling products, slow-moving products, highest-paying customer, highest-due customer.

### 6.8 Notifications
- Low stock alerts, overdue payment reminders, and a "monthly report ready" notice.
- Must continue to function even if the app hasn't been opened in several days (i.e., not purely client-triggered).

### 6.9 Search
- A single search box that surfaces a product's current stock, price, last sale date, and supplier, or a customer's balance and recent activity.

### 6.10 Settings
- Business info, dark mode, language (future), invoice template.
- No manual "backup" action — see `system-design.md` for why this is unnecessary by design.

## 7. Non-functional requirements

- **Offline-first**: every core action (sale, payment, purchase, viewing stock/balances) must work with zero connectivity and sync automatically once reconnected, with no data loss and no operator-visible errors.
- **Simplicity**: large fonts, large tap targets, minimal required typing, no jargon. If a feature can't be explained to the operator in one sentence, it doesn't belong in v1.
- **Remote operability**: the admin (son) must be able to observe data and diagnose problems without physical access to the operator's device.
- **Data integrity**: stock and pending-balance figures must never drift from what they should be, even under offline use, app crashes, or the operator force-closing mid-transaction.

## 8. Success criteria

- Father records a real sale and a real payment without asking for help, within the first week.
- Zero instances of "the app says X but the real stock/balance is Y" in the first three months.
- A crash or bug is visible to the son (via Crashlytics) before the father needs to report it, in the majority of cases.
