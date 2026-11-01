#!/usr/bin/env bash
# Behavior test for plugins/ascent-ops/scripts/check-drills.sh.
#
# The good fixture (fixtures/drills-good: a restore path, a failover path the IaC
# declares, a paging alert, and a passing record of every kind) passes all eleven
# checks except OPS-R6, which has no failed drill to check. Each check then gets
# negative controls: a copy broken in exactly one way fails that check and no
# other. Also covers durations, the maturity levels, values never printed, the
# blueprint's real restore drill, IaC detection, and bad input.
#
# Runs with the default awk and every other awk found (mawk, gawk, BWK awk).
# Prints "test-check-drills: N/N PASS" last (make/test-plugins.sh T11 requires it).
# Portable: bash 3.2+, GNU/Linux and BSD/macOS.

set -u
WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT INT TERM

HERE="$(cd "$(dirname "$0")" && pwd)"
CHECK="$HERE/../../../plugins/ascent-ops/scripts/check-drills.sh"
GOOD="$HERE/fixtures/drills-good"
BP="$HERE/../../../plugins/ascent-ops/blueprints/operable-service"
DR=docs/operations/drills; RB=docs/operations/runbooks; MO=docs/operations/MAINTENANCE-AND-OPERATIONS.md
for f in "$CHECK" "$GOOD/$DR/2026-10-30-db.md" "$GOOD/infra/main.tf" "$BP/drills/2026-11-01-db.md"; do [ -f "$f" ] || { echo "test-check-drills: missing $f"; echo "test-check-drills: 0/1 PASS"; exit 1; }; done

PASS=0; FAIL=0
ok()  { PASS=$((PASS + 1)); }
bad() { FAIL=$((FAIL + 1)); printf "FAIL  [%s] %s\n" "$AWKNAME" "$1"; }
run_in() {  # DIR ARGS... -> RC, OUT
  local d="$1"; shift
  (cd "$d" && PATH="$SHIM:$PATH" bash "$CHECK" "$@") >"$WORK/out" 2>"$WORK/err"; RC=$?
  OUT=$(cat "$WORK/out" "$WORK/err")
}
# chk NAME [ARGS] — the fixture's contract values; NODB, NOORD, NOALERT, NOREADY and
# NORTO drop one, PDB, ALERT and RTOV replace one, TODAY and MATURITY set the run.
chk() {
  local n="$1"; shift
  local a=(--today "${TODAY:-2026-11-01}" --maturity "${MATURITY:-enterprise}" --manual "$MO" --iac infra --iac compose.yml)
  [ "${NORTO:-0}" = 1 ] || a+=(--rto "${RTOV:-4h}" --rpo 24h)
  [ "${NOREADY:-0}" = 1 ] || a+=(--ready-path /-/ready)
  [ "${NODB:-0}" = 1 ] || a+=(--path "${PDB:-db:restore:$RB/restore-db.md}")
  [ "${NOORD:-0}" = 1 ] || a+=(--path "orders:failover:$RB/failover-orders.md")
  [ "${NOALERT:-0}" = 1 ] || a+=(--alert "${ALERT:-ready-failing:$RB/ready-failing.md:page}")
  run_in "$WORK/$n" "${a[@]}" "$@" "$DR"
}
mk() { rm -rf "${WORK:?}/$1"; cp -R "$GOOD" "$WORK/$1"; }
q() { printf '%s' "$1" | sed 's/"/\\"/g'; }
after() { printf '{ print } index($0, "%s") && !d { print "%s"; d = 1 }' "$(q "$1")" "$(q "$2")"; }
subst() { printf '{ if (index($0, "%s")) { i = index($0, "%s"); $0 = substr($0, 1, i - 1) "%s" substr($0, i + length("%s")) } print }' "$(q "$1")" "$(q "$1")" "$(q "$2")" "$(q "$1")"; }
drop()  { printf 'index($0, "%s") { next } { print }' "$(q "$1")"; }
edit() {
  awk "$3" "$WORK/$1/$2" > "$WORK/edit.tmp"
  if cmp -s "$WORK/$1/$2" "$WORK/edit.tmp"; then bad "$1: edit of $2 changed nothing (stale anchor)"; return 1; fi
  mv "$WORK/edit.tmp" "$WORK/$1/$2"
}
# rec NAME FILE — a record in copy NAME from "key value" lines on stdin.
rec() { { printf '# Drill\n\n| Field | Value |\n|---|---|\n'; while read -r k v; do printf '| %s | %s |\n' "$k" "$v"; done; } > "$WORK/$1/$DR/$2"; }
expect_only() {  # NAME CHECK [SEVERITY] — after chk
  nfail=$(printf '%s\n' "$OUT" | grep -c '^FAIL ' || true)
  nmine=$(printf '%s\n' "$OUT" | grep -c "^FAIL  $2 " || true)
  if [ "$RC" -ne 1 ]; then bad "$1: expected exit 1, got $RC: $(printf '%s\n' "$OUT" | grep -E '^FAIL|failure' | head -3 | tr '\n' ';')"
  elif [ "$nmine" -eq 0 ]; then bad "$1: $2 did not fail: $(printf '%s\n' "$OUT" | grep '^FAIL' | head -2 | tr '\n' ';')"
  elif [ "$nfail" -ne "$nmine" ]; then bad "$1: expected only $2 to fail, got: $(printf '%s\n' "$OUT" | grep '^FAIL' | cut -c1-100 | tr '\n' ';')"
  elif [ -n "${3:-}" ] && ! printf '%s\n' "$OUT" | grep -q "^FAIL  $2 *$3 "; then bad "$1: $2 should be $3: $(printf '%s\n' "$OUT" | grep "^FAIL  $2" | head -1)"
  else ok; fi
}
expect_pass() { if [ "$RC" -eq 0 ]; then ok; else bad "$1 should pass ($2): $(printf '%s\n' "$OUT" | grep '^FAIL' | head -2 | tr '\n' ';')"; fi; }
has() { if printf '%s\n' "$OUT" | grep -qF -- "$2"; then ok; else bad "$1: output lacks: $2"; fi; }
lacks() { if printf '%s\n' "$OUT" | grep -qF -- "$2"; then bad "$1: output must not contain: $2"; else ok; fi; }

matrix() {
  mk good; chk good
  if [ "$RC" -eq 0 ] && [ "$(printf '%s\n' "$OUT" | grep -c '^PASS ')" -eq 10 ] && printf '%s\n' "$OUT" | grep -q '^N/A   OPS-R6 .*no failed drill'; then ok
  else bad "good fixture should pass 10 and leave OPS-R6 N/A: exit $RC $(printf '%s\n' "$OUT" | grep -vE '^PASS' | tr '\n' ';')"; fi
  has good 'a record shows a drill was recorded consistently, not that it was honest'

  # OPS-R1 — a runbook per recovery path
  mk r1-missing;   rm "$WORK/r1-missing/$RB/restore-db.md"; chk r1-missing; expect_only r1-missing OPS-R1 Medium
  has r1-missing "db (restore): runbook $RB/restore-db.md not found"
  mk r1-none;      PDB="db:restore:" chk r1-none; expect_only r1-none OPS-R1 Medium
  mk r1-unmeasured; edit r1-unmeasured infra/main.tf "$(drop 'multi_az')" && NODB=1 NOORD=1 chk r1-unmeasured && expect_only r1-unmeasured OPS-R1 Low
  has r1-unmeasured 'orders (backup retention, infra/main.tf:7)'

  # OPS-R2 — the runbook standard
  mk r2-rollback;  edit r2-rollback "$RB/restore-db.md" "$(subst '## Rollback' '## Afterwards')" && chk r2-rollback && expect_only r2-rollback OPS-R2 Medium
  has r2-rollback 'lacks rollback'
  mk r2-stop;      edit r2-stop "$RB/failover-orders.md" "$(drop 'Stop if')" && chk r2-stop && expect_only r2-stop OPS-R2
  mk r2-pre;       edit r2-pre "$RB/restore-db.md" "$(subst '## Pre-flight' '## Before')" && chk r2-pre && expect_only r2-pre OPS-R2
  # A heading inside a code block is not a section.
  mk r2-code;      edit r2-code "$RB/restore-db.md" "$(subst '## Post-flight' '## Afterwards')" && printf '\n```\n## Post-flight\n```\n' >> "$WORK/r2-code/$RB/restore-db.md" && chk r2-code && expect_only r2-code OPS-R2

  # A backup the paths do not name is a NOTE; a runbook shared by two paths is reported once.
  mk r1-note;      printf 'resource "aws_db_instance" "billing" {\n  backup_retention_period = 7\n}\n' > "$WORK/r1-note/infra/billing.tf"; chk r1-note; expect_pass r1-note 'an unnamed backup is unrated'
  has r1-note 'backup retention on billing: list it in ops.drills.paths if it is a recovery path'
  mk r2-shared;    edit r2-shared "$RB/restore-db.md" "$(drop 'Stop if')" && chk r2-shared --path "cache:restore:$RB/restore-db.md"
  if [ "$(printf '%s\n' "$OUT" | grep -c '^FAIL  OPS-R2 ')" -eq 1 ]; then ok; else bad "r2-shared: a runbook shared by two paths should be reported once"; fi
  # An empty runbook exists: it lacks every part, it is not "not found".
  mk r2-empty;     : > "$WORK/r2-empty/$RB/restore-db.md"; chk r2-empty; expect_only r2-empty OPS-R2
  # A backslash in a runbook path is kept as written.
  mk r1-backslash; cp "$WORK/r1-backslash/$RB/restore-db.md" "$WORK/r1-backslash/$RB/re\\store-db.md"; PDB="db:restore:$RB/re\\store-db.md" chk r1-backslash; expect_pass r1-backslash 'a backslash in a runbook path'
  # A symlinked drills folder is read.
  mk r3-symlink;   mv "$WORK/r3-symlink/$DR" "$WORK/r3-symlink/drills-real" && ln -s ../../drills-real "$WORK/r3-symlink/$DR" && chk r3-symlink && expect_pass r3-symlink 'records behind a symlinked folder'

  # OPS-R3 — a current record per path, well formed
  mk r3-absent;    rm "$WORK/r3-absent/$DR/2026-10-20-orders.md"; chk r3-absent; expect_only r3-absent OPS-R3 Medium
  has r3-absent "no failover drill record for orders in $DR"
  mk r3-old;       edit r3-old "$DR/2026-10-20-orders.md" "$(subst '| date | 2026-10-20 |' '| date | 2026-07-01 |')" && mv "$WORK/r3-old/$DR/2026-10-20-orders.md" "$WORK/r3-old/$DR/2026-07-01-orders.md" && chk r3-old && expect_only r3-old OPS-R3
  has r3-old 'newest passing failover drill for orders is 123 days old (limit 90)'
  # A fresh failed drill with a follow-up does not make an old pass current.
  mk r3-stale-pass; edit r3-stale-pass "$DR/2026-10-20-orders.md" "$(subst '| date | 2026-10-20 |' '| date | 2026-07-01 |')" && mv "$WORK/r3-stale-pass/$DR/2026-10-20-orders.md" "$WORK/r3-stale-pass/$DR/2026-07-01-orders.md"
  printf 'path orders\nkind failover\ndate 2026-10-31\nresult fail\nevidence %s/evidence/2026-10-20-orders.txt\nfollow_up https://tracker.example/issues/15\n' "$DR" | rec r3-stale-pass 2026-10-31-orders.md
  chk r3-stale-pass; expect_only r3-stale-pass OPS-R3 Medium
  has r3-stale-pass 'newest passing failover drill for orders is 123 days old'
  mk r3-failonly;  edit r3-failonly "$DR/2026-10-20-orders.md" "$(subst '| result | pass |' '| result | fail |')" && edit r3-failonly "$DR/2026-10-20-orders.md" "$(subst '| follow_up | — |' '| follow_up | https://tracker.example/issues/16 |')" && chk r3-failonly && expect_only r3-failonly OPS-R3 Medium
  has r3-failonly 'no passing failover drill for orders; the newest, 2026-10-20, failed'
  TODAY=2027-01-18 chk good; if printf '%s\n' "$OUT" | grep -q '^FAIL  OPS-R3 '; then bad "r3-edge: a record exactly 90 days old is current"; else ok; fi
  mk r3-field;     edit r3-field "$DR/2026-10-20-orders.md" "$(drop '| result |')" && chk r3-field && expect_only r3-field OPS-R3
  has r3-field 'record is missing field(s): result'
  mk r3-name;      edit r3-name "$DR/2026-10-27-ready-failing-dry-run.md" "$(subst '| date | 2026-10-27 |' '| date | 2026-10-28 |')" && chk r3-name && expect_only r3-name OPS-R3
  has r3-name 'date 2026-10-28 differs from the file name'
  # A record's own format problems stay Low; values that are not plain are withheld.
  mk r3-result;    edit r3-result "$DR/2026-10-30-db.md" "$(subst '| result | pass |' '| result | acked by sam.doe@example.org |')" && chk r3-result
  has r3-result 'result is "<value withheld>"'; lacks r3-result 'sam.doe'
  mk r3-baddate;   printf 'path misc\nkind dry-run\ndate 2026-02-31\nresult pass\nevidence %s/evidence/2026-10-30-db.txt\n' "$DR" | rec r3-baddate 2026-02-31-misc.md; chk r3-baddate; expect_only r3-baddate OPS-R3 Low
  has r3-baddate 'date "2026-02-31" is not a YYYY-MM-DD calendar date'
  # An empty record is still a record, missing every field.
  mk r3-empty;     : > "$WORK/r3-empty/$DR/2026-10-29-empty.md"; chk r3-empty; [ "$RC" -eq 1 ] && ok || bad "r3-empty: an empty record should fail, got $RC"
  has r3-empty 'record is missing field(s): path kind date result'
  mk r3-kind;      printf 'path misc\nkind tabletop\ndate 2026-10-28\nresult pass\nevidence %s/evidence/2026-10-30-db.txt\n' "$DR" | rec r3-kind 2026-10-28-misc.md; chk r3-kind; expect_only r3-kind OPS-R3
  mk r3-future;    printf 'path misc\nkind dry-run\ndate 2026-12-01\nresult pass\nevidence %s/evidence/2026-10-30-db.txt\n' "$DR" | rec r3-future 2026-12-01-misc.md; chk r3-future; expect_only r3-future OPS-R3
  # A record for a path the contract does not name is a NOTE; other files are not records.
  mk r3-note;      printf 'path cache\nkind restore\ndate 2026-10-28\nresult pass\nevidence %s/evidence/2026-10-30-db.txt\n' "$DR" | rec r3-note 2026-10-28-cache.md; chk r3-note; expect_pass r3-note 'a record for an unknown path is unrated'
  has r3-note 'restore record for "cache", which no recovery path names'
  printf '| path | x |\n| kind | nonsense |\n' > "$WORK/r3-note/$DR/TEMPLATE.md"; chk r3-note; expect_pass r3-note 'a file not named YYYY-MM-DD-*.md is not a record'

  # OPS-R4 — the targets
  mk r4-rto;       edit r4-rto "$DR/2026-10-30-db.md" "$(subst '| measured_rto | 25m |' '| measured_rto | 4h1m |')" && chk r4-rto && expect_only r4-rto OPS-R4 Medium
  has r4-rto 'db: measured_rto 4h1m exceeds the rto target 4h'
  mk r4-edge;      edit r4-edge "$DR/2026-10-30-db.md" "$(subst '| measured_rto | 25m |' '| measured_rto | 3h60m |')" && chk r4-edge && expect_pass r4-edge 'exactly the target'
  mk r4-rpo;       edit r4-rpo "$DR/2026-10-20-orders.md" "$(subst '| measured_rpo | 0 |' '| measured_rpo | 1d1s |')" && chk r4-rpo && expect_only r4-rpo OPS-R4
  mk r4-unread;    edit r4-unread "$DR/2026-10-30-db.md" "$(subst '| measured_rpo | 6h |' '| measured_rpo | 6 hours |')" && chk r4-unread && expect_only r4-unread OPS-R4
  has r4-unread 'measured_rpo "6 hours" is not a duration'
  mk r4-missing;   edit r4-missing "$DR/2026-10-30-db.md" "$(drop '| measured_rto |')" && chk r4-missing && expect_only r4-missing OPS-R4
  RTOV=four chk good; [ "$RC" -eq 2 ] && ok || bad "r4-target: an rto that is not a duration should exit 2, got $RC"
  has r4-target 'durations such as 4h'
  # Only one target: rpo is not measured, rto is.
  mk r4-one;       edit r4-one "$DR/2026-10-30-db.md" "$(drop '| measured_rpo |')" && NORTO=1 chk r4-one --rto 4h && expect_pass r4-one 'no rpo target, no measured_rpo needed'
  NORTO=1 chk good; expect_pass r4-none 'no target'
  if printf '%s\n' "$OUT" | grep -q '^N/A   OPS-R4 .*no rto or rpo target (unmeasured)'; then ok; else bad "r4-none: should be N/A, unmeasured: $(printf '%s\n' "$OUT" | grep OPS-R4)"; fi
  # The newest passing record is the one measured; an older slow one does not count.
  mk r4-newest;    printf 'path db\nkind restore\ndate 2026-09-01\nresult pass\nmeasured_rto 9h\nmeasured_rpo 1h\nevidence %s/evidence/2026-10-30-db.txt\n' "$DR" | rec r4-newest 2026-09-01-db.md; chk r4-newest; expect_pass r4-newest 'an older record over the target'

  # OPS-R5 — evidence present, inside the repository, clean (values never printed)
  mk r5-none;      edit r5-none "$DR/2026-10-25-ready-failing.md" "$(subst "| evidence | $DR/evidence/2026-10-25-ready-failing.txt |" '| evidence | — |')" && chk r5-none && expect_only r5-none OPS-R5 Medium
  mk r5-missing;   rm "$WORK/r5-missing/$DR/evidence/2026-10-20-orders.txt"; chk r5-missing; expect_only r5-missing OPS-R5 Medium
  has r5-missing "evidence $DR/evidence/2026-10-20-orders.txt not found"
  mk r5-abs;       edit r5-abs "$DR/2026-10-30-db.md" "$(subst "| evidence | $DR/" '| evidence | /var/log/drill/')" && chk r5-abs && expect_only r5-abs OPS-R5
  mk r5-up;        edit r5-up "$DR/2026-10-30-db.md" "$(subst "| evidence | $DR/" "| evidence | $DR/../../")" && chk r5-up && expect_only r5-up OPS-R5
  mk r5-url;       edit r5-url "$DR/2026-10-30-db.md" "$(subst "| evidence | $DR/" '| evidence | https://logs.example/')" && chk r5-url && expect_only r5-url OPS-R5
  mk r5-link;      edit r5-link "$DR/2026-10-30-db.md" "$(subst "| evidence | $DR/evidence/2026-10-30-db.txt |" "| evidence | [output]($DR/evidence/2026-10-30-db.txt), $DR/evidence/2026-10-20-orders.txt |")" && chk r5-link && expect_pass r5-link 'a Markdown link and a list are read'
  mk r5-secret;    printf 'DB_PASSWORD=hunter2-fixture-value\n' >> "$WORK/r5-secret/$DR/evidence/2026-10-30-db.txt"; chk r5-secret; expect_only r5-secret OPS-R5 High
  if printf '%s\n' "$OUT" | grep -q 'hunter2-fixture-value'; then bad "r5-secret: the value was printed"; else ok; fi
  has r5-secret "$DR/evidence/2026-10-30-db.txt:6"
  mk r5-akia;      printf '\naws_access_key_id AKIAABCDEFGHIJKLMNOP\n' >> "$WORK/r5-akia/$DR/2026-10-20-orders.md"; chk r5-akia; expect_only r5-akia OPS-R5 High
  mk r5-pem;       printf '\n-----BEGIN OPENSSH PRIVATE KEY-----\n' >> "$WORK/r5-pem/$DR/evidence/2026-10-30-db.txt"; chk r5-pem; expect_only r5-pem OPS-R5 High
  has r5-pem 'private key block'
  mk r5-email;     printf '\nAcknowledged by sam.doe@example.org\n' >> "$WORK/r5-email/$DR/2026-10-25-ready-failing.md"; chk r5-email; expect_only r5-email OPS-R5 Medium
  mk r5-phone;     printf 'paged +1 555 123 4567\n' >> "$WORK/r5-phone/$DR/evidence/2026-10-25-ready-failing.txt"; chk r5-phone; expect_only r5-phone OPS-R5 Medium
  mk r5-clean;     printf 'token: ${API_TOKEN}\napi_token = ***\nfinished 2026-11-01T19:28:25Z after 1480 s, 10.0.0.12\npassword: stored in the vault\ntoken_count=123456\npassword_expires_at: 2026-12-01\nBasic auth disabled\n' >> "$WORK/r5-clean/$DR/evidence/2026-10-30-db.txt"; chk r5-clean; expect_pass r5-clean 'placeholders, timestamps, addresses, prose and counters are not credentials or phone numbers'
  # Shapes a drill's output takes: an assignment before a command, an option, JSON,
  # a connection string, an authorization header and a table row in the record.
  n=0
  for line in 'PGPASSWORD=Xy9kLmNqPw pg_restore -h scratch -d app dump.sql' 'mysql --password=Xy9kLmNqPw orders' '{"user":"app","password":"Xy9kLmNqPw"}' 'postgres://admin:Xy9kLmNqPw@db.internal.example.com:5432/app' 'Authorization: Bearer abcdefghijklmnopqrstuvwxyz0123' '| db_password | Xy9kLmNqPw |'; do
    n=$((n + 1)); mk "r5-shape$n"; printf '%s\n' "$line" >> "$WORK/r5-shape$n/$DR/evidence/2026-10-30-db.txt"; chk "r5-shape$n"; expect_only "r5-shape$n" OPS-R5 High
    lacks "r5-shape$n" 'Xy9kLmNqPw'; lacks "r5-shape$n" 'abcdefghijklmnop'
  done
  # A value that is not plain never reaches a message: a token in the probe, a
  # password in an evidence URL.
  mk r5-probe;     edit r5-probe "$DR/2026-10-26-db-down.md" "$(subst '| probe | /-/ready |' '| probe | http://localhost:8080/-/ready?token=AbC123secretvalue |')" && chk r5-probe
  lacks r5-probe 'AbC123secretvalue'; has r5-probe '(probe <value withheld>'
  mk r5-evurl;     edit r5-evurl "$DR/2026-10-30-db.md" "$(subst "| evidence | $DR/evidence/2026-10-30-db.txt |" '| evidence | https://ci:ghp0123456789abcdef@ci.example/x.log |')" && chk r5-evurl
  lacks r5-evurl 'ghp0123456789abcdef'; has r5-evurl 'evidence <value withheld> is outside the repository'

  # OPS-R6 — failed drills followed up
  mk r6;           printf 'path db\nkind restore\ndate 2026-10-31\nresult fail\nevidence %s/evidence/2026-10-30-db.txt\nfollow_up —\n' "$DR" | rec r6 2026-10-31-db.md; chk r6; expect_only r6 OPS-R6 Medium
  mk r6-issue;     printf 'path db\nkind restore\ndate 2026-10-31\nresult fail\nevidence %s/evidence/2026-10-30-db.txt\nfollow_up https://tracker.example/issues/12\n' "$DR" | rec r6-issue 2026-10-31-db.md; chk r6-issue; expect_pass r6-issue 'a follow-up link'
  mk r6-later;     printf 'path db\nkind restore\ndate 2026-10-29\nresult fail\nevidence %s/evidence/2026-10-30-db.txt\n' "$DR" | rec r6-later 2026-10-29-db.md; chk r6-later; expect_pass r6-later 'a later passing drill'

  # OPS-R7 — the manual's restore date
  mk r7-old;       edit r7-old "$MO" "$(subst 'Last restore drill: 2026-10-30' 'Last restore drill: 2026-10-01')" && chk r7-old && expect_only r7-old OPS-R7 Low
  has r7-old "the manual's last restore is 2026-10-01; the newest restore drill is 2026-10-30"
  # A planned date in the section is not a restore.
  mk r7-planned;   edit r7-planned "$MO" "$(subst 'Last restore drill: 2026-10-30' 'Last restore drill: 2026-10-01')" && printf '\nNext restore drill: 2027-01-15\n' > "$WORK/r7-planned/next.tmp" && edit r7-planned "$MO" "$(after 'Last restore drill' 'Next restore drill: 2027-01-15')" && chk r7-planned && expect_only r7-planned OPS-R7
  mk r7-nomanual;  rm "$WORK/r7-nomanual/$MO"; chk r7-nomanual; expect_only r7-nomanual OPS-R7
  has r7-nomanual "manual $MO not found"
  mk r7-none;      edit r7-none "$MO" "$(drop 'Last restore drill')" && chk r7-none && expect_only r7-none OPS-R7
  # A date in another section does not count.
  mk r7-section;   edit r7-section "$MO" "$(drop 'Last restore drill')" && printf '\nRestore drill: 2026-10-30\n' >> "$WORK/r7-section/$MO" && chk r7-section && expect_only r7-section OPS-R7

  # OPS-R8 — declared failover has a failover path
  NOORD=1 chk good; expect_only r8 OPS-R8 Low
  has r8 'orders (Multi-AZ, infra/main.tf:7)'
  mk r8-cfn;       edit r8-cfn infra/main.tf "$(drop 'multi_az')" && printf 'Resources:\n  Db:\n    Type: AWS::RDS::DBInstance\n    Properties:\n      MultiAZ: true\n' > "$WORK/r8-cfn/infra/db.yaml" && NOORD=1 chk r8-cfn && expect_only r8-cfn OPS-R8
  mk r8-dns;       edit r8-dns infra/main.tf "$(drop 'multi_az')" && printf 'resource "aws_route53_record" "api" {\n  failover_routing_policy {\n    type = "PRIMARY"\n  }\n}\n' > "$WORK/r8-dns/infra/dns.tf" && NOORD=1 chk r8-dns && expect_only r8-dns OPS-R8
  mk r8-replica;   edit r8-replica infra/main.tf "$(drop 'multi_az')" && printf 'resource "aws_dynamodb_table" "sessions" {\n  name = "sessions"\n  replica {\n    region_name = "us-west-2"\n  }\n}\n' > "$WORK/r8-replica/infra/table.tf" && NOORD=1 chk r8-replica && expect_only r8-replica OPS-R8
  # A setting before any resource in a second file is not named after the first file's resource.
  mk r8-carry;     edit r8-carry infra/main.tf "$(drop 'multi_az')" && printf '  multi_az = true\n' > "$WORK/r8-carry/infra/z.tf" && NOORD=1 chk r8-carry && expect_only r8-carry OPS-R8
  has r8-carry ' (Multi-AZ, infra/z.tf:1)'; lacks r8-carry 'orders (Multi-AZ, infra/z.tf'
  mk r8-comment;   edit r8-comment infra/main.tf "$(subst '  multi_az                = true' '  # multi_az = true')" && NOORD=1 chk r8-comment && expect_pass r8-comment 'a commented setting declares nothing'

  # OPS-X1 — paging alarms exercised
  mk x1;           rm "$WORK/x1/$DR/2026-10-25-ready-failing.md"; chk x1; expect_only x1 OPS-X1 Low
  mk x1-reached;   edit x1-reached "$DR/2026-10-25-ready-failing.md" "$(drop '| reached |')" && chk x1-reached && expect_only x1-reached OPS-X1
  has x1-reached 'alarm drill for ready-failing does not say which role it reached'
  # A passing alarm drill older than --max-age no longer counts.
  mk x1-stale;     mv "$WORK/x1-stale/$DR/2026-10-25-ready-failing.md" "$WORK/x1-stale/$DR/2026-07-01-ready-failing.md"
  edit x1-stale "$DR/2026-07-01-ready-failing.md" "$(subst '| date | 2026-10-25 |' '| date | 2026-07-01 |')" && chk x1-stale && expect_only x1-stale OPS-X1 Low
  has x1-stale 'paging alert ready-failing has no passing alarm drill in the last 90 days'
  mk x1-nopage;    rm "$WORK/x1-nopage/$DR/2026-10-25-ready-failing.md"; ALERT="ready-failing:$RB/ready-failing.md" chk x1-nopage; expect_pass x1-nopage 'an alert that does not page'
  mk x1-failed;    edit x1-failed "$DR/2026-10-25-ready-failing.md" "$(subst '| result | pass |' '| result | fail |')" && edit x1-failed "$DR/2026-10-25-ready-failing.md" "$(subst '| follow_up | — |' '| follow_up | https://tracker.example/issues/14 |')" && chk x1-failed && expect_only x1-failed OPS-X1

  # OPS-X2 — readiness fails with a dependency down
  mk x2-200;       edit x2-200 "$DR/2026-10-26-db-down.md" "$(subst '| probe_status | 503 |' '| probe_status | 200 |')" && chk x2-200 && expect_only x2-200 OPS-X2 Low
  mk x2-path;      edit x2-path "$DR/2026-10-26-db-down.md" "$(subst '| probe | /-/ready |' '| probe | /healthz |')" && chk x2-path && expect_only x2-path OPS-X2
  mk x2-other;     edit x2-other "$DR/2026-10-26-db-down.md" "$(subst '| probe | /-/ready |' '| probe | /api/-/ready |')" && chk x2-other && expect_only x2-other OPS-X2
  mk x2-url;       edit x2-url "$DR/2026-10-26-db-down.md" "$(subst '| probe | /-/ready |' '| probe | http://localhost:8080/-/ready |')" && chk x2-url && expect_pass x2-url 'a full URL ending in the ready path'
  mk x2-stale;     mv "$WORK/x2-stale/$DR/2026-10-26-db-down.md" "$WORK/x2-stale/$DR/2026-07-01-db-down.md"
  edit x2-stale "$DR/2026-07-01-db-down.md" "$(subst '| date | 2026-10-26 |' '| date | 2026-07-01 |')" && chk x2-stale && expect_only x2-stale OPS-X2 Low
  has x2-stale 'no passing readiness drill in the last 90 days'
  mk x2-absent;    rm "$WORK/x2-absent/$DR/2026-10-26-db-down.md"; chk x2-absent; expect_only x2-absent OPS-X2
  NOREADY=1 chk good; expect_pass x2-na 'no ready path'

  # OPS-X3 — alert runbooks dry-run
  mk x3;           edit x3 "$DR/2026-10-27-ready-failing-dry-run.md" "$(subst "| runbook | $RB/ready-failing.md |" "| runbook | $RB/restore-db.md |")" && chk x3 && expect_only x3 OPS-X3 Low
  has x3 "runbook $RB/ready-failing.md (alert ready-failing) has no passing dry-run in the last 90 days"
  TODAY=2027-01-26 chk good; if printf '%s\n' "$OUT" | grep -q '^FAIL  OPS-X3 '; then ok; else bad "x3-old: a dry-run 91 days old is not current"; fi

  # Maturity: standard asks for R1–R5, prototype for nothing but a clean record.
  mk mat;          rm "$WORK/mat/$DR/2026-10-25-ready-failing.md"; MATURITY=standard chk mat; expect_pass mat-standard 'OPS-X1 is not required at standard'
  if printf '%s\n' "$OUT" | grep -q '^N/A   OPS-X1 .*(not required at standard)'; then ok; else bad "mat-standard: OPS-X1 should be N/A"; fi
  rm "$WORK/mat/$RB/restore-db.md"; MATURITY=prototype chk mat; expect_pass mat-prototype 'nothing is required at prototype'
  mk mat-secret;   printf 'DB_PASSWORD=hunter2-fixture-value\n' >> "$WORK/mat-secret/$DR/evidence/2026-10-30-db.txt"; printf 'Acknowledged by sam.doe@example.org\n' >> "$WORK/mat-secret/$DR/2026-10-30-db.md"
  MATURITY=prototype chk mat-secret; expect_only mat-secret OPS-R5 High
  if [ "$(printf '%s\n' "$OUT" | grep -c '^FAIL ')" -eq 1 ] && printf '%s\n' "$OUT" | grep -q ', 1 failure(s);'; then ok; else bad "mat-secret: only the High credential line counts at prototype: $(printf '%s\n' "$OUT" | grep -E '^FAIL|failure' | tr '\n' ';')"; fi

  # The blueprint's real restore drill passes against its own contract values.
  run_in "$BP" --today 2026-11-01 --rto 4h --rpo 24h --manual MAINTENANCE-AND-OPERATIONS.md --path db:restore:runbooks/restore-db.md --iac . drills
  if [ "$RC" -eq 0 ] && [ "$(printf '%s\n' "$OUT" | grep -c '^PASS ')" -eq 6 ]; then ok; else bad "blueprint drill should pass R1–R5 and R7: exit $RC $(printf '%s\n' "$OUT" | grep -vE '^(PASS|N/A)' | tr '\n' ';')"; fi
  # With no path given, the blueprint's database is proposed (unmeasured).
  run_in "$BP" --today 2026-11-01 --iac . drills
  if printf '%s\n' "$OUT" | grep -q '^FAIL  OPS-R1  Low    compose.yml:.*db (database volume'; then ok; else bad "blueprint without paths: the db volume should be reported: $(printf '%s\n' "$OUT" | grep OPS-R1)"; fi

  # Bad input and help.
  run_in "$WORK/good" --maturity gold "$DR"; [ "$RC" -eq 2 ] && ok || bad "a bad --maturity should exit 2, got $RC"
  run_in "$WORK/good" --path db:backup:x.md "$DR"; [ "$RC" -eq 2 ] && ok || bad "a bad --path kind should exit 2, got $RC"
  run_in "$WORK/good" --path 'd b:restore:x.md' "$DR"; [ "$RC" -eq 2 ] && ok || bad "a --path name with a space should exit 2, got $RC"
  run_in "$WORK/good" --path db:restore "$DR"; [ "$RC" -eq 2 ] && ok || bad "a --path without a runbook field should exit 2, got $RC"
  run_in "$WORK/good" --alert x:y:z "$DR"; [ "$RC" -eq 2 ] && ok || bad "an --alert ending in other than :page should exit 2, got $RC"
  run_in "$WORK/good" --today 01-11-2026 "$DR"; [ "$RC" -eq 2 ] && ok || bad "a bad --today should exit 2, got $RC"
  for bad_today in 2026-19-45 2026-02-29 2026-04-31; do run_in "$WORK/good" --today "$bad_today" "$DR"; [ "$RC" -eq 2 ] && ok || bad "--today $bad_today is not a calendar date and should exit 2, got $RC"; done
  run_in "$WORK/good" --today 2028-02-29 "$DR"; [ "$RC" -ne 2 ] && ok || bad "--today 2028-02-29 is a leap day"
  run_in "$WORK/good" --rto 90min "$DR"; [ "$RC" -eq 2 ] && ok || bad "--rto 90min should exit 2, got $RC"
  run_in "$WORK/good" --rpo 1h30m "$DR"; [ "$RC" -ne 2 ] && ok || bad "--rpo 1h30m is a duration"
  run_in "$WORK/good" --max-age ninety "$DR"; [ "$RC" -eq 2 ] && ok || bad "a non-numeric --max-age should exit 2, got $RC"
  run_in "$WORK/good" "$DR" --rto; [ "$RC" -eq 2 ] && ok || bad "an option without a value should exit 2, got $RC"
  run_in "$WORK/good" --colour "$DR"; [ "$RC" -eq 2 ] && ok || bad "an unknown option should exit 2, got $RC"
  run_in "$WORK/good" --repo no-such-dir "$DR"; [ "$RC" -eq 2 ] && ok || bad "a --repo that is not a directory should exit 2, got $RC"
  run_in "$WORK/good" --manual "$DR" "$DR"; [ "$RC" -eq 2 ] && ok || bad "a --manual that is not a file should exit 2, got $RC"
  run_in "$WORK/good" --path db:restore:a:b.md "$DR"; [ "$RC" -eq 2 ] && ok || bad "a --path runbook holding ':' should exit 2, got $RC"
  run_in "$WORK/good" --alert noseparator "$DR"; [ "$RC" -eq 2 ] && ok || bad "an --alert without ':' should exit 2, got $RC"
  run_in "$WORK/good" --alert 'bad name:x.md' "$DR"; [ "$RC" -eq 2 ] && ok || bad "an --alert name with a space should exit 2, got $RC"
  # A path starting with "-" is a path, never an option to find.
  mkdir -p "$WORK/good/-iac"; cp "$WORK/good/infra/main.tf" "$WORK/good/-iac/db.tf"
  run_in "$WORK/good" --iac -iac "$DR"; [ "$RC" -ne 2 ] && ok || bad "an --iac folder named -iac should be read, got $RC"
  has dash-iac '(Multi-AZ, -iac/db.tf:7)'
  run_in "$WORK/good" "$MO"; [ "$RC" -eq 2 ] && ok || bad "a file as DRILLS-DIR should exit 2, got $RC"
  run_in "$WORK/good" --iac no-such-dir "$DR"; [ "$RC" -eq 2 ] && ok || bad "a missing --iac path should exit 2, got $RC"
  run_in "$WORK/good" "$DR" extra; [ "$RC" -eq 2 ] && ok || bad "two directories should exit 2, got $RC"
  run_in "$WORK/good" --today 2026-11-01 --path "db:restore:$RB/restore-db.md" no-such-dir
  if [ "$RC" -eq 1 ] && printf '%s\n' "$OUT" | grep -q '^FAIL  OPS-R3  Medium absent  no restore drill record for db in no-such-dir'; then ok; else bad "a missing drills folder is no records: $(printf '%s\n' "$OUT" | grep -E '^FAIL' | head -2 | tr '\n' ';')"; fi
  run_in "$WORK/good" --help; if [ "$RC" -eq 0 ] && printf '%s\n' "$OUT" | grep -q '^Usage: check-drills.sh'; then ok; else bad "--help should print usage and exit 0"; fi
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

printf "test-check-drills: %s/%s PASS (awk: %s)\n" "$PASS" "$((PASS + FAIL))" "$AWKS"
[ "$FAIL" -eq 0 ]
