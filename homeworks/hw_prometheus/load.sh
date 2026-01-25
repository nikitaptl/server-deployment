#!/usr/bin/env bash
set -euo pipefail

BASE_URL="${BASE_URL:-https://muffin.nrunnercloud.xyz}"
DURATION_SECONDS="${DURATION_SECONDS:-180}"
CONCURRENCY="${CONCURRENCY:-5}"

OWNER_PLAIN="${OWNER_PLAIN:-load_plain}"
OWNER_CHOKO="${OWNER_CHOKO:-load_choko}"

create_wallet() {
  local owner_name="$1"
  local type="$2"

  curl -sS -X POST "${BASE_URL}/v1/muffin-wallets" \
    -H "Content-Type: application/json" \
    -d "{\"type\":\"${type}\",\"owner_name\":\"${owner_name}\"}"
}

extract_id() {
  sed -n 's/.*"id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p'
}

do_one_iteration() {
  local plain_id="$1"
  local choko_id="$2"

  curl -sS "${BASE_URL}/v1/muffin-wallets" > /dev/null

  curl -sS "${BASE_URL}/v1/muffin-wallet/${plain_id}" > /dev/null
  curl -sS "${BASE_URL}/v1/muffin-wallet/${choko_id}" > /dev/null

  curl -sS -X POST "${BASE_URL}/v1/muffin-wallet/${plain_id}/transaction" \
    -H "Content-Type: application/json" \
    -d "{\"to_muffin_wallet_id\":\"${choko_id}\",\"amount\":1}" > /dev/null

  curl -sS -X POST "${BASE_URL}/v1/muffin-wallet/${choko_id}/transaction" \
    -H "Content-Type: application/json" \
    -d "{\"to_muffin_wallet_id\":\"${plain_id}\",\"amount\":1}" > /dev/null
}

worker() {
  local plain_id="$1"
  local choko_id="$2"
  local end_ts="$3"

  while [ "$(date +%s)" -lt "${end_ts}" ]; do
    do_one_iteration "${plain_id}" "${choko_id}"
  done
}

main() {
  echo "BASE_URL=${BASE_URL}"
  echo "DURATION_SECONDS=${DURATION_SECONDS}"
  echo "CONCURRENCY=${CONCURRENCY}"

  echo "[1/3] Creating wallets (type=PLAIN, CHOKOLATE)..."

  local plain_json
  plain_json="$(create_wallet "${OWNER_PLAIN}" "PLAIN")"
  local plain_id
  plain_id="$(printf '%s' "${plain_json}" | extract_id)"

  local choko_json
  choko_json="$(create_wallet "${OWNER_CHOKO}" "CHOKOLATE")"
  local choko_id
  choko_id="$(printf '%s' "${choko_json}" | extract_id)"

  if [ -z "${plain_id}" ] || [ -z "${choko_id}" ]; then
    echo "Failed to parse wallet ids."
    echo "PLAIN response: ${plain_json}"
    echo "CHOKOLATE response: ${choko_json}"
    exit 1
  fi

  echo "PLAIN wallet id: ${plain_id}"
  echo "CHOKOLATE wallet id: ${choko_id}"

  echo "[2/3] Warming up..."
  do_one_iteration "${plain_id}" "${choko_id}"

  echo "[3/3] Running load for ${DURATION_SECONDS}s with concurrency=${CONCURRENCY}..."
  local end_ts
  end_ts="$(( $(date +%s) + DURATION_SECONDS ))"

  for _ in $(seq 1 "${CONCURRENCY}"); do
    worker "${plain_id}" "${choko_id}" "${end_ts}" &
  done

  wait
  echo "Done."
}

main
