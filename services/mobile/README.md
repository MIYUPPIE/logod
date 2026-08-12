# Revenue Agent App

Flutter field app for the Local Government Digital Seller Registration & Revenue Management
MVP. A Revenue Agent uses this app offline or online to register market sellers (GPS + photo)
and collect levy payments, with instant on-device receipts and background sync.

Talks to `services/backend` only through `contracts/openapi.yaml` (read-only from this
service's point of view — never edited here).

## Running

```
flutter pub get
flutter run --dart-define=API_BASE_URL=http://localhost:4000/api/v1
```

`API_BASE_URL` defaults to `http://localhost:4000/api/v1` (the sibling backend's dev address),
so `flutter run` with no flags works out of the box against a local backend. Override it for a
staging/prod backend, e.g. `--dart-define=API_BASE_URL=https://revenue.example.gov.ng/api/v1`.

Android needs `INTERNET`, `ACCESS_FINE_LOCATION`/`ACCESS_COARSE_LOCATION`, and `CAMERA`
permissions, already declared in `android/app/src/main/AndroidManifest.xml`. iOS needs the
matching usage-description strings, already in `ios/Runner/Info.plist`.

## Testing

```
flutter analyze   # must be clean, no warnings
flutter test      # unit + widget tests
```

Both are clean as of this build: `flutter analyze` reports no issues; `flutter test` runs 40
tests (36 unit across 6 files, 4 widget tests across 2 files) and all pass.

- `test/unit/` — repository layer (sqflite, via `sqflite_common_ffi` in-memory) and the sync
  service, using `mocktail` to fake `Dio`/`FlutterSecureStorage`. No platform channels touched.
- `test/widget/` — `registration_flow_test.dart` drives the full 4-step registration wizard
  end to end and asserts the local SQLite row; `payment_flow_test.dart` drives levy-type
  selection, method selection, confirms, and asserts the local payment row plus the on-device
  receipt (including the pending-sync watermark).
- `test/helpers/` — shared fixtures/fakes: an in-memory `AppDatabase`, fake `LocationService` /
  `PhotoService` (so tests never touch real GPS/camera plugins), a `FakeSyncController`, and
  `tapKey`/`scrollToKey`/`pumpUntilFound` pump helpers (see "Widget-test gotchas" below).

### Widget-test gotchas (read before touching test/widget/)

Two non-obvious things bit this build hard enough to be worth recording:

1. **Real sqflite (FFI) I/O does not resolve under `flutter_test`'s default fake-async zone,
   even inside `tester.runAsync()`, if it's triggered by Riverpod machinery (a `FutureProvider`
   create function, or a `StateNotifierProvider`'s constructor) rather than by an `await` your
   test code directly controls.** Worked around by overriding such providers with data that
   resolves via a plain microtask (`Future.value(...)`) instead of a real repository/DB call,
   and by overriding `syncControllerProvider` with `FakeSyncController` (see
   `test/helpers/fakes.dart`) so its constructor's background DB read never runs in tests.
2. **`tester.pump(Duration(milliseconds: N))` does not block for `N` real milliseconds** — it
   only advances the simulated clock. A real async operation you *do* explicitly `await` from a
   button handler (e.g. the final `saveNewRegistration` write) can still take longer in real
   wall-clock time than a bounded loop of `pump()` calls actually spends executing. Use
   `pumpUntilFound` (real `Future.delayed` + `pump()`, see `test/helpers/pump_helpers.dart`)
   after any tap that triggers a real local-DB write.
3. **`ListView(children: [...])` still lazily culls elements outside its viewport + cache
   extent**, exactly like `.builder` — a widget several items down (e.g. the payment amount
   card) simply isn't in the element tree until something scrolls it into range.
   `WidgetTester.ensureVisible` can't help because it needs the element to already exist to
   compute where to scroll; use `scrollUntilVisible`/the `scrollToKey` helper instead, which
   scrolls blindly and re-checks after each step.

None of this affects production code — real devices don't run inside a fake-async test zone.

## Architecture

```
lib/
  core/
    config/        API base URL, tunables (dart-define driven)
    db/             AppDatabase - single sqflite schema (sellers, payments, geo_*, levy_types)
    network/        Dio wiring + AuthInterceptor (attach/refresh/logout-on-failure)
    services/       LocationService, PhotoService - thin plugin wrappers, injectable for tests
    storage/        TokenStorage - flutter_secure_storage wrapper
    utils/          client_uuid + ISO timestamp generation
  models/           Hand-written (no codegen) request/response/local-row models
  repositories/     One per concern: auth, geo, levy types, sellers, payments, + SyncService
  providers/        Riverpod wiring - db/network/auth/connectivity/sync/geo providers
  screens/          auth, home, registration (4-step wizard), payment, search/QR, flagged
```

State management: **Riverpod** (`flutter_riverpod`), chosen over `provider` per the brief's
"pick one" instruction — its provider-override mechanism is what makes the widget tests above
possible without a DI framework.

### Offline-first data flow

Every seller registration and payment write goes straight to local SQLite first (status
`pending_sync`, tagged with a `client_uuid` generated once, on-device, at creation time) and
is immediately usable — the registration wizard and payment flow both work with zero
connectivity end to end, per the brief.

`SyncService.syncPending()` (`lib/repositories/sync_service.dart`) batches every locally
`pending_sync` seller/payment row (capped at 200 total per `SyncBatchRequest.records.maxItems`,
split proportionally seller-then-payment) and posts them to `/sync/batch`. Idempotency rests on
two guarantees that are unit-tested in `test/unit/sync_service_test.dart`:

- **Client_uuid is generated exactly once**, at local-write time, and never regenerated — so a
  retry after a killed/timed-out request rebuilds the exact same batch. The server already
  treats a repeated `client_uuid` as an idempotent no-op per the contract.
- **Applying a `SyncResult` is a keyed `UPDATE` on that same `client_uuid` primary key**
  (`SellerRepository.applySyncResult` / `PaymentRepository.applySyncResult`), never an insert —
  so applying the same result twice converges to one row, not two, and a row that already left
  `pending_sync` is never re-included in a later batch.

`SyncController` (`lib/providers/sync_providers.dart`) triggers `syncPending()` automatically on
a `connectivity_plus` reconnect event and exposes a manual trigger for the home screen's
"Sync now" button, surfacing pending/flagged counts.

## Contract gaps observed

Per the brief, these are noted here rather than guessed at:

1. **Photo upload is JSON-base64 only, despite the contract's own prose suggesting multipart.**
   `SellerCreateRequest.photo_base64`'s description says "multipart upload preferred; base64
   accepted for offline sync payloads," but `POST /sellers` only defines an
   `application/json` request body in `contracts/openapi.yaml` — no multipart content type is
   actually specified anywhere for that path. Rather than invent an undocumented multipart
   variant, this app always sends the photo as base64 inside the JSON body, for both direct
   registration and sync-batch payloads. If the backend later adds a multipart path, this is a
   contract version bump, not a client guess.

2. **A payment cannot be recorded against a seller who is still `pending_sync`.**
   `PaymentCreateRequest.seller_id` (and the identical field inside a `SyncRecord` payload of
   type `payment`) is a required *integer* — the server's canonical seller id, assigned only at
   first successful sync. An offline-registered seller has only a `client_uuid` until then, and
   the contract has no mechanism for a payment (in the live endpoint or inside a sync batch) to
   reference a sibling record by `client_uuid` instead of a canonical id. Rather than guess at
   unspecified backend behavior, this app gates payment collection on
   `seller.status == synced && seller.serverId != null`: a seller found via search/QR that
   hasn't synced yet shows a "still pending sync — cannot collect payment yet" message instead
   of a payment button. If two-network-hop registration-then-payment for a same-session offline
   seller becomes a real field requirement, that needs a contract change (e.g. letting a sync
   batch resolve payment.seller_id against a sibling seller record's client_uuid within the same
   batch), not a client-side workaround.

3. **`SyncResult.status` has no `duplicate_suspected` value** (only `synced | flagged | error`),
   even though the design doc describes duplicate-phone-offline registrations as being flagged
   `duplicate_suspected`. This app maps any non-`synced` sync outcome to a local `flagged`
   status and surfaces the server's `reason` string to the agent verbatim, rather than
   string-matching "duplicate" in `reason` to fabricate a distinct UI state the contract doesn't
   actually promise. Separately, `Seller.duplicate_suspected` (a boolean, present on the full
   `Seller` object returned by `GET`/search/QR endpoints) *is* honored when caching a fetched
   seller, since that field is explicitly defined there.

## Deviations from the brief (with reasoning)

- The receipt screen's row layout (`lib/screens/payment/receipt_screen.dart`) uses
  `Expanded`/`textAlign: end` for values instead of a bare `mainAxisAlignment: spaceBetween`
  `Row` — the original version overflowed for longer values (e.g. a full `seller_uid`), caught
  by the payment widget test, not a deviation from the brief so much as a bug the tests earned
  their keep catching.
- No other deviations: `sqflite` for the offline queue, `connectivity_plus` for sync triggers,
  `geolocator` for GPS, `image_picker` (camera) for the photo, `mobile_scanner` for QR search,
  `qr_flutter` for displaying a seller's own QR, `dio` for HTTP, `flutter_secure_storage` for
  tokens, and Riverpod for state — all as pinned by the brief.
