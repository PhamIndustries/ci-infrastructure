# ci-templates

Shared **GitHub Actions** patterns for the Skynet Mac fleet (`rag-orchestrator`, `rag-dashboard`, `domain-rag`, scrapers, …).

## Contract

| Piece | Standard |
|-------|----------|
| Runner labels | `self-hosted`, `macOS`, `ARM64`, `skynet` |
| Triggers | Push to `main`/`master` + PRs |
| Unit entrypoint | `scripts/ci-unit.sh` (required, hermetic) |
| Integration | `scripts/ci-integration.sh` (optional) |
| Preflight | `scripts/ci-preflight.sh` (optional) |
| Reusable workflow | `.github/workflows/python-uv-ci.yml` — pin **`@v1`** |

**One self-hosted runner process per GitHub repo** on the Mac (personal accounts cannot share a single repo-scoped runner across repos).

## Quick adopt

1. Register a runner for the repo — see [docs/RUNNER_MAC.md](docs/RUNNER_MAC.md).
2. Add `scripts/ci-unit.sh` (see [docs/REPO_CI.md](docs/REPO_CI.md)).
3. Add thin `.github/workflows/ci.yml`:

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
      run-integration: false
```

Or copy [examples/ci.yml](examples/ci.yml) if you cannot `workflow_call` yet.

## Test layers

See [docs/TEST_LAYERS.md](docs/TEST_LAYERS.md) — unit = offline; integration = live localhost services.

## Versioning

- Breaking input changes → `v2`
- Compatible additions → `v1.x` tags; callers may stay on `@v1`
