#!/usr/bin/env bash
# Per-repo deploy: reload LaunchAgent(s) so ~/Projects/<repo> code is live.
# CI does NOT run this. Copy into scripts/deploy.sh and edit LABELS / health URLs.
#
# Usage:
#   bash scripts/deploy.sh              # kickstart + health
#   bash scripts/deploy.sh --pull       # ff-only pull, then restart
#   bash scripts/deploy.sh --sync       # uv sync, then restart
#   bash scripts/deploy.sh --dry-run
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

# --- customize per repo ---
# Space-separated launchd labels this repo owns (gui/$UID domain).
LABELS="com.skynet.REPLACE_ME"
# Health probes: "url" or "url|ok_substr" (substr optional; HTTP 2xx required).
HEALTH_URLS=(
  "http://127.0.0.1:PORT/health"
)
HEALTH_TIMEOUT_S="${HEALTH_TIMEOUT_S:-60}"
# --- end customize ---

PULL=0
SYNC=0
DRY=0
for arg in "$@"; do
  case "$arg" in
    --pull) PULL=1 ;;
    --sync) SYNC=1 ;;
    --dry-run) DRY=1 ;;
    -h|--help)
      sed -n '2,12p' "$0"
      exit 0
      ;;
    *)
      echo "unknown arg: $arg (use --pull --sync --dry-run)" >&2
      exit 2
      ;;
  esac
done

DOMAIN="gui/$(id -u)"

run() {
  if [[ "$DRY" -eq 1 ]]; then
    echo "dry-run: $*"
  else
    "$@"
  fi
}

if [[ "$PULL" -eq 1 ]]; then
  run git pull --ff-only
fi
if [[ "$SYNC" -eq 1 ]]; then
  if [[ -f pyproject.toml ]]; then
    run uv sync
  else
    echo "no pyproject.toml — skip --sync" >&2
  fi
fi

for label in $LABELS; do
  if [[ "$DRY" -eq 1 ]]; then
    echo "dry-run: launchctl kickstart -k ${DOMAIN}/${label}"
    continue
  fi
  if launchctl print "${DOMAIN}/${label}" >/dev/null 2>&1; then
    launchctl kickstart -k "${DOMAIN}/${label}"
    echo "kickstarted ${label}"
  else
    plist="${HOME}/Library/LaunchAgents/${label}.plist"
    if [[ -f "$plist" ]]; then
      launchctl bootstrap "$DOMAIN" "$plist"
      launchctl enable "${DOMAIN}/${label}" 2>/dev/null || true
      launchctl kickstart -k "${DOMAIN}/${label}" 2>/dev/null || true
      echo "bootstrapped+started ${label}"
    else
      echo "missing LaunchAgent ${label} (no print, no ${plist})" >&2
      exit 1
    fi
  fi
done

if [[ "$DRY" -eq 1 ]]; then
  echo "dry-run: would probe ${#HEALTH_URLS[@]} health URL(s)"
  exit 0
fi

deadline=$((SECONDS + HEALTH_TIMEOUT_S))
for spec in "${HEALTH_URLS[@]}"; do
  url="${spec%%|*}"
  want=""
  [[ "$spec" == *"|"* ]] && want="${spec#*|}"
  ok=0
  while (( SECONDS < deadline )); do
    body="$(curl -fsS --max-time 5 "$url" 2>/dev/null || true)"
    code="$(curl -sS -o /dev/null -w '%{http_code}' --max-time 5 "$url" 2>/dev/null || echo 000)"
    if [[ "$code" =~ ^2[0-9][0-9]$ ]]; then
      if [[ -z "$want" ]] || grep -q -- "$want" <<<"$body"; then
        echo "health ok ${code} ${url}"
        ok=1
        break
      fi
    fi
    sleep 2
  done
  if [[ "$ok" -ne 1 ]]; then
    echo "health FAILED ${url} (timeout ${HEALTH_TIMEOUT_S}s)" >&2
    exit 1
  fi
done

echo "deploy ok: ${LABELS}"
