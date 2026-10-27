#!/usr/bin/env bash
# Behavior test for plugins/ascent-architecture/scripts/check-cfn-static-site.sh.
#
# The blueprint template must pass all 12 checks. Then each check gets its own
# negative control: a copy of the blueprint broken in exactly one way must fail
# that check and no other (so a check can neither miss its defect nor fire on
# the wrong one). Also covers N/A for absent resources, commented-out
# properties, and bad input (JSON, no Resources:, missing file).
#
# Runs with the default awk and every other awk found (mawk, gawk, BWK awk).
# Prints "test-check-cfn: N/N PASS" last (make/test-plugins.sh T11 requires it).
# Portable: bash 3.2+, GNU/Linux and BSD/macOS.

set -u
WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT INT TERM

HERE="$(cd "$(dirname "$0")" && pwd)"
PLUGIN="$HERE/../../../plugins/ascent-architecture"
CHECK="$PLUGIN/scripts/check-cfn-static-site.sh"
BP="$PLUGIN/blueprints/static-site-serverless-aws/template.yaml"
for f in "$CHECK" "$BP"; do [ -f "$f" ] || { echo "test-check-cfn: missing $f"; echo "test-check-cfn: 0/1 PASS"; exit 1; }; done

PASS=0; FAIL=0
ok()  { PASS=$((PASS + 1)); }
bad() { FAIL=$((FAIL + 1)); printf "FAIL  [%s] %s\n" "$AWKNAME" "$1"; }
run() {  # FILE -> RC, OUT
  PATH="$SHIM:$PATH" bash "$CHECK" "$1" >"$WORK/out" 2>"$WORK/err"; RC=$?
  OUT=$(cat "$WORK/out" "$WORK/err")
}
# mutate NAME AWK-PROGRAM — writes $WORK/NAME.yaml from the blueprint; the program
# must change the file, or the control is reported as a stale anchor.
mutate() {
  awk "$2" "$BP" > "$WORK/$1.yaml"
  if cmp -s "$BP" "$WORK/$1.yaml"; then bad "$1: mutation changed nothing (stale anchor)"; return 1; fi
}
expect_only() {  # NAME CHECK-ID — the mutant fails exactly CHECK-ID
  run "$WORK/$1.yaml"
  nfail=$(printf '%s\n' "$OUT" | grep -c '^FAIL ' || true)
  if [ "$RC" -ne 1 ]; then bad "$1: expected exit 1, got $RC"
  elif ! printf '%s\n' "$OUT" | grep -q "^FAIL  $2 "; then bad "$1: $2 did not fail: $(printf '%s\n' "$OUT" | grep '^FAIL' | head -2 | tr '\n' ';')"
  elif [ "$nfail" -ne 1 ]; then bad "$1: expected only $2 to fail, got $nfail failures: $(printf '%s\n' "$OUT" | grep '^FAIL' | cut -c1-60 | tr '\n' ';')"
  else ok; fi
}
# Program helpers: sub on matching lines, delete the Nth matching line, insert after a match.
SUBP() { printf '{ if ($0 ~ /%s/) sub(/%s/, "%s"); print }' "$1" "$2" "$3"; }
DELN() { printf '/%s/ { n++; if (n == %s) next } { print }' "$1" "$2"; }

matrix() {
  # --help answers with the usage text and exits 0.
  run --help
  if [ "$RC" -eq 0 ] && printf '%s\n' "$OUT" | grep -qF 'Usage: check-cfn-static-site.sh TEMPLATE.yaml'; then ok
  else bad "--help should print the usage text and exit 0: exit $RC"; fi

  # Baseline: the blueprint passes everything.
  run "$BP"
  if [ "$RC" -eq 0 ] && printf '%s\n' "$OUT" | grep -q '12/12 applicable checks passing (0 not applicable)'; then ok
  else bad "blueprint should pass 12/12: exit $RC $(printf '%s\n' "$OUT" | grep -E '^FAIL|passing' | tr '\n' ';')"; fi

  mutate c1-public    "$(SUBP 'RestrictPublicBuckets: true' 'true' 'false')" && expect_only c1-public ARC-C1
  mutate c2-website   '{ print } /^      VersioningConfiguration:/ && !d { print "      WebsiteConfiguration:"; print "        IndexDocument: index.html"; d = 1 }' && expect_only c2-website ARC-C2
  mutate c2-no-oac    "$(DELN 'OriginAccessControlId: !GetAtt' 1)" && expect_only c2-no-oac ARC-C2
  mutate c3-http      "$(SUBP 'ViewerProtocolPolicy: redirect-to-https' 'redirect-to-https' 'allow-all')" && expect_only c3-http ARC-C3
  mutate c4-old-tls   "$(SUBP 'MinimumProtocolVersion: TLSv1.2_2021' 'TLSv1.2_2021' 'TLSv1_2016')" && expect_only c4-old-tls ARC-C4
  mutate c4-no-tls    "$(DELN 'MinimumProtocolVersion:' 1)" && expect_only c4-no-tls ARC-C4
  mutate c5-no-source "$(SUBP 'AWS:SourceArn:' 'AWS:SourceArn:' 'aws:Referer:')" && expect_only c5-no-source ARC-C5
  mutate c6-headers   '/ResponseHeadersPolicyId: !Ref SecurityHeadersPolicy/ { next } { print }' && expect_only c6-headers ARC-C6
  mutate c7-bucket    "$(DELN '^    DeletionPolicy: Retain' 1)" && expect_only c7-bucket ARC-C7
  mutate c7-table     "$(DELN '^    DeletionPolicy: Retain' 2)" && expect_only c7-table ARC-C7
  mutate c8-pitr      "$(SUBP 'PointInTimeRecoveryEnabled: true' 'true' 'false')" && expect_only c8-pitr ARC-C8
  mutate c8-commented "$(SUBP 'PointInTimeRecoveryEnabled: true' 'PointInTimeRecoveryEnabled' '# PointInTimeRecoveryEnabled')" && expect_only c8-commented ARC-C8
  mutate c9-retention "$(DELN 'RetentionInDays: !Ref LogRetentionDays' 1)" && expect_only c9-retention ARC-C9
  mutate c9-lambda    "$(DELN 'LogGroup: !Ref ApiFunctionLogGroup' 1)" && expect_only c9-lambda ARC-C9
  mutate c10-throttle "$(DELN 'ThrottlingBurstLimit:' 1)" && expect_only c10-throttle ARC-C10
  mutate c11-budget   "$(SUBP 'Type: AWS::Budgets::Budget$' 'AWS::Budgets::Budget' 'AWS::Budgets::BudgetsAction')" && expect_only c11-budget ARC-C11
  mutate c12-logs     "$(SUBP 'LogType: ACCESS_LOGS' 'ACCESS_LOGS' 'CONNECTION_LOGS')" && expect_only c12-logs ARC-C12

  # N/A: a bucket-only template has no CDN, API, table or log checks to apply.
  printf 'Resources:\n  B:\n    Type: AWS::S3::Bucket\n    DeletionPolicy: Retain\n    Properties:\n      PublicAccessBlockConfiguration:\n        BlockPublicAcls: true\n        BlockPublicPolicy: true\n        IgnorePublicAcls: true\n        RestrictPublicBuckets: true\n  Budget:\n    Type: AWS::Budgets::Budget\n' > "$WORK/bucket-only.yaml"
  run "$WORK/bucket-only.yaml"
  if [ "$RC" -eq 0 ] && printf '%s\n' "$OUT" | grep -q '^N/A   ARC-C3 ' && printf '%s\n' "$OUT" | grep -q '^N/A   ARC-C10 ' && printf '%s\n' "$OUT" | grep -q '4/4 applicable checks passing (8 not applicable)'; then ok
  else bad "bucket-only template: expected 4/4 with 8 N/A, got exit $RC $(printf '%s\n' "$OUT" | grep passing)"; fi

  # Layout variants of the compliant blueprint must still pass 12/12: indentation
  # doubled everywhere, CRLF line endings, tabs after colons, lower-case condition key,
  # long-form intrinsics, and a relative path that looks like an awk assignment.
  awk '{ match($0, /^ */); printf "%s%s\n", substr($0, 1, RLENGTH) substr($0, 1, RLENGTH), substr($0, RLENGTH + 1) }' "$BP" > "$WORK/indent4.yaml"
  awk '{ printf "%s\r\n", $0 }' "$BP" > "$WORK/crlf.yaml"
  awk '{ sub(/BlockPublicAcls: true/, "BlockPublicAcls:\ttrue"); print }' "$BP" > "$WORK/tabs.yaml"
  awk '{ sub(/AWS:SourceArn:/, "aws:SourceArn:"); print }' "$BP" > "$WORK/lowerkey.yaml"
  awk '{ sub(/RetentionInDays: !Ref LogRetentionDays/, "RetentionInDays: {Ref: LogRetentionDays}"); print }' "$BP" > "$WORK/longform.yaml"
  cp "$BP" "$WORK/x=1.yaml"
  for v in indent4 crlf tabs lowerkey longform x=1; do
    (cd "$WORK" && PATH="$SHIM:$PATH" bash "$CHECK" "$v.yaml" </dev/null >"$WORK/out" 2>&1); RC=$?; OUT=$(cat "$WORK/out")
    if [ "$RC" -eq 0 ] && printf '%s\n' "$OUT" | grep -q '12/12 applicable checks passing'; then ok
    else bad "layout variant $v should pass 12/12: exit $RC $(printf '%s\n' "$OUT" | grep -E '^FAIL|passing|check-cfn' | head -3 | tr '\n' ';')"; fi
  done

  # Defects the first version missed: each must fail its check, and only that check.
  mutate c2-second-origin '{ print } /^              OriginAccessIdentity: ""/ && !d { print "          - Id: legacy"; print "            DomainName: !GetAtt SiteBucket.RegionalDomainName"; print "            S3OriginConfig:"; print "              OriginAccessIdentity: \"\""; d = 1 }' && expect_only c2-second-origin ARC-C2
  mutate c2-oai-sub '{ sub(/OriginAccessIdentity: ""/, "OriginAccessIdentity: !Sub \"origin-access-identity/cloudfront/${Oai}\""); print }' && expect_only c2-oai-sub ARC-C2
  mutate c3-if-branch '{ sub(/ViewerProtocolPolicy: https-only/, "ViewerProtocolPolicy: !If [UseAlias, https-only, allow-all]"); print }' && expect_only c3-if-branch ARC-C3
  mutate c3-tab '{ sub(/ViewerProtocolPolicy: https-only/, "ViewerProtocolPolicy:\tallow-all"); print }' && expect_only c3-tab ARC-C3
  mutate c5-other-bucket '{ sub(/Bucket: !Ref SiteBucket/, "Bucket: !Ref OtherBucket"); print }' && expect_only c5-other-bucket ARC-C5
  mutate c9-unmanaged '{ sub(/LogGroup: !Ref ApiFunctionLogGroup/, "LogGroup: /aws/lambda/unmanaged"); print }' && expect_only c9-unmanaged ARC-C9
  mutate c12-other-dist '{ if ($0 ~ /ResourceArn: .*distribution/) sub(/[{]Distribution[}]/, "{OtherDistribution}"); print }' && expect_only c12-other-dist ARC-C12

  mutate c2-oac-on-other-origin '/OriginAccessControlId: !GetAtt SiteOriginAccessControl.Id/ { next } { print } /^          - Id: api/ && !d { print "            OriginAccessControlId: !GetAtt FnOac.Id"; d = 1 }' && expect_only c2-oac-on-other-origin ARC-C2
  mutate c3-if-block '/ViewerProtocolPolicy: https-only/ { print "            ViewerProtocolPolicy: !If"; print "              - UseAlias"; print "              - https-only"; print "              - allow-all"; next } { print }' && expect_only c3-if-block ARC-C3
  mutate c5-sub-origin '{ sub(/DomainName: !GetAtt SiteBucket.RegionalDomainName/, "DomainName: !Sub \"${SiteBucket}.s3.${AWS::Region}.amazonaws.com\""); sub(/Bucket: !Ref SiteBucket/, "Bucket: !Ref OtherBucket"); print }' && expect_only c5-sub-origin ARC-C5
  # An origin bucket that lives outside the template leaves ARC-C5 not applicable.
  awk '/^  SiteBucket:$/ { s = 1 } /^  SiteBucketPolicy:/ { s = 2 } /^  SiteOriginAccessControl:/ { s = 0 } s { next } { sub(/DomainName: !GetAtt SiteBucket.RegionalDomainName/, "DomainName: existing-bucket.s3.us-east-1.amazonaws.com"); print }' "$BP" > "$WORK/external.yaml"
  run "$WORK/external.yaml"
  if [ "$RC" -eq 0 ] && printf '%s\n' "$OUT" | grep -q '^N/A   ARC-C5 '; then ok; else bad "external origin bucket: expected ARC-C5 N/A and exit 0, got $RC $(printf '%s\n' "$OUT" | grep -E '^FAIL|ARC-C5' | head -2 | tr '\n' ';')"; fi
  # The default Lambda log group name with retention also satisfies ARC-C9.
  awk '/^      LoggingConfig:/ { skip = 2; next } skip > 0 { skip--; next } { sub(/LogGroupName: !Sub "\/\$\{ProjectName\}\/api-function"/, "LogGroupName: !Sub \"/aws/lambda/${ApiFunction}\""); print }' "$BP" > "$WORK/defaultlg.yaml"
  run "$WORK/defaultlg.yaml"
  if [ "$RC" -eq 0 ] && printf '%s\n' "$OUT" | grep -q '12/12 applicable'; then ok; else bad "default Lambda log group: expected 12/12, got $RC $(printf '%s\n' "$OUT" | grep -E '^FAIL' | head -2 | tr '\n' ';')"; fi

  # Unsupported syntax stops the check instead of skipping a resource.
  awk '{ print } /^Resources:/ { print "  PublicBucket: {Type: AWS::S3::Bucket, Properties: {WebsiteConfiguration: {IndexDocument: index.html}}}" }' "$BP" > "$WORK/flow.yaml"
  run "$WORK/flow.yaml"
  if [ "$RC" -eq 2 ] && printf '%s' "$OUT" | grep -q 'unsupported resource syntax'; then ok; else bad "flow-style resource: expected exit 2, got $RC $(printf '%s\n' "$OUT" | tail -1)"; fi

  # Bad input exits 2 with a reason.
  printf '{ "Resources": {} }\n' > "$WORK/t.json"; run "$WORK/t.json"
  if [ "$RC" -eq 2 ] && printf '%s' "$OUT" | grep -q 'JSON templates are not supported'; then ok; else bad "JSON template: expected exit 2, got $RC"; fi
  printf 'Parameters:\n  X:\n    Type: String\n' > "$WORK/nores.yaml"; run "$WORK/nores.yaml"
  if [ "$RC" -eq 2 ] && printf '%s' "$OUT" | grep -q 'no top-level Resources'; then ok; else bad "no Resources: expected exit 2, got $RC"; fi
  run "$WORK/does-not-exist.yaml"
  if [ "$RC" -eq 2 ]; then ok; else bad "missing file: expected exit 2, got $RC"; fi

  # Severities agree in three places: the script header, the architecture-review
  # mapping table, and what a failing check prints.
  hdr=$(awk '/^#   ARC-C[0-9]+ +(High|Medium|Low) / { print $2, $3 }' "$CHECK" | LC_ALL=C sort)
  tbl=$(awk -F'|' '/^ *\| ARC-C[0-9]+ \|/ { gsub(/ /, "", $2); gsub(/ /, "", $3); print $2, $3 }' "$SKILL" | LC_ALL=C sort)
  if [ -n "$hdr" ] && [ "$hdr" = "$tbl" ] && [ "$(printf '%s\n' "$hdr" | grep -c .)" -eq 12 ]; then ok
  else bad "check severities differ between the script header and architecture-review: header [$(printf '%s' "$hdr" | tr '\n' ',')] table [$(printf '%s' "$tbl" | tr '\n' ',')]"; fi
  for id in ARC-C1 ARC-C3 ARC-C8; do
    want=$(printf '%s\n' "$hdr" | awk -v i="$id" '$1 == i { print $2 }')
    case "$id" in ARC-C1) m=c1-public ;; ARC-C3) m=c3-http ;; ARC-C8) m=c8-pitr ;; esac
    run "$WORK/$m.yaml"
    if printf '%s\n' "$OUT" | grep -q "^FAIL  $id *\[$want\]"; then ok; else bad "$id prints a severity other than its header ($want)"; fi
  done
}
SKILL="$PLUGIN/skills/architecture-review/SKILL.md"

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

# The blueprint passes cfn-lint, when it is installed (the docs say it does).
AWKNAME=cfn-lint
if command -v cfn-lint >/dev/null 2>&1; then
  if cfn-lint "$BP" >"$WORK/lint" 2>&1; then ok; else bad "cfn-lint reports: $(head -3 "$WORK/lint" | tr '\n' ';')"; fi
else
  echo "SKIP  cfn-lint not installed (pip install cfn-lint to check the blueprint)"
fi

printf "test-check-cfn: %s/%s PASS (awk: %s)\n" "$PASS" "$((PASS + FAIL))" "$AWKS"
[ "$FAIL" -eq 0 ]
