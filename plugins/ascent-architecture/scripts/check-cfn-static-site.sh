#!/usr/bin/env bash
# Mechanical checks for a CloudFormation YAML template that serves a static site
# through CloudFront, optionally with a serverless API (blueprint
# static-site-serverless-aws). Part of the ascent-architecture plugin
# (architecture-review Step 4, deployment-options Step 6). Read-only.
#
# Usage: check-cfn-static-site.sh TEMPLATE.yaml
#
# Checks (severity from the architecture-review severity table):
#   ARC-C1  High    every S3 bucket blocks all four kinds of public access
#   ARC-C2  High    no S3 website hosting; every S3 origin uses Origin Access Control
#   ARC-C3  Medium  no CloudFront behavior allows plain HTTP (allow-all)
#   ARC-C4  Medium  a custom certificate uses TLS 1.2 (2019 or later policy) or TLS 1.3
#   ARC-C5  High    each S3 origin bucket has a policy limiting reads to CloudFront (AWS:SourceArn)
#   ARC-C6  Medium  every distribution attaches a response headers policy (security headers)
#   ARC-C7  High    every S3 bucket and DynamoDB table has DeletionPolicy Retain or Snapshot
#   ARC-C8  High    every DynamoDB table has point-in-time recovery enabled
#   ARC-C9  Low     every log group sets RetentionInDays; every Lambda function logs to one of them
#               (LoggingConfig.LogGroup, or a group named /aws/lambda/${Function})
#   ARC-C10 Medium  every API Gateway stage sets throttling (burst and rate)
#   ARC-C11 Medium  the template defines an AWS::Budgets::Budget (cost guardrail)
#   ARC-C12 Low     every distribution has access logging (Logging, or its own log delivery source)
#
# A check whose resources are absent is N/A, never PASS or FAIL.
# Limits: block-style YAML only (convert JSON with cfn-flip; a flow-style resource
# such as "Name: {Type: ...}" stops the check with exit 2). Resources are found by
# indentation under Resources:. Values built at deploy time (Fn::If, Ref) are checked
# as written: a required property in any branch counts as present, and a forbidden
# value in any branch fails. CRLF line endings and tabs are accepted. This is a guard
# rail for one well-known pattern, not a replacement for cfn-lint or cfn-guard.
# Exit: 0 no FAIL; 1 at least one FAIL; 2 bad input.
# Portable: GNU/Linux and BSD/macOS, bash 3.2+, POSIX awk.

set -euo pipefail

case "${1:-}" in -h|--help) sed -n '2,/^$/s/^# \{0,1\}//p' "$0"; exit 0 ;; esac

[ $# -eq 1 ] || { sed -n '7p' "$0" | sed 's/^# //' >&2; exit 2; }
T="$1"
[ -f "$T" ] || { echo "check-cfn-static-site: no such file: $T" >&2; exit 2; }
case "$T" in /*) ;; *) T="./$T" ;; esac   # awk would read "a=b.yaml" as an assignment
first=$(sed -n '/[^[:space:]]/{p;q;}' "$T" | sed 's/^[[:space:]]*//' | cut -c1)
if [ "$first" = "{" ]; then
  echo "check-cfn-static-site: JSON templates are not supported; convert with cfn-flip first" >&2; exit 2
fi
grep -q '^Resources:[[:space:]]*$' "$T" || grep -q '^Resources:' "$T" || { echo "check-cfn-static-site: no top-level Resources: in $T" >&2; exit 2; }

awk -v tpl="$T" '
function ind(s) { match(s, /^ */); return RLENGTH }
function has(r, re) { return body[r] ~ re }
function count(s, re,   n) { n = gsub(re, "", s); return n }
function list_add(l, x) { return (l == "" ? x : l ", " x) }
function word(name) { return "(^|[^A-Za-z0-9])" name "([^A-Za-z0-9]|$)" }
function s3_without_oac(r,   L, nL, k, li, oi, inO, open, s3, oac, bad) {
  nL = split(body[r], L, "\n"); inO = 0; open = 0; bad = 0
  for (k = 1; k <= nL; k++) {
    if (L[k] ~ /^ *$/) continue
    li = ind(L[k])
    if (L[k] ~ /^ *Origins: *$/) { inO = 1; oi = li; continue }
    if (!inO) continue
    if (li <= oi && L[k] !~ /^ *- /) { if (open && s3 && !oac) bad++; inO = 0; open = 0; continue }
    if (L[k] ~ /^ *- / && li <= oi + 2) { if (open && s3 && !oac) bad++; open = 1; s3 = 0; oac = 0 }
    if (L[k] ~ /S3OriginConfig:/) s3 = 1
    if (L[k] ~ /OriginAccessControlId:/) oac = 1
  }
  if (open && s3 && !oac) bad++
  return bad
}
function die(msg) { print "check-cfn-static-site: " msg > "/dev/stderr"; err = 1; exit 2 }
function out(id, sev, desc, fails, napplic, nres) {
  if (napplic) { printf "N/A   %-7s %s\n", "ARC-" id, desc; na++; return }
  if (fails == "") { printf "PASS  %-7s %s (%d checked)\n", "ARC-" id, desc, nres; pass++ }
  else { printf "FAIL  %-7s [%s] %s: %s\n", "ARC-" id, sev, desc, fails; fail++ }
}
{
  line = $0
  sub(/\r$/, "", line); gsub(/\t/, " ", line)
  if (line ~ /^ *#/) line = ""
  sub(/ +#.*$/, "", line)
  gsub(/["\047]/, "", line)
}
line ~ /^[A-Za-z]/ { inres = (line ~ /^Resources: *$/); rind = -1; cur = ""; next }
!inres || line ~ /^ *$/ { next }
{
  i = ind(line)
  if (rind < 0) rind = i
  if (i < rind) die("line " NR ": indentation above the resource level inside Resources:")
  if (i == rind) {
    if (line !~ /^ *[A-Za-z0-9]+: *$/) die("line " NR ": unsupported resource syntax (use block-style YAML, one \"Name:\" line per resource)")
    cur = line; sub(/^ */, "", cur); sub(/:.*/, "", cur)
    names[++n] = cur; pind[cur] = -1; next
  }
  if (pind[cur] < 0) pind[cur] = i
  body[cur] = body[cur] "\n" line
  if (i == pind[cur] && line ~ /^ *Type:/) { t = line; sub(/^ *Type: */, "", t); sub(/ +$/, "", t); type[cur] = t }
  if (i == pind[cur] && line ~ /^ *DeletionPolicy: *(Retain|RetainExceptOnCreate|Snapshot) *$/) retain[cur] = 1
}
END {
  if (err) exit 2
  if (n == 0) die("no resources found under Resources:")
  for (k = 1; k <= n; k++) { r = names[k]; if (type[r] == "") die("resource " r " has no Type at its property level"); cnt[type[r]]++ }
  nb = cnt["AWS::S3::Bucket"]; nd = cnt["AWS::CloudFront::Distribution"]; nt = cnt["AWS::DynamoDB::Table"]
  ns = cnt["AWS::ApiGatewayV2::Stage"] + cnt["AWS::ApiGateway::Stage"]
  printf "check-cfn-static-site: %s (%d resources)\n", tpl, n

  # Pass 1: log groups with retention, compliant bucket policies, access-log sources.
  for (k = 1; k <= n; k++) {
    r = names[k]; ty = type[r]
    if (ty == "AWS::Logs::LogGroup" && has(r, "RetentionInDays:( *[0-9!{]| *\n| *$)")) retained[r] = 1
    if (ty == "AWS::S3::BucketPolicy" && has(r, "cloudfront\\.amazonaws\\.com") && has(r, "[Aa][Ww][Ss]:[Ss][Oo][Uu][Rr][Cc][Ee][Aa][Rr][Nn]")) cfpol[++npol] = r
    if (ty == "AWS::Logs::DeliverySource" && has(r, "LogType: *ACCESS_LOGS")) logsrc[++nsrc] = r
  }
  n4 = 0; n7 = 0; n9 = 0; n5 = 0
  for (k = 1; k <= n; k++) {
    r = names[k]; ty = type[r]
    if (ty == "AWS::S3::Bucket") {
      if (!(has(r, "BlockPublicAcls: *true") && has(r, "BlockPublicPolicy: *true") && has(r, "IgnorePublicAcls: *true") && has(r, "RestrictPublicBuckets: *true"))) f1 = list_add(f1, r)
      if (has(r, "WebsiteConfiguration:")) f2 = list_add(f2, r " (website hosting)")
    }
    if (ty == "AWS::S3::Bucket" || ty == "AWS::DynamoDB::Table") {
      n7++
      if (!(r in retain)) f7 = list_add(f7, r)
    }
    if (ty == "AWS::DynamoDB::Table" && !has(r, "PointInTimeRecoveryEnabled: *true")) f8 = list_add(f8, r)
    if (ty == "AWS::CloudFront::Distribution") {
      ncfg = count(body[r], "S3OriginConfig:"); noac = count(body[r], "OriginAccessControlId:")
      nbad = s3_without_oac(r)
      if (nbad > 0) f2 = list_add(f2, r " (" nbad " S3 origin(s) without OriginAccessControlId)")
      if (has(r, "OriginAccessIdentity:[^\n]*origin-access-identity")) f2 = list_add(f2, r " (legacy origin access identity)")
      if (has(r, "\\.s3-website[.-]")) f2 = list_add(f2, r " (S3 website endpoint origin)")
      if (has(r, "(: *|- *|, *|\\[ *)allow-all") || !has(r, "ViewerProtocolPolicy:")) f3 = list_add(f3, r)
      if (has(r, "AcmCertificateArn:") || has(r, "IamCertificateId:")) {
        n4++
        if (!has(r, "MinimumProtocolVersion: *TLSv1\\.(2_20(19|21|25)|3)") || has(r, "MinimumProtocolVersion:[^\n]*(SSLv3|TLSv1_2016|TLSv1\\.1_2016|TLSv1\\.2_2018|TLSv1( |,|\\]|\n|$))")) f4 = list_add(f4, r)
      }
      if (!has(r, "ResponseHeadersPolicyId:")) f6 = list_add(f6, r)
      # ARC-C5: every bucket in this template used as an S3 origin needs a CloudFront-only policy.
      if (ncfg > 0 || noac > 0) {
        found = 0
        for (j = 1; j <= n; j++) {
          b = names[j]; if (type[b] != "AWS::S3::Bucket") continue
          if (!has(r, "(\\$\\{" b "[}.]|GetAtt:? *\\[ *" b " *,|[ !]" b "\\.(Regional)?DomainName)")) continue
          found = 1; n5++; ok5 = 0
          for (q = 1; q <= npol; q++) if (body[cfpol[q]] ~ ("Bucket:[^\n]*" word(b))) ok5 = 1
          if (!ok5) f5 = list_add(f5, b " (origin of " r ")")
        }
        if (!found && nb > 0) { n5++; f5 = list_add(f5, r " (an S3 origin is not linked to a bucket in this template; reference it as !GetAtt <Bucket>.RegionalDomainName)") }
      }
      # ARC-C12: Logging in the distribution, or a delivery source that names it.
      if (!has(r, "\n *Logging:")) {
        ok12 = 0
        for (q = 1; q <= nsrc; q++) if (body[logsrc[q]] ~ ("[{ ]" r "[}.]")) ok12 = 1
        if (!ok12) f12 = list_add(f12, r)
      }
    }
    if (ty == "AWS::Logs::LogGroup") { n9++; if (!(r in retained)) f9 = list_add(f9, r " (no RetentionInDays)") }
    if (ty == "AWS::Lambda::Function") {
      n9++; lg = ""
      if (match(body[r], /\n *LogGroup:[^\n]*/)) { lg = substr(body[r], RSTART, RLENGTH) }
      okl = 0
      if (has(r, "LoggingConfig:") && lg != "") for (g in retained) if (lg ~ ("(Ref:? *|\\$\\{)" g "([^A-Za-z0-9]|$)")) okl = 1
      if (!has(r, "LoggingConfig:")) for (g in retained) if (body[g] ~ ("LogGroupName:[^\n]*/aws/lambda/\\$\\{" r "\\}")) okl = 1
      if (!okl) f9 = list_add(f9, r " (logs do not go to a log group with retention in this template)")
    }
    if ((ty == "AWS::ApiGatewayV2::Stage" || ty == "AWS::ApiGateway::Stage") && !(has(r, "ThrottlingBurstLimit:") && has(r, "ThrottlingRateLimit:"))) f10 = list_add(f10, r)
  }

  out("C1", "High", "S3 buckets block all public access", f1, nb == 0, nb)
  out("C2", "High", "S3 content reaches CloudFront only through Origin Access Control", f2, nb + nd == 0, nb + nd)
  out("C3", "Medium", "CloudFront redirects or requires HTTPS on every behavior", f3, nd == 0, nd)
  out("C4", "Medium", "custom certificate requires TLS 1.2 (2019+ policy) or TLS 1.3", f4, n4 == 0, n4)
  out("C5", "High", "each S3 origin bucket allows reads only by CloudFront (AWS:SourceArn)", f5, n5 == 0, n5)
  out("C6", "Medium", "every distribution attaches a response headers policy", f6, nd == 0, nd)
  out("C7", "High", "S3 buckets and DynamoDB tables are retained on stack delete", f7, n7 == 0, n7)
  out("C8", "High", "DynamoDB tables have point-in-time recovery", f8, nt == 0, nt)
  out("C9", "Low", "log retention is set and Lambda logs go to a retained group", f9, n9 == 0, n9)
  out("C10", "Medium", "API Gateway stages set burst and rate throttling", f10, ns == 0, ns)
  out("C11", "Medium", "an AWS::Budgets::Budget is defined (cost guardrail)", (cnt["AWS::Budgets::Budget"] > 0 ? "" : "no budget in this template; define one or record where the account budget lives (waiver ADR)"), 0, cnt["AWS::Budgets::Budget"])
  out("C12", "Low", "CloudFront access logging is configured", f12, nd == 0, nd)
  printf "check-cfn-static-site: %d/%d applicable checks passing (%d not applicable)\n", pass, pass + fail, na
  exit (fail > 0 ? 1 : 0)
}
' "$T"
