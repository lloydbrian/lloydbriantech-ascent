#!/usr/bin/env bash
# Portable helpers for ASCENT skill tests.
#
# Every test sources this file right after its cleanup trap. The helpers give
# one behaviour on GNU/Linux (CI runners, containers, devcontainers) and on
# BSD/macOS, so a test result never depends on the operator's laptop.
#
# Rule of thumb for test authors: never call stat, touch -t/-d, date -d/-j/-v,
# or sed -i directly in a test. Use the helper instead. ADR-008 records why.
#
# Compatible with bash 3.2 (macOS default) and bash 5.

# Fixture repositories must never reach the repository the tests run in. Git
# hooks (pre-commit and friends) export these variables; with them set,
# `git -C fixture …` would write the outer repo's config, HEAD and index.
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_OBJECT_DIRECTORY \
      GIT_ALTERNATE_OBJECT_DIRECTORIES GIT_COMMON_DIR GIT_NAMESPACE GIT_PREFIX

# Return 0 when the coreutils on PATH are GNU, 1 for BSD. Detected once.
ascent_is_gnu() {
  if [ -z "${_ASCENT_GNU:-}" ]; then
    if date --version >/dev/null 2>&1; then _ASCENT_GNU=1; else _ASCENT_GNU=0; fi
  fi
  [ "$_ASCENT_GNU" = "1" ]
}

# file_mtime FILE — modification time as epoch seconds; prints 0 if missing.
file_mtime() {
  local f="$1" out=""
  [ -e "$f" ] || { printf '0'; return 0; }
  if ascent_is_gnu; then
    out=$(stat -c %Y "$f" 2>/dev/null) || out=""
  else
    out=$(stat -f %m "$f" 2>/dev/null) || out=""
  fi
  case "$out" in
    ''|*[!0-9]*) printf '0' ;;
    *) printf '%s' "$out" ;;
  esac
}

# file_age_days FILE — whole days since FILE was last modified.
file_age_days() {
  local m now
  m=$(file_mtime "$1")
  now=$(date +%s)
  printf '%s' $(( (now - m) / 86400 ))
}

# epoch_days_ago N — epoch seconds for N days before now.
epoch_days_ago() {
  printf '%s' $(( $(date +%s) - $1 * 86400 ))
}

# ymd_to_epoch YYYY-MM-DD — epoch seconds at local NOON (noon always exists and
# keeps day arithmetic one DST hour away from a date boundary); 0 if unparseable.
ymd_to_epoch() {
  local out=""
  if ascent_is_gnu; then
    out=$(date -d "$1 12:00:00" +%s 2>/dev/null) || out=""
  else
    out=$(date -j -f "%Y-%m-%d %H:%M:%S" "$1 12:00:00" +%s 2>/dev/null) || out=""
  fi
  case "$out" in ''|*[!0-9]*) printf '0' ;; *) printf '%s' "$out" ;; esac
}

# ymd_days_ago N — calendar date (YYYY-MM-DD) N days before today, computed
# from today's noon so a DST change inside the window cannot shift the date.
ymd_days_ago() {
  local noon ts
  noon=$(ymd_to_epoch "$(date +%Y-%m-%d)")
  ts=$(( noon - $1 * 86400 ))
  if ascent_is_gnu; then date -d "@$ts" +%Y-%m-%d; else date -r "$ts" +%Y-%m-%d; fi
}

# set_mtime_days_ago FILE N — backdate FILE's modification time by N days.
set_mtime_days_ago() {
  local f="$1" ts
  ts=$(epoch_days_ago "$2")
  if ascent_is_gnu; then
    touch -d "@$ts" "$f"
  else
    touch -t "$(date -r "$ts" +%Y%m%d%H%M.%S)" "$f"
  fi
}

# sed_inplace SCRIPT FILE — in-place sed that behaves the same on GNU and BSD.
sed_inplace() {
  local script="$1" f="$2"
  sed -i.ascent-bak -e "$script" "$f" && rm -f "$f.ascent-bak"
}

# count_matches ERE FILE — number of matching lines; 0 (never an error) when
# nothing matches or the file is missing. Safe under `set -euo pipefail`.
count_matches() {
  local n=""
  n=$(grep -cE -- "$1" "$2" 2>/dev/null) || true
  printf '%s' "${n:-0}"
}

# git_init_main DIR — new repository whose default branch is main, with a local
# identity so commits work on CI runners that have no global git config.
git_init_main() {
  local d="$1"
  mkdir -p "$d"
  git -C "$d" init -q
  # Stop before writing anything if git resolved some other repository.
  if [ "$(cd "$d" && git rev-parse --absolute-git-dir)" != "$(cd "$d" && pwd -P)/.git" ]; then
    echo "git_init_main: $d is not its own repository — refusing to continue" >&2
    return 1
  fi
  git -C "$d" symbolic-ref HEAD refs/heads/main
  git -C "$d" config user.email "ascent-tests@example.invalid"
  git -C "$d" config user.name "ASCENT tests"
  git -C "$d" config commit.gpgsign false
  git -C "$d" config core.hooksPath /dev/null
  git -C "$d" config color.ui false
}

# git_commit_days_ago DIR N MESSAGE — commit everything in DIR with both the
# author and committer dates set N days in the past (skills read %ct).
git_commit_days_ago() {
  local d="$1" ts
  ts="$(epoch_days_ago "$2") +0000"
  git -C "$d" add -A
  GIT_AUTHOR_DATE="$ts" GIT_COMMITTER_DATE="$ts" git -C "$d" commit -q -m "$3"
}
