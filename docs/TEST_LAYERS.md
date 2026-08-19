# Test layers (unit vs integration)

## Unit (default CI)

- Offline / mocked
- No dependency on OWUI `:8080`, Qdrant, domain-rag `:8794`, orch `:8787`
- Command: `uv run pytest -q -m "not integration"`
- Entry: `scripts/ci-unit.sh` — **required green on every push/PR**

## Integration (optional)

- May hit localhost services
- Mark tests: `@pytest.mark.integration`
- Command: `uv run pytest -q -m integration`
- Entry: `scripts/ci-integration.sh`
- Enable in workflow with `run-integration: true` only when the runner host keeps those services healthy

## Fleet mapping

| Repo | Unit | Integration (later) |
|------|------|---------------------|
| rag-orchestrator | `tests/` hermetic | Live control API |
| rag-dashboard | contract + shell pytest (+ node) | Browser e2e optional |
| domain-rag | pytest offline | Qdrant + `:8794` |
| autoforge / lds-docs | pytest offline | Live scrape (manual/`workflow_dispatch`) |
| webui-model-configs | unittest offline | Live OWUI regress (existing) |

## Rule

**Nothing in `ci-unit.sh` may require live services.** That keeps CI green during ops windows (index, NAS rsync, cleanup).
