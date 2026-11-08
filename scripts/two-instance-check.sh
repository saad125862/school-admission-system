#!/usr/bin/env bash
# Bonus check: two backend processes (ports 8081 and 8082) share ONE Postgres.
# Fires parallel applications at BOTH and verifies held + confirmed never exceeds totalSeats.
# Needs: Postgres from `docker compose up -d postgres` on localhost:5432, .NET 8 SDK, curl, python.
set -euo pipefail
cd "$(dirname "$0")/../backend/src/SchoolAdmission.Api"
dotnet build -c Release -o /tmp/sas-api >/dev/null
export DATABASE_URL="Host=localhost;Port=5432;Database=school_admission_twoproc;Username=school;Password=school_pw"
PORT=8081 dotnet /tmp/sas-api/SchoolAdmission.Api.dll >/tmp/sas-8081.log 2>&1 & P1=$!
PORT=8082 dotnet /tmp/sas-api/SchoolAdmission.Api.dll >/tmp/sas-8082.log 2>&1 & P2=$!
trap 'kill $P1 $P2 2>/dev/null || true' EXIT
for port in 8081 8082; do until curl -sf localhost:$port/health >/dev/null; do sleep 1; done; done

SEATS=${SEATS:-10}; N=${N:-200}
CLASS=$(curl -s -X POST localhost:8081/classes -H 'Content-Type: application/json' -d "{\"name\":\"Two-process race\",\"totalSeats\":$SEATS}" | python -c "import sys,json;print(json.load(sys.stdin)['id'])")
RES=$(mktemp -d)
PIDS=()
for i in $(seq 1 $N); do
  port=$((8081 + i % 2))
  curl -s -o /dev/null -w '%{http_code}
' -X POST localhost:$port/classes/$CLASS/holds -H "X-Student-Id: $(printf '4%016d' $i)" >"$RES/$i.txt" &
  PIDS+=($!)
done
wait "${PIDS[@]}"   # only the curl jobs, not the two servers
cat "$RES"/*.txt | sort | uniq -c
echo "--- class as seen from 8081 and 8082:"
curl -s localhost:8081/classes/$CLASS; echo
curl -s localhost:8082/classes/$CLASS; echo
HELD=$(curl -s localhost:8081/classes/$CLASS | python -c "import sys,json;d=json.load(sys.stdin);print(d['heldSeats']+d['confirmedSeats'])")
[ "$HELD" -le "$SEATS" ] && echo "OK: held+confirmed=$HELD <= totalSeats=$SEATS" || { echo "FAIL: oversold ($HELD > $SEATS)"; exit 1; }
