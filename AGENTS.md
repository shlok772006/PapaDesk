# AGENTS.md

Instructions for any AI agent (Antigravity or otherwise) working on this codebase. Read `prd.md`, `architecture.md`, and `system-design.md` before making changes — this file states the non-negotiable constraints; those files explain the reasoning.

## Project context

A Flutter app for one small retail/wholesale electronics-accessories business. The primary user has no technical background and will not be near the developer if something breaks. Simplicity and offline reliability outrank feature richness every time.

## Non-negotiable constraints

1. **Never use a Firestore transaction for `currentStock`, `pendingAmount`, or `totalPurchases`.** Use `FieldValue.increment()` only, issued in the same batched write as the triggering document. Transactions fail offline; this app must work offline. See `system-design.md` §2.
2. **Every sale, payment, and purchase write must succeed with no network connection.** If a change requires a live server round-trip to work, it's the wrong design — redo it.
3. **No barcode field or scanning UI in Phase 1.** Not in scope; don't add it speculatively.
4. **No feature ships without a one-sentence explanation a non-technical person could understand.** If you can't summarize a feature that simply, flag it for the human rather than building it.
5. **UI defaults**: large fonts, large tap targets, minimal typing, no jargon in labels. Prefer selecting from existing lists (customers, products) over free-text entry wherever possible.
6. **`createdBy` is required on every `sales`, `payments`, and `purchases` document.** Never omit it, even though there's currently only one operator.
7. **Do not touch the `smart-business-manager-prod` Firebase project during development.** All building and testing happens against `smart-business-manager-dev`.

## Build order

Follow the phases in `roadmap.md`. Within Phase 1, build in this order:
1. Firestore data layer and repository classes (test the increment logic in isolation before any UI touches it).
2. Sales and Payments modules (the highest-stakes, most-used flows).
3. Inventory and Customer Ledger (read-heavy views over the same data).
4. Dashboard, Reports, Search (aggregating views).
5. Settings and onboarding last.

## Working style

- Propose a plan before writing code for any new module. Include what data it reads/writes and which constraints above apply.
- Build one module at a time; don't let changes span multiple modules in a single pass unless the human asks for it.
- Use the hot-reload/live-preview loop to check each screen against the UI defaults (§5) as it's built, not after the fact.
- When a requirement is ambiguous, prefer the interpretation that keeps the operator's flow to fewer taps — and say which interpretation you picked.

## When to stop and ask the human

- Any change to how `pendingAmount` or `currentStock` is calculated or written.
- Any change to the Firestore security rules or the operator/admin role split.
- Anything that would only work with connectivity, for a feature listed as core (Phase 1 or 2) rather than Phase 3.
- Any new third-party package addition not already listed in `architecture.md` §6.
