# Adopt CI in a fleet repo

Checklist for any Python repo on Skynet-MS.

## 1. Runner (once per repo)

See [RUNNER_MAC.md](RUNNER_MAC.md). Confirm **Idle** under  
GitHub → repo → **Settings → Actions → Runners**.

Labels required: `self-hosted`, `macOS`, `ARM64`, `skynet`.

## 2. Scripts

Create at repo root:

### `scripts/ci-unit.sh` (required)

Must be **hermetic** (no OWUI / Qdrant / control serve):

```bash
#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
uv sync --extra dev   # or: uv sync --group dev
uv run python -m pytest -q -m "not integration"
```

### `scripts/ci-integration.sh` (optional)

Only when live services are intentional:

```bash
#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
bash scripts/ci-preflight.sh
uv run python -m pytest -q -m integration
```

### `scripts/ci-preflight.sh` (optional)

Print host + curl health of dependencies; exit non-zero if required services are down.

## 3. Pytest markers

In `pyproject.toml`:

```toml
[tool.pytest.ini_options]
markers = [
  "integration: needs live localhost services",
]
```

Mark live tests: `@pytest.mark.integration`.

## 4. Workflow

Prefer reusable call (this repo public / accessible):

```yaml
# .github/workflows/ci.yml
name: CI
on:
  push:
    branches: [master, main]
  pull_request:
    branches: [master, main]
jobs:
  ci:
    uses: PhamIndustries/ci-templates/.github/workflows/python-uv-ci.yml@v1
    with:
      unit-command: bash scripts/ci-unit.sh
      run-integration: false
```

Fallback: copy [../examples/ci-standalone.yml](../examples/ci-standalone.yml) into `.github/workflows/ci.yml`.

## 5. Verify

```bash
bash scripts/ci-unit.sh          # local
git push                         # should enqueue Actions on self-hosted
```

Enable **branch protection → require CI** only after the first green run.
