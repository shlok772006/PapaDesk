# Smart Business Manager — System Design

## 1. Data model (Firestore collections)

```
customers/{customerId}
  name: string
  phone: string
  address: string
  totalPurchases: number      // updated via increment, never written directly
  pendingAmount: number       // updated via increment, never written directly
  createdAt: timestamp

products/{productId}
  name: string
  category: string
  supplierId: string
  purchasePrice: number
  sellingPrice: number
  currentStock: number        // updated via increment, never written directly
  minStock: number

suppliers/{supplierId}
  name: string
  phone: string

sales/{saleId}
  customerId: string
  saleDate: timestamp
  items: array<{ productId, productName, quantity, unitPrice, subtotal }>
  totalAmount: number
  discount: number
  paidAmount: number
  createdBy: string            // operator uid, for audit purposes

payments/{paymentId}
  customerId: string
  saleId: string | null        // optional reference only, never required
  amount: number
  paymentDate: timestamp
  method: string
  createdBy: string

purchases/{purchaseId}
  supplierId: string
  purchaseDate: timestamp
  items: array<{ productId, quantity, unitCost }>
  totalCost: number
  createdBy: string
```

**Design rule**: `totalPurchases`, `pendingAmount`, and `currentStock` are never set directly by client code. They are only ever changed via `FieldValue.increment(±n)`, alongside the write of the `sales`/`payments`/`purchases` document that caused the change. This is the single most important rule in the whole system — see §2.

## 2. Aggregate consistency strategy

Firestore *transactions* (read-check-write) require a live round trip to the server and fail with no connectivity. Since offline use is a hard requirement (see PRD §7), aggregates are kept correct using **atomic increments** instead:

- **Recording a sale**: write the `sales` document, and in the same batched write call `increment(-quantity)` on each product's `currentStock`, `increment(saleTotal - paidAmount)` on the customer's `pendingAmount`, and `increment(saleTotal)` on `totalPurchases`.
- **Recording a payment**: write the `payments` document and call `increment(-amount)` on the customer's `pendingAmount`.
- **Recording a purchase**: write the `purchases` document and call `increment(quantity)` on each product's `currentStock`.

Increments queue on the device like any other offline write and apply, in order, once the phone reconnects — so the numbers are always eventually correct, even if several sales are recorded back-to-back with no signal in between.

**Trade-off, stated plainly**: increments don't support conditional checks (e.g., "reject this sale if it would make stock negative"). At this business's scale — one operator, not a high-concurrency system — that's an acceptable trade for offline reliability. A soft client-side warning ("only 3 in stock, you're recording 5") is appropriate; a hard server-side block is not, since it would require the very online round-trip we're avoiding.

## 3. Offline behavior specification

- Firestore's offline cache should be configured to **unlimited size** on app initialization, so a full catalog of products, customers, and recent transaction history stays available locally regardless of how long the phone stays offline.
- Every write (sale, payment, purchase) succeeds immediately from the operator's point of view, online or offline — this is Firestore's default behavior, not something built manually.
- Each transaction document's snapshot exposes `metadata.hasPendingWrites`. The UI shows a small "saving…" indicator on any record where this is `true`, and clears it once the write is confirmed by the server. This is the "offline drafts" behavior requested — implemented with an existing SDK flag, not a custom queue.
- **Known limitation**: on a brand-new install with zero prior connectivity, there's nothing in the local cache yet. First run needs one window of connectivity to pull down the initial product/customer lists. Worth building into onboarding (see `roadmap.md`).

## 4. Authentication and access control

Two Firebase Authentication accounts:

| Role | Access | Login method |
|---|---|---|
| Operator (father) | Read/write on all collections | Phone number OTP — same pattern as WhatsApp, needs no explanation |
| Admin (son) | Read-only on all collections | Email/password or Google sign-in, used only from the admin's own device |

Example Firestore security rule shape enforcing this split:

```
match /databases/{database}/documents {
  function isOperator() {
    return request.auth.uid == resource.data.operatorUid;
  }
  function isAdmin() {
    return request.auth.token.role == 'admin';
  }

  match /{collection}/{docId} {
    allow read: if isOperator() || isAdmin();
    allow write: if isOperator();
  }
}
```

(The `role` custom claim for the admin account is set once via a Cloud Function or the Firebase console — not something the app itself needs to expose.)

## 5. Module data flows

- **Sale**: pick customer → add line items (auto-filled price from `products`) → optional discount → enter amount paid → on save: write `sales` doc + increments (see §2) → UI reflects new stock/balance instantly from local cache, synced silently in the background.
- **Payment**: pick customer → enter amount → on save: write `payments` doc + one increment on `pendingAmount`.
- **Purchase**: pick supplier → add line items and cost → on save: write `purchases` doc + increments on `currentStock`.
- **Dashboard**: a set of Firestore queries/streams (today's sales, sum of `pendingAmount` across customers, low-stock product count) — all served from local cache first, so the dashboard renders instantly even offline.
- **Search**: a client-side filter over the locally cached `products`/`customers` collections — no server round-trip needed for typical catalog sizes (hundreds, not tens of thousands, of items).

## 6. Notifications (server-side)

A **scheduled Cloud Function** (e.g., runs daily) queries Firestore directly — not dependent on the app being open — and:
- Flags any product where `currentStock < minStock`.
- Flags any customer whose `pendingAmount` has been non-zero for longer than a configurable threshold (e.g., 30 days).
- Sends a push notification via Firebase Cloud Messaging for either condition.

This keeps notifications working even if the father hasn't opened the app in several days.

## 7. Error handling and edge cases

- **App force-closed mid-sale**: since the write + increments are issued together as a single batched write, either the whole batch is queued or none of it is — no partial state.
- **First-run with no connectivity**: the app should detect an empty local cache and prompt for one-time setup connectivity rather than silently showing an empty dashboard.
- **Negative stock**: allowed to occur (see §2 trade-off), surfaced as a soft warning in the UI and visible to the admin via the Dashboard's low-stock/negative-stock indicator — never silently hidden.
- **Multiple devices for the operator** (e.g., phone replaced): since data lives in Firestore, signing in on a new device with the same operator account restores everything — this is the "restore" story referenced in `prd.md` §6.10.
