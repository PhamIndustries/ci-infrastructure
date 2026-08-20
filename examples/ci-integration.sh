#!/usr/bin/env bash
# Example integration entrypoint — copy to scripts/ci-integration.sh.
# Reusable workflow already ran scripts/ci-preflight.sh before this.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if [[ -f pyproject.toml ]] && grep -q '\[dependency-groups\]' pyproject.toml 2>/dev/null; then
  uv sync --group dev || uv sync --extra dev || uv sync
elif [[ -f pyproject.toml ]]; then
  uv sync --extra dev || uv sync --group dev || uv sync
else
  echo "No pyproject.toml — adjust this script" >&2
  exit 1
fi

# pytest exits 5 when no tests collected — OK until marks exist
set +e
uv run python -m pytest -q -m integration --tb=short
rc=$?
set -e
if [[ "$rc" -eq 0 || "$rc" -eq 5 ]]; then
  exit 0
fi
exit "$rc"
