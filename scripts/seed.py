#!/usr/bin/env python3
"""Seed demo data through the public API (works for local Docker and the deployed backend).

Usage:
    python scripts/seed.py                      # http://localhost:8080
    python scripts/seed.py https://your-api     # any backend URL

Creates a handful of classes and fills them with CONFIRMED admissions (confirmed seats never expire, so the demo
looks the same tomorrow). Safe to re-run: classes that already exist by name are skipped.
"""
import json
import sys
import urllib.error
import urllib.request
from concurrent.futures import ThreadPoolExecutor

API = (sys.argv[1] if len(sys.argv) > 1 else "http://localhost:8080").rstrip("/")

# (name, total seats, confirmed admissions to create)
CLASSES = [
    ("Class 6 - Morning Shift", 120, 46),
    ("Class 6 - Day Shift", 100, 28),
    ("Class 7 - Morning Shift", 40, 37),   # only a few seats left
    ("Class 8 - Morning Shift", 60, 14),
    ("Class 9 - Science", 80, 22),
    ("Class 10 - Day Shift", 3, 3),        # full
]


def call(method, path, body=None, student=None, timeout=90):
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(API + path, data=data, method=method)
    if body is not None:
        req.add_header("Content-Type", "application/json")
    if student:
        req.add_header("X-Student-Id", student)
    try:
        with urllib.request.urlopen(req, timeout=timeout) as r:
            raw = r.read()
            return r.status, (json.loads(raw) if raw else None)
    except urllib.error.HTTPError as e:
        raw = e.read()
        return e.code, (json.loads(raw) if raw else None)


def admit(args):
    class_id, student = args
    status, hold = call("POST", f"/classes/{class_id}/holds", student=student)
    if status != 201:
        return False
    status, _ = call("POST", f"/holds/{hold['holdId']}/confirm", student=student)
    return status == 200


def main():
    print(f"Seeding {API} (the first call may take ~50s if a free host is asleep)...")
    status, existing = call("GET", "/classes")
    if status != 200:
        sys.exit(f"Cannot reach the API: HTTP {status}")
    by_name = {c["name"]: c for c in existing}

    for idx, (name, seats, admissions) in enumerate(CLASSES, start=1):
        if name in by_name:
            print(f"- {name}: already exists, skipped")
            continue
        status, created = call("POST", "/classes", {"name": name, "totalSeats": seats})
        if status != 201:
            print(f"- {name}: could not create (HTTP {status})")
            continue
        # deterministic, valid 17-digit demo IDs: 2016 + class index (2 digits) + running number (11 digits)
        students = [f"2016{idx:02d}{n:011d}" for n in range(1, admissions + 1)]
        with ThreadPoolExecutor(max_workers=6) as pool:
            ok = sum(pool.map(admit, [(created["id"], s) for s in students]))
        print(f"- {name}: {seats} seats, {ok} confirmed")

    _, classes = call("GET", "/classes")
    print("\nResult:")
    for c in classes:
        print(f"  {c['name']:<28} total {c['totalSeats']:>3}  confirmed {c['confirmedSeats']:>3}  available {c['availableSeats']:>3}")


if __name__ == "__main__":
    main()
