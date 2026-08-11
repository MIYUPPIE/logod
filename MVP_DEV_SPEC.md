# Local Government Digital Seller Registration & Revenue Management System
### MVP Developer Specification — v0.1

> Derived from SRS v1.0. This doc cuts the full spec down to what a small team needs to ship a working, demo-able MVP in one build cycle, then lists what's deliberately deferred.

---

## 1. MVP Goal

Ship a system where a **Revenue Agent** can register a seller with GPS + photo, collect a levy payment, and the **Seller** instantly gets an SMS + digital receipt — with an **Admin/Supervisor** able to see it all on a live dashboard. Everything else in the SRS is v2.

**Definition of done for MVP:** an agent in the field, offline or online, can onboard a seller and take a payment in under 3 minutes, and that transaction is visible on the supervisor dashboard within seconds of sync.

---

## 2. MVP Scope (in vs. out)

### In scope
| Module | MVP behavior |
|---|---|
| Seller Registration | Full Name, Photo, Phone, NIN (optional), DOB, Gender, Business Name/Category/Shop No/Ward/Market/LGA/State, GPS capture, permanent Seller ID + QR |
| Auth | Email/Phone + password login, JWT + refresh token, RBAC (Admin, Supervisor, Agent, Seller) |
| Revenue Collection | Search seller (ID / phone / QR scan), select levy type, record payment (Cash, POS, Transfer), auto-generate receipt |
| SMS Confirmation | Send SMS on payment (Seller ID, amount, receipt no., date) via one gateway (Termii recommended for NG) |
| Digital Receipt | PDF receipt with QR verification link |
| Offline Mode | Local SQLite queue on agent device; sync on reconnect |
| Supervisor Dashboard | Live agent list, today's collections, pending sync queue, basic revenue totals |
| Admin Panel | Manage users/agents, configure levy types & amounts, basic reports (CSV export) |
| Audit Log | Every write action logged (who, what, when, where) |

### Explicitly deferred (v2+)
Face recognition login/duplicate-detection, GPS spoofing detection, PostGIS heat maps, WhatsApp/USSD, multi-language, national ID/bank gateway integration, predictive analytics, Bluetooth printer/POS SDK integration, receipt cryptographic tamper-proofing beyond a signed hash, mobile money payment.

**Note:** biometric *photo capture* stays in MVP (it's cheap and needed for the seller card); biometric *facial-recognition matching* does not.

---

## 3. Tech Stack (MVP-pinned)

- **Mobile (Agent + Seller app):** Flutter, offline-first via `sqflite` + `connectivity_plus`
- **Backend API:** Elixir + Phoenix (JSON API, no LiveView needed for MVP admin — plain React/Phoenix HTML is fine, pick one and don't mix)
- **Admin/Supervisor Web:** Phoenix LiveView (fastest path to a real-time dashboard with one codebase) — **recommended over a separate React app for MVP**
- **DB:** PostgreSQL 15+ with PostGIS extension enabled from day one (even if unused, avoids a painful migration later)
- **Object storage:** MinIO (self-hosted) or S3 for photos/receipts
- **SMS:** Termii (or Africa's Talking) — abstract behind a `Notifier` behaviour so the provider is swappable
- **Auth:** `guardian` (JWT) + `bcrypt`/`argon2` via `comeonin`
- **PDF generation:** `pdf_generator`/`chromic_pdf` (Elixir) or generate receipt HTML → PDF server-side
- **Background jobs:** `Oban` (for SMS sending, sync reconciliation, report generation)
- **QR codes:** `eqrcode` (Elixir) server-side; `qr_flutter` client-side for display/scan

---

## 4. Core Data Model (MVP tables)

```
states            (id, name, code)
lgas              (id, state_id, name, code)
wards             (id, lga_id, name)
markets           (id, ward_id, name)

users             (id, name, email, phone, password_hash, role[admin|supervisor|agent], lga_id, device_id, active)

sellers           (id, seller_uid [LAG-IKJ-2026-000012], full_name, photo_url, phone,
                   nin, dob, gender, home_address,
                   business_name, business_category, shop_number,
                   market_id, ward_id, lga_id, state_id,
                   lat, lng, gps_accuracy, gps_captured_at,
                   registered_by_user_id, created_at)

levy_types        (id, lga_id, name, amount, frequency[daily|weekly|monthly|one_off])

payments          (id, seller_id, levy_type_id, amount, method[cash|pos|transfer],
                   agent_id, receipt_no, status[pending_sync|synced|flagged],
                   client_uuid  -- for offline idempotency
                   paid_at, synced_at)

receipts          (id, payment_id, pdf_url, qr_payload, verification_url)

sms_logs          (id, payment_id, phone, message, status, provider_ref, sent_at)

audit_logs        (id, user_id, action, entity_type, entity_id, ip, device_id, gps, metadata, inserted_at)
```

**Key design decisions:**
- `seller_uid` is generated server-side on first successful sync, format `STATE-LGA-YEAR-SEQUENCE`. The mobile app shows a temporary local ID until sync confirms the real one — this avoids sequence collisions from offline agents.
- `client_uuid` on `payments` is generated on-device and is the idempotency key for sync — prevents duplicate payments if a sync retries.
- Soft-delete only (`deleted_at`), never hard delete — satisfies the "immutable audit trail" requirement without needing a separate event-sourcing layer for MVP.

---

## 5. API Surface (MVP)

```
POST   /api/v1/auth/login
POST   /api/v1/auth/refresh
POST   /api/v1/auth/logout

POST   /api/v1/sellers                 (create/register — idempotent on client_uuid)
GET    /api/v1/sellers/:id
GET    /api/v1/sellers/search?q=       (id | phone | business name)
GET    /api/v1/sellers/qr/:seller_uid

GET    /api/v1/levy-types?lga_id=
POST   /api/v1/payments                (idempotent on client_uuid)
GET    /api/v1/payments/:id
GET    /api/v1/sellers/:id/payments

GET    /api/v1/receipts/:id/pdf
GET    /api/v1/verify/:receipt_qr_payload   (public, no auth — third-party receipt check)

POST   /api/v1/sync/batch              (bulk upload queued offline records)

GET    /api/v1/dashboard/summary       (supervisor/admin — today's totals, active agents)
GET    /api/v1/reports/revenue?from=&to=&format=csv

GET    /api/v1/admin/users
POST   /api/v1/admin/users
PATCH  /api/v1/admin/levy-types/:id
```

All authenticated routes require `Authorization: Bearer <jwt>`. Role checks enforced via a Phoenix plug (`RequireRole`), not scattered in controllers.

---

## 6. Offline Sync Strategy (the part most likely to break — design it first)

1. Agent app writes every registration/payment to local SQLite immediately, tagged `pending_sync` with a `client_uuid`.
2. On connectivity, app calls `POST /sync/batch` with an array of pending records.
3. Server processes each by `client_uuid`:
   - New `client_uuid` → insert, return canonical server ID (`seller_uid` / `receipt_no`).
   - Existing `client_uuid` → treat as already-synced, return existing canonical ID (idempotent, no duplicate).
4. Server responds per-record success/failure; app marks each `synced` or `flagged` locally.
5. Conflicts (e.g., same phone number registered by two agents offline) are **not auto-merged in MVP** — both are inserted and flagged `duplicate_suspected` for a supervisor to resolve manually. Auto-merge logic is v2.

---

## 7. Milestones (suggested 6–8 week MVP build)

1. **1:** DB schema + migrations, auth (login/JWT/roles), seed states/LGAs/wards/markets
2. **2:** Seller registration API + Flutter registration flow (online only first)
3. **3:** Payment API + receipt PDF + SMS integration
4. **4:** Offline queue (SQLite) + sync endpoint + idempotency
5. **5:** Supervisor LiveView dashboard (live agents, today's collections, pending sync)
6. **6:** Admin panel (levy config, user management, CSV reports)
7. **7:** Audit logging pass, QR verification endpoint, hardening (rate limits, input validation)
8. **8:** Field pilot with 2–3 agents in one ward, bug fixes, demo prep

---

## 8. Non-functional bar for MVP

- All API traffic over HTTPS (self-signed acceptable for pilot, not for launch)
- Passwords: argon2, never logged
- Photos/PDFs: private bucket, signed URLs only
- Every mutating endpoint writes an `audit_logs` row
- Rate-limit `/auth/login` and `/verify/:qr` (public endpoint) to prevent brute force/scraping
- Target: agent app usable on a low-end Android device (2GB RAM) with 3G-equivalent sync speed

---

## 9. Open decisions before coding starts

- [ ] Confirm SMS provider account (Termii vs Africa's Talking) — affects `Notifier` adapter
- [ ] Confirm whether NIN validation hits an external verification API in MVP or is stored as free text only (recommend: free text only for MVP, validate later)
- [ ] Single-LGA pilot or multi-LGA from day one? (affects whether `lga_id` scoping is enforced in every query from the start — do it from the start either way, cheap now, expensive later)
- [ ] Admin/Supervisor web: confirm LiveView over separate SPA (recommended, see §3)
