# Smart Business Manager — Information Architecture (IA)

## 1. Overview
This document outlines the screen hierarchy and navigation flow for the Smart Business Manager app, focusing on simplicity, large tap targets, and minimizing user cognitive load. 

## 2. Global Navigation (Bottom Nav Bar or Drawer)
Given the core modules, the primary navigation should prioritize the most frequent actions:
1. **Dashboard** (Default home screen)
2. **Sales**
3. **Customers**
4. **Inventory**
5. **More** (Access to Purchases, Reports, Settings)

## 3. Screen Hierarchy & Flows

### 3.1 Dashboard (Home)
- **Content:**
  - Today's Sales Total (Large metric)
  - Total Pending Payments (across all customers)
  - Current Stock Value
  - Low-stock Alerts / Actionable items
- **Actions:**
  - Quick action FAB (Floating Action Button): "New Sale" or "New Payment"
  - Tap on "Pending Payments" -> Navigates to Customer Ledger sorted by due amount.
  - Tap on "Low-stock Alerts" -> Navigates to Inventory (filtered).

### 3.2 Sales Module
- **Sales List Screen:**
  - Chronological list of recent sales.
  - Search bar (by customer name).
  - Action: "Record New Sale" button.
- **New Sale Flow:**
  1. **Select Customer:** Search or pick from a list (or add new).
  2. **Add Products:** Pick products, enter quantity (shows current stock & price).
  3. **Review & Checkout:** 
     - Show Subtotal.
     - Option to add Discount.
     - Field: "Amount Paid Now" (Defaults to full amount, operator can edit for partial payment).
  4. **Save & Finish** (Updates stock and customer balances automatically).

### 3.3 Payments Module
- **Payments List Screen:**
  - Chronological list of recent payments received.
  - Action: "Record New Payment" button.
- **New Payment Flow:**
  1. **Select Customer:** Search or pick from list (shows current pending balance).
  2. **Enter Amount:** Large keypad entry.
  3. **Save & Finish** (Instantly reduces customer's pending amount).

### 3.4 Customer Ledger
- **Customer List Screen:**
  - List of all customers, showing names and current `pendingAmount`.
  - Sort by: Name, Pending Amount (Highest first).
  - Action: "Add Customer".
- **Customer Detail Screen:**
  - **Header:** Name, Phone, Address, Total Pending Balance.
  - **Tabs/List:** 
    - *Ledger History*: Interleaved chronological view of Sales and Payments for this customer.
  - **Actions:** "Record Payment" (auto-selects this customer), "Call", "WhatsApp".

### 3.5 Inventory
- **Product List Screen:**
  - List of products showing name, price, and `currentStock`.
  - Visual indicators for low stock (e.g., red text).
  - Search bar.
  - Action: "Add Product".
- **Product Detail Screen:**
  - Info: Category, Supplier, Purchase/Selling Price, Min Stock.
  - Action: "Edit Details", "Quick Stock Adjustment" (if explicitly needed, though standard flow is via Purchases).

### 3.6 Purchases
- **Purchase List Screen:**
  - History of stock inward entries.
  - Action: "New Purchase" button.
- **New Purchase Flow:**
  1. **Select Supplier.**
  2. **Add Products:** Enter received quantity and cost.
  3. **Review Total Cost.**
  4. **Save & Finish** (Increases stock for all items).

### 3.7 Reports
- **Reports Dashboard:**
  - Toggles: Weekly / Monthly / Yearly.
  - Metrics: Revenue, Profit, Total Pending.
  - Lists: Best-selling products, Highest-due customers.

### 3.8 Settings
- **Settings Screen:**
  - Business Information (Name, Contact).
  - Preferences: Dark/Light Mode.
  - "Signed in as [Phone Number]".
  - Logout.

## 4. Search (Global)
- Accessible from the top app bar in main screens.
- **Results:**
  - Products (shows stock, price).
  - Customers (shows balance, recent activity).

## 5. UI/UX Principles
- **Minimal Typing:** Use selectors and pre-filled defaults (e.g., product prices) over manual text entry.
- **Large Targets:** Buttons and list items should be easily tappable by someone not used to complex apps.
- **No Jargon:** Use "Money to collect" instead of "Accounts Receivable", "Stock" instead of "Inventory Count".
- **Immediate Feedback:** "Saved, syncing..." state to reassure the operator that data is safe offline.
