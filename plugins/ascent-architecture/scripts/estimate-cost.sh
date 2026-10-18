#!/usr/bin/env bash
# Monthly cost estimate from a dated pricing file and a usage profile.
# Part of the ascent-architecture plugin (deployment-options Step 3). Read-only.
#
# Usage: estimate-cost.sh PRICING USAGE [--plans PLANS] [--no-free-tier]
#   PRICING  TSV with "# as_of: YYYY-MM-DD" and rows: key per usd free pool unit source
#   USAGE    TSV rows: key quantity [comment]; plan_needs_<feature> 1 rows state plan needs
#   --plans  CloudFront flat-rate plans TSV with a header row naming its columns
#   --no-free-tier  ignore always-free allowances (the account already uses them)
#
# Output: one LINE per priced usage key, a TOTAL, an optional flat-rate comparison, and
# a WARN when the pricing file is more than 90 days old (ASCENT_TODAY=YYYY-MM-DD
# overrides today). Rows sharing a "pool" share one free allowance, used in usage order.
# Exit: 0 estimate printed; 2 bad input (unknown key, bad number, missing as_of, ...).
# Every usage key must be priced: an unknown key stops the estimate, never drops silently.
# Portable: GNU/Linux and BSD/macOS, bash 3.2+, POSIX awk. CRLF files are accepted.

set -euo pipefail

usage() { sed -n '4,9p' "$0" | sed 's/^# \{0,1\}//' >&2; exit 2; }
die() { echo "estimate-cost: $*" >&2; exit 2; }
rel() { case "$1" in /*) printf '%s' "$1" ;; *) printf './%s' "$1" ;; esac; }  # "a=b.tsv" is not an awk assignment

PRICING=""; USAGE=""; PLANS=""; FREE=1
while [ $# -gt 0 ]; do
  case "$1" in
    --plans) [ $# -ge 2 ] || usage; PLANS="$2"; shift 2 ;;
    --no-free-tier) FREE=0; shift ;;
    -h|--help) usage ;;
    -*) die "unknown option $1" ;;
    *) if [ -z "$PRICING" ]; then PRICING="$1"; elif [ -z "$USAGE" ]; then USAGE="$1"; else die "unexpected argument $1"; fi; shift ;;
  esac
done
[ -n "$PRICING" ] && [ -n "$USAGE" ] || usage
for f in "$PRICING" "$USAGE" ${PLANS:+"$PLANS"}; do [ -f "$f" ] || die "no such file: $f"; done
PRICING=$(rel "$PRICING"); USAGE=$(rel "$USAGE"); [ -z "$PLANS" ] || PLANS=$(rel "$PLANS")

TODAY="${ASCENT_TODAY:-$(date +%Y-%m-%d)}"
export ASCENT_EST_TODAY="$TODAY" ASCENT_EST_PLANS="$PLANS" ASCENT_EST_FREE="$FREE"

awk -F'\t' '
function num(s) { return s ~ /^[0-9]+(\.[0-9]+)?$/ }
function isdate(d,   m, dd) {
  if (d !~ /^[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]$/) return 0
  m = substr(d, 6, 2) + 0; dd = substr(d, 9, 2) + 0
  return m >= 1 && m <= 12 && dd >= 1 && dd <= 31
}
function fail(msg) { print "estimate-cost: " msg > "/dev/stderr"; bad = 1; exit 2 }
function days(d,   y, m, dd, a) {   # days since 1970-01-01, proleptic Gregorian
  y = substr(d, 1, 4) + 0; m = substr(d, 6, 2) + 0; dd = substr(d, 9, 2) + 0
  if (m <= 2) { y--; m += 12 }
  a = int(y / 100)
  return int(365.25 * (y + 4716)) + int(30.6001 * (m + 1)) + dd + 2 - a + int(a / 4) - 1524.5 - 2440587.5
}
function trim(s) { sub(/^[ ]+/, "", s); sub(/[ ]+$/, "", s); return s }
BEGIN {
  today = ENVIRON["ASCENT_EST_TODAY"]; plans_file = ENVIRON["ASCENT_EST_PLANS"]; free_on = ENVIRON["ASCENT_EST_FREE"] + 0
  if (!isdate(today)) fail("ASCENT_TODAY must be a real date YYYY-MM-DD (got \"" today "\")")
}
{ sub(/\r$/, "") }
FNR == 1 { file++ }
/^[ \t]*$/ { next }
file == 1 && /^# as_of:/ { asof = $0; sub(/^# as_of:[ \t]*/, "", asof); sub(/[ \t]+$/, "", asof); next }
/^[ \t]*#/ || (file == 1 && $1 == "key") { next }
file == 1 {
  if (NF < 5) fail("pricing row " FNR " has " NF " columns, needs key per usd free pool unit source")
  k = trim($1)
  if (!num($2) || $2 + 0 == 0 || !num($3) || !num($4)) fail("pricing row " FNR " (" k ") has a non-numeric or zero value")
  if (k in per) fail("pricing key " k " appears twice")
  per[k] = $2; usd[k] = $3; fr[k] = $4; pool[k] = ($5 == "" || $5 == "-") ? "" : $5; nprice++
  if (pool[k] != "") { if (pool[k] in poolfree && poolfree[pool[k]] != fr[k] + 0) fail("pool " pool[k] " has two different free allowances"); poolfree[pool[k]] = fr[k] + 0 }
  next
}
file == 2 {
  k = trim($1); q = trim($2)
  if (!num(q)) fail("usage key " k " has non-numeric quantity \"" q "\" (line " FNR ")")
  if ((k in qty) || (k in need)) fail("usage key " k " appears twice")
  if (k ~ /^plan_needs_/) { if (q + 0 > 0) { f = k; sub(/^plan_needs_/, "", f); need[k] = f; needs = needs " " f }; next }
  if (!(k in per)) fail("unknown usage key " k " (line " FNR "): not in the pricing file")
  qty[k] = q; order[++n] = k
  next
}
END {
  if (bad) exit 2
  if (!isdate(asof)) fail("pricing file has no valid \"# as_of: YYYY-MM-DD\" line")
  if (nprice == 0) fail("pricing file has no rows")
  if (n == 0) fail("usage profile has no priced rows")
  printf "estimate-cost: pricing as_of %s, list prices, estimate only (free tier %s)\n", asof, (free_on ? "applied" : "ignored")
  for (pk in poolfree) left[pk] = poolfree[pk]
  total = 0; covered = 0; cfreq = 0; cfgb = 0
  for (i = 1; i <= n; i++) {
    k = order[i]
    f = 0
    if (free_on) {
      f = fr[k] + 0
      if (pool[k] != "") { if (f > left[pool[k]]) f = left[pool[k]] }
    }
    b = qty[k] - f; if (b < 0) { f = qty[k] + 0; b = 0 }
    if (free_on && pool[k] != "") left[pool[k]] -= f
    c = b / per[k] * usd[k]
    bill[k] = b
    total += c
    printf "LINE  %-26s qty %14s  free %12s  billable %14s  usd %10.2f\n", k, qty[k], f, b, c
    if (k ~ /^(cf_|waf_|r53_)/) covered += c
    if (k == "cf_https_requests" || k == "cf_http_requests") cfreq += qty[k]
    if (k == "cf_data_out_gb") cfgb += qty[k]
  }
  printf "TOTAL %.2f USD/month\n", total
  if (plans_file != "") {
    best = ""; nplans = 0; ncol = 0
    while ((rc = (getline line < plans_file)) > 0) {
      sub(/\r$/, "", line)
      if (line ~ /^[ \t]*#/ || line ~ /^[ \t]*$/) continue
      m = split(line, pr, "\t")
      if (pr[1] == "plan") { for (c2 = 1; c2 <= m; c2++) col[pr[c2]] = c2; ncol = m; continue }
      if (ncol == 0) fail("plans file has no header row (plan, usd, requests, data_gb, s3_credit_gb, ...)")
      nplans++
      if (!num(pr[col["usd"]]) || !num(pr[col["requests"]]) || !num(pr[col["data_gb"]]) || !num(pr[col["s3_credit_gb"]])) fail("plans row \"" pr[1] "\" has a non-numeric value")
      fits = (cfreq <= pr[col["requests"]] + 0 && cfgb <= pr[col["data_gb"]] + 0)
      nn = split(needs, nl, " ")
      for (j = 1; j <= nn; j++) {
        if (!(nl[j] in col)) fail("usage needs plan feature \"" nl[j] "\" but the plans file has no such column")
        if (pr[col[nl[j]]] != "yes") fits = 0
      }
      if (fits && (best == "" || pr[col["usd"]] + 0 < bestusd)) { best = pr[1]; bestusd = pr[col["usd"]] + 0; credit = pr[col["s3_credit_gb"]] + 0 }
    }
    if (rc < 0) fail("cannot read plans file " plans_file)
    close(plans_file)
    if (nplans == 0) fail("plans file has no plan rows")
    why = (needs == "" ? "" : ", needs" needs)
    if (best == "") {
      print "FLAT-RATE none fits (requests " cfreq ", data " cfgb " GB" why "); ask AWS for custom pricing"
    } else {
      s3credit = 0
      if ("s3_storage_gb" in bill) { cg = (bill["s3_storage_gb"] < credit) ? bill["s3_storage_gb"] : credit; s3credit = cg / per["s3_storage_gb"] * usd["s3_storage_gb"] }
      alt = total - covered - s3credit + bestusd
      printf "FLAT-RATE %s plan %.2f USD (cheapest that fits%s) replaces %.2f USD of CloudFront, WAF and Route 53 lines and %.2f USD of S3 storage: total %.2f USD/month (%s)\n", best, bestusd, why, covered, s3credit, alt, (alt < total ? "cheaper" : "not cheaper")
    }
    print "NOTE flat-rate plans are not available to accounts on the AWS Free Tier plan"
  }
  if (plans_file == "" && needs != "") print "NOTE plan_needs rows ignored: no --plans file given"
  age = days(today) - days(asof)
  if (age > 90) printf "WARN pricing is %d days old (as_of %s): refresh it from the source URLs before relying on this estimate\n", age, asof
  if (age < 0) printf "WARN pricing as_of %s is after today (%s)\n", asof, today
}' "$PRICING" "$USAGE"
