#!/usr/bin/env bash
# TEMPLATE — copy into the app's backend/pocketbase/tests/ and fill in the
# schedule rewrites for ITS crons.
#
# The cron jobs, against a throwaway PocketBase.
#
# ── Why this is a second script and not part of run.sh ──────────────────────
# `cronAdd` jobs are INVISIBLE to that suite: nothing in the API can trigger
# one, so an assertion suite can only ever test the guard a cron has to get
# past, never the cron itself. The only way to observe one is to make it DUE —
# so this copies pb_hooks to a tempdir, rewrites the schedule to every minute,
# and runs a container against that copy. The committed hooks are never touched.
#
# It is deliberately NOT part of run.sh or CI: it has to wait for a wall-clock
# minute boundary, which no other test does.
#
# Usage:  backend/pocketbase/tests/run_cron.sh
# Env:    ZV_TEST_PORT (default 8098 — one above run.sh, so both can run)
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
PB_DIR="$(cd "$HERE/.." && pwd)"
ROOT="$(cd "$PB_DIR/../.." && pwd)"
IMAGE="SERVICE-pocketbase:test"
PORT="${ZV_TEST_PORT:-8098}"
NAME="zv_cron_$$"
DATA="$(mktemp -d)"
HOOKS="$(mktemp -d)"
ADMIN_EMAIL="admin@SERVICE.local"
ADMIN_PASS="Admin12345!"

cleanup() {
  docker rm -f "$NAME" >/dev/null 2>&1 || true
  docker run --rm -v "$DATA:/data" --entrypoint sh "$IMAGE" \
    -c 'rm -rf /data/* /data/.[!.]* /data/..?* 2>/dev/null' >/dev/null 2>&1 || true
  rm -rf "$DATA" "$HOOKS"
}
trap cleanup EXIT

echo "==> Ensuring image $IMAGE exists"
docker image inspect "$IMAGE" >/dev/null 2>&1 || \
  docker build --target backend -t "$IMAGE" -f "$ROOT/Dockerfile" "$ROOT"

echo "==> Copying hooks and making the jobs under test due every minute"
cp -r "$PB_DIR/pb_hooks/." "$HOOKS/"

# ── Rewrite, then VERIFY the rewrite ────────────────────────────────────────
#
# Every `sed` here is followed by a `grep` that fails the run if it did not
# apply. A sed that silently matches nothing leaves the real daily schedule in
# place, the job never becomes due, and the suite then passes by asserting
# nothing at all — the worst possible outcome for a test of a cron. Renaming a
# cron must break this script loudly.
#
# Rewrite ONLY the jobs under test. The others keep their real schedules so they
# cannot interfere; jobs on disjoint collections can all be due together.
rewrite() {
  local file="$1" name="$2"
  sed -i "s|cronAdd(\"$name\", \"[^\"]*\"|cronAdd(\"$name\", \"* * * * *\"|" \
    "$HOOKS/$file"
  grep -q "cronAdd(\"$name\", \"\* \* \* \* \*\"" "$HOOKS/$file" || {
    echo "the schedule rewrite for $name did not apply — has it been renamed?"
    exit 1
  }
}

# rewrite "audit.pb.js" "auditRetention"
# rewrite "finder_retention.pb.js" "finderPiiRetention"

# ── And watch for the OTHER kind of vacuous pass ────────────────────────────
#
# A fixed grace period measured from a server-owned autodate that no client can
# backdate makes a deletion UNOBSERVABLE: with it in place no test can ever see
# the job act, and the whole cron is asserted vacuously. Neutralise it in the
# COPY, and have the Python suite read the COMMITTED file and fail if the real
# grace period has gone missing — so the test cannot be the reason it was
# removed.
#
# sed -i 's|const ORPHAN_GRACE_MS = 24 \* 60 \* 60 \* 1000;|const ORPHAN_GRACE_MS = 0;|' \
#   "$HOOKS/retention.pb.js"
# grep -q 'const ORPHAN_GRACE_MS = 0;' "$HOOKS/retention.pb.js" || {
#   echo "the grace-period rewrite did not apply — has the constant changed?"
#   exit 1; }

echo "==> Applying migrations to throwaway data dir"
docker run --rm \
  -v "$PB_DIR/pb_migrations:/pb/pb_migrations:ro" \
  -v "$DATA:/pb/pb_data" \
  "$IMAGE" migrate up >/dev/null

echo "==> Creating superuser"
docker run --rm \
  -v "$PB_DIR/pb_migrations:/pb/pb_migrations:ro" \
  -v "$DATA:/pb/pb_data" \
  "$IMAGE" superuser upsert "$ADMIN_EMAIL" "$ADMIN_PASS" >/dev/null

echo "==> Starting server on :$PORT"
docker run -d --name "$NAME" -p "$PORT:8090" \
  -v "$PB_DIR/pb_migrations:/pb/pb_migrations:ro" \
  -v "$HOOKS:/pb/pb_hooks:ro" \
  -v "$PB_DIR/typst:/pb/typst:ro" \
  -v "$DATA:/pb/pb_data" \
  "$IMAGE" >/dev/null

echo "==> Waiting for health"
for _ in $(seq 1 40); do
  curl -sf "http://localhost:$PORT/api/health" >/dev/null && break
  sleep 0.5
done
curl -sf "http://localhost:$PORT/api/health" >/dev/null || {
  echo "server never became healthy"; docker logs "$NAME"; exit 1; }

echo "==> Running cron assertions (waits for a minute boundary)"
set +e
ZV_TEST_URL="http://localhost:$PORT" \
ZV_ADMIN_EMAIL="$ADMIN_EMAIL" \
ZV_ADMIN_PASS="$ADMIN_PASS" \
PYTHONPATH="$PB_DIR/tests" \
  python3 "$HERE/test_cron.py"
STATUS=$?
set -e

# The jobs log what they did; on a failure that is the first thing to look at.
if [ "$STATUS" -ne 0 ]; then
  echo "==> Container log (job lines)"
  docker logs "$NAME" 2>&1 | grep -iE "retention|purge" || echo "  (none)"
fi
exit "$STATUS"
