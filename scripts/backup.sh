#!/usr/bin/env bash
set -Eeuo pipefail

#  ---- config ----
TARGET_DIR="${1:-$HOME/projects/important}"
BACKUP_REPO="$HOME/myworks/backup_folder_daily/"
MACHINE_ID="$(hostname -s)"
EXCLUDES_FILE="$BACKUP_REPO/excludes/common.txt"
RETAIN=7
LOCKFILE="/tmp/backup_git.lock"
LOGDIR="$BACKUP_REPO/../logs"; mkdir -p "$LOGDIR"
mkdir -p "$LOGDIR"

shopt -s nullglob globstar

log() {
	printf "[%(%F %T)T] %s\n" -1 "$*"
}

run_backup() {
  [[ -d "$TARGET_DIR" ]]      || { log "No TARGET_DIR: $TARGET_DIR"; exit 2; }
  [[ -d "$BACKUP_REPO/.git" ]]|| { log "No repo at $BACKUP_REPO"; exit 3; }

  cd "$BACKUP_REPO"

  git fetch --all --prune
  git switch -q main
  git pull --ff-only || true

  ts="$(date +%Y%m%d-%H%M%S)"
  yyyy="$(date +%Y)"
  mm="$(date +%m)"
  daydir="archives/${MACHINE_ID}/${yyyy}/${mm}"
  mkdir -p "$daydir"

  base="$(basename "$TARGET_DIR")"
  out="${daydir}/${base}-${ts}.tar.gz"

  tar_opts=()
  [[ -f "$EXCLUDES_FILE" ]] && tar_opts+=( --exclude-from="$EXCLUDES_FILE" )

  tar -C "$(dirname "$TARGET_DIR")" -czf "$out" "${tar_opts[@]}" "$base"
  sha256sum "$out" > "${out}.sha256"

  # retention
  mapfile -t files < <(ls -1t archives/"$MACHINE_ID"/**/*.tar.gz 2>/dev/null)
  if (( ${#files[@]} > RETAIN )); then
    for f in "${files[@]:RETAIN}"; do
      rm -f "$f" "${f}.sha256" || true
    done
  fi

  git add -A
  if ! git diff --cached --quiet; then
    git commit -m "backup(${MACHINE_ID}): ${base} @ ${ts}"
    git push -q origin main
  fi

  printf "%s  %s\n" "$(date -Is)" "$out" >> "$LOGDIR/backup.log"
}

main() {
  # FD-based flock (no subshell, no function-scope issues)
  exec 9>"$LOCKFILE"
  if ! flock -w 10 9; then
    log "Could not acquire lock $LOCKFILE"; exit 1
  fi
  run_backup
}

main "$@"
