# Fleet backup standard

**Hybrid ownership.** Each product repo owns **what** to copy (`scripts/backup.sh`).  
Orch owns **when**: scheduled flow `fleet-backup-window` — a **maintenance window** (stop → backup → start → validate). Do not hot-backup live SQLite/Qdrant as the SoT path.

Copy [examples/backup.sh](../examples/backup.sh) into `scripts/backup.sh` and set `PRODUCT` + `PAYLOAD_PATHS`.

## Stamp layout

```text
$BACKUP_ROOT/<host>/<YYYYMMDD-HHMM>/
  BACKUP.md
  REVERT.md
  versions.txt
  secrets/          # mode 700
  <payload>
$BACKUP_ROOT/<host>/LATEST -> <stamp>
```

**Default `BACKUP_ROOT`:** NAS `/tmp/KBs-nas/Backups/<product>` when the Project Data share is mounted and writable; else `$HOME/Backups/<product>`.  
Do not invent a second NAS tree. Share is `//PhamilyFiles.local/Project Data` (`Backups/<product>/<host>/`).

```bash
bash scripts/backup.sh              # write stamp
bash scripts/backup.sh --check      # LATEST restore-capable? (BACKUP.md present)
bash scripts/backup.sh --dry-run
# restore (product-specific):
bash scripts/setup.sh --from-backup "$BACKUP_ROOT/<host>/LATEST"
```

`--check` must exit **non-zero** when LATEST is missing or not restore-capable. The fleet window fails closed on any required dataset.

## Maintenance window (orch)

Flow preset **`fleet-backup-window`** (Running Flows):

1. **Preflight** — NAS mount; snapshot fleet health.
2. **Quiesce** — stop product LaunchAgents in documented order (providers → APIs → Qdrants → Open WebUI last if backing `webui.db`). Keep NAS mount + Spotlight. Do **not** stop the org Actions runner.
3. **Backup** — each in-scope `scripts/backup.sh`.
4. **`--check`** — required datasets must be restore-capable.
5. **Start** — reverse order via each repo’s `scripts/deploy.sh` / kickstart.
6. **Validate** — `verify-skynet-boot-services.sh` plus provider `/v1/health` for every registered dashboard provider.

CI does **not** run backups. Time Machine is not the fleet plan.

## Who backs up what

| Dataset | Owner | Notes |
|---------|-------|-------|
| Autoforge `data/` + DBs | autoforge `backup.sh` | NAS default |
| LDS `data/` + `scraper_state.db` | lds-docs-scraper `backup.sh` | NAS default |
| Open WebUI `data/` (`webui.db`) | ollama-webui `backup.sh` | NAS default; huge — keep 2 stamps |
| Domain corpus | orch `mirror-gen` | already hard-fail + twin guard; window only `--check` |
| Domain pin | domain-rag `backup.sh` | restore = pin + reindex from corpus |
| wiki-rag index | wiki-rag `backup.sh` | official restore may be HF re-download |
| photo-search catalog/Qdrant/thumbs | photo-search `backup.sh` | originals already on NAS |
| medical-rag shelves + Qdrant | medical-rag `backup.sh` | same class as domain-rag |
| Orch secrets | `backup-secrets.sh` | include in window |
| Orch control DBs | orch `backup.sh` | sqlite `.backup` of `control.db` / `flows.db` / `rag_state.db` + `flow_schedules.json` |
| webui-model-configs | n/a | lives in OWUI `webui.db` |

Retention: 3 stamps per product (OWUI: 2).

## WSL — retired

Do **not** write `Backups/ollama-webui/<wsl-host>/` or any WSL restore path. The WSL product stack is removed. Windows 5090 remains a **native** token factory, not WSL.

## Do / don’t

| Do | Don’t |
|----|--------|
| Quiesce before SQLite/Qdrant copy | Treat a live `cp webui.db` as restore-capable |
| Fail the window if `--check` fails | Soft-fail required datasets |
| Keep secrets mode 700 | Commit backup stamps |
| Document restore in `REVERT.md` | Central script hard-coding every product path |
