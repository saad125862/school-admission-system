# Assumptions

The brief leaves some behaviour open. These are the choices made and why.

## Identity and validation
- **Student ID** is exactly 17 digits. A missing or malformed `X-Student-Id` returns **400**. *Why:* the brief defines it as the 17-digit birth registration number; failing fast avoids junk rows.
- Class `name` must be non-empty (max 200 chars) and `totalSeats` an integer ≥ 1 (≤ 1,000,000), otherwise **400**. Duplicate class names are allowed (shifts of different schools/years may repeat). *Why:* the brief does not forbid it and uniqueness would need a rule nobody asked for.

## Seats and holds
- `heldSeats` counts only **unexpired** `HELD` applications; `confirmedSeats` counts `CONFIRMED`; `availableSeats = totalSeats − held − confirmed` (never negative).
- **No seat → 409** with the message "No seats are available in this class."
- A student may have **at most one active (`HELD`, unexpired) or `CONFIRMED` application per class**. A second apply → **409** ("You already have an active application…"). Different message than sold-out so the UI can explain it. Enforced under the class lock *and* by a partial unique index as a safety net.
- After a **cancel or expiry** the student may apply again to the same class. *Why:* the seat was released and the brief only limits *active* or confirmed ones.
- Hold duration comes from `HOLD_DURATION_SECONDS` (default 600), measured on the server clock (UTC).

## Expiry
- A hold is treated as expired as soon as `expires_at <= now`, **in every read and write path** (counts, status, confirm, my-holds), so correctness never depends on a timer.
- A background sweeper (every second) additionally flips overdue `HELD` rows to `EXPIRED` so stored data is tidy. Overdue holds of a class are also swept inside the apply transaction so they cannot block the unique index.
- `GET /holds/{id}` of an overdue hold reports `EXPIRED` even if the sweeper has not run yet.

## Confirm / cancel
- **Confirm** only works for the owner, on an unexpired `HELD` hold. Confirm on an already-`CONFIRMED` hold returns **200** with no change (idempotent, `confirmedSeats` increases once). Confirm on `EXPIRED`/`CANCELLED` → **409**.
- Payment is simulated: the confirm call *is* the successful payment (per the brief).
- **Cancel** (`DELETE`) on an active hold → status `CANCELLED`, seat freed, **204**. On an already `CANCELLED`/`EXPIRED` hold → **204** (idempotent). On a `CONFIRMED` admission → **409** (refunds are out of scope).
- Another student's hold on confirm/cancel → **404** (not 403), so hold IDs cannot be probed. `GET /holds/{id}` needs no header (the brief's contract has none) and exposes no personal data beyond what the owner already knows.

## API / data
- IDs are opaque strings (`c_…`, `h_…`). Timestamps are ISO-8601 UTC with milliseconds (`2026-11-01T04:10:00.000Z`).
- Responses may contain **extra** fields (e.g. `studentId` on a hold) but never drop or rename the contract fields.
- Errors are JSON: `{ "error": "<message>" }`.
- The schema is created at startup with EF Core `EnsureCreated` (with retry until the database is up) instead of migrations. *Why:* two tables, no upgrade path required for the assignment, and zero extra tooling for `docker compose up`.
- CORS defaults to any origin because there is no authentication or cookies; restrict with `CORS_ORIGINS` when deployed.
- No pagination: a school has a handful of classes.

## Several backend processes, one database (bonus)
Correctness lives in the database, not in process memory. Applying runs in a transaction that first executes `SELECT … FOR UPDATE` on the class row, so two processes cannot both read "1 seat left" and both insert. Confirm and cancel lock the hold row. No in-process locks or caches are used. The partial unique index is a last line of defence. Verified with `scripts/two-instance-check.sh` (200 parallel requests across two processes, 10 seats → exactly 10 holds).
- The connection pool is capped at 20 per process: each request holds its connection while it waits for the row lock, and an unbounded pool exhausted Postgres' `max_connections` in testing (see AI_USAGE.md). Excess requests queue for a connection instead of failing.
- Expiry uses each process's own clock; processes are assumed to run on hosts with roughly synchronised time (normal for any deployment).

## UI
- The student ID box is the only "login": it is validated (17 digits) and remembered in `localStorage`; the open application is remembered too, so refresh or reopening the browser keeps it.
- The countdown is computed from the server's `expiresAt` against the browser clock; the UI additionally re-checks the server when the countdown reaches zero and trusts the server status. A badly wrong device clock could therefore show the wrong time left, but never a wrong status after the next refresh.
- Seat counts and application state poll every 3–4 s (no websockets) — enough for this scale and simple to run.
- The Flutter app is an extra client over the same API; it is not part of `docker-compose.yml`.
