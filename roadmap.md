# Smart Business Manager — Roadmap

## Phase 1 — Core (ship this first, father starts using it daily)

| Module | Notes |
|---|---|
| Data layer | Firestore collections, repositories, atomic-increment logic — build and test this before any UI |
| Dashboard | Module 1 |
| Inventory | Module 2 (no barcode field) |
| Customer Ledger | Module 3 |
| Sales | Module 4 |
| Payments | Module 5 |
| Purchases | Module 6 |
| Reports | Module 7 (weekly/monthly views) |
| Search | Module 9 |
| Settings | Module 10 (no manual backup — see `system-design.md`) |
| Operator login | Phone OTP via Firebase Auth |
| First-run onboarding | In-app walkthrough + one required connectivity window to seed local cache |

**Exit criteria for Phase 1**: father can record a real sale and a real payment without help, stock and pending balances stay correct through at least a week of offline/online mixed use.

## Phase 2 — Remote operations

| Item | Notes |
|---|---|
| Admin (read-only) account | Son's remote visibility into live data |
| Crashlytics | Wired in from the first Phase 1 build, not deferred — cheap to add early, valuable immediately |
| Firebase App Distribution pipeline | For pushing test builds without a physical visit |
| Google Play internal testing track | Once the app is stable for daily use |
| Notifications (Module 8) | Scheduled Cloud Function for low stock / overdue payments |
| Onboarding support materials | Recorded WhatsApp walkthrough video, voice-note support channel |

## Phase 3 — AI features (optional, connectivity-gated, never a dependency for core recording)

| Feature | Notes |
|---|---|
| Smart sales assistant | Natural-language questions over existing Firestore data |
| Voice-based sales entry | Falls back to manual entry if offline or misheard |
| Predictive inventory | Reorder suggestions from sales history |
| Customer payment insights | Flags customers who reliably pay late |
| Invoice scanning (OCR) | Auto-fills a purchase from a photographed supplier bill |
| Business insights | Plain-language summaries on the Dashboard/Reports |

None of Phase 3 blocks or is required for Phase 1 or 2 — the business runs correctly without any of it.
