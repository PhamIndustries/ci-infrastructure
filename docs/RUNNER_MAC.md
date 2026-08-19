# Self-hosted Mac runner (per repo)

Personal GitHub: **one runner registration per repository**. Multiple runners can share one machine.

## Labels (fleet standard)

```text
self-hosted, macOS, ARM64, skynet
```

Existing `webui-model-configs` runner used `skynet-ms` historically — add `skynet` when reconfiguring, or keep both.

## Install (example: rag-orchestrator)

```bash
REPO=rag-orchestrator
OWNER=vuudoopham
DIR="$HOME/Projects/actions-runner-${REPO}"
mkdir -p "$DIR" && cd "$DIR"

# Match version used by sibling runners when possible (see actions-runner-webui-model-configs/bin.*)
curl -fsSL -o actions-runner-osx-arm64.tar.gz \
  https://github.com/actions/runner/releases/download/v2.336.0/actions-runner-osx-arm64-2.336.0.tar.gz
tar xzf actions-runner-osx-arm64.tar.gz

# Create a registration token in the browser:
#   https://github.com/${OWNER}/${REPO}/settings/actions/runners/new
# Or via API (admin):
#   gh api -X POST "repos/${OWNER}/${REPO}/actions/runners/registration-token" --jq .token

./config.sh \
  --url "https://github.com/${OWNER}/${REPO}" \
  --token "<REGISTRATION_TOKEN>" \
  --name "skynet-ms-${REPO}" \
  --labels "self-hosted,macOS,ARM64,skynet" \
  --work "_work" \
  --unattended

./svc.sh install
./svc.sh start
./svc.sh status
```

Repeat for `rag-dashboard` (and any other fleet repo).

## Ops

| Task | Command |
|------|---------|
| Status | `cd ~/Projects/actions-runner-<repo> && ./svc.sh status` |
| Stop | `./svc.sh stop` |
| Start | `./svc.sh start` |
| Uninstall | `./svc.sh stop && ./svc.sh uninstall` |

Do **not** commit registration tokens or `.credentials` / `.runner` files.

## Security

- Self-hosted runners must **not** run workflows from **fork PRs** (workflow `if:` guards this).
- Prefer hermetic unit jobs; keep secrets out of logs.
