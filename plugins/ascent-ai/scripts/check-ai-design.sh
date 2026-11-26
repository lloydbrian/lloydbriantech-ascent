#!/usr/bin/env bash
# Holds one AI application's declarations to its code: the value it must
# show, its models, its autonomy, tools and limits, its prompts, its off switch
# and its fine-tuning. Part of the ascent-ai plugin (ai-design-check Step 1,
# ai-review Step 2), and made to run in a project's own CI at no token cost;
# ascent-governance's check-audit.sh runs it once for each application.
# Read-only: it reads files and never runs a model.
#
# Usage: check-ai-design.sh --app NAME --root DIR --design FILE [--tier-record FILE] [--prompts DIR] [--golden DIR] [--pilot FILE] [--selection FILE] [--fine-tune-runbook FILE] [--env NAME] [--prod-env NAME] [--app-root NAME=ROOT]... [--threshold SEV] [--today YYYY-MM-DD] [REPO]
#
# REPO is the repository root (default "."); every path is relative to it.
# --app is the application's name and --root the folder of its code. --design is
# its AI design record (references/design-record-template.md); --tier-record its
# AI risk-tier record (ascent-governance), which scales every severity: the
# severities below are for tier 3, one level lighter at tier 2, two at tier 1,
# never below Low, except the rules marked fixed; with no record, tier 3.
# --prompts and --golden are its prompts folder and golden set, --pilot its pilot
# result, --selection its model selection record, --fine-tune-runbook its
# fine-tuning runbook. --env is the environment asked about, and --prod-env the
# production one (default prod). Each --app-root is another application of the
# repository: code under a root deeper than --root that belongs to another
# application is not this one's.
#
# Checks (references/ai-rules.md):
#   AI-V1  High     a baseline (metric, value, the date it was measured) and a
#                   target are declared
#   AI-V2  Medium   before a production launch, the pilot result exists and
#                   names the baseline metric
#   AI-M1  Medium   model names appear only in the design record's "defined in"
#                   files (tests, docs, Markdown and comments are not read)
#   AI-M2  Medium   a fallback model is declared and named in a "defined in" file
#   AI-M3  Medium   at tier 3, the model selection record exists
#   AI-A1  High     the autonomy is prompt, workflow or agent and matches the
#                   code: no tool under prompt, no model-driven loop under
#                   prompt or workflow
#   AI-A2  High     every declared tool is defined in the code, and every tool
#                   the code defines is declared
#   AI-A3  Critical every irreversible tool (reversible is not yes) needs a
#                   person's approval and names a "limit enforced in" file that
#                   exists and names the tool (fixed)
#   AI-A4  High     a workflow or an agent declares its most steps, tokens and
#                   seconds; every model call sets an output token limit
#   AI-A5  High     no tool is irreversible while the tier record says tier 1
#                   or 2 (fixed)
#   AI-P1  Medium   every prompt file has a golden test case that names it
#                   (metadata.prompt)
#   AI-K1  High     the off switch's flag is read in the file named
#   AI-F1  High     a fine-tune runbook has a spend cap, a personal-data check
#                   of the dataset and an eval against the golden set
# Tools recognised: OpenAI function tools and @function_tool, Anthropic tools
# (input_schema), LangChain @tool and StructuredTool, Agent SDK tool("name"),
# Vercel AI SDK tool({...}). A model-driven loop is a for or while loop that
# branches on a tool-use stop reason, or an agent framework's own loop
# (create_react_agent, AgentExecutor, Runner.run, stopWhen, maxSteps,
# ClaudeSDKClient, query with a prompt).
#
# Output: FAIL lines (FAIL  AI-Xn  SEVERITY  [app] file[:line]  message), a PASS
# line per rule that passes, N/A lines, then "check-ai-design: [app] N finding(s)".
# Exit: 0 when no finding is at or above --threshold (default High); 1 when one
# is; 2 bad input, with "check-ai-design: <option>: <reason>" first (ADR-030).
# Portable: GNU/Linux and BSD/macOS, bash 3.2+, POSIX awk, run with LC_ALL=C.

set -euo pipefail
export LC_ALL=C

usage() { sed -n '9p' "$0" | sed 's/^# //'; }
bad() { echo "check-ai-design: $1" >&2; usage >&2; exit 2; }
APP=""; ROOT=""; DESIGN=""; TIER=""; PROMPTS=""; GOLDEN=""; PILOT=""; SELECTION=""; FINETUNE=""; ENVNAME=""; PRODENV=prod
THRESHOLD=High; TODAY=""; ROOTS=(); POS=()
need() { [ "$1" -ge 2 ] || bad "$2: needs a value"; }
while [ $# -gt 0 ]; do
  case "$1" in
    --app) need $# "$1"; APP="$2"; shift 2 ;;
    --root) need $# "$1"; ROOT="$2"; shift 2 ;;
    --design) need $# "$1"; DESIGN="$2"; shift 2 ;;
    --tier-record) need $# "$1"; TIER="$2"; shift 2 ;;
    --prompts) need $# "$1"; PROMPTS="$2"; shift 2 ;;
    --golden) need $# "$1"; GOLDEN="$2"; shift 2 ;;
    --pilot) need $# "$1"; PILOT="$2"; shift 2 ;;
    --selection) need $# "$1"; SELECTION="$2"; shift 2 ;;
    --fine-tune-runbook) need $# "$1"; FINETUNE="$2"; shift 2 ;;
    --env) need $# "$1"; ENVNAME="$2"; shift 2 ;;
    --prod-env) need $# "$1"; PRODENV="$2"; shift 2 ;;
    --app-root) need $# "$1"; ROOTS+=("$2"); shift 2 ;;
    --threshold) need $# "$1"; THRESHOLD="$2"; shift 2 ;;
    --today) need $# "$1"; TODAY="$2"; shift 2 ;;
    -h|--help) usage; awk 'NR > 9 && /^#/ { sub(/^# ?/, ""); print; next } NR > 9 { exit }' "$0"; exit 0 ;;
    --) shift; while [ $# -gt 0 ]; do POS+=("$1"); shift; done ;;
    -*) bad "$1: unknown option" ;;
    *) POS+=("$1"); shift ;;
  esac
done
[ -n "$APP" ] || bad "--app: required"
printf '%s\n' "$APP" | grep -Eq '^[A-Za-z0-9][A-Za-z0-9_-]*$' || bad "--app: the name '$APP' is not letters, digits, - and _"
[ -n "$ROOT" ] || bad "--root: required"
[ -n "$DESIGN" ] || bad "--design: required"
case "$THRESHOLD" in Critical|High|Medium|Low) ;; *) bad "--threshold: expected Critical, High, Medium or Low, got $THRESHOLD" ;; esac
[ "${#POS[@]}" -le 1 ] || bad "${POS[1]}: one REPO only"
REPO="${POS[0]:-.}"
[ -d "$REPO" ] || bad "$REPO: not a directory"
HERE="$(cd "$(dirname "$0")" && pwd)"; LIB="$HERE/lib"
for f in common.awk record.awk design.awk; do [ -f "$LIB/$f" ] || bad "$LIB/$f: missing"; done
cd "$REPO"
[ -n "$TODAY" ] || TODAY=$(date +%Y-%m-%d)
printf '%s\n' "$TODAY" | awk '{ if ($0 !~ /^[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]$/) exit 1
  y = substr($0, 1, 4) + 0; m = substr($0, 6, 2) + 0; d = substr($0, 9, 2) + 0
  n = (m == 2) ? ((y % 4 == 0 && y % 100 != 0) || y % 400 == 0 ? 29 : 28) : ((m == 4 || m == 6 || m == 9 || m == 11) ? 30 : 31)
  exit !(m >= 1 && m <= 12 && d >= 1 && d <= n) }' || bad "--today: $TODAY is not a real date (YYYY-MM-DD)"
norm() { local r="$1"; while case "$r" in ./*) true ;; *) false ;; esac; do r="${r#./}"; done; while [ "${r%/}" != "$r" ]; do r="${r%/}"; done; printf '%s' "${r:-.}"; }
inside() { case "/$1/" in */../*) return 1 ;; esac; case "$1" in /*) return 1 ;; esac; return 0; }
ROOT=$(norm "$ROOT"); inside "$ROOT" || bad "--root: $ROOT is not inside the repository"
[ -d "$ROOT" ] || bad "--root: $ROOT is not a directory"
OTHERS=""
for a in ${ROOTS[@]+"${ROOTS[@]}"}; do
  case "$a" in *=?*) ;; *) bad "--app-root: expected NAME=ROOT, got $a" ;; esac
  OTHERS="$OTHERS${a%%=*}=$(norm "${a#*=}");"
done

T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT INT TERM
# test data is not the application (detect-ai skips it the same way)
PRUNE=( \( -name node_modules -o -name .venv -o -name venv -o -name .git -o -name dist -o -name build -o -name fixtures -o -name testdata -o -name __fixtures__ \) -prune )
# the code of the application: source files under its root, outside tests and docs
find "$ROOT" "${PRUNE[@]}" -o -type f \( -name '*.py' -o -name '*.ts' -o -name '*.tsx' -o -name '*.js' -o -name '*.jsx' -o -name '*.mjs' -o -name '*.cjs' \) -print \
  | sed 's|^\./||' | awk '{ p = "/" $0 "/"; b = $0; sub(/^.*\//, "", b)
      if (p ~ /\/(tests?|__tests__|docs|spec)\//) next
      if (b ~ /^test_.*\.py$/ || b ~ /_test\.py$/ || b ~ /\.(test|spec)\.[a-z]+$/) next
      print }' | sort > "$T/code"
: > "$T/prompts"; : > "$T/golden"
if [ -n "$PROMPTS" ] && [ -d "$PROMPTS" ]; then find "$PROMPTS" -type f ! -name '.*' -print | sed 's|^\./||' | sort > "$T/prompts"; fi
if [ -n "$GOLDEN" ] && [ -d "$GOLDEN" ]; then find "$GOLDEN" -type f \( -name '*.yaml' -o -name '*.yml' -o -name '*.json' -o -name '*.jsonl' \) -print | sed 's|^\./||' | sort > "$T/golden"; fi

awk -v app="$APP" -v root="$ROOT" -v others="$OTHERS" -v design="$DESIGN" -v tierfile="$TIER" \
  -v promptsdir="$PROMPTS" -v goldendir="$GOLDEN" -v pilot="$PILOT" -v selection="$SELECTION" -v finetune="$FINETUNE" \
  -v envname="$ENVNAME" -v prodenv="$PRODENV" -v threshold="$THRESHOLD" -v today="$TODAY" \
  -v promptlist="$T/prompts" -v goldenlist="$T/golden" -v promptsok="$([ -n "$PROMPTS" ] && [ -d "$PROMPTS" ] && echo 1 || echo 0)" \
  -f "$LIB/common.awk" -f "$LIB/record.awk" -f "$LIB/design.awk" "$T/code"
