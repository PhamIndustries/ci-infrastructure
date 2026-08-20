# Per-repo deploy (restart services)

**CI ≠ CD.** GitHub Actions on `skynet-ms-org-1` validates code; it does **not** reload LaunchAgents. Skynet product processes run from `~/Projects/<repo>` checkouts. After merging code that a live service imports, that repo must **deploy** — usually `git pull` (if needed) + restart its LaunchAgent(s) + health probe.

## Contract

| Piece | Standard |
|-------|----------|
| Entry | `scripts/deploy.sh` in **each** fleet repo that owns a LaunchAgent |
| Who runs it | Human or agent on Skynet-MS — **not** the CI workflow |
| What it does | Restart **this repo’s** services so they load the current checkout |
| What it must not do | Restart unrelated fleet services; push; amend; register runners |

## Ownership (who restarts what)

| Repo | LaunchAgent label(s) | Typical health probe |
|------|----------------------|----------------------|
| **rag-orchestrator** | `com.skynet.rag-orch` | `http://127.0.0.1:8787/provider/v1/health` |
| **rag-dashboard** | `com.skynet.rag-dash-shell` | `http://127.0.0.1:8790/health` |
| **domain-rag** | `com.skynet.domain-rag` (+ qdrant / provider if that change needs them) | `http://127.0.0.1:8794/health` |
| **autoforge** | `com.skynet.autoforge-provider` | `http://127.0.0.1:8791/v1/health` |
| **lds-docs-scraper** | `com.skynet.lds-docs-provider` | `http://127.0.0.1:8792/v1/health` |
| **wiki-rag** | `com.skynet.wiki-rag` (+ wiki qdrant if needed) | repo health URL |
| **ollama-webui** / webui stack | `com.skynet.open-webui` (Ollama app/agent separate) | `http://127.0.0.1:8080/` |

Provider **plist wrappers** may live under `rag-orchestrator/deploy/macos/skynet-ms/` for install convenience; **runtime ownership** still follows the product repo. Product code change → product `deploy.sh`. Orch wrapper-only change → orch deploy (optional `--with-providers`) or re-run `install-launchagents.sh`.

## Required shape of `scripts/deploy.sh`

Copy [examples/deploy.sh](../examples/deploy.sh) and fill in labels + probes.

```bash
bash scripts/deploy.sh              # restart + health (current checkout)
bash scripts/deploy.sh --pull       # git pull --ff-only then restart
bash scripts/deploy.sh --sync       # uv sync (if deps changed) then restart
bash scripts/deploy.sh --dry-run    # print actions only
```

Minimum behavior:

1. `cd` to repo root.
2. Optional `--pull` → `git pull --ff-only` (fail closed on divergence).
3. Optional `--sync` → `uv sync` (or the repo’s documented dep install).
4. `launchctl kickstart -k "gui/$(id -u)/<label>"` for each owned label (or bootout/bootstrap if not loaded).
5. Retry health curl until OK or timeout; **exit non-zero** on failure.
6. Print a one-line summary (labels + HTTP codes).

## Do / don’t

| Do | Don’t |
|----|--------|
| Own only this repo’s services | Kickstart the whole Skynet fleet from one script |
| Fail closed on health timeout | Assume `git push` green means processes reloaded |
| Document labels + ports in the script header | Put secrets or PAT minting in deploy |
| Keep deploy **local / manual** | Wire `deploy.sh` into default `ci.yml` |

## Agent rule

After merging or pulling changes that affect a running service in **this** repo: run `bash scripts/deploy.sh` (with `--pull` / `--sync` as needed) **before** claiming the host is on the new code. CI green alone is not enough.

## Reference implementations

- Orch: `PhamIndustries/rag-orchestrator` → `scripts/deploy.sh`
- Dash: `PhamIndustries/rag-dashboard` → `scripts/deploy.sh`
- Host install / bulk boot: `rag-orchestrator/deploy/macos/skynet-ms/install-launchagents.sh` (ops, not per-repo deploy)

## Related

- CI adopt: [AGENT_CI.md](AGENT_CI.md) · [REPO_CI.md](REPO_CI.md)
- Boot services map: `rag-orchestrator/deploy/macos/skynet-ms/README.md`
