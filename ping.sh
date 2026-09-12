#!/usr/bin/env bash

set -uo pipefail

TIMEOUT_SECONDS=10
RETRIES=3
RETRY_DELAY_SECONDS=5

mapfile -t service_vars < <(env | grep -E '^[A-Za-z0-9_]+_URL=' | cut -d= -f1 | sort)

if [ "${#service_vars[@]}" -eq 0 ]; then
  echo "::error::no *_URL env vars found — check the /service-urls path in infisical and the workflow's secret-path"
  exit 1
fi

failures=0

for var_name in "${service_vars[@]}"; do
  url="${!var_name}"
  service_name="${var_name%_URL}"

  attempt=1
  ok=0
  while [ "$attempt" -le "$RETRIES" ]; do
    if curl --fail --silent --show-error --max-time "$TIMEOUT_SECONDS" --output /dev/null "$url"; then
      ok=1
      break
    fi
    echo "  attempt $attempt/$RETRIES failed for $service_name, retrying in ${RETRY_DELAY_SECONDS}s..."
    attempt=$((attempt + 1))
    sleep "$RETRY_DELAY_SECONDS"
  done

  if [ "$ok" -eq 1 ]; then
    echo "OK    $service_name ($url)"
  else
    echo "FAIL  $service_name ($url) — no response after $RETRIES attempts"
    failures=$((failures + 1))
  fi
done

echo "$((${#service_vars[@]} - failures))/${#service_vars[@]} services responded"

if [ "$failures" -gt 0 ]; then
  exit 1
fi
