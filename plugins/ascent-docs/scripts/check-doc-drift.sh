#!/usr/bin/env bash
# Checks what a repository's documents name against the repository: paths, make
# targets, package scripts, environment variables, the project's version and the
# pinned runtimes. Part of the ascent-docs plugin (doc-drift Step 1, docs-review
# Step 2). Read-only: it reads the files and git ls-files.
#
# Usage: check-doc-drift.sh [--path P]... [--exclude P]... [--version-file FILE] [--ignore-env NAME]... [--ignore NAME]... [--maturity LEVEL] [--no-git] [REPO]
#
# REPO is the repository root (default "."). The documents checked are chosen as
# check-docs.sh chooses them (--path is docs.paths, --exclude docs.exclude), less
# changelogs and release notes, which name old things on purpose. --version-file
# (docs.version_file) is where the project's version is; by default VERSION, then
# package.json, pyproject.toml, Cargo.toml. --ignore-env (docs.ignore_env) names
# an environment variable the documents may name although the repository does not
# (a CI or platform variable). --ignore (docs.ignore) names a path, make target or
# package script the documents may name although this repository does not have it
# (one that belongs to another project the documents describe).
#
# Checks (severity from the doc-severity table in docs-review):
#   DOC-R1  Medium  a path in inline code whose folder exists names a file or
#                   folder that exists (relative to the root or the document);
#                   a placeholder segment (N, NNN, X) or an example name
#                   (x.sh, whatever.sh, your-file.md) is skipped
#   DOC-R2  Medium  every make target named (inline code, shell blocks) is a
#                   target of the Makefile or a file it includes
#   DOC-R3  Medium  every npm, pnpm, yarn or bun "run" script named is in a
#                   package.json of the repository (workspaces included)
#   DOC-R4  Low     every environment variable named in inline code is in an
#                   .env example or read by a non-Markdown file
#   DOC-R5  Low     every "Version: X.Y.Z" line in a README matches the version
#                   file (other documents state their own version)
#   DOC-R6  Low     every Node.js or Python version stated matches the pin
#                   (.nvmrc, .node-version, engines.node, .python-version); ">= N"
#                   is satisfied by the pin
# At prototype maturity every finding is a NOTE.
#
# Output: FAIL lines (FAIL  DOC-Rk  SEVERITY  file:line  message), a PASS line per
# check with no finding, N/A, NOTE lines, then "check-doc-drift: ...". Limits: it
# checks the names documents use, not that their descriptions are right.
# Exit: 0 no FAIL; 1 at least one FAIL; 2 bad input.
# Portable: GNU/Linux and BSD/macOS, bash 3.2+, POSIX awk, run with LC_ALL=C.

set -euo pipefail
export LC_ALL=C

usage() { sed -n '7p' "$0" | sed 's/^# //'; }
PATHS=(); EXCL=(); VFILE=""; IGN=""; IGNORE=""; MATURITY=enterprise; NOGIT=""; POS=()
need() { [ "$1" -ge 2 ] || { usage >&2; exit 2; }; }
bad() { echo "check-doc-drift: $1" >&2; exit 2; }
relpath() { case "$1" in ''|/*|*..*) bad "$2 is relative to the repository, without ..: '$1'" ;; esac; }
while [ $# -gt 0 ]; do
  case "$1" in
    --path) need $#; relpath "$2" --path; PATHS+=("$2"); shift 2 ;;
    --exclude) need $#; relpath "$2" --exclude; EXCL+=("$2"); shift 2 ;;
    --version-file) need $#; relpath "$2" --version-file; VFILE="$2"; shift 2 ;;
    --ignore-env) need $#; case "$2" in *[!A-Z0-9_]*|'') bad "--ignore-env takes a variable name" ;; esac; IGN="$IGN $2"; shift 2 ;;
    --ignore) need $#; case "$2" in ''|*[!A-Za-z0-9_./:-]*) bad "--ignore takes a path, target or script name" ;; esac; IGNORE="$IGNORE$2
"; shift 2 ;;
    --maturity) need $#; MATURITY="$2"; shift 2 ;;
    --no-git) NOGIT="--no-git given"; shift ;;
    -h|--help) usage; exit 0 ;;
    -*) bad "unknown option $1" ;;
    *) POS+=("$1"); shift ;;
  esac
done
[ ${#POS[@]} -le 1 ] || { usage >&2; exit 2; }
REPO="${POS[0]:-.}"
[ -d "$REPO" ] || bad "not a directory: $REPO"
case "$MATURITY" in enterprise|standard|prototype) ;; *) bad "--maturity must be enterprise, standard or prototype" ;; esac
[ ${#PATHS[@]} -gt 0 ] || PATHS=(README.md CONTRIBUTING.md docs doc)

LIB="$(cd "$(dirname "$0")" && pwd)/lib"
for f in doc-set.sh md-common.awk check-doc-drift.awk; do [ -f "$LIB/$f" ] || bad "missing $LIB/$f"; done
cd "$REPO"
[ -z "$VFILE" ] || [ -f "$VFILE" ] || bad "--version-file $VFILE: no such file"
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
. "$LIB/doc-set.sh"
if [ -z "$NOGIT" ]; then
  if ! command -v git >/dev/null 2>&1 || ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then NOGIT="not a git repository"; fi
fi
doc_files; doc_set
grep -viE '(^|/)(CHANGELOG|CHANGES|HISTORY|RELEASE-NOTES|RELEASES)[^/]*\.md$' "$T/set" > "$T/set.d" || true

# make targets: the Makefile and the files it includes
HAVEMAKE=0; : > "$T/targets"
MK=""; for m in GNUmakefile makefile Makefile; do [ -f "$m" ] && { MK="$m"; break; }; done
if [ -n "$MK" ]; then
  HAVEMAKE=1; MKS=("$MK")
  for inc in $(awk '/^(-|s)?include[ \t]/ { s = $0; sub(/^[^ \t]*[ \t]+/, "", s); gsub(/\)/, "", s)  # $(wildcard make/*.mk): the pattern stays
      n = split(s, w, /[ \t]+/); for (i = 1; i <= n; i++) if (w[i] != "" && w[i] !~ /[$(]/) print w[i] }' "$MK"); do
    for g in $inc; do [ -f "$g" ] && MKS+=("$g"); done
  done
  awk '/^[A-Za-z0-9_.\/-][A-Za-z0-9_.\/ -]*:([^=]|$)/ { t = $0; sub(/:.*$/, "", t); n = split(t, a, /[ \t]+/); for (i = 1; i <= n; i++) if (a[i] != "" && a[i] !~ /^\./) print a[i] }' "${MKS[@]}" | sort -u > "$T/targets"
fi
# package scripts: every package.json in the repository, so workspaces count
HAVEPKG=0; : > "$T/scripts"
grep -E '(^|/)package\.json$' "$T/files" | grep -vE '(^|/)(node_modules|vendor)/' > "$T/pkgs" || true
if [ -s "$T/pkgs" ]; then
  HAVEPKG=1
  while IFS= read -r f; do [ -f "$f" ] && printf '%s\0' "$f"; done < "$T/pkgs" | xargs -0 awk 'FNR == 1 { on = 0 }
       /"scripts"[ \t]*:[ \t]*\{/ && !on { on = 1; sub(/.*"scripts"[ \t]*:[ \t]*\{/, "") }
       on == 1 { s = $0; while (match(s, /"[^"]+"[ \t]*:/)) { k = substr(s, RSTART + 1, RLENGTH - 1); sub(/"[ \t]*:$/, "", k); print k; s = substr(s, RSTART + RLENGTH); sub(/^[ \t]*"([^"\\]|\\.)*"/, "", s) }
            l = $0; gsub(/"([^"\\]|\\.)*"/, "", l); if (index(l, "}")) on = 2 }' | sort -u > "$T/scripts"
fi
# environment variable names the repository defines or reads: every name in a
# non-Markdown file, .env examples and the code alike
{
  grep -vE '\.md$' "$T/files" | while IFS= read -r f; do [ -f "$f" ] && printf '%s\0' "$f"; done \
    | xargs -0 grep -ohIE '[A-Z][A-Z0-9]*(_[A-Z0-9]+)+' 2>/dev/null || true
} | sort -u > "$T/env"
# the project's version and the pinned runtimes
VER=""; VSRC=""
plainver() { head -1 "$1" | sed 's/^[ \t]*[vV]\{0,1\}//; s/[ \t\r]*$//'; }  # "v1.2.0-dev" -> "1.2.0-dev"
jsonver() { awk 'match($0, /"version"[ \t]*:[ \t]*"[^"]+"/) { v = substr($0, RSTART, RLENGTH); sub(/.*:[ \t]*"/, "", v); sub(/"$/, "", v); print v; exit }' "$1"; }
tomlver() { awk -v sec="$2" '/^\[/ { on = ($0 == sec) } on && /^version[ \t]*=/ { v = $0; sub(/^[^"]*"/, "", v); sub(/".*$/, "", v); print v; exit }' "$1"; }
if [ -n "$VFILE" ]; then
  case "$VFILE" in *.json) VER=$(jsonver "$VFILE") ;; *.toml) VER=$(tomlver "$VFILE" '[project]'); [ -n "$VER" ] || VER=$(tomlver "$VFILE" '[package]'); [ -n "$VER" ] || VER=$(tomlver "$VFILE" '[tool.poetry]') ;; *) VER=$(plainver "$VFILE") ;; esac
  VSRC="$VFILE"
elif [ -f VERSION ]; then VER=$(plainver VERSION); VSRC=VERSION
elif [ -f package.json ]; then VER=$(jsonver package.json); VSRC=package.json
elif [ -f pyproject.toml ]; then VER=$(tomlver pyproject.toml '[project]'); [ -n "$VER" ] || VER=$(tomlver pyproject.toml '[tool.poetry]'); VSRC=pyproject.toml
elif [ -f Cargo.toml ]; then VER=$(tomlver Cargo.toml '[package]'); VSRC=Cargo.toml; fi
NODE=""; NSRC=""
for f in .nvmrc .node-version; do
  if [ -z "$NODE" ] && [ -f "$f" ]; then NODE=$(head -1 "$f" | sed 's/^[^0-9]*//; s/[^0-9].*$//'); NSRC="$f"; fi
done
if [ -z "$NODE" ] && [ -f package.json ]; then
  NODE=$(awk '/"engines"/ { on = 1 } on && match($0, /"node"[ \t]*:[ \t]*"[^"]*"/) { v = substr($0, RSTART, RLENGTH); sub(/.*:[ \t]*"/, "", v); sub(/^[^0-9]*/, "", v); sub(/[^0-9].*$/, "", v); print v; exit }' package.json)
  [ -z "$NODE" ] || NSRC="package.json engines.node"
fi
PY=""; PSRC=""
if [ -f .python-version ]; then PY=$(head -1 .python-version | sed 's/^[^0-9]*//' | awk -F. '{ print $1 "." $2 }'); PSRC=.python-version; fi

DOCS=(); while IFS= read -r f; do [ -f "$f" ] && DOCS+=("./$f"); done < "$T/set.d"
DD_MATURITY="$MATURITY" DD_HAVE_MAKE="$HAVEMAKE" DD_HAVE_PKG="$HAVEPKG" DD_VERSION="$VER" DD_VERSION_SRC="$VSRC" \
DD_NODE="$NODE" DD_NODE_SRC="$NSRC" DD_PYTHON="$PY" DD_PYTHON_SRC="$PSRC" DD_IGNORE_ENV="$IGN" DD_IGNORE="$IGNORE" \
DD_FILES="$T/files" DD_TARGETS="$T/targets" DD_SCRIPTS="$T/scripts" DD_ENV="$T/env" \
  awk -f "$LIB/md-common.awk" -f "$LIB/check-doc-drift.awk" "$T/files" "$T/targets" "$T/scripts" "$T/env" ${DOCS[@]+"${DOCS[@]}"}
