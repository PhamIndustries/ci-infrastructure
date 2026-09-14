#!/usr/bin/env bash
# Per-repo backup template. Copy to scripts/backup.sh and fill PRODUCT / payload.
# CI does NOT run this. Fleet cadence is orch flow fleet-backup-window (maintenance).
#
# Usage:
#   bash scripts/backup.sh              # write stamp
#   bash scripts/backup.sh --check      # restore-capable? (LATEST exists + BACKUP.md)
#   bash scripts/backup.sh --dry-run
#   BACKUP_ROOT=/path bash scripts/backup.sh
#
# Default BACKUP_ROOT:
#   NAS  /tmp/KBs-nas/Backups/<product>  when the Project Data share is mounted
#   else $HOME/Backups/<product>
#
# Stamp:
#   $BACKUP_ROOT/<host>/<YYYYMMDD-HHMM>/
#     BACKUP.md  REVERT.md  versions.txt  secrets/  <payload>
#   $BACKUP_ROOT/<host>/LATEST -> <stamp>
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

# --- customize per repo ---
PRODUCT="REPLACE_ME"
# Space-separated relative paths to copy (directories ok). Empty = metadata-only.
PAYLOAD_PATHS=""
# --- end customize ---

NAS_MOUNT="${NAS_MOUNT:-/tmp/KBs-nas}"
NAS_BACKUPS="${NAS_MOUNT}/Backups/${PRODUCT}"

host_tag() {
  local h
  h=$(hostname -s 2>/dev/null || hostname 2>/dev/null || echo unknown)
  printf '%s' "$h" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9._-]/-/g'
}

default_backup_root() {
  if [[ -d "$NAS_MOUNT" && -w "$NAS_MOUNT" ]]; then
    mkdir -p "$NAS_BACKUPS" 2>/dev/null || true
    if [[ -d "$NAS_BACKUPS" && -w "$NAS_BACKUPS" ]]; then
      printf '%s' "$NAS_BACKUPS"
      return 0
    fi
  fi
  printf '%s' "${HOME}/Backups/${PRODUCT}"
}

CHECK=0
DRY=0
for arg in "$@"; do
  case "$arg" in
    --check) CHECK=1 ;;
    --dry-run) DRY=1 ;;
    -h|--help)
      sed -n '2,22p' "$0"
      exit 0
      ;;
    *)
      echo "unknown arg: $arg (use --check --dry-run)" >&2
      exit 2
      ;;
  esac
done

HOST_TAG="${BACKUP_HOSTNAME:-$(host_tag)}"
BACKUP_ROOT="${BACKUP_ROOT:-$(default_backup_root)}"
HOST_DIR="${BACKUP_ROOT}/${HOST_TAG}"
LATEST="${HOST_DIR}/LATEST"

restore_capable() {
  local dir="$1"
  [[ -d "$dir" ]] || return 1
  [[ -f "$dir/BACKUP.md" ]] || return 1
  return 0
}

if [[ "$CHECK" -eq 1 ]]; then
  target=""
  if [[ -L "$LATEST" || -d "$LATEST" ]]; then
    target="$(cd "$LATEST" 2>/dev/null && pwd -P || true)"
  fi
  if [[ -n "$target" ]] && restore_capable "$target"; then
    echo "backup ok: $target"
    exit 0
  fi
  echo "backup MISSING or not restore-capable: $LATEST" >&2
  exit 1
fi

STAMP="$(date +%Y%m%d-%H%M)"
BACKUP_DIR="${HOST_DIR}/${STAMP}"
if [[ -e "$BACKUP_DIR" ]]; then
  STAMP="$(date +%Y%m%d-%H%M%S)"
  BACKUP_DIR="${HOST_DIR}/${STAMP}"
fi

if [[ "$DRY" -eq 1 ]]; then
  echo "dry-run: would write $BACKUP_DIR"
  echo "dry-run: payload: ${PAYLOAD_PATHS:-<none>}"
  exit 0
fi

mkdir -p "$BACKUP_DIR/secrets"
chmod 700 "$HOST_DIR" "$BACKUP_DIR" "$BACKUP_DIR/secrets" 2>/dev/null || true

{
  echo "# ${PRODUCT} backup"
  echo
  echo "- host: ${HOST_TAG}"
  echo "- stamp: ${STAMP}"
  echo "- created: $(date '+%Y-%m-%d %H:%M:%S %Z')"
  echo "- root: ${ROOT}"
  echo "- backup_root: ${BACKUP_ROOT}"
} >"$BACKUP_DIR/BACKUP.md"

{
  echo "Restore:"
  echo "  bash scripts/setup.sh --from-backup ${BACKUP_DIR}"
  echo "  # or copy payload back, then bash scripts/deploy.sh"
} >"$BACKUP_DIR/REVERT.md"

{
  echo "git=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null || echo unknown)"
  echo "host=${HOST_TAG}"
} >"$BACKUP_DIR/versions.txt"

# Copy any local secrets the product keeps next to the repo (gitignored).
if [[ -d "$ROOT/config/secrets" ]]; then
  cp -a "$ROOT/config/secrets/." "$BACKUP_DIR/secrets/" 2>/dev/null || true
fi

for rel in $PAYLOAD_PATHS; do
  src="${ROOT}/${rel}"
  if [[ -e "$src" ]]; then
    mkdir -p "$BACKUP_DIR/$(dirname "$rel")"
    rsync -a --delete "${src%/}" "$BACKUP_DIR/$(dirname "$rel")/"
  else
    echo "warn: missing payload $src" >&2
  fi
done

ln -sfn "$STAMP" "$LATEST"
echo "backup ok: $BACKUP_DIR"
