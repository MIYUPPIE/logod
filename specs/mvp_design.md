# MVP Technical Design — Local Government Digital Seller Registration & Revenue Management

Source of truth for scope: [`MVP_DEV_SPEC.md`](../MVP_DEV_SPEC.md). This document resolves the open
decisions in SRS §9, fixes the few gaps in the data model, and gives the three-perspective
(Frontend/Backend/Security) breakdown per feature before implementation.

## Open decisions — resolved

| # | Decision | Resolution | Rationale |
|---|---|---|---|
| 1 | SMS provider | Termii, behind a `Notifier` behaviour | Spec's own recommendation for NG; behaviour makes swapping to Africa's Talking a one-module change. A `Console`/`Test` adapter is the default in `dev`/`test` so the whole system runs with zero external credentials. |
| 2 | NIN validation | Free text only, format-checked (11 digits) not verified against an external registry | Spec's own recommendation. `nin` stored as an optional string; no external call in MVP. |
| 3 | Single-LGA vs multi-LGA pilot | Build multi-LGA from day one | Spec's own recommendation ("cheap now, expensive later"). Every query scoped by `lga_id`; `RequireRole`/`RequireLga` plug enforces it centrally, not per-controller. |
| 4 | Admin/Supervisor web | Phoenix LiveView, same codebase as the API | Spec's own recommendation. One deploy unit, real-time dashboard without a second frontend stack. |

## Data model gap-fill

The §4 table lists `client_uuid` only on `payments`, but §5 states seller registration is also
"idempotent on client_uuid." `sellers` gets a `client_uuid` column too (unique, not null), for the
same offline-retry-safety reason payments has one. Both are enforced with a DB unique index, so a
retried sync batch can never double-insert.

`seller_uid` format is `STATE-LGA-YEAR-SEQUENCE` (e.g. `LAG-IKJ-2026-000012`), assigned server-side
at first successful sync via a per-(state,lga,year) sequence — never client-generated, so two
offline agents in the same LGA can never collide.

## Architecture

- **Backend** (`services/backend`): Elixir 1.17 / Phoenix 1.7, Ecto + PostgreSQL 16 (PostGIS enabled,
  unused in MVP beyond lat/lng columns), Guardian (JWT) + Argon2 (via `comeonin`), Oban (SMS +
  sync-adjacent async work), `chromic_pdf` (headless Chrome is present on this host) for receipt
  PDFs, `eqrcode` for QR payloads, Hammer for rate limiting. LiveView for Supervisor Dashboard and
  Admin Panel — no separate SPA.
- **Mobile** (`services/mobile`): Flutter 3.x, `sqflite` (offline queue) + `connectivity_plus` (sync
  trigger), `geolocator` (GPS capture), `image_picker`/`camera` (seller photo), `mobile_scanner`
  (QR search), `dio` (HTTP), `flutter_secure_storage` (JWT/refresh token at rest). Talks to the
  backend only through `contracts/openapi.yaml` — never assumes internal backend structure.
- **Contract** (`contracts/openapi.yaml`): the only thing both services are allowed to depend on.
  Any breaking change bumps the `info.version` and must update both sides in the same change.

## Feature breakdown

### Feature: Auth (login / refresh / logout / RBAC)

**[Frontend — mobile]**
- Login screen (email/phone + password), stores JWT + refresh token in `flutter_secure_storage`.
- Silent refresh on 401 before failing a request.
- Role is embedded in the JWT claims; UI hides agent-only screens from non-agent roles (defense in depth only — server is the real gate).

**[Backend]**
- `POST /api/v1/auth/login`, `POST /api/v1/auth/refresh`, `POST /api/v1/auth/logout`.
- Guardian issues short-lived access token (15 min) + longer-lived refresh token (14 days), refresh token stored hashed server-side so logout can revoke it.
- `RequireRole` plug reads role from the Guardian claims, not from a DB hit, on every request.

**[Security]**
- Argon2 password hashing, never logged (custom `Logger` filter strips `password`/`password_hash`/`token` keys).
- Login rate-limited (5/15min per IP+identifier combo) via Hammer — brute-force mitigation named explicitly in SRS §8.
- Refresh tokens are single-use-rotating: each refresh issues a new refresh token and invalidates the old one, limiting replay window.
- Failed logins write an `audit_logs` row (`action: "login_failed"`).

### Feature: Seller Registration

**[Frontend — mobile]**
- Multi-step form: identity (name, photo, phone, NIN optional, DOB, gender) → business (name, category, shop no, market/ward/LGA/state cascading pickers) → GPS capture (auto, with manual "recapture" if `gps_accuracy` > threshold) → review → submit.
- Works fully offline: writes to local SQLite immediately, shows a temporary local ID (`LOCAL-<client_uuid prefix>`) and a "pending sync" badge until the server confirms `seller_uid`.
- Client-side validation (required fields, phone format, NIN is 11 digits if present) — never the only gate.

**[Backend]**
- `POST /api/v1/sellers` — idempotent on `client_uuid`. Validates via Ecto changeset, geo-scopes to the registering agent's LGA (agent cannot register a seller outside their assigned `lga_id`), assigns `seller_uid` via the per-LGA sequence, generates QR payload for the seller card.
- `GET /api/v1/sellers/:id`, `GET /api/v1/sellers/search?q=`, `GET /api/v1/sellers/qr/:seller_uid`.
- Photo upload goes through the `Storage` behaviour (local disk in dev/test, S3/MinIO in prod) and is stored as a signed URL, never a public one.

**[Security]**
- Agent role required; `RequireRole` + LGA-ownership check (an agent from LGA A cannot create/read sellers scoped to LGA B).
- Photo upload validated by content-type sniff + size cap (5MB) server-side, not by trusting the client's declared MIME type.
- Every create/update writes an `audit_logs` row with `who, what, when, where` (GPS + device_id from the request).

### Feature: Revenue Collection (Payments)

**[Frontend — mobile]**
- Search seller by ID / phone / QR scan → select levy type (from cached `levy_types` list, refreshed on sync) → enter amount + method (cash/POS/transfer) → confirm → local write with `client_uuid` → immediate on-screen receipt (from cached data) even before sync confirms.

**[Backend]**
- `POST /api/v1/payments` — idempotent on `client_uuid`, generates `receipt_no` server-side on first insert, enqueues an Oban job to (a) render the PDF receipt and (b) send the SMS.
- `GET /api/v1/payments/:id`, `GET /api/v1/sellers/:id/payments`.

**[Security]**
- Payment amount validated against the `levy_types.amount` for that LGA server-side (client cannot submit an arbitrary amount) unless a documented "custom amount" flag is set by a supervisor role — not in MVP, so amount is always looked up server-side from `levy_type_id`, request-supplied amount is ignored/rejected if it doesn't match.
- `audit_logs` row on every payment insert.

### Feature: SMS Confirmation + Digital Receipt

**[Backend]**
- `Notifier` behaviour: `send_sms(phone, message)`. `Notifier.Termii` (HTTP adapter) in prod, `Notifier.Console` (logs, no network) in dev/test. Selected via `config :revenue_api, :notifier, Notifier.Termii | Notifier.Console`.
- Oban worker `SendReceiptSmsWorker` — retries with backoff, writes `sms_logs` row with provider status regardless of outcome (never silently drops a failed send).
- `GET /api/v1/receipts/:id/pdf` (authenticated — owner agent, the seller, or admin/supervisor).
- `GET /api/v1/verify/:receipt_qr_payload` — public, no auth, rate-limited, returns only non-sensitive verification fields (receipt no, amount, seller business name, date, valid/invalid) — never full seller PII.

**[Security]**
- `/verify/:qr` rate-limited (30/min per IP) — it's public and named explicitly in SRS §8 as a scraping/brute-force target.
- Receipt PDF URL is signed and short-lived even though the route itself is authenticated (defense in depth for link-sharing).

### Feature: Offline Sync

**[Frontend — mobile]**
- `SyncService`: on connectivity regained (via `connectivity_plus` listener) or manual pull-to-sync, batches all `pending_sync` local rows (registrations + payments) and posts to `/sync/batch`. Per-record response updates local row to `synced` (with canonical server ID) or `flagged` (with reason shown to the agent).

**[Backend]**
- `POST /api/v1/sync/batch` — accepts a mixed array of `{type: "seller"|"payment", client_uuid, payload}`. Processes each independently in its own transaction so one bad record doesn't fail the whole batch. Existing `client_uuid` → idempotent no-op returning the canonical record. Duplicate-phone-offline case → both inserted, both flagged `duplicate_suspected`, surfaced on the Supervisor Dashboard's pending-sync queue for manual resolution (per SRS §6 — explicitly not auto-merged in MVP).

**[Security]**
- Batch size capped (e.g. 200 records/request) to bound worst-case transaction/request size from a compromised or buggy client.
- Every record in the batch still goes through the same changeset validation and LGA-ownership check as the synchronous endpoints — sync is not a validation bypass.

### Feature: Supervisor Dashboard / Admin Panel (LiveView)

**[Frontend — LiveView, server-rendered]**
- Supervisor: live agent list (last-seen, today's collection total per agent), today's collections total, pending-sync/flagged queue with a manual "resolve duplicate" action.
- Admin: user/agent management (create/deactivate), levy type CRUD, CSV export of revenue reports (`from`/`to` range).
- Real-time updates via `Phoenix.PubSub` broadcast on payment insert/sync — no polling.

**[Security]**
- `RequireRole` plug on the LiveView mount (`on_mount` hook), not just the router — LiveView sockets bypass the HTTP router's plug pipeline after the initial mount unless explicitly re-checked.
- Admin actions (user create, levy change) write `audit_logs`.
- CSV export scoped to the requesting admin/supervisor's LGA unless role is a state-level admin.

## Non-functional (carried from SRS §8, enforced in code not just docs)

- HTTPS enforced via `force_ssl` in `endpoint.ex` prod config (self-signed acceptable for pilot).
- Argon2, never logged — custom logger filter, verified by a test that asserts no log line ever contains a raw password.
- Private bucket, signed URLs only — `Storage` behaviour never exposes a public-read URL.
- Every mutating endpoint → `audit_logs` row — enforced via a shared `AuditLog.record/1` call inside each context function that writes, plus a test per context asserting the audit row exists after the action.
- Rate limits on `/auth/login` and `/verify/:qr` — Hammer, tested.

## Implementation order

Matches SRS §7 milestones 1–7 (milestone 8, the field pilot, is out of scope for this build —
it requires real devices and real agents). Within backend, ship in dependency order: schema → auth
→ registration → payments/receipts/SMS → sync → dashboards → admin → audit/hardening pass →
tests throughout, not bolted on at the end.

## Known limitation: same-batch seller reference

`PaymentCreateRequest.seller_id` (contracts/openapi.yaml) requires a canonical integer seller id.
An agent who registers a seller and wants to collect a payment from them in the **same** offline
session, before either record has ever reached the server, has no way to reference "the seller I
just registered in this batch" — there's no local-`client_uuid`-to-payment-payload mechanism in
the contract. `services/mobile` handles this conservatively: it gates payment collection to
sellers that already have a canonical `seller_uid` (i.e. have synced at least once), with a clear
"pending sync" message otherwise, rather than guessing at an unspecified contract behavior.

This doesn't violate the MVP's "under 3 minutes" definition of done — the agent still onboards and
collects in one continuous field interaction, sync happens automatically on reconnect (or a manual
tap) within that same session in the normal case — but a seller registered and paid in a single
*fully offline* session (no connectivity at all during the interaction) can't be paid until the
next sync. A v1.1 fix: let `Sync.process_batch` resolve `seller_client_uuid` against either an
already-created row (this call) or a seller record earlier in the *same* batch, and add that field
to `SyncRecord`'s payment payload in the contract. Left out of this build because it's a contract
change touching both services, not a same-service fix, and the conservative fallback the mobile
app already ships is correct, not broken.
