#!/usr/bin/env bash
# Finds the AI applications of a repository: the code that calls a model, the
# vector stores and gateways, and which declared application each piece of AI
# code belongs to. Part of the ascent-ai plugin (every ascent-ai skill's first
# step, and ascent-governance's GOV-A1); read-only.
#
# Usage: detect-ai.sh [--app NAME=ROOT]... [REPO]
#
# REPO is the repository root (default "."). Each --app is an AI application the
# contract declares (ai.applications: its name and root folder). Prints one
# tab-separated line per finding, sorted:
#   ai<TAB>PATH<TAB>SIGNAL[<TAB>APP]  AI code: SIGNAL is sdk:<name> (a model SDK
#            imported, or listed in pyproject.toml, requirements*.txt or
#            package.json), prompts-dir (a prompts/ folder that holds a file that is not code), evals-dir (a
#            tests/evals/ folder) or contract (an ai: section in
#            .ascent/contract.yml or .claude/contract.yml). With --app, APP is the
#            application whose root holds PATH; when roots nest, the deepest wins
#   retrieval<TAB>PATH<TAB>PACKAGE   a vector store (chromadb, lancedb, pgvector,
#            qdrant-client, pinecone, weaviate-client, faiss)
#   gateway<TAB>PATH<TAB>litellm|portkey   a model gateway's configuration or SDK
#   app<TAB>NAME<TAB>ROOT   each --app; with none, the whole repository is one application, named
#            after the origin remote's repository (else its folder), with characters other than
#            letters, digits, - and _ turned into -, when any AI code is found
#   orphan<TAB>PATH   AI code under no declared application's root (with --app). A manifest, test
#            code, a prompts or an evals folder outside every root is not one: it belongs to the one
#            application under the nearest folder above it that holds a root, and to none (no APP)
#            when several applications share that folder
# Retrieval alone is not an AI application: a vector store with no model SDK
# prints retrieval lines and no app line, unless the contract has an ai: section.
# Never read: node_modules, .venv, venv, .git, dist, build, and test data (fixtures, testdata, __fixtures__).
#
# Exit: 0 (whatever it finds); 2 bad input, with "detect-ai: <option>: <reason>"
# first. Portable: GNU/Linux and BSD/macOS, bash 3.2+, POSIX awk, run with LC_ALL=C.

set -euo pipefail
export LC_ALL=C

usage() { sed -n '7p' "$0" | sed 's/^# //'; }
bad() { echo "detect-ai: $1" >&2; usage >&2; exit 2; }
APPS=(); POS=()
while [ $# -gt 0 ]; do
  case "$1" in
    --app) [ $# -ge 2 ] || bad "--app: needs NAME=ROOT"; APPS+=("$2"); shift 2 ;;
    -h|--help) usage; awk 'NR > 7 && /^#/ { sub(/^# ?/, ""); print; next } NR > 7 { exit }' "$0"; exit 0 ;;
    --) shift; while [ $# -gt 0 ]; do POS+=("$1"); shift; done ;;
    -*) bad "$1: unknown option" ;;
    *) POS+=("$1"); shift ;;
  esac
done
[ "${#POS[@]}" -le 1 ] || bad "${POS[1]}: one REPO only"
REPO="${POS[0]:-.}"
[ -d "$REPO" ] || bad "$REPO: not a directory"
HERE="$(cd "$(dirname "$0")" && pwd)"; LIB="$HERE/lib"
[ -f "$LIB/detect.awk" ] || bad "$LIB/detect.awk: missing"
REPO="$(cd "$REPO" && pwd)"
TAB="$(printf '\t')"

# the implicit application's name: the origin remote's repository name when REPO is a git checkout's top folder
# (a clone under another folder name keeps it), else the folder's; characters the checkers refuse become "-"
NAME=""
if command -v git >/dev/null 2>&1; then
  TOP=$(git -C "$REPO" rev-parse --show-toplevel 2>/dev/null || true)
  if [ -n "$TOP" ] && [ "$(cd "$TOP" && pwd -P)" = "$(cd "$REPO" && pwd -P)" ]; then
    U=$(git -C "$REPO" config --get remote.origin.url 2>/dev/null || true)
    U="${U%/}"; U="${U%.git}"; U="${U##*/}"; NAME="${U##*:}"
  fi
fi
[ -n "$NAME" ] || NAME=$(basename "$REPO")
NAME=$(printf '%s' "$NAME" | sed 's/[^A-Za-z0-9_-]/-/g; s/^[^A-Za-z0-9]*//')
[ -n "$NAME" ] || NAME=app

T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT INT TERM
: > "$T/apps"
for a in ${APPS[@]+"${APPS[@]}"}; do
  case "$a" in *=?*) ;; *) bad "--app: expected NAME=ROOT, got $a" ;; esac
  n="${a%%=*}"; r="${a#*=}"
  printf '%s\n' "$n" | grep -Eq '^[A-Za-z0-9][A-Za-z0-9_-]*$' || bad "--app: the name '$n' is not letters, digits, - and _"
  while case "$r" in ./*) true ;; *) false ;; esac; do r="${r#./}"; done
  while [ "${r%/}" != "$r" ]; do r="${r%/}"; done
  [ -n "$r" ] || r=.
  case "/$r/" in /*/../*|*/../*) bad "--app: the root $r is not inside the repository" ;; esac
  case "$r" in /*) bad "--app: the root $r is not inside the repository" ;; esac
  printf '%s\t%s\n' "$n" "$r" >> "$T/apps"
done

cd "$REPO"
# test data is not an application: fixtures/, testdata/ and __fixtures__/ are skipped like dependencies
PRUNE=( \( -name node_modules -o -name .venv -o -name venv -o -name .git -o -name dist -o -name build -o -name fixtures -o -name testdata -o -name __fixtures__ \) -prune )
find . "${PRUNE[@]}" -o -type f \( -name '*.py' -o -name '*.ts' -o -name '*.tsx' -o -name '*.js' -o -name '*.jsx' -o -name '*.mjs' -o -name '*.cjs' \
  -o -name pyproject.toml -o -name 'requirements*.txt' -o -name package.json -o -name '*.yaml' -o -name '*.yml' \) -print0 > "$T/files"
: > "$T/found"
[ -s "$T/files" ] && xargs -0 awk -f "$LIB/detect.awk" < "$T/files" >> "$T/found"
# a prompts/ folder counts when it holds a file that is not code: a folder of question modules (inquirer) is not a model's prompts
find . "${PRUNE[@]}" -o -type d -name prompts -print | sed 's|^\./||' | while IFS= read -r d; do
  [ -n "$(find "$d" -type f ! \( -name '*.py' -o -name '*.ts' -o -name '*.tsx' -o -name '*.js' -o -name '*.jsx' -o -name '*.mjs' -o -name '*.cjs' \) -print | head -1)" ] && printf 'ai\t%s\tprompts-dir\n' "$d"
done >> "$T/found"
find . "${PRUNE[@]}" -o -type d -name evals -print | sed 's|^\./||' | awk '$0 == "tests/evals" || $0 ~ /\/tests\/evals$/' | while IFS= read -r d; do printf 'ai\t%s\tevals-dir\n' "$d"; done >> "$T/found"
for c in .ascent/contract.yml .claude/contract.yml; do
  if [ -f "$c" ] && grep -q '^ai:' "$c"; then printf 'ai\t%s\tcontract\n' "$c" >> "$T/found"; fi
done

# which application each piece of AI code belongs to: the deepest root that holds it
awk -F '\t' -v repo="$NAME" '
  FILENAME == ARGV[1] { NA++; AN[NA] = $1; AR[NA] = $2; next }
  { L[++NL] = $0; K[NL] = $1; P[NL] = $2; if ($1 == "ai") AI = 1 }
  function owner(p,   i, best, bl, r) {
    best = ""; bl = -1
    for (i = 1; i <= NA; i++) {
      r = AR[i]
      if (r == "." || p == r || index(p, r "/") == 1) { if (length(r) > bl || (r == "." && bl < 0)) { best = AN[i]; bl = (r == "." ? 0 : length(r)) } }
    }
    return best
  }
  # a manifest, test code, a prompts or an evals folder outside every root supports the applications below it: it
  # belongs to the one application under the nearest folder above it that holds a root, and is not an orphan when
  # several share that folder ("*")
  function support(p, sig,   b) {
    if (sig == "prompts-dir" || sig == "evals-dir") return 1
    b = p; sub(/.*\//, "", b)
    if (b == "pyproject.toml" || b == "package.json" || b ~ /^requirements.*\.txt$/) return 1
    if (("/" p) ~ /\/(tests?|__tests__|spec)\//) return 1
    return (b ~ /^test_.*\.py$/ || b ~ /_test\.py$/ || b ~ /\.(test|spec)\.[A-Za-z]+$/ || b == "conftest.py")
  }
  function near(p,   d, i, n, who) {
    d = p
    while (d != ".") {
      if (index(d, "/") == 0) d = "."; else sub(/\/[^\/]*$/, "", d)
      n = 0; who = ""
      for (i = 1; i <= NA; i++) if (d == "." || index(AR[i], d "/") == 1) { n++; who = AN[i] }
      if (n == 1) return who
      if (n > 1) return "*"
    }
    return ""
  }
  END {
    for (i = 1; i <= NL; i++) {
      if (K[i] == "ai" && NA > 0) {
        split(L[i], F, "\t")
        if (F[3] == "contract") { print L[i]; continue }
        o = owner(P[i])
        if (o == "" && support(P[i], F[3])) { o = near(P[i]); if (o == "*") { print L[i]; continue } }
        if (o == "") { print L[i]; ORPH[P[i]] = 1 } else print L[i] "\t" o
      } else print L[i]
    }
    if (NA > 0) for (i = 1; i <= NA; i++) printf "app\t%s\t%s\n", AN[i], AR[i]
    else if (AI) printf "app\t%s\t.\n", repo
    for (p in ORPH) printf "orphan\t%s\n", p
  }' "$T/apps" "$T/found" | sort -u
