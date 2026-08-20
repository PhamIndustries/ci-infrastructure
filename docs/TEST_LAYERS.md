# Test layers (unit vs integration)

## Unit (every push/PR)

- Offline / mocked
- **No** dependency on OWUI `:8080`, Qdrant, domain-rag `:8794`, orch `:8787`, scrapers, NAS
- Command: `uv run pytest -q -m "not integration"`
- Entry: `scripts/ci-unit.sh` — **required green**

## Integration (after unit, when enabled)

- May hit localhost services on Skynet-MS
- Mark tests: `@pytest.mark.integration`
- Command: `uv run pytest -q -m integration`
- Entry: `scripts/ci-integration.sh`
- Preflight: `scripts/ci-preflight.sh` (**required** when `run-integration: true` — fail closed if missing)
- Enable with `run-integration: true` in the thin `ci.yml`

### What to mark

Mark a test **integration** if it:

- Opens real TCP/HTTP to fixed ports (`:8787`, `:8794`, `:6335`, `:8790`, …)
- SSHs to WSL / peers
- Depends on a live NAS mount or tmux campaign panes
- Would hang or flake when those services are down

Ephemeral `ThreadingHTTPServer(("127.0.0.1", 0), …)` fixtures stay **unit**.

## Fleet mapping

| Repo | Unit | Integration |
|------|------|-------------|
| rag-orchestrator | `tests/` hermetic | Fleet service probes, index panel snap, ops NAS shape |
| rag-dashboard | contract + shell pytest (+ node `.mjs`) | Shell `:8790` + orch provider health |
| domain-rag | pytest offline | Qdrant `:6335` + API `:8794` (mark live tests) |
| autoforge / lds-docs | pytest offline | Live scrape rare — prefer `workflow_dispatch` |
| webui-model-configs | unittest offline | Keep custom `regress.yml` for live OWUI |
| wiki-rag | pytest offline | Qdrant / API as needed |

## Rule

**Nothing in `ci-unit.sh` may require live services.** That keeps push CI green during ops windows (index, NAS rsync, cleanup, reboot).

## CI vs deploy

| Layer | Entry | Restarts LaunchAgents? |
|-------|-------|------------------------|
| Unit / integration | `scripts/ci-*.sh` via Actions | **No** |
| Deploy | `scripts/deploy.sh` on Skynet-MS | **Yes** (this repo’s labels only) |

Green CI does not mean `:8787` / `:8790` / providers are running the new commit. See [DEPLOY.md](DEPLOY.md).
