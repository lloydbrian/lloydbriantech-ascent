#!/usr/bin/env bash
# Behavior test for the two other views of plugins/ascent-governance/scripts/check-audit.sh:
# the CI job summary and the one-file HTML page.
#
# The result of a run is written as Markdown to $GITHUB_STEP_SUMMARY when that
# is set, and nowhere when it is not. --html writes the run as one page, and
# --html with --from converts a launch record, so the plain-words summary and
# the signature appear. The page stands alone (no script, nothing fetched), has
# a dark theme and a print style, shows anything that looks like a tag as text,
# and is never written into the launch folder or over a file this script did not
# write. Each of those gets a negative case.
#
# Runs with the default awk and every other awk found (mawk, gawk, BWK awk).
# Prints "test-views: N/N PASS" last (make/test-plugins.sh T11 requires it).
# Portable: bash 3.2+, GNU/Linux and BSD/macOS.

set -u
NAME=test-views
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/lib.sh"
CHECK="$PLUGIN/scripts/check-audit.sh"
need "$CHECK" "$PLUGIN/scripts/lib/md-html.awk" "$FIX/audit-good/docs/governance/launches/2026-01-05-prod.md"
LD=docs/governance/launches
f_has() { if grep -qF -- "$3" "$2" 2>/dev/null; then ok; else bad "$1: $(basename "$2") lacks: $3"; fi; }
f_lacks() { if [ -f "$2" ] && ! grep -qF -- "$3" "$2"; then ok; else bad "$1: $(basename "$2") is missing or contains: $3"; fi; }
count() { grep -o -- "$2" "$1" | wc -l | tr -d ' '; }
closed() {  # NAME FILE TAG... — every opened tag is closed
  local n="$1" f="$2" t; shift 2
  for t in "$@"; do
    if [ "$(count "$f" "<$t[ >]")" -gt 0 ] && [ "$(count "$f" "<$t[ >]")" -eq "$(count "$f" "</$t>")" ]; then ok
    else bad "$n: <$t> opened $(count "$f" "<$t[ >]") time(s), closed $(count "$f" "</$t>")"; fi
  done
}

matrix() {
  O="$WORK/o-$AWKNAME"; rm -rf "$O"; mkdir -p "$O"
  # --- the job summary ---------------------------------------------------------
  stubs; mk good; STEP_SUMMARY="$O/sum.md" chk good --env beta; expect_pass summary-written
  f_has summary-written "$O/sum.md" '# Launch readiness: good, beta'; f_has summary-written "$O/sum.md" '**Verdict:** GO'; f_has summary-written "$O/sum.md" '## Evidence'
  f_has summary-written "$O/sum.md" '| ascent-docs/check-docs passes | check | pass | ascent-docs/check-docs |'; f_has summary-written "$O/sum.md" '## Conditions'
  f_lacks summary-written "$O/sum.md" '**Signed:**'; f_lacks summary-written "$O/sum.md" 'In plain words'; f_lacks summary-written "$O/sum.md" 'Launch record'
  # it is added to what the job already wrote
  printf 'An earlier step wrote this.\n' > "$O/sum2.md"; STEP_SUMMARY="$O/sum2.md" chk good --env beta; STEP_SUMMARY="$O/sum2.md" chk good --env local
  f_has summary-appends "$O/sum2.md" 'An earlier step wrote this.'; f_has summary-appends "$O/sum2.md" 'good, beta'; f_has summary-appends "$O/sum2.md" 'good, local'
  # a NO-GO is summarized too, with what blocks it
  stubs; stub_rc ascent-docs/check-docs 1; STEP_SUMMARY="$O/sum3.md" chk good --env beta; expect_rc summary-nogo 1
  f_has summary-nogo "$O/sum3.md" '**Verdict:** NO-GO'; f_has summary-nogo "$O/sum3.md" '1. **High** GOV-L1: ascent-docs/check-docs failed'
  # not set, or empty: nothing extra is written, and nothing fails
  stubs; chk good --env beta; expect_pass summary-unset; lacks summary-unset 'summary'
  if [ "$(ls "$O" | wc -l | tr -d ' ')" -eq 3 ]; then ok; else bad "summary-unset: a file was written: $(ls "$O" | tr '\n' ' ')"; fi
  # a summary that cannot be written does not change the answer
  STEP_SUMMARY="$O/no/such/dir/sum.md" chk good --env beta; expect_rc summary-unwritable 0; has summary-unwritable 'could not write the job summary'
  has summary-unwritable 'check-audit: beta: GO, '

  # --- the page of a run -------------------------------------------------------
  stubs; chk good --env beta --html "$O/run.html"; expect_pass html-run; has html-run "wrote $O/run.html"
  f_has html-run "$O/run.html" '<!doctype html>'; f_has html-run "$O/run.html" '<h1>Launch readiness: good, beta</h1>'; f_has html-run "$O/run.html" '<title>Launch readiness: good, beta</title>'
  f_has html-run "$O/run.html" '<p class="verdict go"><strong>Verdict:</strong> GO</p>'; f_has html-run "$O/run.html" '<td>ascent-docs/check-docs passes</td><td>check</td><td>pass</td>'
  f_has html-run "$O/run.html" ' · commit '; f_lacks html-run "$O/run.html" 'Signed:'
  stubs; stub_rc ascent-docs/check-docs 1; chk good --env beta --html "$O/nogo.html"; expect_rc html-nogo 1
  f_has html-nogo "$O/nogo.html" '<p class="verdict nogo"><strong>Verdict:</strong> NO-GO</p>'; f_has html-nogo "$O/nogo.html" '<li><strong>High</strong> GOV-L1: ascent-docs/check-docs failed'
  stubs; mkdir -p "$WORK/empty"; PLUGINS_DIR="$WORK/empty" chk good --env beta --html "$O/cond.html"; f_has html-cond "$O/cond.html" '<p class="verdict cond"><strong>Verdict:</strong> GO WITH CONDITIONS</p>'
  # a folder that does not exist yet is made
  stubs; chk good --env beta --html "$O/new/dir/run.html"; expect_pass html-new-dir; f_has html-new-dir "$O/new/dir/run.html" '</html>'

  # --- the page of a launch record ---------------------------------------------
  stubs; mk rec; chk rec --html "$O/rec.html" --from "$LD/2026-01-05-prod.md"; expect_rc html-from-record 0; has html-from-record "wrote $O/rec.html"
  f_has html-from-record "$O/rec.html" '<h1>Launch record: audit-good, prod</h1>'; f_has html-from-record "$O/rec.html" 'commit 3f9c2ab'
  f_has html-from-record "$O/rec.html" 'The first production launch.'; f_has html-from-record "$O/rec.html" '<p><strong>Signed:</strong> ana-lopez</p>'
  f_has html-from-record "$O/rec.html" '<p><strong>Date:</strong> 2026-01-05</p>'; f_lacks html-from-record "$O/rec.html" 'summary: written by'
  if [ -s "$WORK/log" ]; then bad "html-from-record: converting a record ran the checkers"; else ok; fi
  lacks html-from-record 'check-audit: local:'

  # the page stands alone
  for f in run rec nogo; do
    f_lacks html-self-contained "$O/$f.html" '<script'; f_lacks html-self-contained "$O/$f.html" 'http://'; f_lacks html-self-contained "$O/$f.html" 'https://'
    f_lacks html-self-contained "$O/$f.html" ' src='; f_lacks html-self-contained "$O/$f.html" '<link'; f_lacks html-self-contained "$O/$f.html" '<img'; f_lacks html-self-contained "$O/$f.html" '@import'
    f_lacks html-self-contained "$O/$f.html" 'url('
    f_has html-self-contained "$O/$f.html" 'prefers-color-scheme: dark'; f_has html-self-contained "$O/$f.html" '@media print'; f_has html-self-contained "$O/$f.html" 'name="viewport"'
    f_has html-self-contained "$O/$f.html" '<meta charset="utf-8">'; f_has html-self-contained "$O/$f.html" 'overflow-x: auto'
    closed "html-valid-$f" "$O/$f.html" html head body main style table thead tbody tr td th h1 h2 p div
  done
  closed html-valid-nogo "$O/nogo.html" ol li

  # what looks like a tag is shown as text
  stubs; mk esc; mkdir -p "$WORK/esc/docs/adr"; printf '# ADR-021: x\n\n**Status:** Accepted\n' > "$WORK/esc/docs/adr/ADR-021-x.md"
  printf 'security:\n  waivers:\n    - id: ADR-021\n      skips: "<script>alert(1)</script> & a|b"\n      review_by: 2026-12-10\ndecisions:\n  dir: docs/adr/\n  acknowledged_changes:\n    - adr: ADR-003\n      commit: abc1234\n' >> "$WORK/esc/$CON"
  # a backslash, a link and the marks of bold and code in a contract value are text too: none forges a cell, a link or a style
  printf '%s\n' 'ux:' '  waivers:' '    - id: ADR-021' "      skips: 'x \\| y [l](u) **z** \`c\` end\\'" '      review_by: 2027-06-30' >> "$WORK/esc/$CON"
  STEP_SUMMARY="$O/esc.md" chk esc --env beta --html "$O/esc.html"; expect_rc html-escaped 0
  f_has md-escaped "$O/esc.md" '| ADR-021 | ux | x \\\| y \[l](u) \*\*z\*\* \`c\` end\\ | 2027-06-30 |'
  f_has html-escaped "$O/esc.html" '<td>x \| y [l](u) &#42;&#42;z&#42;&#42; &#96;c&#96; end\</td><td>2027-06-30</td>'; f_lacks html-escaped "$O/esc.html" '<strong>z'; f_lacks html-escaped "$O/esc.html" '<code>c'
  f_has html-escaped "$O/esc.html" '<td>&lt;script&gt;alert(1)&lt;/script&gt; &amp; a|b</td>'; f_lacks html-escaped "$O/esc.html" '<script>alert'
  f_has html-escaped "$O/esc.html" '<li>ADR-003: the change at commit abc1234</li>'; closed html-escaped "$O/esc.html" table tr td ol ul li
  # a record a person edited by hand
  printf '# Launch record: <i>x</i>, prod\n\n2026-12-02 · commit abc1234 · maturity standard (m) · ascent-governance 0.1.0\n\n**Verdict:** GO\n\n## In plain words\n\n<!-- summary: written by launch-readiness -->\n\nReady, with `two` things <b onclick="x()">to</b> watch & more.\nA second line.\n\n<script>alert(2)</script>\n\n## Evidence\n\n| What | Kind | Result | Source |\n|:---|---|---:|---|\n| a\\|b \\<img src=x> **bold** | check | pass | z |\n\n## Conditions\n\n1. one ** unpaired\n2. two\n\n**Signed:** Ana Lopez\n\n**Date:** 2026-12-02\r\n' > "$WORK/rec/$LD/2026-12-02-prod.md"
  chk rec --html "$O/hand.html" --from "$LD/2026-12-02-prod.md"; expect_rc html-hand 0
  f_has html-hand "$O/hand.html" '<h1>Launch record: &lt;i&gt;x&lt;/i&gt;, prod</h1>'; f_has html-hand "$O/hand.html" '<title>Launch record: &lt;i&gt;x&lt;/i&gt;, prod</title>'
  f_has html-hand "$O/hand.html" '<p>Ready, with <code>two</code> things &lt;b onclick=&quot;x()&quot;&gt;to&lt;/b&gt; watch &amp; more. A second line.</p>'
  f_has html-hand "$O/hand.html" '<p>&lt;script&gt;alert(2)&lt;/script&gt;</p>'; f_lacks html-hand "$O/hand.html" '<script'; f_lacks html-hand "$O/hand.html" '<img'; f_lacks html-hand "$O/hand.html" '<b '
  f_has html-hand "$O/hand.html" '<tr><td>a|b &lt;img src=x&gt; <strong>bold</strong></td><td>check</td><td>pass</td><td>z</td></tr>'
  f_has html-hand "$O/hand.html" '<li>one ** unpaired</li>'; f_has html-hand "$O/hand.html" '<p><strong>Date:</strong> 2026-12-02</p>'; f_lacks html-hand "$O/hand.html" ':---'
  f_lacks html-hand "$O/hand.html" 'summary: written by'
  closed html-hand "$O/hand.html" table tr td th ol li p strong code

  # --- where it will not write --------------------------------------------------
  for p in "$LD/page.html" "./$LD/page.html" "$WORK/rec/$LD/page.html" "$LD/../launches/page.html" "docs/governance/../governance/launches/sub/page.html"; do
    chk rec --env local --html "$p"; expect_rc "html-in-launch-dir ($p)" 2; has html-in-launch-dir 'launch'
  done
  if [ -z "$(find "$WORK/rec/$LD" -name '*.html')" ] && [ ! -d "$WORK/rec/$LD/sub" ]; then ok; else bad "html-in-launch-dir: a page was written into the launch folder"; fi
  chk rec --html "$LD/page.html" --from "$LD/2026-01-05-prod.md"; expect_rc html-from-in-launch-dir 2
  # through a link to the launch folder
  rm -f "$WORK/rec/pages"; ln -s "$LD" "$WORK/rec/pages"; chk rec --env local --html pages/page.html; expect_rc html-through-a-link 2
  if [ -z "$(find "$WORK/rec/$LD" -name '*.html')" ]; then ok; else bad "html-through-a-link: a page was written into the launch folder"; fi
  # through a link that is the page itself, whether or not it points at a file yet
  ln -s "$WORK/rec/$LD/linked.html" "$O/dangling.html"; chk rec --env local --html "$O/dangling.html"; expect_rc html-dangling-link 2; has html-dangling-link 'is a link'
  if [ ! -e "$WORK/rec/$LD/linked.html" ]; then ok; else bad "html-dangling-link: a page was written through the link"; fi
  # into a folder that does not exist yet, under a link to the launch folder
  chk rec --env local --html pages/sub/page.html; expect_rc html-under-a-link 2
  if [ ! -e "$WORK/rec/$LD/sub" ]; then ok; else bad "html-under-a-link: a folder was made in the launch folder"; fi
  # the launch folder under another spelling (one folder on a volume that ignores case)
  chk rec --env local --html "DOCS/Governance/LAUNCHES/page.html"; expect_rc html-other-case 2
  if [ -z "$(find "$WORK/rec" -name 'page.html')" ]; then ok; else bad "html-other-case: a page was written"; fi
  # the same, before the launch folder exists: the name alone decides
  rm -rf "${WORK:?}/nold"; mkdir -p "$WORK/nold"; cp -R "$WORK/rec/.ascent" "$WORK/nold/"; chk nold --env local --html "DOCS/Governance/LAUNCHES/page.html"; expect_rc html-other-case-no-folder 2
  if [ -z "$(find "$WORK/nold" -name 'page.html')" ]; then ok; else bad "html-other-case-no-folder: a page was written"; fi
  # the path is read from where the command is run
  mkdir -p "$WORK/elsewhere-$AWKNAME/deep"
  (cd "$WORK/elsewhere-$AWKNAME/deep" && PATH="$SHIM:$PATH" HOME="$WORK/home" bash "$CHECK" --plugins "$WORK/stubs" --today 2026-12-02 --no-git --html here.html --from "../../rec/$LD/2026-01-05-prod.md" ../../rec) >"$WORK/out" 2>"$WORK/err"; RC=$?; OUT=$(cat "$WORK/out" "$WORK/err")
  expect_rc html-from-elsewhere 0; f_has html-from-elsewhere "$WORK/elsewhere-$AWKNAME/deep/here.html" '<h1>Launch record: '
  if [ ! -e "$WORK/rec/here.html" ]; then ok; else bad "html-from-elsewhere: the page was written into the repository"; fi
  # over a file it did not write
  printf 'my notes\n\n\n\nthe pages say: generated by ascent-governance check-audit.sh\n' > "$O/quote.html"; chk rec --env local --html "$O/quote.html"; expect_rc html-quotes-the-mark 2; f_has html-quotes-the-mark "$O/quote.html" 'my notes'
  printf 'my notes\n' > "$O/notes.html"; chk rec --env local --html "$O/notes.html"; expect_rc html-not-ours 2; f_has html-not-ours "$O/notes.html" 'my notes'; has html-not-ours 'not written by'
  printf '# Readme\n' > "$WORK/rec/README.md"; chk rec --env local --html README.md; expect_rc html-over-readme 2; f_has html-over-readme "$WORK/rec/README.md" '# Readme'
  # over a page it wrote before
  stubs; chk rec --env local --html "$O/again.html"; chk rec --env beta --html "$O/again.html"; expect_rc html-rewrite 0; f_has html-rewrite "$O/again.html" 'rec, beta'; f_lacks html-rewrite "$O/again.html" 'rec, local'

  # --- bad input ---------------------------------------------------------------
  chk rec --html "$O/x.html" --from "$LD/none.md"; expect_rc from-missing 2
  chk rec --html "$O/x.html" --from README.md; expect_rc from-not-a-record 2; has from-not-a-record 'not a launch record'
  chk rec --from "$LD/2026-01-05-prod.md"; expect_rc from-without-html 2
  chk rec --html; expect_rc html-no-value 2
  if [ -e "$O/x.html" ]; then bad "bad input wrote a page"; else ok; fi
  chk rec --help; has help '--html'; has help '--from'
}
run_matrix
