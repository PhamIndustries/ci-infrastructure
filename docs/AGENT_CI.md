# Agent handoff — adopt fleet CI + deploy in one repo

**Read this first.** Implement CI the same way for every fleet repo under `PhamIndustries`.  
If the repo owns a LaunchAgent, also implement **deploy** (CI does not reload services).

Org: **PhamIndustries** · Runner: **`skynet-ms-org-1`** (already online) · Workflow pin: **`@v1`**

## Goal

On every push/PR to `main`/`master`:

1. **unit** — hermetic `scripts/ci-unit.sh` (must pass)
2. **integration** — after unit, if `run-integration: true`: preflight then `scripts/ci-integration.sh`

**Separately (not in Actions):** after code that a live service imports is on disk → `bash scripts/deploy.sh` so LaunchAgents pick it up. See [DEPLOY.md](DEPLOY.md).

## CI ≠ deploy

| | **CI** (`ci.yml`) | **Deploy** (`scripts/deploy.sh`) |
|--|-------------------|----------------------------------|
| Where | Org runner job | Skynet-MS shell (human/agent) |
| Does | pytest / preflight | `kickstart` this repo’s LaunchAgent(s) + health |
| Does not | Restart services | Run the full test suite (optional local check first) |

## Do / don’t

| Do | Don’t |
|----|--------|
| Transfer or create the repo under `PhamIndustries` | Register a new per-repo Actions runner |
| Use labels `self-hosted,macOS,ARM64,skynet` (org runner already has them) | Use `ubuntu-latest` for fleet Python unit (LDS exception retired) |
| Mark live localhost tests `@pytest.mark.integration` | Put live curls / Qdrant / orch HTTP in unit |
| Copy scripts from `examples/` and adjust URLs | Copy-paste the whole reusable workflow into the repo |
| Pin `uses: PhamIndustries/ci-templates/...@v1` | Pin `@main` long-term or `vuudoopham/...` |
| Add `scripts/deploy.sh` if this repo owns a LaunchAgent | Wire deploy into default CI; restart the whole fleet from one repo |

## Checklist (in order)

1. **Repo under org** — `PhamIndustries/<repo>` (private OK). If still personal, transfer first or accept that org runner won’t pick it up.
2. **Layout** — see [FLEET_CI_STANDARD.md](FLEET_CI_STANDARD.md) § directory layout.
3. **`pyproject.toml` markers:**

```toml
[tool.pytest.ini_options]
markers = [
  "integration: needs live localhost services",
]
```

4. **Audit tests** — any test that opens real sockets to `:8787`, `:8794`, `:6335`, `:8790`, OWUI, SSH/WSL, or live NAS → `@pytest.mark.integration`.
5. **Scripts** (repo root):
   - Copy [examples/ci-unit.sh](../examples/ci-unit.sh) → `scripts/ci-unit.sh`
   - Copy [examples/ci-preflight.sh](../examples/ci-preflight.sh) → `scripts/ci-preflight.sh` (trim required curls to this repo’s deps)
   - Copy [examples/ci-integration.sh](../examples/ci-integration.sh) → `scripts/ci-integration.sh`
   - `chmod +x scripts/ci-*.sh`
6. **Workflow** — copy [examples/ci.yml](../examples/ci.yml) → `.github/workflows/ci.yml`  
   Set `run-integration: true` only when preflight + at least one integration test (or accept exit 0/5 for empty).
7. **Deploy** (if this repo owns a LaunchAgent) — copy [examples/deploy.sh](../examples/deploy.sh) → `scripts/deploy.sh`, set labels + health URLs, `chmod +x`. Details: [DEPLOY.md](DEPLOY.md).
8. **Local verify:**

```bash
bash scripts/ci-unit.sh
bash scripts/ci-preflight.sh    # if enabling integration
bash scripts/ci-integration.sh
bash scripts/deploy.sh --dry-run   # if deploy exists
```

9. **Push to `main`/`master`** — confirm Actions run on **`skynet-ms-org-1`** (unit then integration).
10. **After merge on Skynet-MS** — `bash scripts/deploy.sh` (add `--pull` / `--sync` as needed) so live services load the new checkout.
11. **Definition of Done** — see [REPO_CI.md](REPO_CI.md) § Verify / DoD (+ deploy checklist there).

## Reference implementations

- Orch: `PhamIndustries/rag-orchestrator` — `scripts/ci-*.sh`, `scripts/deploy.sh`, marked tests in `tests/test_service_status.py`, `test_index_panels.py`, `test_ops_live.py`
- Dash: `PhamIndustries/rag-dashboard` — `scripts/ci-*.sh`, `scripts/deploy.sh`, shell live tests in `apps/shell/tests/test_shell_live.py`

## Deeper reading

| Need | Doc |
|------|-----|
| Per-repo service restart | [DEPLOY.md](DEPLOY.md) |
| Full layout / DoD / audit | [FLEET_CI_STANDARD.md](FLEET_CI_STANDARD.md) |
| Unit vs integration rules | [TEST_LAYERS.md](TEST_LAYERS.md) |
| Runner ops | [RUNNER_MAC.md](RUNNER_MAC.md) |
| Org transfer / Ops plan | [ORG_CUTOVER.md](ORG_CUTOVER.md) |
| Original accepted design | [ORG_CUTOVER_AND_FLEET_CI_STANDARD.md](ORG_CUTOVER_AND_FLEET_CI_STANDARD.md) |
