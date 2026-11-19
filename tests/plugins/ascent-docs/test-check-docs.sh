#!/usr/bin/env bash
# Behavior test for plugins/ascent-docs/scripts/check-docs.sh.
#
# The good fixture (fixtures/docs-good: a README with a getting-started section,
# a guide, a reference and CONTRIBUTING, all linked, anchors that resolve, an ADR
# folder that is ascent-adr's) passes DOC-L1–L5 and DOC-P1–P4. Each check then gets
# negative controls: a copy broken in exactly one way fails that check and no
# other. DOC-L3 and DOC-L4 run on throwaway git repositories inside this test's
# temporary folder, with dated commits and git's global and system configuration
# switched off; the project's repository is never touched. Also covers --path,
# --exclude, --persona, the limits, prototype maturity and bad input.
#
# Runs with the default awk and every other awk found (mawk, gawk, BWK awk).
# Prints "test-check-docs: N/N PASS" last (make/test-plugins.sh T11 requires it).
# Portable: bash 3.2+, GNU/Linux and BSD/macOS.

set -u
WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT INT TERM

HERE="$(cd "$(dirname "$0")" && pwd)"
CHECK="$HERE/../../../plugins/ascent-docs/scripts/check-docs.sh"
GOOD="$HERE/fixtures/docs-good"
for f in "$CHECK" "$GOOD/README.md" "$GOOD/docs/guide.md" "$GOOD/Makefile" "$GOOD/package.json"; do
  [ -f "$f" ] || { echo "FAIL  test-check-docs: missing $f"; echo "test-check-docs: 0/1 PASS"; exit 1; }
done

PASS=0; FAIL=0
ok()  { PASS=$((PASS + 1)); }
bad() { FAIL=$((FAIL + 1)); printf "FAIL  [%s] %s\n" "$AWKNAME" "$1"; }
chk() {  # NAME [ARGS] — no git unless GIT=1
  local n="$1"; shift
  local a=(--maturity "${MATURITY:-enterprise}")
  [ "${GIT:-0}" = 1 ] || a+=(--no-git)
  (cd "$WORK/$n" && PATH="$SHIM:$PATH" HOME="$WORK/home" GIT_CONFIG_NOSYSTEM=1 bash "$CHECK" "${a[@]}" "$@") >"$WORK/out" 2>"$WORK/err"; RC=$?
  OUT=$(cat "$WORK/out" "$WORK/err")
}
mk() { rm -rf "${WORK:?}/$1"; cp -R "$GOOD" "$WORK/$1"; }
q() { printf '%s' "$1" | sed 's/"/\\"/g'; }
subst() { printf '{ if (index($0, "%s")) { i = index($0, "%s"); $0 = substr($0, 1, i - 1) "%s" substr($0, i + length("%s")) } print }' "$(q "$1")" "$(q "$1")" "$(q "$2")" "$(q "$1")"; }
drop()  { printf 'index($0, "%s") { next } { print }' "$(q "$1")"; }
edit() {  # COPY FILE AWK
  awk "$3" "$WORK/$1/$2" > "$WORK/edit.tmp" || { bad "$1: the edit's awk failed"; return 1; }
  if cmp -s "$WORK/$1/$2" "$WORK/edit.tmp"; then bad "$1: edit changed nothing (stale anchor)"; return 1; fi
  mv "$WORK/edit.tmp" "$WORK/$1/$2"
}
expect_only() {  # NAME CHECK [SEVERITY]
  nfail=$(printf '%s\n' "$OUT" | grep -c '^FAIL ' || true)
  nmine=$(printf '%s\n' "$OUT" | grep -c "^FAIL  $2 " || true)
  if [ "$RC" -ne 1 ]; then bad "$1: expected exit 1, got $RC: $(printf '%s\n' "$OUT" | grep -E '^FAIL|test-check-docs' | head -3 | tr '\n' ';')"
  elif [ "$nmine" -eq 0 ]; then bad "$1: $2 did not fail: $(printf '%s\n' "$OUT" | grep '^FAIL' | head -2 | tr '\n' ';')"
  elif [ "$nfail" -ne "$nmine" ]; then bad "$1: expected only $2 to fail, got: $(printf '%s\n' "$OUT" | grep '^FAIL' | cut -c1-110 | tr '\n' ';')"
  elif [ -n "${3:-}" ] && ! printf '%s\n' "$OUT" | grep -q "^FAIL  $2 *$3 "; then bad "$1: $2 should be $3: $(printf '%s\n' "$OUT" | grep "^FAIL  $2" | head -1)"
  else ok; fi
}
expect_pass() { if [ "$RC" -eq 0 ]; then ok; else bad "$1 should pass: exit $RC $(printf '%s\n' "$OUT" | grep -E '^FAIL|test-check-docs:' | head -2 | tr '\n' ';')"; fi; }
expect_rc() { if [ "$RC" -eq "$2" ]; then ok; else bad "$1: expected exit $2, got $RC: $(printf '%s\n' "$OUT" | head -2 | tr '\n' ';')"; fi; }
has() { if printf '%s\n' "$OUT" | grep -qF -- "$2"; then ok; else bad "$1: output lacks: $2"; fi; }
lacks() { if printf '%s\n' "$OUT" | grep -qF -- "$2"; then bad "$1: output must not contain: $2"; else ok; fi; }
G() { (cd "$WORK/$1" && shift && HOME="$WORK/home" GIT_CONFIG_NOSYSTEM=1 git -c user.name=test -c user.email=test@example.invalid -c commit.gpgsign=false -c core.hooksPath=/dev/null "$@") >/dev/null 2>&1; }
head_of() { (cd "$WORK/$1" && HOME="$WORK/home" GIT_CONFIG_NOSYSTEM=1 git log -1 --format=%h); }

GD() {  # COPY DATE ARGS — a git command with both dates set
  local c="$1" d="$2"; shift 2
  (cd "$WORK/$c" && HOME="$WORK/home" GIT_CONFIG_NOSYSTEM=1 GIT_AUTHOR_DATE="${d}T12:00:00" GIT_COMMITTER_DATE="${d}T12:00:00" git -c user.name=test -c user.email=test@example.invalid -c commit.gpgsign=false -c core.hooksPath=/dev/null "$@") >/dev/null 2>&1
}
matrix() {
  mk good; chk good
  if [ "$RC" -eq 0 ] && [ "$(printf '%s\n' "$OUT" | grep -c '^PASS ')" -eq 6 ]; then ok; else bad "good fixture should pass 6 without git: exit $RC $(printf '%s\n' "$OUT" | grep -vE '^PASS' | tr '\n' ';')"; fi
  has good 'it checks that the documents can be found and are kept, not that they are right'
  has good '4 document(s), 7 link(s)'

  # DOC-L1 — links resolve
  mk l1; edit l1 docs/guide.md "$(subst '(reference/config.md)' '(reference/settings.md)')" && chk l1 && expect_only l1 DOC-L1 Medium
  has l1 'points to docs/reference/settings.md, which does not exist'
  mk l1-climb; edit l1-climb docs/guide.md "$(subst '(../src/app.js)' '(../../outside.md)')" && chk l1-climb && expect_only l1-climb DOC-L1 Medium
  has l1-climb 'leaves the repository'
  mk l1-code; printf '\nSee `[x](missing.md)` and:\n\n```\n[y](missing.md)\n```\n' >> "$WORK/l1-code/docs/guide.md"; chk l1-code; expect_pass l1-code
  mk l1-url; printf '\nSee [the site](https://example.com/missing.md) and [mail](mailto:a@example.invalid).\n' >> "$WORK/l1-url/docs/guide.md"; chk l1-url; expect_pass l1-url
  mk l1-ref; printf '\n[cfg]: reference/nothing.md\n' >> "$WORK/l1-ref/docs/guide.md"; chk l1-ref; expect_only l1-ref DOC-L1 Medium
  mk l1-dir; printf '\nThe [reference folder](reference/).\n' >> "$WORK/l1-dir/docs/guide.md"; chk l1-dir; expect_pass l1-dir
  mk p2-dir; mkdir -p "$WORK/p2-dir/docs/team"; printf '# Team\n\nWho we are.\n' > "$WORK/p2-dir/docs/team/README.md"; printf '\nThe [team](team/).\n' >> "$WORK/p2-dir/docs/guide.md"; chk p2-dir; expect_pass p2-dir
  mk l1-excl; edit l1-excl docs/guide.md "$(subst '(reference/config.md)' '(reference/settings.md)')" && chk l1-excl --exclude docs/guide.md && expect_pass l1-excl

  # DOC-L2 — anchors
  mk l2; edit l2 README.md "$(subst 'config.md#environment' 'config.md#settings')" && chk l2 && expect_only l2 DOC-L2 Low
  has l2 'names #settings, which is not a heading in docs/reference/config.md'
  mk l2-self; printf '\nSee [above](#layout) and [missing](#nowhere).\n' >> "$WORK/l2-self/docs/guide.md"; chk l2-self; expect_only l2-self DOC-L2 Low
  mk l2-dup; printf '\n## Layout\n\nSee [the second](#layout-1).\n' >> "$WORK/l2-dup/docs/guide.md"; chk l2-dup; expect_pass l2-dup
  mk l2-id; printf '\n<a id="custom-anchor"></a>\n\nSee [here](#custom-anchor).\n' >> "$WORK/l2-id/docs/guide.md"; chk l2-id; expect_pass l2-id
  mk l2-punct-bad; printf '\n## Step 2 \342\200\224 Run it\n\nSee [step 2](#step-2-run-it).\n' >> "$WORK/l2-punct-bad/docs/guide.md"; chk l2-punct-bad; expect_only l2-punct-bad DOC-L2 Low
  mk l2-loose; printf '\n## R\303\251sum\303\251 tips\n\nSee [tips](#resume-tips).\n' >> "$WORK/l2-loose/docs/guide.md"; chk l2-loose; expect_pass l2-loose
  mk l2-punct; printf '\n## Step 1 \342\200\224 Read the `config`\n\nSee [step 1](#step-1--read-the-config).\n' >> "$WORK/l2-punct/docs/guide.md"; chk l2-punct; expect_pass l2-punct

  # DOC-L3 — stale markers (no git: no date, so stale)
  mk l3; printf '\nTODO: describe the search index.\n' >> "$WORK/l3/docs/guide.md"; chk l3; expect_only l3 DOC-L3 Low
  has l3 'no git date'
  mk l3-soon; printf '\nPagination is coming soon.\n' >> "$WORK/l3-soon/docs/guide.md"; chk l3-soon; expect_only l3-soon DOC-L3 Low
  mk l3-code; printf '\nThe flag `TODO` is literal, and so is:\n\n```\n# TODO in a sample\n```\n' >> "$WORK/l3-code/docs/guide.md"; chk l3-code; expect_pass l3-code
  mk l3-word; printf '\nThe TODOS list and a mastodon post are not markers.\n' >> "$WORK/l3-word/docs/guide.md"; chk l3-word; expect_pass l3-word

  # DOC-L5, DOC-P3 — the README
  mk l5; rm "$WORK/l5/README.md"; chk l5 --path docs; expect_only l5 DOC-L5 Medium
  has l5 'no README at the repository root'
  mk p3; edit p3 README.md "$(subst '## Getting started' '## Overview')" && chk p3 && expect_only p3 DOC-P3 Low
  mk p3-cmd; edit p3-cmd README.md "$(subst '## Getting started' '## Commands')" && chk p3-cmd && expect_pass p3-cmd
  mk l1-indent; printf '\nAn example:\n\n    [x](missing.md)\n    TODO: in an example\n\nBack to prose.\n' >> "$WORK/l1-indent/docs/guide.md"; chk l1-indent; expect_pass l1-indent
  mk l1-listcont; printf '\n- An item\n\n    with a [continuation](missing.md)\n' >> "$WORK/l1-listcont/docs/guide.md"; chk l1-listcont; expect_only l1-listcont DOC-L1 Medium
  mk l1-afterpara; printf '\nA paragraph\n    [x](missing.md) is not code: it continues the paragraph\n' >> "$WORK/l1-afterpara/docs/guide.md"; chk l1-afterpara; expect_only l1-afterpara DOC-L1 Medium
  mk p3-h7; edit p3-h7 README.md "$(subst '## Getting started' '####### Getting started')" && chk p3-h7 && expect_only p3-h7 DOC-P3 Low
  mk p2-adrfile; printf '# ADR-0001: Use Node\n\n**Status:** Accepted\n' > "$WORK/p2-adrfile/docs/ADR-0001-use-node.md"; chk p2-adrfile; expect_pass p2-adrfile

  # DOC-P1, DOC-P2, DOC-P4 — personas and reachability
  mk p1; chk p1 --persona Operator=docs/operations/README.md; expect_only p1 DOC-P1 Medium
  has p1 'the entry point of the Operator persona does not exist'
  chk p1 --persona Developer=docs/guide.md; expect_pass p1-ok
  mk p2; printf '# Orphan\n\nNobody links here.\n' > "$WORK/p2/docs/orphan.md"; chk p2; expect_only p2 DOC-P2 Low
  has p2 'docs/orphan.md:1  no link reaches this document'
  chk p2 --persona Ops=docs/orphan.md; expect_pass p2-persona
  mk p4; mkdir -p "$WORK/p4/docs/a"
  printf '# A\n\n[B](b.md)\n' > "$WORK/p4/docs/a/a.md"; printf '# B\n\n[C](c.md)\n' > "$WORK/p4/docs/a/b.md"; printf '# C\n\nDeep.\n' > "$WORK/p4/docs/a/c.md"
  printf '\n[A](../a/a.md)\n' >> "$WORK/p4/docs/reference/config.md"; chk p4; expect_only p4 DOC-P4 Low
  has p4 'docs/a/c.md:1  this document is 4 links'
  chk p4 --max-clicks 4; expect_pass p4-limit

  # DOC-L3, DOC-L4 — git dates, on throwaway repositories
  mkdir -p "$WORK/home"
  mk g; printf '\nTODO: describe the search index.\n' >> "$WORK/g/docs/guide.md"
  GD g 2026-01-10 init -q; GD g 2026-01-10 add -A; GD g 2026-01-10 commit -qm first
  GIT=1 chk g --today 2026-03-01; expect_pass g-young
  has g-young 'NOTE  DOC-L3'
  has g-young 'written 2026-01-10 (50 days ago, within 90)'
  GIT=1 chk g --today 2026-06-01; expect_only g-old DOC-L3 Low
  has g-old 'written 2026-01-10, 142 days ago (max 90)'
  GIT=1 chk g --today 2026-06-01 --marker-days 200; expect_pass g-old-limit
  printf '\n// changed\n' >> "$WORK/g/src/app.js"; GD g 2026-09-01 commit -qam later
  GIT=1 chk g --today 2026-09-02 --marker-days 999; expect_only g-lag DOC-L4 Low
  has g-lag 'docs/guide.md last changed 2026-01-10; src/app.js, which it links to, changed 2026-09-01 (234 days later, max 180)'
  GIT=1 chk g --today 2026-09-02 --marker-days 999 --lag-days 300; expect_pass g-lag-limit
  printf '\nUpdated.\n' >> "$WORK/g/docs/guide.md"; GD g 2026-09-02 commit -qam docs
  GIT=1 chk g --today 2026-09-03 --marker-days 999; expect_pass g-current
  printf '\nFIXME: new and uncommitted.\n' >> "$WORK/g/README.md"
  GIT=1 chk g --today 2026-09-03 --marker-days 999; expect_pass g-uncommitted
  mk g-nogit; printf '\nTODO: x\n' >> "$WORK/g-nogit/docs/guide.md"; GIT=1 chk g-nogit; expect_only g-nogit DOC-L3 Low
  has g-nogit 'N/A   DOC-L4  documents not older than what they link to (not a git repository)'
  # From the review: a non-ASCII file name, and REPO a subfolder of a git repository
  mk gu; printf '# Café\n\nThe menu.\n' > "$WORK/gu/docs/café.md"; printf '\nThe [café](café.md).\n' >> "$WORK/gu/docs/guide.md"
  G gu init -q; G gu add -A; G gu commit -qm first; GIT=1 chk gu; expect_pass g-unicode
  rm -rf "$WORK/gm"; mkdir -p "$WORK/gm"; cp -R "$GOOD" "$WORK/gm/pkg"; GD gm 2026-01-10 init -q; GD gm 2026-01-10 add -A; GD gm 2026-01-10 commit -qm first
  printf '\n// changed\n' >> "$WORK/gm/pkg/src/app.js"; GD gm 2026-09-01 commit -qam later
  (cd "$WORK/gm/pkg" && PATH="$SHIM:$PATH" HOME="$WORK/home" GIT_CONFIG_NOSYSTEM=1 bash "$CHECK" --today 2026-09-02 --marker-days 999) >"$WORK/out" 2>&1; RC=$?; OUT=$(cat "$WORK/out")
  expect_only g-subfolder DOC-L4 Low

  # Maturity, input
  mk proto; rm "$WORK/proto/README.md"; MATURITY=prototype chk proto --path docs; expect_pass proto
  has proto 'NOTE  DOC-L5'
  mk in1; chk in1 --path ../x; expect_rc in1-path 2
  chk in1 --persona Operator; expect_rc in1-persona 2
  chk in1 --max-clicks many; expect_rc in1-clicks 2
  chk in1 --today 2026-1-1; expect_rc in1-today 2
  chk in1 --maturity high; expect_rc in1-maturity 2
  chk in1 --bogus; expect_rc in1-option 2
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

printf "test-check-docs: %s/%s PASS (awk: %s)\n" "$PASS" "$((PASS + FAIL))" "$AWKS"
[ "$FAIL" -eq 0 ]
