#!/usr/bin/env bash
# Rule test for the ascent-security security-test and threat-model skills, their
# three scripts and the security-auditor agent's checks 9 and 10 (ADR-026):
#   R1  every $PLUGIN_ROOT/<path> the skills name exists
#   R2  every id a script header rates is in the live-severity table, at a severity
#       that table gives it, and every SEC-L and SEC-T id is in the table
#   R3  the rules reference and the script headers cover SEC-L1–L10 and SEC-T1–T4
#   R4  run-live-checks.sh sends no credential (no -u, --user, Authorization,
#       Cookie or token option), refuses non-loopback targets inside Claude Code,
#       refuses production without --allow-prod, and gates writes and AI calls
#   R5  the scanner images are pinned to a version, the same in the skill and the
#       README, and never :latest
#   R6  the skills keep Claude from running live checks and from reviewing the
#       threat model in a person's name
#   R7  every security.endpoints, security.live and security.threat_model key in
#       the contract template is named in the security-test skill
#   R8  the agent rates live findings only from committed results, with the live
#       table, and cites existing steps
#   R9  the three scripts parse and print usage under the system /bin/bash
#
# Prints "test-live-rules: N/N PASS" last (make/test-plugins.sh T11 requires it).
# Portable: bash 3.2+, GNU/Linux and BSD/macOS.

set -u
WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT INT TERM

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$HERE/../../.."
PLUGIN="$ROOT/plugins/ascent-security"
ST="$PLUGIN/skills/security-test/SKILL.md"
TM="$PLUGIN/skills/threat-model/SKILL.md"
AGENT="$PLUGIN/agents/security-auditor.md"
RULES="$PLUGIN/references/live-rules.md"
CT="$PLUGIN/references/contract-template.yml"
README="$PLUGIN/README.md"
RUN="$PLUGIN/scripts/run-live-checks.sh"
CLR="$PLUGIN/scripts/check-live-results.sh"
CTM="$PLUGIN/scripts/check-threat-model.sh"
for f in "$ST" "$TM" "$AGENT" "$RULES" "$CT" "$README" "$RUN" "$CLR" "$CTM"; do
  [ -f "$f" ] || { echo "test-live-rules: missing $f"; echo "test-live-rules: 0/1 PASS"; exit 1; }
done

PASS=0; FAIL=0
ok()  { PASS=$((PASS + 1)); }
bad() { FAIL=$((FAIL + 1)); printf "FAIL  %s\n" "$1"; }
has()   { if grep -qF -- "$2" "$1"; then ok; else bad "${1#"$ROOT"/} lacks: $2"; fi; }
lacks() { if grep -qF -- "$2" "$1"; then bad "${1#"$ROOT"/} must not contain: $2"; else ok; fi; }
TABLE=$(awk 'index($0, "<!-- live-severity:start") {on=1; next} index($0, "<!-- live-severity:end") {on=0} on' "$ST")

# R1 — named plugin paths exist
for s in "$ST" "$TM"; do
  for p in $(grep -oE '\$PLUGIN_ROOT/[A-Za-z0-9_./-]+' "$s" | sed 's/^\$PLUGIN_ROOT\///' | sort -u); do
    if [ -e "$PLUGIN/$p" ]; then ok; else bad "R1 ${s#"$ROOT"/} names \$PLUGIN_ROOT/$p, which does not exist"; fi
  done
done

# R2 — header severities agree with the table, and the table covers every id
for s in "$CLR" "$CTM"; do
  grep -E '^#   SEC-[LT][0-9]+ +(High|Medium|Low) ' "$s" | while read -r _ id sev _; do
    if printf '%s\n' "$TABLE" | grep -E "\| $sev \|$" | grep -qE "\($id[,)]|\($id\)|$id\)"; then echo ok; else echo "bad R2 ${s##*/}: $id is $sev in the header, but no $sev row of the live-severity table names it"; fi
  done
done > "$WORK/r2" 2>&1
while read -r l; do case "$l" in ok) ok ;; *) bad "${l#bad }" ;; esac; done < "$WORK/r2"
for n in 1 2 3 4 5 6 7 8 9 10; do printf '%s\n' "$TABLE" | grep -q "SEC-L$n[,)]" && ok || bad "R2 the live-severity table names no SEC-L$n"; done
for n in 1 2 3 4; do printf '%s\n' "$TABLE" | grep -q "SEC-T$n)" && ok || bad "R2 the live-severity table names no SEC-T$n"; done

# R3 — every rule documented
for n in 1 2 3 4 5 6 7 8 9 10; do
  grep -q "^| SEC-L$n |" "$RULES" && ok || bad "R3 live-rules.md has no row for SEC-L$n"
  grep -q "^#   SEC-L$n " "$CLR" && ok || bad "R3 check-live-results.sh header has no SEC-L$n"
done
for n in 1 2 3 4; do
  grep -q "^| SEC-T$n |" "$RULES" && ok || bad "R3 live-rules.md has no row for SEC-T$n"
  grep -q "^#   SEC-T$n " "$CTM" && ok || bad "R3 check-threat-model.sh header has no SEC-T$n"
done

# R4 — the live script's guards
if grep -nE -- '(^|[^A-Za-z-])(-u|--user|--oauth2-bearer|--cookie|-b) |Authorization:|Cookie:|X-Api-Key' "$RUN" | grep -v '^ *[0-9]*:#' >/dev/null; then bad "R4 run-live-checks.sh sends a credential option"; else ok; fi
has "$RUN" 'if [ -n "${CLAUDECODE:-}" ] && [ "$LOOP" = 0 ]; then'
has "$RUN" '[ "$PROD" = 0 ] || [ "$ALLOWPROD" = 1 ] || bad'
has "$RUN" 'case "$auth" in *@*) bad'
has "$RUN" 'if [ "$WRITES" = 1 ]; then'
has "$RUN" 'if [ "$AI" = 1 ] && [ -s "$WORK/ailist" ]; then'
has "$RUN" '--path-as-is'
if grep -n 'cat "$WORK/body"\|>> "$OUT"' "$RUN" >/dev/null; then bad "R4 run-live-checks.sh must never write a response body to the results"; else ok; fi

# R5 — pinned scanner images, the same everywhere
for img in zaproxy/zap-stable projectdiscovery/nuclei hahwul/dalfox; do
  sv=$(grep -oE "$img:[A-Za-z0-9._-]+" "$ST" | sort -u); rv=$(grep -oE "$img:[A-Za-z0-9._-]+" "$README" | sort -u)
  if [ -z "$sv" ]; then bad "R5 security-test names no $img image"
  elif [ "$(printf '%s\n' "$sv" | wc -l | tr -d ' ')" != 1 ]; then bad "R5 security-test names $img at two versions: $(printf '%s' "$sv" | tr '\n' ' ')"
  elif [ "$sv" != "$rv" ]; then bad "R5 $img is $sv in the skill and ${rv:-absent} in the README"
  elif printf '%s' "$sv" | grep -qE ':(latest|stable|v?[0-9]+)$'; then bad "R5 $sv is not pinned to a release"
  else ok; fi
done
if grep -nE ':latest\b' "$ST" "$TM" "$README" "$RULES" >/dev/null; then bad "R5 a :latest image tag in the security-test files"; else ok; fi

# R6 — Claude never runs the live checks, never reviews in a person's name
has "$ST" 'Claude never runs `run-live-checks.sh`, ZAP, nuclei or dalfox against a target'
has "$ST" 'Never sends a request to anything but the test fixture on 127.0.0.1.'
has "$ST" 'Claude never commits them.'
has "$TM" 'Never fill in `reviewed_on` or `reviewed_by`'
has "$TM" 'This skill writes `security.threat_model.path` (default `docs/security/THREAT-MODEL.md`) and nothing else'
has "$TM" 'never write it.'

# R7 — contract keys named in the skill
for k in endpoints targets allow_prod results_dir max_age_days max_body_bytes scan_threshold threat_model; do
  grep -qE "^ *$k:" "$CT" || { bad "R7 the contract template has no $k key"; continue; }
  has "$ST" "\`$k\`"
done
for k in path review_max_age_days; do grep -qE "^ *$k:" "$CT" && ok || bad "R7 the contract template has no threat_model.$k"; done
has "$TM" '`review_max_age_days`'

# R8 — the agent
has "$AGENT" '(security-test Step 4)'
has "$AGENT" '(threat-model Step 4)'
has "$AGENT" 'Never send a request or run a scanner'
has "$AGENT" 'Rate checks 9 and 10 with the live table below, not the shared table.'
grep -q '^### Step 4 ' "$ST" && ok || bad "R8 security-test has no Step 4, which the agent cites"
grep -q '^### Step 4 ' "$TM" && ok || bad "R8 threat-model has no Step 4, which the agent cites"

# R9 — the system bash
for s in "$RUN" "$CLR" "$CTM"; do
  /bin/bash -n "$s" 2>/dev/null && ok || bad "R9 ${s##*/} does not parse under /bin/bash"
  /bin/bash "$s" --help 2>/dev/null | grep -q "^Usage: ${s##*/}" && ok || bad "R9 ${s##*/} --help prints no usage under /bin/bash"
done

printf "test-live-rules: %s/%s PASS\n" "$PASS" "$((PASS + FAIL))"
[ "$FAIL" -eq 0 ]
