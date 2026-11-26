#!/usr/bin/env bash
# Behavior test for the launch records of plugins/ascent-governance/scripts/check-audit.sh:
# --record, and the sign-off rules GOV-L3–L5.
#
# On throwaway git repositories: --record writes an unsigned launch record that
# names the commit it describes, and refuses to overwrite one or to describe a
# working copy that differs from that commit. A rung with sign_off needs the
# newest record of its environment signed by a person (GOV-L3), by an approver
# when the contract lists approvers (GOV-L4), with nothing but governance records
# changed since the commit it names (GOV-L5). Each rule gets negative controls:
# a repository broken in exactly one way fails that rule and no other. Also
# covers a shallow clone, --no-git, a launch folder with a space in its name,
# sign-off inherited up the ladder, and the review log's history after a signed
# launch.
#
# Runs with the default awk and every other awk found (mawk, gawk, BWK awk).
# Prints "test-launch-records: N/N PASS" last (make/test-plugins.sh T11 requires it).
# Portable: bash 3.2+, GNU/Linux and BSD/macOS.

set -u
NAME=test-launch-records
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/lib.sh"
CHECK="$PLUGIN/scripts/check-audit.sh"
GOVVER=$(sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$PLUGIN/.claude-plugin/plugin.json" | head -1)   # the record names the plugin's own version
need "$CHECK" "$PLUGIN/scripts/lib/render.awk" "$FIX/stub-checker.sh"
LD=docs/governance/launches
REC=$LD/2026-12-02-prod.md

# repo NAME [LADDER] — a committed repository whose prod rung needs a signature
repo() {
  stubs; rm -rf "${WORK:?}/$1"; mkdir -p "$WORK/$1/.ascent" "$WORK/$1/src" "$WORK/$1/docs/adr"
  cat > "$WORK/$1/$CON" <<EOC
version: 1
governance:
  environments: ${2:-[local, beta, prod]}
  floors:
    local:
      checks: [ascent-security/check-env]
    prod:
      checks: [ascent-docs/check-docs]
      sign_off: true
  approvers: []
EOC
  printf '# Readme\n' > "$WORK/$1/README.md"; printf 'console.log(1)\n' > "$WORK/$1/src/app.js"
  printf '# ADR-021: Accept the open redirect\n\n**Status:** Accepted\n' > "$WORK/$1/docs/adr/ADR-021-open-redirect.md"
  G "$1" init -q; G "$1" add -A; G "$1" commit -q -m one
}
rec() { local n="$1"; shift; GIT=1 chk "$n" --env prod --record "$REC" "$@"; }
# sign NAME FILE SIGNER DATE — a person signs, and commits the record
sign() {
  edit "$1" "$2" "/^\\*\\*Signed:\\*\\*/ { print \"**Signed:** $3\"; next } /^\\*\\*Date:\\*\\*/ { print \"**Date:** $4\"; next } { print }" || return 1
  G "$1" add -A; G "$1" commit -q -m "sign $2"
}
# signed NAME — a repository with a signed, committed prod record
signed() { repo "$1" "${2:-}"; rec "$1"; sign "$1" "$REC" 'Ana Lopez' 2026-12-02; }
file_has() { if grep -qF -- "$3" "$WORK/$1/$2" 2>/dev/null; then ok; else bad "$1: $2 lacks: $3"; fi; }
file_lacks() { if grep -qF -- "$3" "$WORK/$1/$2" 2>/dev/null; then bad "$1: $2 must not contain: $3"; else ok; fi; }
file_line() { if grep -qxF -- "$3" "$WORK/$1/$2" 2>/dev/null; then ok; else bad "$1: $2 has no line: $3"; fi; }
no_file() { if [ -e "$WORK/$1/$2" ]; then bad "$1: $2 was written"; else ok; fi; }
change() { printf 'console.log(2)\n' >> "$WORK/$1/${2:-src/app.js}"; G "$1" add -A; G "$1" commit -q -m change; }

matrix() {
  # --record writes the record, unsigned
  repo record-written; h=$(head_of record-written); rec record-written; expect_rc record-written 0
  has record-written "wrote $REC"; has record-written 'awaiting signature'; lacks record-written 'GOV-L3'
  for s in '# Launch record: record-written, prod' "2026-12-02 · commit $h · maturity prototype (no maturity_target in .ascent/contract.yml) · ascent-governance $GOVVER" \
           '**Verdict:** GO' '## In plain words' '<!-- summary: written by launch-readiness -->' '## Evidence' '| What | Kind | Result | Source |' \
           '| ascent-docs/check-docs passes | check | pass | ascent-docs/check-docs |' '## Waivers in force' '## Conditions' '## Sign-off'; do file_has record-written "$REC" "$s"; done
  file_line record-written "$REC" '**Signed:**'; file_line record-written "$REC" '**Date:**'; file_line record-written "$REC" '**Verdict:** GO'
  file_lacks record-written "$REC" 'wrote '
  if [ "$(grep -c '^None\.$' "$WORK/record-written/$REC")" -eq 2 ]; then ok; else bad "record-written: waivers and conditions should each say None."; fi

  # it never overwrites a record
  cp "$WORK/record-written/$REC" "$WORK/keep.md"; rec record-written; expect_rc record-exists 2; has record-exists 'exists'
  if cmp -s "$WORK/keep.md" "$WORK/record-written/$REC"; then ok; else bad "record-exists: the record was changed"; fi

  # it describes a commit, so the working copy must be that commit
  repo record-dirty; printf 'console.log(2)\n' >> "$WORK/record-dirty/src/app.js"; rec record-dirty; expect_rc record-dirty 2; no_file record-dirty "$REC"; has record-dirty 'src/app.js'
  repo record-untracked; printf 'x\n' > "$WORK/record-untracked/new.txt"; rec record-untracked; expect_rc record-untracked 2; no_file record-untracked "$REC"; has record-untracked 'new.txt'
  repo record-governance-only; mkdir -p "$WORK/record-governance-only/$LD"; printf '# an older record\n' > "$WORK/record-governance-only/$LD/2026-01-01-beta.md"
  printf '# Review log\n' > "$WORK/record-governance-only/docs/governance/review-log.md"; rec record-governance-only; expect_rc record-governance-only 0
  repo record-no-git; chk record-no-git --env prod --record "$REC"; expect_rc record-no-git 2; no_file record-no-git "$REC"; has record-no-git 'git'
  repo record-name; GIT=1 chk record-name --env prod --record "$LD/prod.md"; expect_rc record-name 2; has record-name "$REC"
  GIT=1 chk record-name --env prod --record "notes/2026-12-02-prod.md"; expect_rc record-elsewhere 2; no_file record-name notes/2026-12-02-prod.md
  GIT=1 chk record-name --env prod --record "$LD/2026-12-02-beta.md"; expect_rc record-other-env 2
  GIT=1 chk record-name --env prod --record; expect_rc record-no-value 2

  repo record-moved; mkdir -p "$WORK/record-moved/$LD"; G record-moved mv src/app.js "$LD/app.js"; rec record-moved; expect_rc record-moved 2; no_file record-moved "$REC"; has record-moved 'src/app.js'
  # the contract's launch_dir ends with a slash: the path the skill builds from it has two, and is the same file
  repo record-two-slashes; GIT=1 chk record-two-slashes --env prod --record "$LD//2026-12-02-prod.md"; expect_rc record-two-slashes 0; file_line record-two-slashes "$REC" '**Verdict:** GO'
  # the path is read from where the command is run, as --contract and --plugins are
  repo record-from-elsewhere; mkdir -p "$WORK/elsewhere/deep"
  (cd "$WORK/elsewhere/deep" && PATH="$SHIM:$PATH" HOME="$WORK/home" GIT_CONFIG_NOSYSTEM=1 STUB_LOG="$WORK/log" STUB_CTL="$WORK/ctl" bash "$CHECK" --plugins "$WORK/stubs" --today 2026-12-02 --env prod --record "../../record-from-elsewhere/$REC" ../../record-from-elsewhere) >"$WORK/out" 2>"$WORK/err"; RC=$?; OUT=$(cat "$WORK/out" "$WORK/err")
  expect_rc record-from-elsewhere 0; file_line record-from-elsewhere "$REC" '**Verdict:** GO'
  # a NO-GO is recorded too
  repo record-nogo; stub_rc ascent-docs/check-docs 1; rec record-nogo; expect_rc record-nogo 1; file_line record-nogo "$REC" '**Verdict:** NO-GO'
  file_has record-nogo "$REC" '1. **High** GOV-L1: ascent-docs/check-docs failed'; file_has record-nogo "$REC" '| FAIL (High) |'
  # conditions, waivers and reviews in the record
  repo record-full; printf 'security:\n  waivers:\n    - id: ADR-021\n      skips: "SEC-L4 on a|b <b>redirect</b>"\n      review_by: 2026-12-10\n' >> "$WORK/record-full/$CON"
  edit record-full $CON '{ print } /^      sign_off: true/ { print "      reviews: { sec-posture: 30 }" }'
  G record-full add -A; G record-full commit -q -m waiver; mkdir -p "$WORK/empty"; PLUGINS_DIR="$WORK/empty" rec record-full; expect_rc record-full 1
  file_line record-full "$REC" '**Verdict:** NO-GO'
  file_has record-full "$REC" '| ADR-021 | security | SEC-L4 on a\|b \<b>redirect\</b> | 2026-12-10 | 8 |'
  file_has record-full "$REC" '1. **High** GOV-R1: sec-posture has no review record'
  file_has record-full "$REC" '**Low** GOV-L2: ascent-docs/check-docs is unmeasured'; file_has record-full "$REC" '**Low** GOV-W2: waiver ADR-021 (security) is due for review in 8 days'
  file_has record-full "$REC" '| unmeasured |'; file_has record-full "$REC" '| due (High) |'
  if [ "$(grep -c '^[0-9][0-9]*\. \*\*' "$WORK/record-full/$REC")" -eq 4 ]; then ok; else bad "record-full: expected 4 numbered conditions: $(grep -c '^[0-9]' "$WORK/record-full/$REC")"; fi
  if awk '/^## Conditions/ { on = 1; next } on && /^[0-9]/ { n++; if ($1 != n ".") bad = 1; if (n == 1 && $2 != "**High**") bad = 1 } END { exit bad }' "$WORK/record-full/$REC"; then ok; else bad "record-full: conditions are not numbered 1.., High first"; fi

  repo record-expired; printf 'security:\n  waivers:\n    - id: ADR-021\n      skips: SEC-L4\n      review_by: 2026-11-30\ndecisions:\n  acknowledged_changes:\n    - adr: ADR-003\n      commit: abc1234\n' >> "$WORK/record-expired/$CON"
  G record-expired add -A; G record-expired commit -q -m waiver; rec record-expired; expect_rc record-expired 1
  file_has record-expired "$REC" '| ADR-021 | security | SEC-L4 | 2026-11-30 | expired |'; file_has record-expired "$REC" '1. **High** GOV-W1: waiver ADR-021 (security) expired 2 days ago'
  file_has record-expired "$REC" 'Acknowledged changes (not waivers; they never expire):'; file_line record-expired "$REC" '- ADR-003: the change at commit abc1234'
  repo record-acks; printf 'decisions:\n  acknowledged_changes:\n    - adr: ADR-003\n      commit: abc1234\n' >> "$WORK/record-acks/$CON"; G record-acks add -A; G record-acks commit -q -m ack
  rec record-acks; expect_rc record-acks 0; file_line record-acks "$REC" '- ADR-003: the change at commit abc1234'
  if [ "$(grep -c '^None\.$' "$WORK/record-acks/$REC")" -eq 1 ]; then ok; else bad "record-acks: only the conditions should say None."; fi

  # GOV-L3: the newest record of the environment is signed by a person
  repo l3-none; GIT=1 chk l3-none --env prod; expect_only l3-none GOV-L3 High; has l3-none 'NO-GO'; has l3-none 'no launch record'
  repo l3-unsigned; rec l3-unsigned; G l3-unsigned add -A; G l3-unsigned commit -q -m record; GIT=1 chk l3-unsigned --env prod; expect_only l3-unsigned GOV-L3 High; has l3-unsigned 'not signed'
  repo l3-no-date; rec l3-no-date; sign l3-no-date "$REC" 'Ana Lopez' ''; GIT=1 chk l3-no-date --env prod; expect_only l3-no-date GOV-L3 High; has l3-no-date 'no date after Date:'
  repo l3-unreal-date; rec l3-unreal-date; sign l3-unreal-date "$REC" 'Ana Lopez' 2026-11-31; GIT=1 chk l3-unreal-date --env prod; expect_only l3-unreal-date GOV-L3 High
  repo l3-future-date; rec l3-future-date; sign l3-future-date "$REC" 'Ana Lopez' 2026-12-03; GIT=1 chk l3-future-date --env prod; expect_only l3-future-date GOV-L3 High; has l3-future-date 'after today'
  repo l3-no-name; rec l3-no-name; sign l3-no-name "$REC" '' 2026-12-02; GIT=1 chk l3-no-name --env prod; expect_only l3-no-name GOV-L3 High
  repo l3-nogo-signed; stub_rc ascent-docs/check-docs 1; rec l3-nogo-signed; sign l3-nogo-signed "$REC" 'Ana Lopez' 2026-12-02; stubs
  GIT=1 chk l3-nogo-signed --env prod; expect_only l3-nogo-signed GOV-L3 High; has l3-nogo-signed 'a NO-GO is not launched'
  signed l3-odd-verdict; edit l3-odd-verdict "$REC" '/^\*\*Verdict:\*\*/ { print "**Verdict:** MAYBE"; next } { print }' && G l3-odd-verdict add -A && G l3-odd-verdict commit -q -m edit
  GIT=1 chk l3-odd-verdict --env prod; expect_only l3-odd-verdict GOV-L3 High; has l3-odd-verdict "'MAYBE'"
  signed l3-no-verdict; edit l3-no-verdict "$REC" "$(drop '**Verdict:**')" && G l3-no-verdict add -A && G l3-no-verdict commit -q -m edit
  GIT=1 chk l3-no-verdict --env prod; expect_only l3-no-verdict GOV-L3 High; has l3-no-verdict 'has no verdict'
  signed good; GIT=1 chk good --env prod; expect_pass good; has good 'check-audit: prod: GO, '
  has good "PASS  GOV-L3  $REC is signed by Ana Lopez on 2026-12-02"; has good 'N/A   GOV-L4'; has good 'PASS  GOV-L5'
  # a record whose verdict was GO WITH CONDITIONS can be signed
  repo conditions-signed; mkdir -p "$WORK/empty"; PLUGINS_DIR="$WORK/empty" rec conditions-signed; file_line conditions-signed "$REC" '**Verdict:** GO WITH CONDITIONS'
  sign conditions-signed "$REC" 'Ana Lopez' 2026-12-02; GIT=1 chk conditions-signed --env prod; expect_pass conditions-signed
  # the newest record is the one that counts, and only this environment's
  signed l3-newest-wins; (cd "$WORK/l3-newest-wins" && sed -e 's/^\*\*Signed:\*\*.*/**Signed:**/' -e 's/^\*\*Date:\*\*.*/**Date:**/' "$REC" > "$LD/2026-12-03-prod.md"); G l3-newest-wins add -A; G l3-newest-wins commit -q -m newer
  TODAY=2026-12-04 GIT=1 chk l3-newest-wins --env prod; expect_only l3-newest-wins GOV-L3 High; has l3-newest-wins '2026-12-03-prod.md'
  signed l3-other-env; (cd "$WORK/l3-other-env" && sed -e 's/^\*\*Signed:\*\*.*/**Signed:**/' "$REC" > "$LD/2026-12-03-beta.md" && cp "$LD/2026-12-03-beta.md" "$LD/2026-12-03-pre-prod.md"); G l3-other-env add -A; G l3-other-env commit -q -m beta
  TODAY=2026-12-04 GIT=1 chk l3-other-env --env prod; expect_pass l3-other-env

  # a signature is a name: a line of underscores or dashes is a blank that was never filled in
  for mark in '_______________' '----' '?' '...'; do
    repo l3-no-letters; rec l3-no-letters; sign l3-no-letters "$REC" "$mark" 2026-12-02; GIT=1 chk l3-no-letters --env prod; expect_only "l3-no-letters" GOV-L3 High; has "l3-no-letters ($mark)" 'not signed'
  done
  repo l3-other-alphabet; rec l3-other-alphabet; sign l3-other-alphabet "$REC" "$(printf '\346\235\216\351\233\267')" 2026-12-02; GIT=1 chk l3-other-alphabet --env prod; expect_pass l3-other-alphabet
  # a record whose file name is dated after today, or on no real day, is not a record yet: it never becomes "the newest" and hides the ones after it
  signed l3-future-name; G l3-future-name mv "$REC" "$LD/2099-01-01-prod.md"; G l3-future-name commit -q -m rename
  GIT=1 chk l3-future-name --env prod; expect_only l3-future-name GOV-L3 High; has l3-future-name 'no launch record'; has l3-future-name "NOTE  $LD/2099-01-01-prod.md is not read: its name is dated after today"
  signed l3-unreal-name; G l3-unreal-name mv "$REC" "$LD/2026-02-30-prod.md"; G l3-unreal-name commit -q -m rename
  GIT=1 chk l3-unreal-name --env prod; expect_only l3-unreal-name GOV-L3 High; has l3-unreal-name "NOTE  $LD/2026-02-30-prod.md is not read: its name is not a real date"
  # the message says how the record is made
  has l3-unreal-name "--record $REC"

  # GOV-L4: an approver signs, when the contract lists approvers
  repo l4-not-approver; edit l4-not-approver $CON "$(subst 'approvers: []' 'approvers: [sam-roe, "Kim Park"]')" && G l4-not-approver add -A && G l4-not-approver commit -q -m approvers
  rec l4-not-approver; sign l4-not-approver "$REC" 'Ana Lopez' 2026-12-02; GIT=1 chk l4-not-approver --env prod; expect_only l4-not-approver GOV-L4 High; has l4-not-approver 'Ana Lopez'
  repo l4-approver; edit l4-approver $CON "$(subst 'approvers: []' 'approvers: [sam-roe, "Kim Park"]')" && G l4-approver add -A && G l4-approver commit -q -m approvers
  rec l4-approver; sign l4-approver "$REC" 'kim park' 2026-12-02; GIT=1 chk l4-approver --env prod; expect_pass l4-approver; has l4-approver 'PASS  GOV-L4'
  repo l4-part-of-a-name; edit l4-part-of-a-name $CON "$(subst 'approvers: []' 'approvers: [sam-roe, "Kim Park"]')" && G l4-part-of-a-name add -A && G l4-part-of-a-name commit -q -m approvers
  rec l4-part-of-a-name; sign l4-part-of-a-name "$REC" 'Kim' 2026-12-02; GIT=1 chk l4-part-of-a-name --env prod; expect_only l4-part-of-a-name GOV-L4 High

  # GOV-L5: nothing but governance records changed since the commit the record names
  signed l5-code-changed; change l5-code-changed; GIT=1 chk l5-code-changed --env prod; expect_only l5-code-changed GOV-L5 High; has l5-code-changed 'src/app.js'
  signed l5-contract-changed; change l5-contract-changed README.md; GIT=1 chk l5-contract-changed --env prod; expect_only l5-contract-changed GOV-L5 High; has l5-contract-changed 'README.md'
  # a tracked file moved into the launch folder is a change to the file it was
  signed l5-moved-in; G l5-moved-in mv src/app.js "$LD/app.js"; G l5-moved-in commit -q -m move; GIT=1 chk l5-moved-in --env prod; expect_only l5-moved-in GOV-L5 High; has l5-moved-in 'src/app.js'
  signed l5-only-governance; printf '# Review log\n\nA row was added.\n' > "$WORK/l5-only-governance/docs/governance/review-log.md"; printf '# beta\n' > "$WORK/l5-only-governance/$LD/2026-12-02-beta.md"
  G l5-only-governance add -A; G l5-only-governance commit -q -m records; GIT=1 chk l5-only-governance --env prod; expect_pass l5-only-governance; has l5-only-governance 'PASS  GOV-L5'
  signed l5-other-governance-file; printf 'notes\n' > "$WORK/l5-other-governance-file/docs/governance/notes.md"; G l5-other-governance-file add -A; G l5-other-governance-file commit -q -m notes
  GIT=1 chk l5-other-governance-file --env prod; expect_only l5-other-governance-file GOV-L5 High
  signed l5-lookalike-folder; mkdir -p "$WORK/l5-lookalike-folder/$LD-old"; printf 'x\n' > "$WORK/l5-lookalike-folder/$LD-old/a.md"; G l5-lookalike-folder add -A; G l5-lookalike-folder commit -q -m lookalike
  GIT=1 chk l5-lookalike-folder --env prod; expect_only l5-lookalike-folder GOV-L5 High
  signed l5-bad-commit; edit l5-bad-commit "$REC" '/ commit [0-9a-f]+ / { sub(/ commit [0-9a-f]+ /, " commit 0123456 ") } { print }' && G l5-bad-commit add -A && G l5-bad-commit commit -q -m edit
  GIT=1 chk l5-bad-commit --env prod; expect_only l5-bad-commit GOV-L5 High; has l5-bad-commit '0123456'
  signed l5-no-commit; edit l5-no-commit "$REC" '/ commit [0-9a-f]+ / { sub(/ commit [0-9a-f]+ /, " ") } { print }' && G l5-no-commit add -A && G l5-no-commit commit -q -m edit
  GIT=1 chk l5-no-commit --env prod; expect_only l5-no-commit GOV-L5 High; has l5-no-commit 'names no commit'
  # where the history cannot be read: fail closed, except when the caller says no git
  signed l5; chk l5 --env prod; expect_pass l5-no-git; has l5-no-git 'N/A   GOV-L5'; has l5-no-git '--no-git'
  rm -rf "$WORK/l5-shallow"; (cd "$WORK" && HOME="$WORK/home" GIT_CONFIG_NOSYSTEM=1 git clone -q --depth 1 "file://$WORK/l5" l5-shallow) >/dev/null 2>&1
  GIT=1 chk l5-shallow --env prod; expect_only l5-shallow GOV-L5 High; has l5-shallow 'fetch-depth: 0'
  rm -rf "$WORK/l5-not-a-repo"; mkdir -p "$WORK/l5-not-a-repo"; (cd "$WORK/l5" && tar cf - --exclude .git .) | (cd "$WORK/l5-not-a-repo" && tar xf -)
  (cd "$WORK/l5-not-a-repo" && PATH="$SHIM:$PATH" HOME="$WORK/home" GIT_CONFIG_NOSYSTEM=1 GIT_CEILING_DIRECTORIES="$WORK" STUB_LOG="$WORK/log" STUB_CTL="$WORK/ctl" GITHUB_STEP_SUMMARY= bash "$CHECK" --plugins "$WORK/stubs" --today 2026-12-02 --env prod .) >"$WORK/out" 2>&1; RC=$?; OUT=$(cat "$WORK/out")
  expect_only l5-not-a-repo GOV-L5 High; has l5-not-a-repo 'not a git repository'

  # sign-off is inherited up the ladder, and never asked below its rung
  signed inherited '[local, beta, prod, dr]'; GIT=1 chk inherited --env dr; expect_only inherited GOV-L3 High; has inherited '-dr.md'
  GIT=1 chk inherited --env dr --record "$LD/2026-12-02-dr.md"; sign inherited "$LD/2026-12-02-dr.md" 'Ana Lopez' 2026-12-02; GIT=1 chk inherited --env dr; expect_pass inherited-signed
  GIT=1 chk inherited --env beta; expect_pass not-below; lacks not-below 'GOV-L3'; lacks not-below 'GOV-L5'
  # --launch asks whether to launch: the signature comes after the answer
  repo launch-awaiting; GIT=1 chk launch-awaiting --env prod --launch; expect_pass launch-awaiting; has launch-awaiting 'NOTE  sign-off: awaiting signature'; lacks launch-awaiting 'GOV-L3'

  # a launch folder with a space in its name
  repo with-space; edit with-space $CON '{ print } /^  approvers:/ { print "  launch_dir: \"docs/launch records/\"" }' && G with-space add -A && G with-space commit -q -m dir
  GIT=1 chk with-space --env prod --record "docs/launch records/2026-12-02-prod.md"; expect_rc with-space-record 0
  sign with-space "docs/launch records/2026-12-02-prod.md" 'Ana Lopez' 2026-12-02; GIT=1 chk with-space --env prod; expect_pass with-space
  change with-space; GIT=1 chk with-space --env prod; expect_only with-space-changed GOV-L5 High

  # the review log's history is read since the newest signed launch
  repo r4; edit r4 $CON '{ print } /^      sign_off: true/ { print "      reviews: { sec-posture: 30 }" }' && mkdir -p "$WORK/r4/docs/governance"
  printf '# Review log\n\n| Date | Review | Commit | Rating | High | Medium | Low | Open High rules | Asked by |\n|---|---|---|---|---|---|---|---|---|\n| 2026-10-01 | sec-posture | 1a2b3c4 | strong | 0 | 0 | 0 | - | operator |\n| 2026-11-28 | sec-posture | 1a2b3c4 | strong | 0 | 0 | 0 | - | operator |\n' > "$WORK/r4/docs/governance/review-log.md"
  G r4 add -A; G r4 commit -q -m log; edit r4 docs/governance/review-log.md "$(drop '| 2026-10-01 |')" && G r4 add -A && G r4 commit -q -m drop
  GIT=1 chk r4 --env prod --launch; expect_only r4-before-launch GOV-R4 Medium
  rec r4; GIT=1 chk r4 --env prod --launch; expect_only r4-unsigned-record GOV-R4 Medium
  sign r4 "$REC" 'Ana Lopez' 2026-12-02; GIT=1 chk r4 --env prod; expect_pass r4-after-launch; has r4-after-launch 'PASS  GOV-R4'; has r4-after-launch 'since the launch record'
  edit r4 docs/governance/review-log.md "$(drop '| 2026-11-28 |')" && printf '| 2026-12-01 | sec-posture | 1a2b3c4 | strong | 0 | 0 | 0 | - | operator |\n' >> "$WORK/r4/docs/governance/review-log.md" && G r4 add -A && G r4 commit -q -m drop2
  GIT=1 chk r4 --env prod; expect_only r4-removed-after-launch GOV-R4 Medium

  # usage
  chk good --help; expect_rc help 0; has help '--record'
}
run_matrix
