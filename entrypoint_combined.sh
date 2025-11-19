#!/bin/bash
set -e

echo "🔧 Chronarr combined (core + web) entrypoint starting..."

# --- Optional: wait for DB if you *do* use Postgres; safe to leave even if ignored ---
if [ -n "$DB_HOST" ]; then
  echo "⏳ Waiting for database at $DB_HOST:${DB_PORT:-5432}..."
  until python - <<EOF
import sys, socket, os
s = socket.socket()
try:
    s.connect(("$DB_HOST", int(os.getenv("DB_PORT", "5432"))))
except OSError:
    sys.exit(1)
else:
    s.close()
EOF
  do
    echo "   Database not up yet, sleeping..."
    sleep 2
  done
  echo "✅ Database is reachable."
fi
# --- end optional DB wait ---

# Start core (main.py)
echo "🚀 Starting chronarr-core (main.py)..."
python -u main.py &
CORE_PID=$!

# Start web (start_web.py)
echo "🚀 Starting chronarr-web (start_web.py)..."
python -u start_web.py &
WEB_PID=$!

terminate() {
  echo "⚠️  Termination signal received, stopping child processes..."
  kill "$CORE_PID" 2>/dev/null || true
  kill "$WEB_PID" 2>/dev/null || true
  wait "$CORE_PID" 2>/dev/null || true
  wait "$WEB_PID" 2>/dev/null || true
  exit 0
}

trap terminate SIGINT SIGTERM

echo "✅ Both core (PID $CORE_PID) and web (PID $WEB_PID) started."

# Wait until one of them exits
set +e
wait -n "$CORE_PID" "$WEB_PID"
EXIT_CODE=$?
echo "❌ One of the processes exited with code $EXIT_CODE, shutting down..."
terminate
