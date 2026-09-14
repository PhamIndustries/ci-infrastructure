#!/usr/bin/env bash
# Hermetic unit tests for logger/parser examples (stdlib unittest).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
python3 -m unittest discover -s tests -p 'test_*.py' -q
