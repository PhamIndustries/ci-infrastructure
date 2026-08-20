# Self-hosted Mac runner (Skynet-MS)

## Primary model (current): one org runner

Org **PhamIndustries** uses a **single** self-hosted runner for all org repos:

| Field | Value |
|-------|--------|
| Name | `skynet-ms-org-1` |
| Host dir | `~/actions-runners/skynet-ms-org-1` (not under `~/Projects`) |
| Labels | `self-hosted`, `macOS`, `ARM64`, `skynet` |
| LaunchAgent | `actions.runner.PhamIndustries.skynet-ms-org-1` |
| GitHub UI | Org → Settings → Actions → Runners |

**Adopting CI in a new fleet repo:** transfer/create under `PhamIndustries` and add the thin workflow — **do not** install another runner.

### Ops (org runner)

```bash
cd ~/actions-runners/skynet-ms-org-1
./svc.sh status
./svc.sh stop
./svc.sh start
```

Clear stale checkouts when idle:

```bash
rm -rf ~/actions-runners/skynet-ms-org-1/_work/*
```

### Re-register (disaster only)

```bash
ORG=PhamIndustries
DIR="$HOME/actions-runners/skynet-ms-org-1"
VER=2.336.0
# … extract runner tarball if needed …
TOKEN=$(gh api -X POST "orgs/${ORG}/actions/runners/registration-token" --jq .token)
cd "$DIR"
./config.sh \
  --url "https://github.com/${ORG}" \
  --token "$TOKEN" \
  --name "skynet-ms-org-1" \
  --labels "self-hosted,macOS,ARM64,skynet" \
  --work "_work" \
  --unattended \
  --replace
./svc.sh install
./svc.sh start
```

Do **not** commit registration tokens or `.credentials` / `.runner` files.

## Legacy: per-repo runners (emergency / rollback)

Personal GitHub accounts cannot share one repo-scoped runner across repos. Before the org cutover we used `actions-runner-<repo>` per repository. Prefer **not** to recreate these.

If you must (rollback):

```bash
REPO=rag-orchestrator
OWNER=PhamIndustries   # or vuudoopham during rollback
DIR="$HOME/Projects/actions-runner-${REPO}"
# config.sh --url https://github.com/${OWNER}/${REPO} --name skynet-ms-${REPO} ...
```

Historical label `skynet-ms` (webui) is retired; use `skynet`.

## Security

- Self-hosted runners must **not** run workflows from **fork PRs** (reusable workflow `if:` guard).
- Prefer hermetic unit jobs; keep secrets out of logs.
- One Mac: serialize heavy integration / index / rsync when possible.
