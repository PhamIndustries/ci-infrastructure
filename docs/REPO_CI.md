# Adopt CI in a fleet repo

Checklist for any Python (or unittest) repo on Skynet-MS under **PhamIndustries**.

**Agents:** prefer [AGENT_CI.md](AGENT_CI.md).

## 1. Runner (org — already done)

Fleet CI uses the **org** runner `skynet-ms-org-1` with labels:

```text
self-hosted, macOS, ARM64, skynet
```

Confirm **Idle/Online** under  
GitHub → **PhamIndustries** → **Settings → Actions → Runners**.

**Do not** register a new per-repo runner for normal adoption. See [RUNNER_MAC.md](RUNNER_MAC.md).

## 2. Scripts

Create at repo root (copy from [../examples/](../examples/)):

### `scripts/ci-unit.sh` (required)

Must be **hermetic** (no OWUI / Qdrant / control serve / live scrapes):

```bash
#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
uv sync --extra dev   # or: uv sync --group dev
uv run python -m pytest -q -m "not integration"
```

### `scripts/ci-preflight.sh` (required if `run-integration: true`)

Curl health endpoints this repo’s integration tests need; **exit non-zero** if required deps are down.  
Template: [../examples/ci-preflight.sh](../examples/ci-preflight.sh).

### `scripts/ci-integration.sh` (required if `run-integration: true`)

```bash
#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
# preflight is invoked by the reusable workflow before this script
uv sync --extra dev   # or --group dev
uv run python -m pytest -q -m integration --tb=short
```

If no integration tests are collected yet, use exit-code `5` handling like [../examples/ci-integration.sh](../examples/ci-integration.sh).

## 3. Pytest markers

```toml
[tool.pytest.ini_options]
markers = [
  "integration: needs live localhost services",
]
```

Mark live tests: `@pytest.mark.integration`.

**webui-model-configs** may keep **unittest** for unit (`scripts/ci-unit.sh` wrapping existing runners); pytest marker DoD applies only where pytest is used.

## 4. Workflow

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
      run-integration: true
      timeout-minutes: 30
```

Use `run-integration: false` only until preflight + scripts exist.

Fallback (no `workflow_call`): copy [../examples/ci-standalone.yml](../examples/ci-standalone.yml).

## 5. Verify / Definition of Done

```bash
bash scripts/ci-unit.sh                 # local, services may be down
bash scripts/ci-preflight.sh            # required deps up
bash scripts/ci-integration.sh          # local
git push                                # Actions on skynet-ms-org-1
```

- [ ] Unit job green on org runner  
- [ ] Integration job green (or explicitly `run-integration: false` with reason)  
- [ ] No live service calls in unmarked tests  
- [ ] Fork PR guard respected (no self-hosted fork runs)

Enable **branch protection → require CI** only after the first green run.
