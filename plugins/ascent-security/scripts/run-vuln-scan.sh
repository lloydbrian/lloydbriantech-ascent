#!/usr/bin/env bash
# Vulnerability scan of dependencies and images, offline by default. Part of the
# ascent-security plugin (dependency-check Step 3). Never installs, resolves,
# downloads or updates a database: trivy runs with its offline flags, and the
# scanners that need the network run only with --allow-network.
#
# Usage: run-vuln-scan.sh [--dry-run] [--threshold Critical|High|Medium|Low|none] [--max-age DAYS] [--maturity enterprise|standard|prototype] [--waived ID,...] [--today YYYY-MM-DD] [--image NAME]... [--image-tar FILE]... [--from FORMAT:FILE[@REF]]... [--allow-network] [--include-tests] PATH
#
# PATH is the repository directory. What runs (--dry-run prints it and runs nothing):
#   offline  trivy version --format json                    database date (SEC-D8)
#   offline  trivy fs <offline flags> PATH                   lockfiles (SEC-D7)
#   offline  trivy image <offline flags> --input FILE        each --image-tar (SEC-D9)
#   offline  trivy image <offline flags> --image-src docker,containerd,podman NAME
#                                                            each --image, from a local daemon
#   network  osv-scanner, npm audit, pip-audit               only with --allow-network; they
#                                                            send package lists to a third party
# The offline flags: --skip-db-update --skip-java-db-update --offline-scan
# --skip-version-check --scanners vuln. trivy runs from a scratch directory with an
# empty --config and --ignorefile, so a trivy.yaml or .trivyignore in the repository
# cannot change what it reports (SEC-D10 checks those files). Test code and fixtures
# are skipped (--skip-dirs) unless --include-tests.
# --from FORMAT:FILE rates recorded output instead of scanning (repeatable): trivy,
# trivy-version, osv, npm-audit, pip-audit. @REF names the lockfile or requirements
# file the output describes, relative to PATH (npm-audit and pip-audit need it).
#
# Checks (severity from the dependency-check severity table):
#   SEC-D7  High    an advisory at or above --threshold in a dependency: High when it
#                   is Critical or High and a fixed release exists; Medium when no fix
#                   exists, or the scanner gives no severity; Low below High
#   SEC-D8  Low     the scan is unmeasured (no offline scanner and no --allow-network),
#                   a scanner failed or wrote something that is not a complete report,
#                   or the trivy database is older than --max-age days; a NOTE at
#                   prototype
#   SEC-D9  High    an advisory at or above --threshold in a local image, rated as D7
# Advisories below the threshold are NOTE counts; --threshold none rates nothing.
# The ids in --waived (and their aliases) are INFO.
#
# Output: FAIL lines (FAIL  SEC-Dn  SEVERITY  file:line  message), PASS or N/A per
# check, NOTE and INFO lines, then "run-vuln-scan: ...".
# Exit: 0 no FAIL; 1 at least one FAIL; 2 bad input.
# Portable: GNU/Linux and BSD/macOS, bash 3.2+, POSIX awk, run with LC_ALL=C.

set -euo pipefail

usage() { sed -n '7p' "$0" | sed 's/^# //'; }
DRY=0; THRESH=""; MAXAGE=""; MATURITY=enterprise; WAIVED=""; TODAY=""; NET=0; TESTS=0
IMAGES=(); TARS=(); FROM=(); ROOT=""
need() { [ $# -ge 2 ] && [ -n "$2" ] || { echo "run-vuln-scan: $1 needs a value" >&2; exit 2; }; }
while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) DRY=1; shift ;;
    --threshold) need "$@"; THRESH="$2"; shift 2 ;;
    --max-age) need "$@"; MAXAGE="$2"; shift 2 ;;
    --maturity) need "$@"; MATURITY="$2"; shift 2 ;;
    --waived) need "$@"; WAIVED="$WAIVED,$2"; shift 2 ;;
    --today) need "$@"; TODAY="$2"; shift 2 ;;
    --image) need "$@"; case "$2" in -*) echo "run-vuln-scan: --image names an image, not an option: $2" >&2; exit 2 ;; esac; IMAGES+=("$2"); shift 2 ;;
    --image-tar) need "$@"; TARS+=("$2"); shift 2 ;;
    --from) need "$@"; FROM+=("$2"); shift 2 ;;
    --allow-network) NET=1; shift ;;
    --include-tests) TESTS=1; shift ;;
    -h|--help) usage; exit 0 ;;
    -*) echo "run-vuln-scan: unknown option $1" >&2; exit 2 ;;
    *) [ -z "$ROOT" ] || { echo "run-vuln-scan: one PATH only" >&2; exit 2; }; ROOT="$1"; shift ;;
  esac
done
[ -n "$ROOT" ] || { usage >&2; exit 2; }
[ -d "$ROOT" ] || { echo "run-vuln-scan: not a directory: $ROOT" >&2; exit 2; }
while [ "${ROOT%/}" != "$ROOT" ] && [ "$ROOT" != / ]; do ROOT="${ROOT%/}"; done
case "$MATURITY" in enterprise) d_t=High; d_a=7 ;; standard) d_t=Critical; d_a=30 ;; prototype) d_t=none; d_a=30 ;;
  *) echo "run-vuln-scan: --maturity must be enterprise, standard or prototype" >&2; exit 2 ;; esac
[ -n "$THRESH" ] || THRESH=$d_t
[ -n "$MAXAGE" ] || MAXAGE=$d_a
case "$THRESH" in Critical|High|Medium|Low|none) ;; *) echo "run-vuln-scan: --threshold must be Critical, High, Medium, Low or none" >&2; exit 2 ;; esac
case "$MAXAGE" in ''|*[!0-9]*) echo "run-vuln-scan: --max-age must be a number of days" >&2; exit 2 ;; esac
[ -n "$TODAY" ] || TODAY=$(date +%Y-%m-%d)
printf '%s' "$TODAY" | grep -qE '^[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]$' || { echo "run-vuln-scan: --today must be YYYY-MM-DD" >&2; exit 2; }
for f in ${TARS[@]+"${TARS[@]}"}; do [ -f "$f" ] || { echo "run-vuln-scan: no such image archive: $f" >&2; exit 2; }; done
# from_split FORMAT:FILE[@REF] — sets fmt, f and ref. A FILE that exists as given keeps
# any "@" in its name; otherwise the last "@" starts REF.
from_split() {
  fmt="${1%%:*}"; f="${1#*:}"; ref=""
  if [ ! -f "$f" ]; then case "$f" in *@*) ref="${f##*@}"; f="${f%@*}" ;; esac; fi
}
for x in ${FROM[@]+"${FROM[@]}"}; do
  from_split "$x"
  case "$fmt" in trivy|trivy-version|osv|npm-audit|pip-audit) ;; *) echo "run-vuln-scan: --from format must be trivy, trivy-version, osv, npm-audit or pip-audit: $x" >&2; exit 2 ;; esac
  [ -f "$f" ] || { echo "run-vuln-scan: no such file: $f" >&2; exit 2; }
done

LIB="$(cd "$(dirname "$0")" && pwd)/lib"
for l in json.awk normalise-vulns.awk; do [ -f "$LIB/$l" ] || { echo "run-vuln-scan: missing $LIB/$l" >&2; exit 2; }; done
ROOTABS="$(cd "$ROOT" && pwd)"

WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT; trap 'exit 130' INT TERM
ARGS=(); SCANNERS=""; FAILED=""; SKIPPED=""; UNMEASURED=""; N=0
: >"$WORK/trivy.yaml"; : >"$WORK/trivyignore"
OFF=(--skip-db-update --skip-java-db-update --offline-scan --skip-version-check --scanners vuln --format json --quiet
  --config "$WORK/trivy.yaml" --ignorefile "$WORK/trivyignore")
SKIP=(--skip-dirs '**/node_modules' --skip-dirs '**/.git' --skip-dirs '**/vendor')
[ "$TESTS" = 1 ] || SKIP+=(--skip-dirs '**/tests' --skip-dirs '**/test' --skip-dirs '**/__tests__' --skip-dirs '**/fixtures' --skip-dirs '**/spec')

# mask — credentials out of scanner messages: user:password@ in URLs, query strings,
# and token or password assignments.
mask() { sed -E -e 's#//[^/[:space:]]*@#//***@#g' -e 's#\?[^[:space:]]*##g' \
  -e 's#([_A-Za-z]*([Tt][Oo][Kk][Ee][Nn]|[Pp][Aa][Ss][Ss][Ww][Oo][Rr][Dd]|_auth))[=:][^[:space:]]*#\1=***#g'; }
# scan MODE FORMAT REF LABEL COMMAND... — print it (--dry-run) or run it into a file,
# from $WORK. A scanner that exits non-zero with JSON output (npm audit, pip-audit and
# osv-scanner exit 1 when they find something) still counts, and the normaliser checks
# that the output is a complete report; one with no output is a SEC-D8 finding.
scan() {
  local mode="$1" fmt="$2" ref="$3" label="$4" out rc q; shift 4
  if [ "$DRY" = 1 ]; then
    printf -v q '%q ' "$@"
    printf 'PLAN  %-7s %s\n' "$mode" "${q% }"
    case "$fmt" in
      osv) echo "      sends package names and versions to api.osv.dev" ;;
      npm-audit) echo "      sends the lockfile's package names and versions to the registry npm is configured with (the project's .npmrc, else registry.npmjs.org)" ;;
      pip-audit) echo "      sends package names and versions to the PyPI and OSV APIs" ;;
    esac
    return 0
  fi
  N=$((N + 1)); out="$WORK/scan-$N.json"; rc=0
  (cd "$WORK" && "$@") >"$out" 2>"$out.err" || rc=$?
  if [ -s "$out" ] && grep -q '[{[]' "$out"; then
    ARGS+=("F=$fmt" "L=$ref" "S=$label" "$out")
    [ "$fmt" = trivy-version ] || SCANNERS="${SCANNERS:+$SCANNERS, }$label"
  else
    FAILED="$FAILED|$label failed (exit $rc): $(head -1 "$out.err" | cut -c1-160 | mask)"
  fi
}

if [ ${#FROM[@]} -gt 0 ]; then
  for x in "${FROM[@]}"; do
    from_split "$x"
    if [ "$DRY" = 1 ]; then printf 'PLAN  %-7s rate the recorded %s output in %s\n' offline "$fmt" "$f"; continue; fi
    ARGS+=("F=$fmt" "L=$ref" "S=recorded $fmt $f" "$f")
    [ "$fmt" = trivy-version ] || SCANNERS="${SCANNERS:+$SCANNERS, }recorded $fmt"
  done
else
  if command -v trivy >/dev/null 2>&1; then
    scan offline trivy-version "" "trivy version" trivy version --format json
    scan offline trivy "" "trivy fs" trivy fs "${OFF[@]}" "${SKIP[@]}" "$ROOTABS"
    for t in ${TARS[@]+"${TARS[@]}"}; do
      ta="$(cd "$(dirname "$t")" && pwd)/$(basename "$t")"
      scan offline trivy "" "trivy image $(basename "$t")" trivy image "${OFF[@]}" --input "$ta"
    done
    for i in ${IMAGES[@]+"${IMAGES[@]}"}; do scan offline trivy "" "trivy image $i" trivy image "${OFF[@]}" --image-src docker,containerd,podman -- "$i"; done
  elif [ ${#TARS[@]} -gt 0 ] || [ ${#IMAGES[@]} -gt 0 ]; then
    FAILED="$FAILED|images not scanned: trivy is not installed"
  fi
  if [ "$NET" = 1 ]; then
    if ! command -v osv-scanner >/dev/null 2>&1; then SKIPPED="$SKIPPED|osv-scanner is not installed"
    elif [ "$DRY" = 1 ]; then  # the dry run runs nothing, so it cannot ask osv-scanner its version
      scan network osv "" "osv-scanner" osv-scanner scan source -r --format json "$ROOTABS"
      echo "      (osv-scanner 1.x: osv-scanner --format json -r PATH)"
    elif osv-scanner --version 2>/dev/null | grep -qE 'version:? *[2-9]\.'; then scan network osv "" "osv-scanner" osv-scanner scan source -r --format json "$ROOTABS"
    else scan network osv "" "osv-scanner" osv-scanner --format json -r "$ROOTABS"; fi
    PRUNE='( -name node_modules -o -name .git -o -name .venv -o -name venv'
    [ "$TESTS" = 1 ] || PRUNE="$PRUNE -o -name tests -o -name test -o -name __tests__ -o -name fixtures -o -name spec"
    PRUNE="$PRUNE )"
    while IFS= read -r lk; do
      [ -n "$lk" ] || continue
      r="${lk#"$ROOT"/}"
      if ! command -v npm >/dev/null 2>&1; then SKIPPED="$SKIPPED|$r: not scanned by npm audit: npm is not installed"; continue; fi
      d="$ROOTABS"; case "$r" in */*) d="$ROOTABS/${r%/*}" ;; esac
      scan network npm-audit "$r" "npm audit $r" npm audit --json --package-lock-only --prefix "$d"
    done <<EOF_LOCKS
$(# shellcheck disable=SC2086
  find "$ROOT" -mindepth 1 $PRUNE -prune -o -name package-lock.json -type f -print 2>/dev/null | LC_ALL=C sort)
EOF_LOCKS
    while IFS= read -r rq; do
      [ -n "$rq" ] || continue
      r="${rq#"$ROOT"/}"
      if ! command -v pip-audit >/dev/null 2>&1; then SKIPPED="$SKIPPED|$r: not scanned by pip-audit: pip-audit is not installed"; continue; fi
      # only fully pinned files: pip-audit would otherwise resolve, which installs nothing
      # but downloads metadata for every range
      if grep -vE '^[[:space:]]*(#|-|$)' "$rq" | grep -qvE '^[A-Za-z0-9._-]+(\[[^]]*\])? *===? *[^ ;,]+'; then
        SKIPPED="$SKIPPED|$r: not scanned by pip-audit: not every requirement is pinned with =="; continue
      fi
      scan network pip-audit "$r" "pip-audit $r" pip-audit -r "$ROOTABS/$r" --no-deps --disable-pip --format json
    done <<EOF_REQS
$(# shellcheck disable=SC2086
  find "$ROOT" -mindepth 1 $PRUNE -prune -o -name 'requirements*.txt' -type f -print 2>/dev/null | LC_ALL=C sort)
EOF_REQS
  fi
  if ! command -v trivy >/dev/null 2>&1 && [ "$NET" = 0 ]; then
    UNMEASURED="unmeasured: trivy is not installed, and the network scanners need --allow-network"
  fi
fi
if [ "$DRY" = 1 ]; then
  set -f; IFS='|'; for m in $FAILED $SKIPPED $UNMEASURED; do [ -z "$m" ] || echo "NOTE  $m"; done; unset IFS; set +f
  echo "run-vuln-scan: dry run, nothing was scanned"; exit 0
fi
[ ${#ARGS[@]} -gt 0 ] || ARGS=(F=none L= S= /dev/null)

LC_ALL=C awk -v THRESH="$THRESH" -v MAXAGE="$MAXAGE" -v MATURITY="$MATURITY" -v WAIVED="$WAIVED" \
  -v TODAY="$TODAY" -v ROOT="$ROOT" -v ROOTABS="$ROOTABS" -v SCANNERS="$SCANNERS" -v FAILED="$FAILED" \
  -v SKIPPED="$SKIPPED" -v UNMEASURED="$UNMEASURED" -f "$LIB/json.awk" -f "$LIB/normalise-vulns.awk" "${ARGS[@]}"
