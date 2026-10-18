#!/usr/bin/env bash
# Behavior test for plugins/ascent-architecture/scripts/estimate-cost.sh.
#
# Uses a small fixture pricing file with round numbers, so every expected value
# below can be checked by hand, then checks the shipped pricing files: they parse,
# carry an as_of date, price every key in the blueprint's usage profile, and give
# the documented total. Bad input must stop the estimate (exit 2), never drop a
# line silently.
#
# Runs with the default awk and every other awk found (mawk, gawk, BWK awk).
# Prints "test-estimate-cost: N/N PASS" last (make/test-plugins.sh T11 requires it).
# Portable: bash 3.2+, GNU/Linux and BSD/macOS.

set -u
WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT INT TERM

HERE="$(cd "$(dirname "$0")" && pwd)"
PLUGIN="$HERE/../../../plugins/ascent-architecture"
EST="$PLUGIN/scripts/estimate-cost.sh"
PRICING="$PLUGIN/pricing/aws-us-east-1.tsv"
PLANS="$PLUGIN/pricing/aws-cloudfront-flat-rate.tsv"
USAGE="$PLUGIN/blueprints/static-site-serverless-aws/usage-small.tsv"
for f in "$EST" "$PRICING" "$PLANS" "$USAGE"; do [ -f "$f" ] || { echo "test-estimate-cost: missing $f"; echo "test-estimate-cost: 0/1 PASS"; exit 1; }; done

PASS=0; FAIL=0
ok()  { PASS=$((PASS + 1)); }
bad() { FAIL=$((FAIL + 1)); printf "FAIL  [%s] %s\n" "$AWKNAME" "$1"; }
run() {  # ARGS... -> RC, OUT (stdout + stderr)
  PATH="$SHIM:$PATH" ASCENT_TODAY="${TODAY:-2026-10-18}" bash "$EST" "$@" >"$WORK/out" 2>"$WORK/err"; RC=$?
  OUT=$(cat "$WORK/out" "$WORK/err")
}
has()  { printf '%s\n' "$OUT" | grep -qF -- "$1"; }
line_usd() { printf '%s\n' "$OUT" | awk -v k="$1" '$1 == "LINE" && $2 == k { print $NF }'; }
expect() {  # NAME CONDITION-RESULT(0|1) DETAIL
  if [ "$2" -eq 0 ]; then ok; else bad "$1: $3"; fi
}

T=$'\t'
cat > "$WORK/p.tsv" <<EOF
# as_of: 2026-09-01
key${T}per${T}usd${T}free${T}pool${T}unit${T}source
gb${T}1${T}0.10${T}10${T}-${T}GB${T}fixture
req${T}1000000${T}2.00${T}1000000${T}-${T}requests${T}fixture
cf_data_out_gb${T}1${T}0.05${T}0${T}-${T}GB${T}fixture
cf_https_requests${T}10000${T}0.01${T}0${T}-${T}requests${T}fixture
s3_storage_gb${T}1${T}1.00${T}0${T}-${T}GB${T}fixture
pa${T}1${T}1.00${T}100${T}shared${T}units${T}fixture
pb${T}1${T}2.00${T}100${T}shared${T}units${T}fixture
EOF
cat > "$WORK/u.tsv" <<EOF
# fixture usage
gb${T}30${T}20 billable
req${T}3000000

cf_data_out_gb${T}200
cf_https_requests${T}2000000
s3_storage_gb${T}8
EOF
cat > "$WORK/plans.tsv" <<EOF
# as_of: 2026-09-01
plan${T}usd${T}requests${T}data_gb${T}s3_credit_gb${T}logs${T}source
Big${T}50${T}100000000${T}100000${T}100${T}yes${T}fixture
Small${T}5${T}3000000${T}500${T}5${T}no${T}fixture
Tiny${T}0${T}1000${T}1${T}1${T}no${T}fixture
EOF

matrix() {
  TODAY=2026-10-18
  run "$WORK/p.tsv" "$WORK/u.tsv"
  # gb: (30-10)*0.10 = 2.00; req: (3M-1M)/1M*2 = 4.00; cf data 200*0.05 = 10.00;
  # cf requests 2M/10k*0.01 = 2.00; s3 8*1 = 8.00; total 26.00
  expect "fixture exit 0" "$RC" "exit $RC: $OUT"
  expect "free tier subtracted (gb)" "$([ "$(line_usd gb)" = 2.00 ] && echo 0 || echo 1)" "gb line $(line_usd gb), want 2.00"
  expect "free tier subtracted (req)" "$([ "$(line_usd req)" = 4.00 ] && echo 0 || echo 1)" "req line $(line_usd req), want 4.00"
  expect "per-block pricing (cf requests)" "$([ "$(line_usd cf_https_requests)" = 2.00 ] && echo 0 || echo 1)" "cf_https_requests $(line_usd cf_https_requests), want 2.00"
  expect "total" "$(has 'TOTAL 26.00 USD/month' && echo 0 || echo 1)" "$(printf '%s\n' "$OUT" | grep TOTAL)"
  expect "as_of shown" "$(has 'pricing as_of 2026-09-01' && echo 0 || echo 1)" "header missing as_of"
  expect "no stale warning at 47 days" "$(has 'WARN' && echo 1 || echo 0)" "unexpected WARN"

  run "$WORK/p.tsv" "$WORK/u.tsv" --no-free-tier
  # gb 3.00, req 6.00, others unchanged: total 29.00
  expect "--no-free-tier total" "$(has 'TOTAL 29.00 USD/month' && echo 0 || echo 1)" "$(printf '%s\n' "$OUT" | grep TOTAL)"
  expect "--no-free-tier header" "$(has 'free tier ignored' && echo 0 || echo 1)" "header does not say ignored"

  run "$WORK/p.tsv" "$WORK/u.tsv" --plans "$WORK/plans.tsv"
  # Cheapest plan that fits 2M requests and 200 GB is Small ($5, 5 GB credit):
  # covered cf lines 12.00, s3 credit 5*1 = 5.00 -> 26 - 12 - 5 + 5 = 14.00
  expect "flat-rate picks cheapest fitting plan" "$(has 'FLAT-RATE Small plan 5.00 USD (cheapest that fits) replaces 12.00 USD' && echo 0 || echo 1)" "$(printf '%s\n' "$OUT" | grep FLAT)"
  expect "flat-rate total" "$(has 'total 14.00 USD/month (cheaper)' && echo 0 || echo 1)" "$(printf '%s\n' "$OUT" | grep FLAT)"

  printf 'cf_https_requests\t900000000\n' > "$WORK/huge.tsv"
  run "$WORK/p.tsv" "$WORK/huge.tsv" --plans "$WORK/plans.tsv"
  expect "no plan fits" "$(has 'FLAT-RATE none fits' && echo 0 || echo 1)" "$(printf '%s\n' "$OUT" | grep FLAT)"

  TODAY=2027-01-15
  run "$WORK/p.tsv" "$WORK/u.tsv"
  expect "stale warning past 90 days" "$(has 'WARN pricing is 136 days old' && echo 0 || echo 1)" "$(printf '%s\n' "$OUT" | grep WARN)"
  TODAY=2026-11-30
  run "$WORK/p.tsv" "$WORK/u.tsv"
  expect "no warning at exactly 90 days" "$([ "$RC" -eq 0 ] && ! has 'WARN' && echo 0 || echo 1)" "exit $RC $(printf '%s\n' "$OUT" | grep WARN)"
  TODAY=2026-99-99
  run "$WORK/p.tsv" "$WORK/u.tsv"
  expect "impossible ASCENT_TODAY exits 2" "$([ "$RC" -eq 2 ] && has 'real date' && echo 0 || echo 1)" "exit $RC: $OUT"
  TODAY=2026-10-18

  # A shared free allowance is used once, in usage order: pa takes 100 free of the
  # shared 100, so pb pays for all 50: 50 * 2.00 = 100.00 (not 0.00).
  printf 'pa\t150\npb\t50\n' > "$WORK/pool.tsv"; run "$WORK/p.tsv" "$WORK/pool.tsv"
  expect "shared pool: first key uses the allowance" "$([ "$(line_usd pa)" = 50.00 ] && echo 0 || echo 1)" "pa $(line_usd pa), want 50.00"
  expect "shared pool: second key pays in full" "$([ "$(line_usd pb)" = 100.00 ] && echo 0 || echo 1)" "pb $(line_usd pb), want 100.00"

  # Plan features: needing logs rules out Small (no logs), so Big (50 USD) is chosen.
  printf 'cf_https_requests\t2000000\ncf_data_out_gb\t200\nplan_needs_logs\t1\n' > "$WORK/needs.tsv"
  run "$WORK/p.tsv" "$WORK/needs.tsv" --plans "$WORK/plans.tsv"
  expect "plan needs exclude plans without the feature" "$(has 'FLAT-RATE Big plan 50.00 USD (cheapest that fits, needs logs)' && echo 0 || echo 1)" "$(printf '%s\n' "$OUT" | grep FLAT)"
  expect "plan_needs rows are not priced lines" "$(printf '%s\n' "$OUT" | grep -q '^LINE  plan_needs' && echo 1 || echo 0)" "a plan_needs row was priced"
  printf 'cf_https_requests\t10\nplan_needs_teleport\t1\n' > "$WORK/needs2.tsv"; run "$WORK/p.tsv" "$WORK/needs2.tsv" --plans "$WORK/plans.tsv"
  expect "unknown plan feature exits 2" "$([ "$RC" -eq 2 ] && has 'no such column' && echo 0 || echo 1)" "exit $RC: $OUT"
  grep '^#' "$WORK/plans.tsv" > "$WORK/emptyplans.tsv"; run "$WORK/p.tsv" "$WORK/u.tsv" --plans "$WORK/emptyplans.tsv"
  expect "plans file without rows exits 2" "$([ "$RC" -eq 2 ] && echo 0 || echo 1)" "exit $RC: $OUT"

  # The S3 credit covers only billable storage: with 8 GB free, no credit is due.
  awk -F'\t' -v OFS='\t' '$1 == "s3_storage_gb" { $4 = 8 } { print }' "$WORK/p.tsv" > "$WORK/s3free.tsv"
  run "$WORK/s3free.tsv" "$WORK/u.tsv" --plans "$WORK/plans.tsv"
  expect "S3 credit applies to billable storage only" "$(has 'and 0.00 USD of S3 storage' && echo 0 || echo 1)" "$(printf '%s\n' "$OUT" | grep FLAT)"

  # Layout tolerance: CRLF files, whitespace-only lines, and a path like "u=1.tsv".
  awk '{ printf "%s\r\n", $0 }' "$WORK/p.tsv" > "$WORK/pcrlf.tsv"; awk '{ printf "%s\r\n", $0 } END { print "   " }' "$WORK/u.tsv" > "$WORK/ucrlf.tsv"
  run "$WORK/pcrlf.tsv" "$WORK/ucrlf.tsv"
  expect "CRLF and whitespace-only lines accepted" "$([ "$RC" -eq 0 ] && has 'TOTAL 26.00 USD/month' && echo 0 || echo 1)" "exit $RC $(printf '%s\n' "$OUT" | tail -2 | tr '\n' ';')"
  cp "$WORK/u.tsv" "$WORK/u=1.tsv"
  (cd "$WORK" && PATH="$SHIM:$PATH" ASCENT_TODAY=2026-10-18 bash "$EST" p.tsv u=1.tsv </dev/null >"$WORK/out" 2>&1); RC=$?; OUT=$(cat "$WORK/out")
  expect "a file named like an awk assignment is read as a file" "$([ "$RC" -eq 0 ] && has 'TOTAL 26.00 USD/month' && echo 0 || echo 1)" "exit $RC $(printf '%s\n' "$OUT" | tail -1)"

  # Bad input stops the estimate.
  printf 'gb\t1\nmystery\t5\n' > "$WORK/unknown.tsv"; run "$WORK/p.tsv" "$WORK/unknown.tsv"
  expect "unknown usage key exits 2" "$([ "$RC" -eq 2 ] && has 'unknown usage key mystery' && echo 0 || echo 1)" "exit $RC: $OUT"
  expect "unknown key prints no total" "$(has 'TOTAL' && echo 1 || echo 0)" "a TOTAL was printed despite the unknown key"
  printf 'gb\t1,000\n' > "$WORK/comma.tsv"; run "$WORK/p.tsv" "$WORK/comma.tsv"
  expect "non-numeric quantity exits 2" "$([ "$RC" -eq 2 ] && has 'non-numeric quantity' && echo 0 || echo 1)" "exit $RC: $OUT"
  printf 'gb\t1\ngb\t2\n' > "$WORK/dup.tsv"; run "$WORK/p.tsv" "$WORK/dup.tsv"
  expect "duplicate usage key exits 2" "$([ "$RC" -eq 2 ] && has 'appears twice' && echo 0 || echo 1)" "exit $RC: $OUT"
  grep -v '^# as_of' "$WORK/p.tsv" > "$WORK/noasof.tsv"; run "$WORK/noasof.tsv" "$WORK/u.tsv"
  expect "missing as_of exits 2" "$([ "$RC" -eq 2 ] && has 'no valid "# as_of' && echo 0 || echo 1)" "exit $RC: $OUT"
  awk -F'\t' -v OFS='\t' '$1 == "gb" { $2 = 0 } { print }' "$WORK/p.tsv" > "$WORK/zero.tsv"; run "$WORK/zero.tsv" "$WORK/u.tsv"
  expect "zero per exits 2" "$([ "$RC" -eq 2 ] && echo 0 || echo 1)" "exit $RC: $OUT"
  run "$WORK/p.tsv"
  expect "missing argument exits 2" "$([ "$RC" -eq 2 ] && echo 0 || echo 1)" "exit $RC"

  # Shipped files: parse, dated, price every blueprint key, documented total.
  run "$PRICING" "$USAGE" --plans "$PLANS"
  expect "shipped pricing + blueprint usage exit 0" "$RC" "exit $RC: $(printf '%s\n' "$OUT" | head -3 | tr '\n' ';')"
  expect "shipped pricing as_of" "$(printf '%s\n' "$OUT" | grep -qE 'pricing as_of 20[0-9]{2}-[01][0-9]-[0-3][0-9]' && echo 0 || echo 1)" "no as_of in header"
  nlines=$(printf '%s\n' "$OUT" | grep -c '^LINE ' || true)
  nusage=$(grep -vE '^(#|$)' "$USAGE" | grep -vc '^plan_needs_' || true)
  expect "every blueprint usage key priced" "$([ "$nlines" -eq "$nusage" ] && echo 0 || echo 1)" "$nlines lines for $nusage usage rows"
  # Documented in the blueprint README: 0.86 USD/month pay-as-you-go; the template's
  # features need the Business plan (200.23 USD); 5.88 USD with no free allowances.
  expect "blueprint total matches README" "$(has 'TOTAL 0.86 USD/month' && echo 0 || echo 1)" "$(printf '%s\n' "$OUT" | grep TOTAL)"
  expect "blueprint flat-rate matches README" "$(has 'FLAT-RATE Business plan 200.00 USD' && has 'total 200.23 USD/month (not cheaper)' && echo 0 || echo 1)" "$(printf '%s\n' "$OUT" | grep FLAT)"
  run "$PRICING" "$USAGE" --no-free-tier
  expect "blueprint no-free-tier total matches README" "$(has 'TOTAL 5.88 USD/month' && echo 0 || echo 1)" "$(printf '%s\n' "$OUT" | grep TOTAL)"
  readme="$PLUGIN/blueprints/static-site-serverless-aws/README.md"
  expect "README states the same totals" "$(grep -q '\*\*0.86 USD\*\*' "$readme" 2>/dev/null && grep -q '\*\*5.88 USD\*\*' "$readme" && grep -q '200.23 USD' "$readme" && echo 0 || echo 1)" "README does not state 0.86, 5.88 and 200.23 USD"
}

realpath_of() {
  local p="$1" l
  while [ -L "$p" ]; do l=$(ls -l "$p" | sed 's/.* -> //'); case "$l" in /*) p="$l" ;; *) p="$(dirname "$p")/$l" ;; esac; done
  printf '%s' "$p"
}
AWKS="default"; SEEN=" $(realpath_of "$(command -v awk)") "
[ "${ASCENT_HOOK_TEST_ONE_AWK:-0}" = 1 ] || for a in mawk gawk original-awk nawk; do
  p=$(command -v "$a" 2>/dev/null) || continue
  r=$(realpath_of "$p")
  case "$SEEN" in *" $r "*) continue ;; esac
  SEEN="$SEEN$r "; AWKS="$AWKS $a"
done
for AWKNAME in $AWKS; do
  SHIM="$WORK/shim-$AWKNAME"; mkdir -p "$SHIM"
  if [ "$AWKNAME" != default ]; then ln -s "$(command -v "$AWKNAME")" "$SHIM/awk"; fi
  matrix
done

printf "test-estimate-cost: %s/%s PASS (awk: %s)\n" "$PASS" "$((PASS + FAIL))" "$AWKS"
[ "$FAIL" -eq 0 ]
