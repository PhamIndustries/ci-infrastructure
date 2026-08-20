# ci-templates

Shared **GitHub Actions** patterns for the Skynet Mac fleet under org **[PhamIndustries](https://github.com/PhamIndustries)**  
(display name **Pham Industries**).

**Agents:** start at **[docs/AGENT_CI.md](docs/AGENT_CI.md)** — single checklist to adopt CI in any fleet repo.

## Contract

| Piece | Standard |
|-------|----------|
| Org | `PhamIndustries` |
| Runner | **One org-level runner:** `skynet-ms-org-1` |
| Labels | `self-hosted`, `macOS`, `ARM64`, `skynet` |
| Triggers | Push to `main`/`master` + PRs into those branches |
| Unit | `scripts/ci-unit.sh` — **required**, hermetic |
| Integration | `scripts/ci-integration.sh` + `scripts/ci-preflight.sh` when enabled |
| Reusable workflow | `PhamIndustries/ci-templates/.github/workflows/python-uv-ci.yml@v1` |

Fork PRs do **not** run on the self-hosted runner (guard in the reusable workflow).

## Quick adopt (agent / human)

1. Ensure the repo lives under **`PhamIndustries`** (or can call the public reusable workflow). Org runner already serves all org repos — **do not** register a new per-repo runner. See [docs/RUNNER_MAC.md](docs/RUNNER_MAC.md).
2. Add scripts (copy from [examples/](examples/)):
   - `scripts/ci-unit.sh` (**required**)
   - `scripts/ci-preflight.sh` + `scripts/ci-integration.sh` (when enabling integration)
3. Add pytest marker in `pyproject.toml` — see [docs/TEST_LAYERS.md](docs/TEST_LAYERS.md).
4. Mark live-touching tests `@pytest.mark.integration`.
5. Add thin `.github/workflows/ci.yml`:

```yaml
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
      run-integration: true   # set false until preflight + marks exist
      timeout-minutes: 30
```

Full checklist: [docs/REPO_CI.md](docs/REPO_CI.md) · Fleet standard: [docs/FLEET_CI_STANDARD.md](docs/FLEET_CI_STANDARD.md).

## Docs map

| Doc | Audience |
|-----|----------|
| [docs/AGENT_CI.md](docs/AGENT_CI.md) | **Agents** — start here |
| [docs/REPO_CI.md](docs/REPO_CI.md) | Adopt checklist |
| [docs/TEST_LAYERS.md](docs/TEST_LAYERS.md) | Unit vs integration |
| [docs/RUNNER_MAC.md](docs/RUNNER_MAC.md) | Org runner (primary) + legacy per-repo |
| [docs/FLEET_CI_STANDARD.md](docs/FLEET_CI_STANDARD.md) | Full agent implementation guide |
| [docs/ORG_CUTOVER.md](docs/ORG_CUTOVER.md) | Org migration / Ops A–G |
| [docs/ORG_CUTOVER_AND_FLEET_CI_STANDARD.md](docs/ORG_CUTOVER_AND_FLEET_CI_STANDARD.md) | Full accepted design (archive / deep reference) |

## Reference implementations

| Repo | Notes |
|------|--------|
| `PhamIndustries/rag-orchestrator` | Unit + integration; fleet preflight curls |
| `PhamIndustries/rag-dashboard` | Unit (+ node `.mjs`) + shell live integration |

## Versioning

- Breaking input changes → `v2`
- Compatible additions → move `v1` tag (callers stay on `@v1`)
