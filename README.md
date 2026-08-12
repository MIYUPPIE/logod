# Local Government Digital Seller Registration & Revenue Management — MVP

An agent registers a market seller with GPS + photo, collects a levy payment, and the seller gets
an SMS + digital receipt — all working offline in the field, syncing when connectivity returns.
Supervisors and admins watch it happen live from a web dashboard.

- **Product spec:** [`MVP_DEV_SPEC.md`](MVP_DEV_SPEC.md)
- **Technical design:** [`specs/mvp_design.md`](specs/mvp_design.md) — resolves the spec's open
  decisions and gives the frontend/backend/security breakdown per feature
- **API contract:** [`contracts/openapi.yaml`](contracts/openapi.yaml) — the single source of truth
  both services below are built against

## Layout

```
services/backend/   Phoenix 1.8 API + LiveView admin/supervisor dashboards
services/mobile/    Flutter agent app (offline-first)
contracts/          Shared API contract
specs/              Technical design doc
docker-compose.yml  Postgres + MinIO, for a portable/prod-like local setup
```

Each service has its own deps, tests, and README. Nothing in `services/backend` imports from
`services/mobile` or vice versa — they only agree on `contracts/openapi.yaml`.

## Running the backend

Requires Elixir 1.17+/OTP 25+, PostgreSQL 16, and Google Chrome (for PDF receipt rendering via
ChromicPDF — any recent Chrome/Chromium binary works).

```bash
cd services/backend
mix setup                    # deps.get, ecto.create, ecto.migrate, seeds, assets
mix phx.server                # http://localhost:4000
```

`mix setup` runs [`priv/repo/seeds.exs`](services/backend/priv/repo/seeds.exs), which seeds all 37
states/FCT, the 20 real Lagos LGAs, Ikeja's 10 real wards, 2 markets, 3 demo levy types, and 3 demo
logins (password `ChangeMe123!` for all three):

| Email | Role |
|---|---|
| `admin@revenue.test` | state admin |
| `supervisor.ikeja@revenue.test` | Ikeja supervisor |
| `agent.ikeja@revenue.test` | Ikeja agent |

Admin/Supervisor dashboards: `http://localhost:4000/login` (session auth). Mobile API base URL:
`http://localhost:4000/api/v1` (JWT auth).

**Tests:** `cd services/backend && mix test` (63 tests) or `mix precommit` for the full gate
(strict compile, unused-deps check, format, test).

### Using docker-compose instead of a native Postgres/MinIO install

```bash
docker compose up -d          # Postgres on :5432, MinIO on :9000/:9001
```

This is an *alternative* to a native Postgres, not something to run alongside one on the same
host/port — if you already have Postgres running locally (as this build environment does), skip
docker-compose and point `config/dev.exs` at it directly (already the default). MinIO is only
exercised by the S3 storage adapter (`RevenueApi.Storage.S3`), which is the `prod`-only default —
dev/test use `RevenueApi.Storage.Local` (disk-backed) so MinIO isn't required for local dev.

## Running the mobile app

```bash
cd services/mobile
flutter pub get
flutter run --dart-define=API_BASE_URL=http://localhost:4000/api/v1
```

See [`services/mobile/README.md`](services/mobile/README.md) for architecture notes and test
instructions.

## What's deliberately deferred

Per [`MVP_DEV_SPEC.md`](MVP_DEV_SPEC.md) §2 and the resolved open decisions in
[`specs/mvp_design.md`](specs/mvp_design.md):

- **PostGIS**: the extension migration is a guarded no-op on hosts where the `postgis` Postgres
  package isn't installed (this build environment doesn't have it, and installing it needs `sudo`
  — see "Restart / setup steps" below). No MVP table actually uses PostGIS types yet (`lat`/`lng`
  are plain floats), so this doesn't block anything; it's there so a v2 heat-map feature doesn't
  need a data migration later.
- **Full national LGA/ward/market data**: only Lagos State has a full LGA tree, and only Ikeja LGA
  has real wards/markets seeded (matching the spec's own worked example,
  `LAG-IKJ-2026-000012`). All 37 states/FCT are seeded by name so the picker isn't empty elsewhere.
  Extending coverage is adding rows to `priv/repo/seeds.exs`, not writing code.
- **Termii SMS in production**: the `Notifier` behaviour and `Notifier.Termii` adapter are fully
  implemented, but sending real SMS needs a live `TERMII_API_KEY` — dev/test use the `Console`
  adapter (logs instead of sending) and a Mox mock, respectively, so the whole system runs with
  zero SMS credentials until deploy time.
- **S3/MinIO in production**: same shape — `Storage.S3` (via `req_s3`, zero-hackney) is implemented
  and config-driven, but only manually exercisable against a real bucket; dev/test use
  `Storage.Local`.
- **Field pilot** (SRS §7 milestone 8): needs real devices and real agents, out of scope for a
  build session.

## Restart / setup steps needing your action

Nothing in this build required `sudo`, but two things are genuinely deferred to whoever deploys
this for real, since they need secrets or system packages this environment doesn't have:

```bash
# Optional, only if you want PostGIS enabled now instead of when v2 needs it:
sudo apt install postgresql-16-postgis-3

# Optional, only if you want live file-watch reload in dev (mix phx.server already
# picks up changes on the next request without this — it's a convenience, not a blocker):
sudo apt install inotify-tools
```

Production deploy needs these environment variables set (see
[`config/runtime.exs`](services/backend/config/runtime.exs)): `DATABASE_URL`, `SECRET_KEY_BASE`,
`GUARDIAN_SECRET_KEY`, `RECEIPT_SIGNING_KEY`, `PHX_HOST`, `TERMII_API_KEY`, `TERMII_SENDER_ID`,
`S3_BUCKET` (+ standard `AWS_ACCESS_KEY_ID`/`AWS_SECRET_ACCESS_KEY`/`AWS_ENDPOINT_URL_S3` for
MinIO), `CORS_ORIGINS`.
