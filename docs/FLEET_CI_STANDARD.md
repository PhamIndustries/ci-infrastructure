# Fleet CI standard (Agent Implementation Guide)

> **SoT for agents adopting CI in one repo.** Start at [AGENT_CI.md](AGENT_CI.md).

| Field | Value |
|-------|-------|
| Org | `PhamIndustries` (display **Pham Industries**) |
| Runner | `skynet-ms-org-1` · labels `self-hosted,macOS,ARM64,skynet` |
| Workflow | `PhamIndustries/ci-templates/.github/workflows/python-uv-ci.yml@v1` |
| Unit | `scripts/ci-unit.sh` hermetic |
| Integration | `run-integration: true` + preflight + `ci-integration.sh` |

Org cutover / Ops → [ORG_CUTOVER.md](ORG_CUTOVER.md). Short checklist → [REPO_CI.md](REPO_CI.md).

---

## Fleet CI standard


#### B.1 Directory layout

**Default (single Python package):**

```text
repo/
  tests/
    test_*.py              # unit by default
    conftest.py            # optional
    fixtures/              # optional offline fixtures
  scripts/
    ci-unit.sh             # REQUIRED
    ci-integration.sh      # optional
    ci-preflight.sh        # optional
  .github/workflows/
    ci.yml                 # thin wrapper
  pyproject.toml           # pytest markers
```

**Monorepo exception — `rag-dashboard`:**

```text
packages/contract/tests/test_*.py
apps/shell/tests/test_*.py
apps/shell/tests/test_*.mjs    # Node pure helpers
```

`pyproject.toml` already sets:

```toml
[tool.pytest.ini_options]
testpaths = ["packages/contract/tests", "apps/shell/tests"]
```

**Do not** invent a third layout. If a repo is a monorepo, declare `testpaths` explicitly and keep `ci-unit.sh` as the single entrypoint.

#### B.2 Unit vs integration definition

| Layer | Definition | May touch | Must not touch |
|-------|------------|-----------|----------------|
| **Unit** | Hermetic, offline, deterministic | tmp dirs, fixtures, mocks, in-process fakes | OWUI `:8080`, Qdrant `:6335`, orch `:8787`, domain-rag `:8794`, live scrape, NAS, real network product APIs |
| **Integration** | Needs healthy localhost services on the runner host | Explicit ports above, after preflight | Untrusted external prod SaaS; long scrapes on every PR |

Latency targets (guidance):

- Unit job: **&lt; 10 min** typical; timeout default **25–30 min** in workflow.
- Integration job: **&lt; 20 min** when enabled; fail fast on preflight.

#### B.3 Pytest marker contract

In every pytest-based repo `pyproject.toml`:

```toml
[tool.pytest.ini_options]
markers = [
  "integration: needs live localhost services",
]
```

Mark live tests:

```python
import pytest

pytestmark = pytest.mark.integration  # whole module

@pytest.mark.integration
def test_control_health_live():
    ...
```

Commands:

```bash
# unit (CI default)
uv run python -m pytest -q -m "not integration"

# integration (optional CI / local)
uv run python -m pytest -q -m integration
```

**Recommended approach: marker-only** (not directory-only).

| Approach | Pros | Cons | Verdict |
|----------|------|------|---------|
| Marker-only | One selector; matches existing orch/dash + reusable workflow | Easy to forget a mark | **Recommended** |
| `tests/integration/` only | Obvious location | CI must path-filter; mixed files awkward; dual SoT | Reject as sole mechanism |
| Both | Nice for humans | Must still mark; dirs alone insufficient | Optional co-location OK |

**Justification:** CI already filters with `-m "not integration"`. Directory co-location (`tests/integration/test_foo.py`) is allowed for clarity but **every** live test must still carry the marker (module-level `pytestmark` preferred).

**domain-rag mandate (fleet wins over local test-plan defaults):**

- `docs/test-plan-generation-delta-index-v1.md` historically suggested marks `unit` / `integration` / `live` / `slow` and default CI `pytest -m "not live and not slow"`. **Fleet gate is `not integration` only.**
- In the adoption PR (PR10): declare `integration` in `pyproject.toml`; add `@pytest.mark.integration` to **every** Qdrant live test (`test_qdrant_clone.py`, `test_delta_index_seed.py`, `test_delta_index_deletes.py`, `test_delta_index_retention.py`, and any similar). Keep `_qdrant_ready()` / `skipif` if desired for local DX, but markers are mandatory for selection.
- Update that test-plan doc’s suggested defaults to `pytest -m "not integration"` as the CI gate; treat `live` / `slow` as **optional extras** only (never the sole filter in `ci-unit.sh`).
- Filename patterns (`test_integration_*`) or directory co-location are **not** enough — unmarked live tests still run under `-m "not integration"` (and may skip via `skipif`, which is green but not selectable as an intentional integration job later).

#### B.4 Required / optional scripts

**`scripts/ci-unit.sh` (required)** — pytest repos:

```bash
#!/usr/bin/env bash
# Hermetic unit tests for GitHub Actions (self-hosted). No live services.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

# Prefer matching the repo's existing uv style:
#   uv sync --extra dev   # orch, autoforge, lds
#   uv sync --group dev   # dash, some uv workspaces
uv sync --extra dev
uv run python -m pytest -q -m "not integration"
```

**`scripts/ci-unit.sh` for unittest-only repos (webui-model-configs)** — do **not** convert to pytest just to adopt the fleet entrypoint name:

```bash
#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
# Offline only — no OWUI. Delegates to existing stdlib unittest runner.
exec ./scripts/run-unit-tests.sh
```

**`scripts/ci-integration.sh` (optional)**

```bash
#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
bash scripts/ci-preflight.sh
uv run python -m pytest -q -m integration
```

**`scripts/ci-preflight.sh` (optional)** — exit non-zero if required services down:

```bash
#!/usr/bin/env bash
set -euo pipefail
echo "host=$(hostname)"
command -v uv; uv --version; python3 --version
# Example orch:
curl -fsS --max-time 3 "http://127.0.0.1:8787/provider/v1/health" >/dev/null
# Example domain-rag:
# curl -fsS --max-time 3 "http://127.0.0.1:8794/health" >/dev/null
```

Make scripts executable: `chmod +x scripts/ci-*.sh`.

#### B.5 Thin workflow (copy-paste)

`.github/workflows/ci.yml`:

```yaml
# Thin wrapper — fleet standard from PhamIndustries/ci-templates@v1
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
      timeout-minutes: 25
```

Until org exists, callers still use `vuudoopham/ci-templates@v1` (current orch/dash).

Fallback if `workflow_call` unavailable: copy `ci-templates/examples/ci-standalone.yml`.

#### B.6 Runner labels

```text
self-hosted, macOS, ARM64, skynet
```

JSON default in reusable workflow:

```json
["self-hosted", "macOS", "ARM64", "skynet"]
```

Do not add repo-specific labels unless a later decision introduces a second runner pool (O2 resolved: one runner; e.g. `skynet-heavy` only if org-2 is added for heavy integration).

#### B.7 Triggers and fork guard

- **Triggers:** push to `main`/`master` + pull_request targeting those branches.
- **Fork guard** (already in `python-uv-ci.yml`):

```yaml
if: github.event_name != 'pull_request' || github.event.pull_request.head.repo.full_name == github.repository
```

Same-repo PRs run; fork PRs skip self-hosted jobs.

#### B.8 How to classify existing tests (audit checklist)

For each `tests/**/test_*.py` (and dash monorepo paths):

1. Does the test open a real socket to `127.0.0.1` / `localhost` for a **service** (not merely assert a URL string)? → **integration**.
2. Does it require LaunchAgent services, OWUI, Qdrant, control serve, or on-disk production scrape trees that are not fixtures? → **integration** (or skip-if-missing **and** mark integration).
3. Does it use `tmp_path`, mocks, `respx`/`httpx` MockTransport, or checked-in fixtures only? → **unit**.
4. Filename contains `live` / `e2e` / `regress`? → inspect; default to **integration** until proven hermetic.
5. Does it call external network (non-localhost)? → not unit; usually not default integration either (manual/`workflow_dispatch`).
6. Does it `pytest.skip` / skip-if-missing when on-disk **production `data/`** (or similar) is absent, but will **run** when that tree exists on Skynet-MS? → treat as **integration** (or dedicated `data` mark excluded by unit) — especially LDS (~16/30 modules). Hosted Ubuntu stayed green because `data/` was missing; the Mac runner will execute them otherwise.
7. After marking, run locally: `bash scripts/ci-unit.sh` with product services **stopped** — must still pass. For LDS-class repos, also prove green with `data/` **hidden/unavailable** (rename/move aside or run from a clean checkout without the production tree).

#### B.9 Acceptance criteria / Definition of Done (repo adoption PR)

- [ ] `scripts/ci-unit.sh` exists, executable, hermetic.
- [ ] `pyproject.toml` declares `integration` marker (**pytest repos only**; unittest repos like webui are exempt — see K12 / C.5).
- [ ] Live / data-present tests marked; `bash scripts/ci-unit.sh` passes with services down (and with production `data/` hidden where applicable).
- [ ] Thin `.github/workflows/ci.yml` calls `PhamIndustries/ci-templates` `@v1` (or `vuudoopham` only **before** Ops B).
- [ ] Push to default branch produces a **green** unit job on labels `self-hosted,macOS,ARM64,skynet`.
- [ ] Same-repo PR triggers CI; documentation one-liner points at ci-templates.
- [ ] No secrets printed; no registration tokens committed.
- [ ] If `run-integration: true`: `ci-integration.sh` **and** `ci-preflight.sh` exist; preflight fails closed; integration is intentional. **Note (K15):** today’s reusable workflow **soft-skips** missing `ci-preflight.sh` — DoD / review must enforce presence until the fail-closed follow-up ships in `ci-templates`.
- [ ] Agent ran the repo’s documented local test gate before merge.
#### B.10 Example commands

```bash
# Local unit (any adopted repo)
bash scripts/ci-unit.sh

# Local integration (only when enabled for that repo)
bash scripts/ci-preflight.sh && bash scripts/ci-integration.sh

# Orch-focused subset (dev loop — not a substitute for ci-unit.sh in CI)
cd ~/Projects/rag-orchestrator
uv run python -m pytest tests/test_flow_*.py tests/test_step_progress*.py tests/test_export_progress_mapping.py -q

# Dash shell JS helpers
cd ~/Projects/rag-dashboard
node --test apps/shell/tests/test_flow_*.mjs
```

---

## Test standardization


#### C.1 Standard locations and naming

| Kind | Pattern |
|------|---------|
| Python tests | `test_*.py` under `tests/` (or declared `testpaths`) |
| Node pure helpers (dash) | `apps/shell/tests/test_*.mjs` via `node --test` |
| Fixtures | `tests/fixtures/` or in-repo `fixtures/` |
| Integration co-location (optional) | `tests/integration/test_*.py` **plus** marker |

#### C.2 What may never appear in unit CI

- OWUI / Open WebUI (`:8080`) or `WEBUI_API_KEY`
- Qdrant (`:6335` or similar)
- `control serve` / orch provider health as a hard dependency
- domain-rag live search (`:8794`) as a hard dependency
- Live scrape against AutoTrader / CarGurus / church sites
- NAS mounts / rsync
- Relying on developer laptop state outside the checked-out workspace + uv env — including **on-disk production scrape/export trees** (e.g. LDS `data/`) that happen to exist on Skynet-MS

#### C.3 Integration policy

| Topic | Policy |
|-------|--------|
| Enable flag | `run-integration: true` in thin `ci.yml` |
| Preflight | **Required by DoD** when integration enabled (`scripts/ci-preflight.sh` must exist and fail closed). Workflow today: missing preflight → soft-skip (K15); missing `ci-integration.sh` → fail. Follow-up: fail closed on missing preflight in `ci-templates` |
| `continue-on-error` | **false** (fail closed) once enabled — do not soft-pass flaky live tests in default CI |
| When to enable | Host LaunchAgents stable; preflight reliable for 1+ week; suite &lt; ~20 min |
| Heavy / scrape | Prefer `workflow_dispatch` separate workflow — not PR unit/integration |
| webui regress | Dedicated `regress.yml` retained initially (K12); treat as integration-class |

#### C.4 Node / JS tests

- Only **rag-dashboard** today.
- `scripts/ci-unit.sh` already runs `node --test apps/shell/tests/test_flow_*.mjs` with Homebrew path fallback.
- Missing node → **WARN + skip** (current behavior). Prefer installing node on Skynet-MS so CI is complete.
- Do not invent a second reusable Node workflow until another repo needs it.

#### C.5 Gap analysis — mapping repos to the standard

| Repo | Tests location | Unit entry today | Gaps to close | Integration candidate |
|------|----------------|------------------|---------------|----------------------|
| **ci-templates** | examples only | n/a | Update docs for org runners + `uses:` ORG; add `ORG_CUTOVER.md` / `FLEET_CI_STANDARD.md` | n/a |
| **rag-orchestrator** | `tests/` (~47 modules) | `scripts/ci-unit.sh` ✅ | Audit & mark any live-touching tests; optional `ci-integration.sh` for `:8787` | Live control/API when orch LaunchAgent up |
| **rag-dashboard** | contract + shell (+ `.mjs`) | `scripts/ci-unit.sh` ✅ | Marker audit; ensure node on runner PATH | Browser e2e = out of scope |
| **webui-model-configs** | `tests/` (unittest) | `scripts/run-unit-tests.sh` | **Preferred:** `ci-unit.sh` wraps unittest + thin `ci.yml` (`run-integration: false`) **and** keep `regress.yml` on `skynet` labels; **pytest marker DoD N/A** (unittest); org secret | Existing `regress.yml` live OWUI |
| **lds-docs-scraper** | `tests/` | Hosted partial pytest list on `ubuntu-latest` | **K14:** move default CI to self-hosted; **remove** hosted job; full `tests/` via `ci-unit.sh`; mark **all** skip-if-data / e2e modules (`test_e2e_pipeline.py`, many `test_extract_*.py`, `test_production_structure.py`, `test_study_aids_path_layout.py`, … — ~16/30) as `integration` (or `data` excluded by unit); prove unit with `data/` hidden | Data-present suites on Mac; not live scrape |
| **autoforge** | `tests/` | None | Add markers, `ci-unit.sh`, thin `ci.yml`; classify `*live*` tests (many are hermetic “live envelope” builders — verify) | Rare live scrape via dispatch |
| **domain-rag** | `tests/` | None | Declare `integration` in `pyproject.toml`; mark all Qdrant live `skipif` tests; align test-plan defaults to `not integration`; `ci-unit.sh` + thin workflow | Qdrant `:6335` + API `:8794` |
| **wiki-rag** | `tests/` (small) | None | **First batch (O5):** `ci-unit.sh` + thin `ci.yml` + markers with domain-rag wave | wiki Qdrant LaunchAgent |

---


## Quick Definition of Done

- [ ] Repo under `PhamIndustries`
- [ ] `scripts/ci-unit.sh` hermetic; `pytest -m "not integration"` green locally with services **down**
- [ ] Live-touching tests marked `@pytest.mark.integration`
- [ ] If `run-integration: true`: `ci-preflight.sh` + `ci-integration.sh` present and executable
- [ ] Thin `.github/workflows/ci.yml` pins `@v1`
- [ ] Push shows **unit** then **integration** on `skynet-ms-org-1`
- [ ] No new per-repo runner registered

## Examples

- [examples/ci.yml](../examples/ci.yml)
- [examples/ci-unit.sh](../examples/ci-unit.sh)
- [examples/ci-preflight.sh](../examples/ci-preflight.sh)
- [examples/ci-integration.sh](../examples/ci-integration.sh)
