#!/usr/bin/env bash
# Behavior test for plugins/ascent-security/scripts/run-vuln-scan.sh.
#
# Rates recorded scanner output (fixtures/scans: trivy fs and image output recorded
# offline from trivy 0.76.1, trimmed; hand-made osv-scanner, npm audit and pip-audit
# output) for SEC-D7–D9: severity from the table, the threshold, waivers, merging the
# same advisory from several scanners, line lookup, the database age and the cap.
# Then runs the live path against stand-in scanners on a PATH without the real ones:
# trivy gets its offline flags and nothing else, the network scanners run only with
# --allow-network, --dry-run runs nothing, and no scanner means unmeasured.
#
# Runs with the default awk and every other awk found (mawk, gawk, BWK awk).
# Prints "test-run-vuln-scan: N/N PASS" last (make/test-plugins.sh T11 requires it).
# Portable: bash 3.2+, GNU/Linux and BSD/macOS.

set -u
WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT INT TERM

HERE="$(cd "$(dirname "$0")" && pwd)"
PLUGIN="$HERE/../../../plugins/ascent-security"
SCAN="$PLUGIN/scripts/run-vuln-scan.sh"
FX="$HERE/fixtures/scans"
for f in "$SCAN" "$FX/trivy-fs.json" "$FX/trivy-image.json" "$FX/repo/package-lock.json"; do [ -f "$f" ] || { echo "test-run-vuln-scan: missing $f"; echo "test-run-vuln-scan: 0/1 PASS"; exit 1; }; done

# The tools the script needs, and nothing else: no real scanner is on this PATH.
BIN="$WORK/bin"; mkdir -p "$BIN"
for t in bash sh sed grep cut head mktemp rm dirname basename find sort date cat tr wc; do
  p=$(command -v "$t") && ln -s "$p" "$BIN/$t"
done
REPO="$WORK/repo"; cp -R "$FX/repo" "$REPO"
printf 'flask>=0.5\n' > "$REPO/requirements-dev.txt"
LOG="$WORK/calls.log"
FAKE="$WORK/fake"; mkdir -p "$FAKE"
fake() {  # NAME BODY — a stand-in scanner that logs its arguments
  printf '#!/bin/sh\necho "%s $*" >> "%s"\n%s\n' "$1" "$LOG" "$2" > "$FAKE/$1"; chmod +x "$FAKE/$1"
}
TRIVY_OK="echo \"cwd \$(pwd)\" >> '$LOG'; case \"\$1\" in version) cat '$FX/trivy-version.json' ;; fs) cat '$FX/trivy-fs.json' ;; image) cat '$FX/trivy-image.json' ;; esac"
fake trivy "$TRIVY_OK"
fake npm "cat '$FX/npm-audit.json'; exit 1"
fake pip-audit "cat '$FX/pip-audit.json'; exit 1"
fake osv-scanner "case \"\$1\" in --version) echo 'osv-scanner version: 2.0.2' ;; *) cat '$FX/osv.json'; exit 1 ;; esac"

PASS=0; FAIL=0
ok()  { PASS=$((PASS + 1)); }
bad() { FAIL=$((FAIL + 1)); printf "FAIL  [%s] %s\n" "$AWKNAME" "$1"; }
# run [OPTIONS...] — no scanner on PATH; live [OPTIONS...] — the stand-ins on PATH
run()  { : > "$LOG"; PATH="$SHIM:$BIN" bash "$SCAN" --today 2026-10-27 "$@" >"$WORK/out" 2>"$WORK/err"; RC=$?; OUT=$(cat "$WORK/out" "$WORK/err"); }
live() { : > "$LOG"; PATH="$SHIM:$FAKE:$BIN" bash "$SCAN" --today 2026-10-27 "$@" >"$WORK/out" 2>"$WORK/err"; RC=$?; OUT=$(cat "$WORK/out" "$WORK/err"); CALLS=$(cat "$LOG"); }
has()   { if printf '%s\n' "$OUT" | grep -qF -- "$2"; then ok; else bad "$1: output should contain \"$2\": $(printf '%s\n' "$OUT" | grep -E '^(FAIL|NOTE|run-)' | head -3 | tr '\n' ';')"; fi; }
hasnt() { if printf '%s\n' "$OUT" | grep -qF -- "$2"; then bad "$1: output should not contain \"$2\""; else ok; fi; }
count() { local n; n=$(printf '%s\n' "$OUT" | grep -c -- "$2" || true); [ "$n" -eq "$3" ] && ok || bad "$1: expected $3 lines matching \"$2\", got $n"; }
rc()    { [ "$RC" -eq "$2" ] && ok || bad "$1: expected exit $2, got $RC: $(printf '%s\n' "$OUT" | grep -E '^(FAIL|run-)|run-vuln' | head -2 | tr '\n' ';')"; }
called() { if printf '%s\n' "$CALLS" | grep -qF -- "$2"; then ok; else bad "$1: expected a call containing \"$2\": $(printf '%s\n' "$CALLS" | head -3 | tr '\n' ';')"; fi; }
notcalled() { if printf '%s\n' "$CALLS" | grep -qF -- "$2"; then bad "$1: should not call \"$2\": $(printf '%s\n' "$CALLS" | grep -F -- "$2" | head -1)"; else ok; fi; }

ALL=(--from "trivy-version:$FX/trivy-version.json" --from "trivy:$FX/trivy-fs.json" --from "npm-audit:$FX/npm-audit.json@package-lock.json" --from "osv:$FX/osv.json" --from "pip-audit:$FX/pip-audit.json@requirements.txt")

matrix() {
  # Recorded output, enterprise defaults (threshold High, database within 7 days).
  run "${ALL[@]}" "$REPO"; rc all 1
  has all "FAIL  SEC-D7  High   $REPO/package-lock.json:15  CVE-2021-23337 (GHSA-35jh-r3h4-6jhm) in lodash 4.17.15: High, fixed in 4.17.21"
  has all "FAIL  SEC-D7  High   $REPO/package-lock.json:21  CVE-2021-44906 (GHSA-xvch-5gv4-984h) in minimist 1.2.0: Critical, fixed in 1.2.6"
  has all "FAIL  SEC-D7  Medium $REPO/package-lock.json  GHSA-0000-1111-2222 in left-pad 1.0.0: High, no fixed release yet"
  has all "FAIL  SEC-D7  Medium $REPO/requirements.txt:2  PYSEC-2019-179 (CVE-2019-1010083 GHSA-5wv5-4vpf-pj6m) in flask 0.5: no severity, fixed in 1.0"
  count all-merged 'GHSA-35jh-r3h4-6jhm' 1
  count all-merged-osv 'GHSA-xvch-5gv4-984h' 1
  count all-fail '^FAIL ' 7
  has all 'PASS  SEC-D8  database 2026-10-25, within 7 days'
  has all 'N/A   SEC-D9  no --image or --image-tar'
  has all 'NOTE  SEC-D7  4 advisories below the threshold (High): 4 Medium'
  has all 'run-vuln-scan: 11 advisories (7 rated, 4 below the threshold, 0 waived) from 4 scans'

  # npm audit alone: the version and line come from the lockfile, the fix from fixAvailable.
  run --from "npm-audit:$FX/npm-audit.json@package-lock.json" "$REPO"; rc npm 1
  has npm "$REPO/package-lock.json:21  GHSA-xvch-5gv4-984h in minimist 1.2.0: Critical, fixed in 1.2.8"
  has npm "$REPO/package-lock.json:15  GHSA-35jh-r3h4-6jhm in lodash 4.17.15: High, fixed in a release npm audit fix can install"
  has npm 'NOTE  SEC-D7  1 advisory below the threshold (High): 1 Medium'
  has npm 'the database date is not recorded for these results'
  has npm 'PASS  SEC-D8  scanned; the database date is not recorded'

  # The threshold, maturity and waivers.
  run "${ALL[@]}" --threshold Critical "$REPO"; rc critical 1
  count critical '^FAIL ' 2
  has critical 'in minimist 1.2.0: Critical'
  has critical 'in flask 0.5: no severity'
  run "${ALL[@]}" --threshold Low "$REPO"; rc low 1
  count low '^FAIL  SEC-D7  Low ' 4
  run "${ALL[@]}" --threshold none "$REPO"; rc none 0
  has none 'below the threshold (none: nothing is rated)'
  run "${ALL[@]}" --maturity prototype "$REPO"; rc prototype 0
  run "${ALL[@]}" --maturity standard "$REPO"; rc standard 1
  count standard '^FAIL ' 2
  run "${ALL[@]}" --waived ghsa-35jh-r3h4-6jhm,CVE-2019-1010083 "$REPO"; rc waived 1
  has waived "INFO  SEC-D7  $REPO/package-lock.json:15  CVE-2021-23337 (GHSA-35jh-r3h4-6jhm) in lodash 4.17.15 is waived"
  has waived 'PYSEC-2019-179 (CVE-2019-1010083 GHSA-5wv5-4vpf-pj6m) in flask 0.5 is waived'
  count waived '^FAIL ' 5

  # SEC-D8: database age.
  # the boundary: 7 days old passes at --max-age 7, 8 days old fails
  run --from "trivy-version:$FX/trivy-version.json" --from "trivy:$FX/trivy-fs.json" --threshold none --today 2026-11-01 "$REPO"; has age-7 'PASS  SEC-D8  database 2026-10-25, within 7 days'
  run --from "trivy-version:$FX/trivy-version.json" --from "trivy:$FX/trivy-fs.json" --threshold none --today 2026-11-02 "$REPO"; has age-8 '8 days ago (scan_max_age_days 7)'
  sed 's/2026-10-25/2026-05-08/g' "$FX/trivy-version.json" > "$WORK/old-db.json"
  run --from "trivy-version:$WORK/old-db.json" --from "trivy:$FX/trivy-fs.json" --threshold none "$REPO"; rc stale 1
  has stale 'FAIL  SEC-D8  Low    trivy  the trivy database was updated 2026-05-08, 172 days ago (scan_max_age_days 7): advisories published since then are not seen'
  run --from "trivy-version:$WORK/old-db.json" --from "trivy:$FX/trivy-fs.json" --threshold none --max-age 200 "$REPO"; rc stale-ok 0
  run --from "trivy-version:$WORK/old-db.json" --from "trivy:$FX/trivy-fs.json" --maturity prototype "$REPO"; rc stale-proto 0
  has stale-proto 'NOTE  SEC-D8  the trivy database was updated 2026-05-08'
  printf '{"Version":"0.76.1"}\n' > "$WORK/no-db.json"
  run --from "trivy-version:$WORK/no-db.json" --from "trivy:$FX/trivy-fs.json" --threshold none "$REPO"; rc no-db 1
  has no-db 'trivy reports no vulnerability database'

  # SEC-D9: images.
  run --from "trivy-version:$FX/trivy-version.json" --from "trivy:$FX/trivy-image.json" "$REPO"; rc image 1
  has image 'FAIL  SEC-D9  High   app-image.tar (alpine 3.18.0)  CVE-2022-48174 in busybox 1.36.0-r0: Critical, fixed in 1.36.1-r1'
  count image '^FAIL  SEC-D9 ' 4
  has image 'NOTE  SEC-D9  20 advisories below the threshold (High): 18 Medium, 2 Low'
  has image 'the base image OS alpine 3.18.0 is past end of support'
  has image 'N/A   SEC-D7  no lockfile the scanners read'
  # The cap: 25 findings per place, the rest counted.
  awk 'BEGIN { print "{ \"ArtifactName\": \"big\", \"ArtifactType\": \"container_image\", \"Results\": [ { \"Target\": \"big (debian 12)\", \"Class\": \"os-pkgs\", \"Vulnerabilities\": ["
    for (i = 1; i <= 30; i++) printf "{ \"VulnerabilityID\": \"CVE-2099-%04d\", \"PkgName\": \"p%d\", \"InstalledVersion\": \"1\", \"FixedVersion\": \"2\", \"Severity\": \"HIGH\" }%s\n", i, i, (i < 30 ? "," : "")
    print "] } ] }" }' > "$WORK/big.json"
  run --from "trivy:$WORK/big.json" "$REPO"; rc cap 1
  count cap '^FAIL  SEC-D9 ' 25
  has cap 'NOTE  SEC-D9  big (debian 12): 5 more rated advisories, not listed'
  has cap '30 findings'

  # Live: trivy with its offline flags only.
  # run from the repository root, as the skill does
  cd "$REPO"; live --image-tar "$FX/trivy-image.json" --image app:1.4.2 "$REPO"; rc live 1; cd "$HERE"
  called live-version 'trivy version --format json'
  called live-fs "trivy fs --skip-db-update --skip-java-db-update --offline-scan --skip-version-check --scanners vuln --format json --quiet --config "
  called live-skip '--skip-dirs **/fixtures'
  called live-tar "trivy image --skip-db-update --skip-java-db-update --offline-scan --skip-version-check --scanners vuln --format json --quiet --config "
  called live-tar-input "--input $FX/trivy-image.json"
  called live-img '--image-src docker,containerd,podman -- app:1.4.2'
  # a trivy.yaml or .trivyignore in the repository never applies: trivy runs elsewhere,
  # with an empty --config and --ignorefile of its own
  called live-ignorefile '--ignorefile '
  notcalled live-repo-config "--config $REPO"; notcalled live-cwd "cwd $REPO"
  has live 'database 2026-10-25 (trivy 0.76.1)'
  notcalled live-net 'npm '; notcalled live-net 'pip-audit'; notcalled live-net 'osv-scanner'
  notcalled live-db '--download-db-only'; notcalled live-db '--reset'
  has live 'from 3 scans (trivy fs, trivy image trivy-image.json, trivy image app:1.4.2)'
  live --include-tests "$REPO"; called include-tests-fs 'trivy fs '; notcalled include-tests '--skip-dirs **/fixtures'
  # Live with --allow-network: each network scanner, pip-audit only on fully pinned files.
  live --allow-network "$REPO"; rc network 1
  called network-osv "osv-scanner scan source -r --format json $REPO"
  called network-npm "npm audit --json --package-lock-only --prefix $REPO"
  called network-pip "pip-audit -r $REPO/requirements.txt --no-deps --disable-pip --format json"
  notcalled network-pip-ranges 'requirements-dev.txt'
  notcalled network-install 'install'
  count network-merged 'GHSA-35jh-r3h4-6jhm' 1
  # Network scanners that are missing, and files they cannot scan, are NOTEs.
  mkdir -p "$WORK/fake-trivy-only"; ln -s "$FAKE/trivy" "$WORK/fake-trivy-only/trivy"
  : > "$LOG"; PATH="$SHIM:$WORK/fake-trivy-only:$BIN" bash "$SCAN" --today 2026-10-27 --allow-network "$REPO" >"$WORK/out" 2>&1; OUT=$(cat "$WORK/out")
  has net-missing 'NOTE  SEC-D8  osv-scanner is not installed'
  has net-missing 'NOTE  SEC-D8  package-lock.json: not scanned by npm audit: npm is not installed'
  has net-missing 'NOTE  SEC-D8  requirements.txt: not scanned by pip-audit: pip-audit is not installed'
  live --allow-network "$REPO"; has net-unpinned 'NOTE  SEC-D8  requirements-dev.txt: not scanned by pip-audit: not every requirement is pinned with =='
  # osv-scanner 1.x gets its own syntax.
  fake osv-scanner "case \"\$1\" in --version) echo 'osv-scanner version: 1.9.2' ;; *) cat '$FX/osv.json'; exit 1 ;; esac"
  live --allow-network "$REPO"; called osv-v1 "osv-scanner --format json -r $REPO"
  fake osv-scanner "case \"\$1\" in --version) echo 'osv-scanner version: 2.0.2' ;; *) cat '$FX/osv.json'; exit 1 ;; esac"
  # A PATH named like a pruned directory is still scanned; a trailing slash changes nothing.
  cp -R "$REPO" "$WORK/test"
  live --allow-network "$WORK/test"; called root-test "npm audit --json --package-lock-only --prefix $WORK/test"
  live --allow-network "$REPO/"; has trailing-slash "$REPO/package-lock.json:15"; hasnt trailing-slash "$REPO//"
  # A scanner that fails leaves that part unmeasured (SEC-D8); with no output at all the
  # whole scan is. Its message is masked.
  fake trivy 'echo "FATAL no database at https://u:s3cret@db.example/x?token=abc password=hunter2" >&2; exit 1'
  live "$REPO"; rc broken 1
  has broken 'FAIL  SEC-D8  Low    scan  trivy fs failed (exit 1): FATAL no database at https://***@db.example/x password=***: that part of the scan is unmeasured'
  has broken 'FAIL  SEC-D8  Low    scan  no scanner output'
  hasnt broken-mask 's3cret'; hasnt broken-mask 'token=abc'; hasnt broken-mask 'hunter2'
  live --maturity prototype "$REPO"; rc broken-proto 0; has broken-proto 'NOTE  SEC-D8  trivy fs failed (exit 1)'
  fake trivy "$TRIVY_OK"
  # Output that is not a complete report is a failed scan, never a clean one.
  printf '{"error": {"code": "ENOLOCK", "summary": "This command requires an existing lockfile."}}\n' > "$WORK/npm-error.json"
  run --from "npm-audit:$WORK/npm-error.json@package-lock.json" "$REPO"; rc npm-error 1
  has npm-error "FAIL  SEC-D8  Low    scan  recorded npm-audit $WORK/npm-error.json: the output is an error, not a report"
  has npm-error 'N/A   SEC-D7  not scanned'; hasnt npm-error 'PASS  SEC-D7'
  head -c 400 "$FX/trivy-fs.json" > "$WORK/cut.json"
  run --from "trivy:$WORK/cut.json" --from "npm-audit:$FX/npm-audit.json@package-lock.json" "$REPO"; rc cut 1
  has cut "recorded trivy $WORK/cut.json: the output is not valid JSON or was cut short"
  printf '{"actions": [], "advisories": {}, "metadata": {}}\n' > "$WORK/npm6.json"
  run --from "npm-audit:$WORK/npm6.json@package-lock.json" "$REPO"; rc npm6 1; has npm6 'npm 6 audit format'
  printf '{"results": []}\n' > "$WORK/wrong.json"
  run --from "trivy:$WORK/wrong.json" "$REPO"; rc wrong-format 1; has wrong-format 'the output is not a trivy report'
  # A scan that found no lockfile is N/A, not a PASS (trivy writes no Results then).
  printf '{"SchemaVersion": 2, "ArtifactName": "x", "ArtifactType": "filesystem"}\n' > "$WORK/no-targets.json"
  run --from "trivy-version:$FX/trivy-version.json" --from "trivy:$WORK/no-targets.json" "$REPO"; rc no-targets 0
  has no-targets 'N/A   SEC-D7  no lockfile the scanners read'; hasnt no-targets 'PASS  SEC-D7'
  printf '[]\n' > "$WORK/pip-empty.json"
  run --from "pip-audit:$WORK/pip-empty.json@requirements.txt" "$REPO"; rc pip-empty 0; has pip-empty 'PASS  SEC-D7'
  # A fix npm audit reports for one lockfile does not apply to another.
  mkdir -p "$WORK/two/a" "$WORK/two/b"; cp "$REPO/package-lock.json" "$WORK/two/a/"; cp "$REPO/package-lock.json" "$WORK/two/b/"
  sed 's/"fixAvailable": true/"fixAvailable": false/' "$FX/npm-audit.json" > "$WORK/npm-nofix.json"
  run --from "npm-audit:$FX/npm-audit.json@a/package-lock.json" --from "npm-audit:$WORK/npm-nofix.json@b/package-lock.json" "$WORK/two"
  has fix-per-lock "$WORK/two/a/package-lock.json:15  GHSA-35jh-r3h4-6jhm in lodash 4.17.15: High, fixed in a release npm audit fix can install"
  has fix-per-lock "$WORK/two/b/package-lock.json:15  GHSA-35jh-r3h4-6jhm in lodash 4.17.15: High, no fixed release yet"
  # Absolute trivy targets under PATH are printed relative to it.
  sed "s#\"Target\": \"package-lock.json\"#\"Target\": \"$REPO/package-lock.json\"#" "$FX/trivy-fs.json" > "$WORK/abs.json"
  cd "$WORK"; run --from "trivy:$WORK/abs.json" repo; cd "$HERE"
  has abs-target "repo/package-lock.json:15  CVE-2021-23337"; hasnt abs-target "$REPO/package-lock.json"
  # --from keeps an "@" in an existing file name.
  cp "$FX/osv.json" "$WORK/osv@ci.json"
  run --from "osv:$WORK/osv@ci.json" "$REPO"; rc from-at 1; has from-at 'from 1 scan (recorded osv'
  # No scanner on PATH.
  run "$REPO"; rc unmeasured 1
  has unmeasured 'FAIL  SEC-D8  Low    scan  unmeasured: trivy is not installed, and the network scanners need --allow-network'
  has unmeasured 'N/A   SEC-D7  not scanned'
  run --image app:1 "$REPO"; has no-trivy-image 'images not scanned: trivy is not installed'
  # --dry-run lists the plan and runs nothing.
  live --dry-run --allow-network --image app:1 "$REPO"; rc dry 0
  [ -z "$CALLS" ] && ok || bad "dry: should run nothing: $(printf '%s' "$CALLS" | head -2 | tr '\n' ';')"
  has dry 'PLAN  offline trivy fs --skip-db-update'
  has dry 'PLAN  network npm audit --json --package-lock-only'
  has dry "sends the lockfile's package names and versions to the registry npm is configured with"
  has dry 'NOTE  requirements-dev.txt: not scanned by pip-audit'
  run --dry-run "$REPO"; has dry-none 'NOTE  unmeasured: trivy is not installed'
  live --dry-run --image 'app:1 x' "$REPO"; has dry-quoted 'app:1\ x' 
  has dry 'run-vuln-scan: dry run, nothing was scanned'

  # Bad input and help.
  run "$WORK/nope"; rc missing 2
  run "$REPO" "$REPO"; rc two-paths 2
  run --threshold Severe "$REPO"; rc threshold 2
  run --max-age 7d "$REPO"; rc max-age 2
  run --from "sarif:$FX/osv.json" "$REPO"; rc from-format 2
  run --from "osv:$WORK/nope.json" "$REPO"; rc from-file 2
  run --image-tar "$WORK/nope.tar" "$REPO"; rc tar 2
  run --image --server=http://x "$REPO"; rc image-option 2
  run --help; if [ "$RC" -eq 0 ] && printf '%s\n' "$OUT" | grep -q '^Usage: run-vuln-scan.sh'; then ok; else bad "--help should print usage and exit 0"; fi
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
  if [ "$AWKNAME" != default ]; then ln -s "$(command -v "$AWKNAME")" "$SHIM/awk"; else ln -s "$(command -v awk)" "$SHIM/awk"; fi
  matrix
done

printf "test-run-vuln-scan: %s/%s PASS (awk: %s)\n" "$PASS" "$((PASS + FAIL))" "$AWKS"
[ "$FAIL" -eq 0 ]
