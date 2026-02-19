#!/usr/bin/env bash
set -euo pipefail

BASE_URL="${ELECTRIC_BASE_URL:-http://localhost:3000}"
SECRET="${ELECTRIC_SECRET:-}"
DATABASE_URL="${DATABASE_URL:-}"
TABLE_NAME="${ELECTRIC_TEST_TABLE:-electric_smoketest}"
TIMEOUT_SECONDS="${ELECTRIC_TEST_TIMEOUT_SECONDS:-60}"
HOST_HEADER="${ELECTRIC_HOST_HEADER:-}"
ALLOW_INSECURE_TLS="${ELECTRIC_CURL_INSECURE:-false}"
REQUEST_TIMEOUT_SECONDS="${ELECTRIC_CURL_MAX_TIME_SECONDS:-15}"
CONNECT_TIMEOUT_SECONDS="${ELECTRIC_CURL_CONNECT_TIMEOUT_SECONDS:-5}"
INITIAL_SYNC_DELAY_SECONDS="${ELECTRIC_INITIAL_SYNC_DELAY_SECONDS:-3}"
RESOLVE_RULE="${ELECTRIC_CURL_RESOLVE:-}"

CURL_ARGS=()
if [[ -n "$HOST_HEADER" ]]; then
  CURL_ARGS+=(-H "Host: ${HOST_HEADER}")
fi
if [[ "$ALLOW_INSECURE_TLS" == "true" ]]; then
  CURL_ARGS+=(-k)
fi
if [[ -n "$RESOLVE_RULE" ]]; then
  CURL_ARGS+=(--resolve "$RESOLVE_RULE")
fi
CURL_ARGS+=(--connect-timeout "$CONNECT_TIMEOUT_SECONDS" --max-time "$REQUEST_TIMEOUT_SECONDS")

if [[ -z "$SECRET" ]]; then
  echo "Missing ELECTRIC_SECRET env var" >&2
  exit 1
fi

if [[ -z "$DATABASE_URL" ]]; then
  echo "Missing DATABASE_URL env var" >&2
  exit 1
fi

for cmd in curl psql jq rg awk; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Missing required command: $cmd" >&2
    exit 1
  fi
done

TEST_ID="smoke_$(date +%s)"
TEST_NOTE="inserted from electric sync smoke test"

psql "$DATABASE_URL" -v ON_ERROR_STOP=1 <<SQL
CREATE TABLE IF NOT EXISTS public.${TABLE_NAME} (
  id text PRIMARY KEY,
  note text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.${TABLE_NAME} REPLICA IDENTITY FULL;
SQL

initial_headers="$(mktemp)"
initial_body="$(mktemp)"
curl -sS -L "${CURL_ARGS[@]}" -D "$initial_headers" -o "$initial_body" \
  "${BASE_URL}/v1/shape?table=${TABLE_NAME}&offset=-1&secret=${SECRET}"

HANDLE="$(awk 'tolower($1)=="electric-handle:" {print $2}' "$initial_headers" | tr -d '\r')"
OFFSET="$(awk 'tolower($1)=="electric-offset:" {print $2}' "$initial_headers" | tr -d '\r')"

if [[ -z "$HANDLE" || -z "$OFFSET" ]]; then
  echo "Failed to obtain Electric handle/offset from initial shape request" >&2
  cat "$initial_headers" >&2
  exit 1
fi

if (( INITIAL_SYNC_DELAY_SECONDS > 0 )); then
  sleep "$INITIAL_SYNC_DELAY_SECONDS"
fi

psql "$DATABASE_URL" -v ON_ERROR_STOP=1 \
  -c "INSERT INTO public.${TABLE_NAME} (id, note) VALUES ('${TEST_ID}', '${TEST_NOTE}')"

max_attempts=$(( TIMEOUT_SECONDS < 1 ? 1 : TIMEOUT_SECONDS ))

for ((attempt=1; attempt<=max_attempts; attempt++)); do
  poll_headers="$(mktemp)"
  poll_body="$(mktemp)"

  curl -sS -L "${CURL_ARGS[@]}" -D "$poll_headers" -o "$poll_body" \
    "${BASE_URL}/v1/shape?table=${TABLE_NAME}&handle=${HANDLE}&offset=${OFFSET}&secret=${SECRET}"

  body="$(cat "$poll_body")"
  new_offset="$(awk 'tolower($1)=="electric-offset:" {print $2}' "$poll_headers" | tr -d '\r')"

  if printf "%s" "$body" | rg -q "$TEST_ID"; then
    echo "PASS: observed row $TEST_ID via Electric stream on attempt $attempt"
    echo "base_url=$BASE_URL"
    echo "table=$TABLE_NAME"
    echo "handle=$HANDLE"
    echo "offset=$OFFSET"
    exit 0
  fi

  if [[ -n "$new_offset" ]]; then
    OFFSET="$new_offset"
  fi

  sleep 1
done

echo "FAIL: did not observe test row $TEST_ID within ${TIMEOUT_SECONDS}s" >&2
exit 1
