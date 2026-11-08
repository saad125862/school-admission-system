# AI usage

**Tool:** Claude Code (Claude Sonnet 5.5), used as a pair-programmer for the whole project.

## What the AI was used for
- Reading and summarising the assignment PDF and listing ambiguities (these became [ASSUMPTIONS.md](ASSUMPTIONS.md)).
- Drafting the backend (minimal API, EF Core model, hold/confirm/cancel logic, expiry sweeper), the Dockerfiles and `docker-compose.yml`.
- Drafting the React UI, the Flutter app, the backend / frontend / Flutter tests, Swagger metadata, the helper scripts and the docs.
- Driving the app in a browser and with headless Chrome to check behaviour and capture screenshots.

I decided the architecture (database row lock for concurrency, lazy + background expiry), the stack choices, and the deployment targets (Render, Neon, Vercel, GitHub Releases), and reviewed the results by running them.

## Where the AI got it wrong, and how it was caught

1. **Connection pool exhaustion under load (found by the concurrency test).** The first version used Npgsql's default pool (100). The 100-parallel-request test failed intermittently with one `500` ("transient failure… OpenInternalAsync") instead of 201/409. Each request holds a connection while waiting for the class row lock, so a burst exhausted Postgres' `max_connections`. Fix: cap the pool at 20 per process with a 60 s wait so requests queue instead of failing, then re-ran the test repeatedly. I only noticed because the test printed the unexpected response bodies.
2. **Unique index vs. expired holds (caught while designing, before running).** A first draft inserted a new hold while an old overdue-but-not-yet-swept `HELD` row for the same student still existed, which the partial unique index (`HELD`/`CONFIRMED`) would reject, wrongly blocking a legitimate re-apply. Fix: expire the class's overdue holds inside the apply transaction before inserting.
3. **Line endings would have broken the Docker image.** On Windows git would convert `docker-entrypoint.sh` to CRLF, which fails inside the Linux container. Added a `.gitattributes` forcing LF for shell scripts, Dockerfiles and nginx config.
4. **The helper script hung.** `scripts/two-instance-check.sh` used a bare `wait`, which also waits for the two server processes (which never exit). Then its per-request tally lost lines because 200 processes appended to one file on Windows. Fixed by waiting only on the curl PIDs and writing one file per request. The server-side invariant check was correct all along; the tally was the part that was wrong.
5. **The PDF could not be read directly.** Text extraction returned overlapping, garbled layers and dropped the Bengali text. I rendered the pages to images and read them instead, rather than trusting the garbled text.
6. **Overlapping Docker runs.** I started the compose build twice, which produced a "container name already in use" conflict. Harmless, but it cost time; I waited for the first build to finish before testing.

## What I verified myself
- All endpoints with curl against the Docker stack, including 60 parallel applicants for 5 seats (exactly 5 held).
- The full UI flow in a browser: apply, countdown, pay, refresh keeps the application.
- Backend tests (5), frontend tests (9), Flutter tests (4), and the two-process script (10 holds for 10 seats out of 200 requests).
