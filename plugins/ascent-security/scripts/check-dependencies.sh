#!/usr/bin/env bash
# Offline dependency checks: lockfiles, pinning, engine constraints, sources,
# licences and scanner ignore files. Part of the ascent-security plugin
# (dependency-check Step 2). Read-only: never installs, resolves or downloads.
#
# Usage: check-dependencies.sh [--maturity enterprise|standard|prototype] [--pinning exact|minor] [--lockfile-required yes|no] [--registry URL]... [--deny SPDX,...] [--waived ID,...] [--today YYYY-MM-DD] [--include-tests] PATH...
#
# PATH is a directory (or a manifest, lockfile or ignore file). Directories are
# searched for npm (package.json, package-lock.json, npm-shrinkwrap.json,
# yarn.lock, pnpm-lock.yaml, .npmrc, .nvmrc, .node-version), Python
# (pyproject.toml, requirements*.txt, requirements*.in, constraints*.txt,
# Pipfile, Pipfile.lock, poetry.lock, uv.lock, pdm.lock, setup.cfg, setup.py,
# .python-version, runtime.txt), Go (go.mod, go.sum), Cargo (Cargo.toml,
# Cargo.lock) and scanner ignore files (.trivyignore, .trivyignore.yaml,
# osv-scanner.toml, .nsprc, audit-ci.json, audit-ci.jsonc). Skipped:
# node_modules, .git, vendor, dist, build, target, virtualenvs, __pycache__,
# and test code (tests/, test/, __tests__/, fixtures/, spec/) unless
# --include-tests. PATH itself is never skipped, whatever its name. A file named
# on the command line is always read.
#
# Checks (severity from the dependency-check severity table):
#   SEC-D1  Medium  a manifest with dependencies has no lockfile in its directory or
#                   above (go.mod: beside it), or the lockfile there does not cover
#                   it, or git does not track it, where a lockfile is required (not
#                   at prototype)
#   SEC-D2  Low     manifest versions are ranges under --pinning exact, or unbounded
#                   (*, latest, >= with no upper bound) under minor; npm and Python
#   SEC-D3  Medium  the lockfile is out of step with its manifest: a dependency
#                   missing from it, or (npm) recorded with another range
#   SEC-D4  Low     no engine constraint: engines.node, volta.node, .nvmrc or
#                   .node-version (npm); requires-python, python_requires, Poetry's
#                   python, Pipfile [requires], .python-version or runtime.txt (Python)
#   SEC-D5  Medium  a dependency or registry from an unexpected source: git, a URL
#                   tarball, a registry, index or find-links location other than the
#                   public default or a --registry (matched at a host or path
#                   boundary), a Go replace to another module, a Cargo git, registry
#                   or [patch] source or a Cargo.lock source other than crates.io;
#                   High when fetched over plain http://
#   SEC-D6  High    a licence on the --deny list that the SPDX expression leaves no
#                   way around (npm lockfiles carry licences; other lockfiles do
#                   not, which is reported as a NOTE)
#   SEC-D10 Low     a scanner ignore entry with no waiver (--waived), or past its
#                   expiry; a NOTE at prototype; INFO when waived
#
# Output: FAIL lines (FAIL  SEC-Dn  SEVERITY  file:line  message), a PASS line per
# check with no finding, N/A when a check found nothing to check, NOTE lines
# (unrated), INFO lines (waived), then "check-dependencies: ...". Credentials in
# URLs are masked; other .npmrc lines are never read into the output.
# Limits: static and line-based. Lockfiles are read, never resolved; YAML and TOML
# are read for the keys named above only.
# Exit: 0 no FAIL; 1 at least one FAIL; 2 bad input.
# Portable: GNU/Linux and BSD/macOS, bash 3.2+, POSIX awk, run with LC_ALL=C.

set -euo pipefail

usage() { sed -n '6p' "$0" | sed 's/^# //'; }
MATURITY=enterprise; PINNING=exact; LOCKREQ=""; REGS=""; DENY=""; WAIVED=""; TODAY=""; TESTS=0
PATHS=()
need() { [ $# -ge 2 ] && [ -n "$2" ] || { echo "check-dependencies: $1 needs a value" >&2; exit 2; }; }
while [ $# -gt 0 ]; do
  case "$1" in
    --maturity) need "$@"; MATURITY="$2"; shift 2 ;;
    --pinning) need "$@"; PINNING="$2"; shift 2 ;;
    --lockfile-required) need "$@"; LOCKREQ="$2"; shift 2 ;;
    --registry) need "$@"; REGS="$REGS $2"; shift 2 ;;
    --deny) need "$@"; DENY="$DENY,$2"; shift 2 ;;
    --waived) need "$@"; WAIVED="$WAIVED,$2"; shift 2 ;;
    --today) need "$@"; TODAY="$2"; shift 2 ;;
    --include-tests) TESTS=1; shift ;;
    -h|--help) usage; exit 0 ;;
    -*) echo "check-dependencies: unknown option $1" >&2; exit 2 ;;
    *) PATHS+=("$1"); shift ;;
  esac
done
[ ${#PATHS[@]} -gt 0 ] || { usage >&2; exit 2; }
case "$MATURITY" in enterprise|standard|prototype) ;; *) echo "check-dependencies: --maturity must be enterprise, standard or prototype" >&2; exit 2 ;; esac
case "$PINNING" in exact|minor) ;; *) echo "check-dependencies: --pinning must be exact or minor" >&2; exit 2 ;; esac
case "$LOCKREQ" in ''|yes|no) ;; *) echo "check-dependencies: --lockfile-required must be yes or no" >&2; exit 2 ;; esac
[ -n "$LOCKREQ" ] || { [ "$MATURITY" = prototype ] && LOCKREQ=no || LOCKREQ=yes; }
[ -n "$TODAY" ] || TODAY=$(date +%Y-%m-%d)
printf '%s' "$TODAY" | grep -qE '^[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]$' || { echo "check-dependencies: --today must be YYYY-MM-DD" >&2; exit 2; }

ARGS=()
LOCKS=()
add() { local f; case "$2" in /*|./*) f="$2" ;; *) f="./$2" ;; esac; ARGS+=("K=$1" "$f"); case "$1" in npm-lock|yarn-lock|pnpm-lock|py-lock|pipfile-lock|go-sum|cargo-lock) LOCKS+=("$f") ;; esac; }
TRACKED="|"; INGIT="|"
# tracked PATH — record the files git tracks under PATH (one git call per PATH), and
# PATH itself when it is in a work tree; lockfiles outside every such PATH are not judged
tracked() {
  local d="$1" f
  [ -d "$d" ] || d=$(dirname "$d")
  command -v git >/dev/null 2>&1 && git -C "$d" rev-parse --is-inside-work-tree >/dev/null 2>&1 || return 0
  INGIT="$INGIT$d|"
  while IFS= read -r f; do TRACKED="$TRACKED${d%/}/$f|"; done <<EOF_GIT
$(git -C "$d" -c core.quotePath=false ls-files 2>/dev/null || true)
EOF_GIT
}
# ingit FILE — FILE is under a PATH that is in a git work tree
ingit() {
  local g rest="${INGIT#|}"
  while [ -n "$rest" ]; do
    g="${rest%%|*}"; rest="${rest#*|}"
    case "$1" in "$g"/*|"./${g#./}"/*|"$g") return 0 ;; esac
    [ "$g" = . ] && return 0
  done
  return 1
}
classify() {  # FILE EXPLICIT
  local f="$1" b="${1##*/}"
  case "$b" in
    package.json) add npm "$f" ;;
    package-lock.json|npm-shrinkwrap.json) add npm-lock "$f" ;;
    yarn.lock) add yarn-lock "$f" ;;
    pnpm-lock.yaml) add pnpm-lock "$f" ;;
    .npmrc) add npmrc "$f" ;;
    .nvmrc|.node-version) add node-version "$f" ;;
    pyproject.toml) add pyproject "$f" ;;
    requirements*.txt|constraints*.txt) add py-req "$f" ;;
    requirements*.in) add py-in "$f" ;;
    Pipfile) add pipfile "$f" ;;
    Pipfile.lock) add pipfile-lock "$f" ;;
    poetry.lock|uv.lock|pdm.lock) add py-lock "$f" ;;
    setup.cfg|setup.py) add py-setup "$f" ;;
    .python-version|runtime.txt) add python-version "$f" ;;
    go.mod) add go-mod "$f" ;;
    go.sum) add go-sum "$f" ;;
    Cargo.toml) add cargo "$f" ;;
    Cargo.lock) add cargo-lock "$f" ;;
    .trivyignore) add ignore-trivy "$f" ;;
    .trivyignore.yaml|.trivyignore.yml) add ignore-trivy-yaml "$f" ;;
    osv-scanner.toml) add ignore-osv "$f" ;;
    .nsprc|audit-ci.json|audit-ci.jsonc) add ignore-json "$f" ;;
    *) if [ "$2" = 1 ]; then echo "check-dependencies: not a manifest, lockfile or ignore file: $f" >&2; exit 2; fi ;;
  esac
}
NL='
'
for p in "${PATHS[@]}"; do
  while [ "${p%/}" != "$p" ] && [ "$p" != / ]; do p="${p%/}"; done
  if [ -d "$p" ]; then
    if [ "$TESTS" = 1 ]; then SKIP='( -name node_modules -o -name .git -o -name vendor -o -name dist -o -name build -o -name target -o -name .venv -o -name venv -o -name __pycache__ -o -name .tox )'
    else SKIP='( -name node_modules -o -name .git -o -name vendor -o -name dist -o -name build -o -name target -o -name .venv -o -name venv -o -name __pycache__ -o -name .tox -o -name tests -o -name test -o -name __tests__ -o -name fixtures -o -name spec )'; fi
    # -mindepth 1: PATH itself is never pruned, whatever its name. A file name with a
    # newline in it is skipped: it is no manifest name, and it would split in two here.
    while IFS= read -r f; do
      [ -n "$f" ] || continue
      classify "$f" 0
    done <<EOF_FILES
$(# shellcheck disable=SC2086
  find "$p" -mindepth 1 $SKIP -prune -o -type f ! -name "*$NL*" -print 2>/dev/null | LC_ALL=C sort || true)
EOF_FILES
    tracked "$p"
  elif [ -f "$p" ]; then
    classify "$p" 1
    tracked "$p"
  else
    echo "check-dependencies: no such file or directory: $p" >&2; exit 2
  fi
done
[ ${#ARGS[@]} -gt 0 ] || ARGS=("K=none" /dev/null)

# A lockfile git does not track is not a lockfile anyone else gets (SEC-D1).
UNTRACKED=""
if [ "$INGIT" != "|" ] && [ ${#LOCKS[@]} -gt 0 ]; then
  for f in "${LOCKS[@]}"; do
    ingit "$f" || continue
    case "$TRACKED" in *"|$f|"*|*"|${f#./}|"*|*"|./${f#./}|"*) ;; *) UNTRACKED="$UNTRACKED|${f#./}" ;; esac
  done
fi

LIB="$(cd "$(dirname "$0")" && pwd)/lib"
for l in json.awk check-dependencies.awk; do [ -f "$LIB/$l" ] || { echo "check-dependencies: missing $LIB/$l" >&2; exit 2; }; done

LC_ALL=C awk -v MATURITY="$MATURITY" -v PINNING="$PINNING" -v LOCKREQ="$LOCKREQ" -v REGS="$REGS" \
  -v DENY="$DENY" -v WAIVED="$WAIVED" -v TODAY="$TODAY" -v UNTRACKED="$UNTRACKED|" \
  -f "$LIB/json.awk" -f "$LIB/check-dependencies.awk" "${ARGS[@]}"
