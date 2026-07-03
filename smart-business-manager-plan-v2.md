# Smart Business Manager — Project Plan v2

*Revised from the original vision document. This version fixes the gaps flagged in review, accounts for the fact that the developer (you) lives in a different city from the primary user (your father), and locks in the actual tech stack: Flutter, built with Google Antigravity, backed by Firebase.*

---

## 1. What changed from v1

| # | v1 gap | v2 fix |
|---|---|---|
| 1 | Backup/Restore was a manual settings action — easy to forget, useless if the phone is lost before a backup is taken | Data lives in the cloud by default (Firestore). There is no "backup step" — every save is already off the phone. Restore = sign in on a new device. |
| 2 | Sale flow (per-invoice partial payment) and Customer Ledger (running balance) implied two different data models | Locked to **one model**: a running balance per customer, with a payment log. A payment can optionally be tagged to a specific sale for reference, but the balance is always `pendingAmount` on the customer record — kept correct automatically (see §4). |
| 3 | No concept of who entered a transaction | Every sale, payment, and purchase now carries `createdBy`. Not urgent with one user, but it's free to add now and expensive to retrofit later — and it becomes genuinely useful with the remote-access setup in §5. |
| 4 | Barcode field on products implied a scanning feature nothing else supported | Cut from v1. Your father's suppliers don't barcode fridge stands and remotes — this field added complexity with no payoff. Revisit only if a supplier relationship changes. |
| 5 | AI features (voice entry, invoice scanning) assumed always-on connectivity, conflicting with the offline-first goal | Explicitly scoped as **optional, connectivity-dependent enhancements** that fail gracefully back to manual entry. They're phase 3 (see §8), not core. |

## 2. New constraint that reshapes the plan: you're not in the same city

This is the single biggest change from v1, bigger than any individual bug fix. It affects almost every decision below:

- You can't walk over and fix a sync conflict, restore a backup, or show your father how to tap a button. **Whatever ships has to be self-explanatory, and whatever breaks has to be visible and fixable by you, remotely, without touching his phone.**
- This pushes hard toward a **cloud-first architecture** rather than a "local database that occasionally syncs" architecture. If the source of truth lives in the cloud, you can inspect it, fix it, and monitor it from your own laptop in your own city, any time.
- It also means onboarding and support need a plan, not just the app itself (see §5.4).

## 3. Tech stack decision

| Layer | Choice | Why |
|---|---|---|
| App framework | **Flutter** | Already decided in the earlier discussion — good fit for a simple, large-button, single-codebase app. |
| Build tool | **Google Antigravity** | Since you're building this solo, remotely, and want to move fast: Antigravity is Google's agentic IDE for Flutter — you describe a module in plain language, review its plan, and it writes, runs, and hot-reloads the code. It has native Firebase integration, which pairs directly with the backend choice below. |
| Backend / DBMS | **Firebase (Firestore + Authentication + Cloud Functions + Crashlytics + App Distribution)** | See §4 for the full reasoning. Short version: it removes the need to hand-build a sync layer, and it gives you remote visibility into your father's data and app health without needing physical access to his phone. |

### Why Firebase specifically (you asked me to just decide)

I'd initially sketched a hybrid — a local SQLite-style database (Drift) with manual sync to a cloud backend — because that gives the cleanest relational modeling for ledger math. That was the right call *if you're on-site and can debug a custom sync layer in person*. It's the wrong call now:

- **You won't be there to debug sync bugs.** A hand-rolled sync layer is exactly the kind of thing that breaks in a way only visible on your father's phone, at a moment you can't see.
- **Firestore's offline persistence is built in, not built by you.** Reads and writes work identically online or offline; queued writes sync automatically the moment connectivity returns. No `synced` flag to manage, no custom queue, no conflict-resolution code to write and maintain.
- **You get a remote window into the business.** Anything happening on your father's phone is visible to you, from your city, in the Firebase console — sales as they're recorded, crash reports if the app misbehaves, usage patterns if something seems off. This directly solves the "I'm not there to notice something's wrong" problem.
- **Antigravity has native Firebase tooling**, which means less custom integration code for the AI agent to get wrong.
- The trade-off is that Firestore is a NoSQL document store, not relational — no joins. At the scale of one shop's inventory and customer ledger (hundreds of customers, thousands of transactions a year, not millions), this is a non-issue as long as the aggregate numbers (stock levels, pending balances) are kept correct at write-time using Firestore transactions, rather than computed with a join at read-time. That's exactly the pattern in §4.

## 4. Revised data model (Firestore collections)

Same entities as the diagram from the earlier discussion, restructured as Firestore collections. The key difference from a SQL schema: instead of computing `pendingAmount` with a `SUM()` query, it's stored directly on the customer record and updated **atomically** inside the same transaction as the sale or payment that changed it. This is the standard Firestore pattern for exactly this kind of running-balance problem.

```
customers/{customerId}
  name, phone, address
  totalPurchases        ← updated atomically on each sale
  pendingAmount          ← updated atomically on each sale/payment
  createdAt

products/{productId}
  name, category, supplierId
  purchasePrice, sellingPrice
  currentStock           ← updated atomically on each sale/purchase
  minStock

suppliers/{supplierId}
  name, phone

sales/{saleId}
  customerId, saleDate
  items: [{ productId, productName, quantity, unitPrice, subtotal }]
  totalAmount, discount, paidAmount
  createdBy

payments/{paymentId}
  customerId, saleId (optional — for reference only)
  amount, paymentDate, method
  createdBy

purchases/{purchaseId}
  supplierId, purchaseDate
  items: [{ productId, quantity, unitCost }]
  totalCost
  createdBy
```

**How the atomic update works, concretely — and why it has to work offline:** a Firestore *transaction* (reading the current value, checking it, writing a new one) requires a live round-trip to the server, so it fails outright with no connectivity. Since recording a sale offline is a hard requirement here, stock and balance updates instead use Firestore's **atomic increment operator** (`FieldValue.increment()`) rather than a transaction. When a sale is saved: the `sales` document is written, `currentStock` on each product is decremented by an increment call, and the customer's `totalPurchases`/`pendingAmount` are incremented the same way. Increments queue locally exactly like any other offline write and apply in order once the phone is back online — so the numbers stay correct whether he's connected or not. Recording a payment is the same pattern in miniature: write the `payments` document and decrement `pendingAmount` by an increment call.

### 4.1 Offline drafts and sync status

Nothing needs to be built as a separate "offline mode" — Firestore's SDK caches writes locally by default and syncs them the moment connectivity returns, so a sale recorded with no signal looks and behaves exactly like one recorded with signal. The one addition worth making: each Firestore snapshot exposes a `hasPendingWrites` flag, which tells you whether that specific record has actually reached the server yet. Surface this as a small "saved, syncing…" indicator on recent transactions in Module 4 — it gives your father visible confirmation that nothing's lost even before it's uploaded, without any custom queue or draft system to build and maintain.

One practical setup step: make sure Firestore's offline cache is configured for unlimited size (rather than the SDK default) when the app is initialized, so a full day's transactions and the product/customer lists stay available locally even after extended offline use.

## 5. Designing for remote operation

### 5.1 Two accounts, two roles
Set up Firebase Authentication with two accounts:
- **Operator (your father)** — full read/write access to his own business data. Simple phone-number OTP login, the same login pattern as WhatsApp, so it needs no explanation.
- **Admin (you)** — read-only access via Firestore security rules. You can open the Firebase console or a lightweight admin view from your own city and see exactly what he sees — stock levels, pending payments, recent sales — without any risk of accidentally editing his live data.

### 5.2 Remote crash visibility
Wire in **Firebase Crashlytics**. If the app crashes or throws an error on his phone, you get a report in your console with a stack trace — you'll often know about a problem before he mentions it, and you can usually diagnose it without asking him to describe what happened.

### 5.3 Pushing updates without being there
Two practical options, both avoiding a trip to install anything by hand:
- **Firebase App Distribution** for pre-release builds — you send a link, he taps it, it installs. Good while the app is actively evolving.
- **Google Play (internal testing track)** once it's stable enough for daily use — updates just show up the way any Play Store app updates.

### 5.4 Onboarding and ongoing support
The app itself needs a first-run walkthrough (large text, one tap at a time — this matters more here than in a typical app, since there's no one beside him to say "no, tap that one"). Beyond the app:
- Record a short screen-share walkthrough and send it over WhatsApp — he already uses WhatsApp daily, so this costs him nothing to consume.
- Keep a WhatsApp voice-note channel open for "how do I..." questions rather than expecting him to text a detailed bug report.
- If something needs your hands-on help, a remote-control app (e.g. AnyDesk) as a fallback is worth having installed in advance, before it's needed in a panic.

## 6. Module changes at a glance

Modules 1, 4, 5, 6, 7, 9, 10 from the original plan are unchanged in spirit. The changes:

- **Module 2 (Inventory):** drop the barcode field for v1.
- **Module 3 (Customer Ledger):** now explicitly backed by the running-balance model in §4, not per-invoice reconciliation.
- **Module 8 (Notifications):** low-stock and overdue-payment alerts are a natural fit for a Cloud Function that runs on a schedule and pushes a notification — this can live entirely server-side, so it keeps working even if his phone hasn't opened the app in a few days.
- **Module 10 (Settings):** "Backup/Restore" is reframed as "Signed in as [phone number]" — there's nothing to manually back up anymore.

## 7. Building it with Antigravity

Practical notes for the actual build process, since this is new territory:

- **Plan first, always.** Antigravity works best when you ask it to propose a plan before writing code — for each module, describe the goal, the data it touches, and constraints ("must work offline," "must update stock atomically"), and review the plan before letting it execute.
- **Build the data layer first.** Get the Firestore collections and the atomic transaction logic (§4) working and tested in isolation before building the UI on top of them — that logic is the part where a subtle bug costs your father real money, so it deserves the most scrutiny.
- **One module at a time.** Match the module boundaries from §6 — it keeps each Antigravity session focused and each change easy to review.
- **Use the built-in device preview loop.** Antigravity can hot-reload the running app as it edits, so you can sanity-check each screen (large buttons, big fonts, minimal text) as it's built rather than at the end.

## 8. Roadmap

| Phase | Scope |
|---|---|
| **Phase 1 — Core** | Modules 1–7, 9, 10. Firestore data model, atomic balance/stock updates, operator login. This is the app your father starts using daily. |
| **Phase 2 — Remote operations** | Admin read-only view, Crashlytics, App Distribution pipeline, notifications (Module 8). |
| **Phase 3 — AI features** | Smart sales assistant, predictive inventory, invoice scanning — each shipped as optional and connectivity-gated, never a dependency for core recording of a sale. |

---

*Next natural step once you start building: define the exact Firestore security rules for the operator/admin split in §5.1 — that's worth getting right before the first real transaction is recorded.*
