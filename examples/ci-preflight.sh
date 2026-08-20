#!/usr/bin/env bash
# Example integration preflight — copy to scripts/ci-preflight.sh and trim.
# Exit non-zero if REQUIRED deps are down. Optional URLs may warn only.
set -euo pipefail

curl_ok() {
  local url="$1"
  curl -fsS --connect-timeout 2 --max-time 5 "$url" >/dev/null \
    || { echo "FAIL: $url" >&2; return 1; }
  echo "ok  $url"
}

echo "host=$(hostname)"
command -v uv >/dev/null && uv --version || echo "WARN: uv missing"

# --- REQUIRED: edit for this repo ---
# Orch control (common):
# curl_ok "http://127.0.0.1:8787/provider/v1/health"
# Domain-rag:
# curl_ok "http://127.0.0.1:8794/health"
# curl_ok "http://127.0.0.1:6335/collections"
# Dashboard shell:
# curl_ok "http://127.0.0.1:8790/"

# Placeholder so a naive copy fails closed until edited:
if [[ "${CI_PREFLIGHT_ALLOW_EMPTY:-}" != "1" ]]; then
  echo "Edit scripts/ci-preflight.sh: add curl_ok lines for this repo's live deps." >&2
  echo "(Or export CI_PREFLIGHT_ALLOW_EMPTY=1 only for dry wiring checks.)" >&2
  exit 1
fi

echo "preflight ok"
