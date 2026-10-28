#!/usr/bin/env bash
# Rule test for the ascent-security dependency-check skill, its two scripts and the
# security-auditor agent's dependency check (ADR-016):
#   R1  every $PLUGIN_ROOT/<path> the skill names exists
#   R2  maturity, threshold and default values agree across the skill, the contract
#       template and run-vuln-scan.sh
#   R3  every check id a script prints is in the dep-severity table, and the script
#       header and every fail()/emit() call give it a severity that table gives it
#   R4  trivy runs only with its offline flags, images only from an archive or a local
#       daemon, and no script installs, resolves or refreshes anything
#   R5  the network scanners run only inside the --allow-network block
#   R6  the skill shows the dry run first and asks before the network
#   R7  no floating image tag (:latest) anywhere in the plugin's dependency files
#   R8  off-table concerns are unrated, evidence is fresh, and the database is the
#       operator's to refresh
#   R9  the agent rates no advisory without scanner output and says what it did not check
#   R10 every security.dependencies key in the contract template is named in the skill
#   R11 the rules reference and the script headers cover SEC-D1–D10
#   R12 both scripts parse and run under the system /bin/bash (3.2 on macOS)
#
# Prints "test-dependency-rules: N/N PASS" last (make/test-plugins.sh T11 requires it).
# Portable: bash 3.2+, GNU/Linux and BSD/macOS.

set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$HERE/../../.."
PLUGIN="$ROOT/plugins/ascent-security"
SKILL="$PLUGIN/skills/dependency-check/SKILL.md"
AGENT="$PLUGIN/agents/security-auditor.md"
TEMPLATE="$PLUGIN/references/contract-template.yml"
RULES="$PLUGIN/references/dependency-rules.md"
CHECK="$PLUGIN/scripts/check-dependencies.sh"
SCAN="$PLUGIN/scripts/run-vuln-scan.sh"
CAWK="$PLUGIN/scripts/lib/check-dependencies.awk"
NAWK="$PLUGIN/scripts/lib/normalise-vulns.awk"
for f in "$SKILL" "$AGENT" "$TEMPLATE" "$RULES" "$CHECK" "$SCAN" "$CAWK" "$NAWK"; do
  [ -f "$f" ] || { echo "test-dependency-rules: missing $f"; echo "test-dependency-rules: 0/1 PASS"; exit 1; }
done

PASS=0; FAIL=0
ok()  { PASS=$((PASS + 1)); }
bad() { FAIL=$((FAIL + 1)); printf "FAIL  %s\n" "$1"; }
has() { if grep -qF -- "$3" "$2"; then ok; else bad "$1 ${2#"$ROOT"/} does not contain: $3"; fi; }
hasnt() { if grep -qF -- "$3" "$2"; then bad "$1 ${2#"$ROOT"/} must not contain: $3"; else ok; fi; }
table() { awk 'index($0, "<!-- dep-severity:start") {on=1; next} index($0, "<!-- dep-severity:end") {on=0} on && /^\| /' "$SKILL"; }

# R1 — named plugin paths exist
N=0
for p in $(grep -oE '\$PLUGIN_ROOT/[A-Za-z0-9_./-]+' "$SKILL" | sed 's/^\$PLUGIN_ROOT\///' | LC_ALL=C sort -u); do
  N=$((N + 1)); [ -e "$PLUGIN/$p" ] && ok || bad "R1 the skill names \$PLUGIN_ROOT/$p, which does not exist"
done
[ "$N" -ge 2 ] && ok || bad "R1 the skill should name both scripts under \$PLUGIN_ROOT (found $N)"

# R2 — maturity, threshold and defaults agree
has R2 "$TEMPLATE" '# enterprise (default) | standard | prototype.'
has R2 "$SKILL" 'enterprise defaults (lockfile required, threshold High, database within 7 days, exact pinning)'
has R2 "$TEMPLATE" '# Medium | Low | none. Defaults: High (enterprise), Critical (standard), none'
has R2 "$TEMPLATE" '# (enterprise), 30 (standard, prototype).'
has R2 "$SCAN" 'enterprise) d_t=High; d_a=7 ;; standard) d_t=Critical; d_a=30 ;; prototype) d_t=none; d_a=30 ;;'
has R2 "$SCAN" 'Critical|High|Medium|Low|none) ;;'
has R2 "$CHECK" '[ -n "$LOCKREQ" ] || { [ "$MATURITY" = prototype ] && LOCKREQ=no || LOCKREQ=yes; }'
has R2 "$TEMPLATE" '# yes (enterprise, standard) | no (prototype)'

# R3 — printed ids and severities are in the table
sev_ok() {  # ID SEVERITY — some table row naming the id carries the severity
  table | grep -E "SEC-$1[,)]" | grep -qE "\| $2 \|$"
}
for spec in "$CHECK:$CAWK" "$SCAN:$NAWK"; do
  sh="${spec%%:*}"; aw="${spec#*:}"
  ids=$(grep -oE '^#   SEC-D[0-9]+ +[A-Z][a-z]+' "$sh" | awk '{ print $2 ":" $3 }')
  [ -n "$ids" ] || bad "R3 ${sh#"$ROOT"/} header lists no checks"
  for x in $ids; do id="${x%%:*}"; id="${id#SEC-}"; s="${x#*:}"
    sev_ok "$id" "$s" && ok || bad "R3 ${sh#"$ROOT"/} header gives SEC-$id $s, which no dep-severity row for SEC-$id has"; done
  calls=$(grep -oE '(fail|emit)\("D[0-9]+", "[A-Za-z]+"' "$aw" | sed -E 's/^(fail|emit)\("//; s/", "/:/; s/"$//' | LC_ALL=C sort -u)
  for x in $calls; do id="${x%%:*}"; s="${x#*:}"
    sev_ok "$id" "$s" && ok || bad "R3 ${aw#"$ROOT"/} rates SEC-$id $s, which no dep-severity row for SEC-$id has"
    grep -qE "^#   SEC-$id " "$sh" && ok || bad "R3 ${aw#"$ROOT"/} prints SEC-$id, which the ${sh#"$ROOT"/} header does not list"; done
done
# srcsev() and the computed severities: High and Medium for SEC-D5; High, Medium and Low for D7 and D9
for x in D5:High D5:Medium D7:High D7:Medium D7:Low D9:High D9:Medium D9:Low; do sev_ok "${x%%:*}" "${x#*:}" && ok || bad "R3 no dep-severity row gives SEC-${x%%:*} ${x#*:}"; done

# R4 — offline trivy, nothing installed or refreshed
has R4 "$SCAN" 'OFF=(--skip-db-update --skip-java-db-update --offline-scan --skip-version-check --scanners vuln --format json --quiet'
# a trivy.yaml or .trivyignore in the repository must not apply: trivy gets empty ones
has R4 "$SCAN" '--config "$WORK/trivy.yaml" --ignorefile "$WORK/trivyignore")'
has R4 "$SCAN" '(cd "$WORK" && "$@")'
N=0
while IFS= read -r l; do
  [ -n "$l" ] || continue; N=$((N + 1))
  case "$l" in *'"${OFF[@]}"'*) ok ;; *) bad "R4 a trivy scan without the offline flags: $l" ;; esac
done <<EOF_T
$(grep -vE '^[[:space:]]*#' "$SCAN" | grep -E 'trivy (fs|image) ')
EOF_T
[ "$N" -eq 3 ] && ok || bad "R4 expected 3 trivy scan commands (fs, image archive, image daemon), found $N"
has R4 "$SCAN" '--image-src docker,containerd,podman -- "$i"'
for s in "$CHECK" "$SCAN" "$CAWK" "$NAWK"; do
  if grep -vE '^[[:space:]]*#' "$s" | grep -E '(npm (install|i|ci|update)( |$)|yarn (install|add|up)|pnpm (install|add|update)|pip3? install|poetry (lock|install|update)|uv (lock|sync|pip)|go (get|mod tidy|mod download)|cargo (update|fetch|generate-lockfile)|download-db-only|download-java-db-only|--reset|curl |wget |docker pull|podman pull)' >/dev/null; then
    bad "R4 ${s#"$ROOT"/} runs an install, resolve, download or refresh: $(grep -nE '^[^#]*(npm (install|i|ci|update)( |$)|pip3? install|download-db-only|curl |wget |docker pull)' "$s" | head -1)"
  else ok; fi
done
# npm audit fix rewrites the lockfile (the normaliser only names it in a message)
for s in "$CHECK" "$SCAN"; do if grep -vE '^[[:space:]]*#' "$s" | grep -q 'npm audit fix'; then bad "R4 ${s#"$ROOT"/} runs npm audit fix"; else ok; fi; done
has R4 "$RULES" 'Never run, and never recommend, `npm install --package-lock-only`'
has R4 "$SKILL" 'Never run `npm install --package-lock-only`'

# R5 — network scanners only with --allow-network
start=$(grep -n '^  if \[ "\$NET" = 1 \]; then$' "$SCAN" | head -1 | cut -d: -f1)
if [ -z "$start" ]; then bad "R5 run-vuln-scan.sh has no --allow-network block"; else
  end=$(awk -v s="$start" 'NR > s && /^  fi$/ { print NR; exit }' "$SCAN")
  N=0
  while IFS=: read -r n _; do
    [ -n "$n" ] || continue; N=$((N + 1))
    if [ "$n" -gt "$start" ] && [ "$n" -lt "$end" ]; then ok; else bad "R5 run-vuln-scan.sh:$n runs a network scanner outside the --allow-network block"; fi
  done <<EOF_N
$(grep -nE '^[^#]*scan network ' "$SCAN")
EOF_N
  [ "$N" -ge 4 ] && ok || bad "R5 expected the osv-scanner (2), npm audit and pip-audit scans, found $N"
  if grep -nE '^[^#]*scan offline (osv|npm-audit|pip-audit)' "$SCAN" >/dev/null; then bad "R5 a network scanner is marked offline"; else ok; fi
fi
has R5 "$SCAN" 'pip-audit -r "$ROOTABS/$r" --no-deps --disable-pip --format json'
has R5 "$SCAN" 'npm audit --json --package-lock-only --prefix "$d"'

# R6 — dry run first, ask before the network
has R6 "$SKILL" 'First show the plan, which runs nothing:'
has R6 "$SKILL" 'needs the operator'"'"'s yes in this session, after they have seen the `--dry-run` plan'
has R6 "$SKILL" 'say what each `network` line sends and to whom, and ask. Run it only on a yes in this session.'
has R6 "$SCAN" 'sends package names and versions to api.osv.dev'

# R7 — no floating image tags
for f in "$SKILL" "$TEMPLATE" "$RULES" "$CHECK" "$SCAN"; do hasnt R7 "$f" ':latest'; done

# R8 — unrated, fresh, operator refreshes
has R8 "$SKILL" 'goes under **Other observations (unrated)**'
has R8 "$SKILL" '**Fresh evidence.** Run the scripts in this session.'
has R8 "$SKILL" 'Never refresh the vulnerability database; the operator does (`trivy image --download-db-only`).'
has R8 "$SKILL" 'Write nothing: the operator commits the file.'

# R9 — the agent
has R9 "$AGENT" 'Never rate an advisory you recall rather than read in scanner'
has R9 "$AGENT" 'Vulnerability scanning (SEC-D7–D9, dependency-check Step 3) needs a shell'
has R9 "$AGENT" 'lockfile tracking, vulnerability scan'
has R9 "$AGENT" 'never quote a token or a credential in a URL'

# R10 — contract keys named in the skill
keys=$(awk '/^  dependencies:/ { on = 1; next } on && /^  [a-z]/ { on = 0 } on && /^    [a-z_]+:/ { k = $1; sub(/:$/, "", k); print k }' "$TEMPLATE")
[ -n "$keys" ] || bad "R10 no security.dependencies keys found in the contract template"
for k in $keys; do has R10 "$SKILL" "\`$k\`"; done

# R11 — every rule documented
for n in 1 2 3 4 5 6 7 8 9 10; do has R11 "$RULES" "| SEC-D$n |"; done
for n in 1 2 3 4 5 6 10; do grep -qE "^#   SEC-D$n " "$CHECK" && ok || bad "R11 check-dependencies.sh header lacks SEC-D$n"; done
for n in 7 8 9; do grep -qE "^#   SEC-D$n " "$SCAN" && ok || bad "R11 run-vuln-scan.sh header lacks SEC-D$n"; done

# R12 — the system bash
for s in "$CHECK" "$SCAN"; do
  /bin/bash -n "$s" 2>/dev/null && ok || bad "R12 ${s#"$ROOT"/} does not parse under /bin/bash"
  /bin/bash "$s" --help >/dev/null 2>&1 && ok || bad "R12 ${s#"$ROOT"/} --help fails under /bin/bash"
done
# A stand-in git that tracks every fixture file, so the result does not depend on
# whether this clone has committed the fixtures yet.
GITSHIM=$(mktemp -d); trap 'rm -rf "$GITSHIM"' EXIT
printf '#!/bin/sh\n[ "$1" = -C ] && cd "$2" && shift 2\n[ "$1" = -c ] && shift 2\ncase "$1" in rev-parse) exit 0 ;; ls-files) find . -type f | sed "s|^\\./||" ;; esac\n' > "$GITSHIM/git"; chmod +x "$GITSHIM/git"
out=$(PATH="$GITSHIM:$PATH" /bin/bash "$CHECK" --today 2026-10-27 --waived CVE-2021-23337 "$HERE/fixtures/deps-good" 2>&1); rc=$?
[ "$rc" -eq 0 ] && ok || bad "R12 check-dependencies.sh on the good fixture under /bin/bash: exit $rc $(printf '%s' "$out" | grep FAIL | head -1)"

printf "test-dependency-rules: %s/%s PASS\n" "$PASS" "$((PASS + FAIL))"
[ "$FAIL" -eq 0 ]
