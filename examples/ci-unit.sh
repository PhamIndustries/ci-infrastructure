#!/usr/bin/env bash
# Example hermetic unit entrypoint — copy to scripts/ci-unit.sh and adjust.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if [[ -f pyproject.toml ]] && grep -q '\[project.optional-dependencies\]' pyproject.toml 2>/dev/null; then
  uv sync --extra dev
elif [[ -f pyproject.toml ]]; then
  uv sync --group dev || uv sync
else
  echo "No pyproject.toml — adjust this script for the repo"
  exit 1
fi

uv run python -m pytest -q -m "not integration"
