#!/usr/bin/env bash
# Ownership gate T13 (ADR-015): compares docs/framework/OWNERSHIP.md with the
# repository and prints one line per rule, PASS or FAIL, labelled T13.<n>:
#   T13.1  registry: every marked table exists once, has rows, every line in it
#          is a table row, and every row has as many cells as its header
#   T13.2  plugins: plugin directories, marketplace entries and "released" rows
#          agree; planned plugins have no directory; status and build are known;
#          every released plugin has a "Which plugins do I need?" signal
#   T13.3  components: every skill, agent and hook of a released plugin is
#          registered, and every registered one exists
#   T13.4  families: plugin codes and rule-id prefixes are unique; a family's
#          prefix starts with its plugin's code; its defining file mentions its
#          first id; reserved names are not used by another plugin
#   T13.5  contract: a plugin's contract template declares only its own section,
#          and no two plugins claim one section
#   T13.6  markers: every "→ ascent-<name>" in plugins/ names a released plugin
#   T13.7  domains: one row per domain; every owner is registered
#   T13.8  lenses: the three delivery lens tables (delivery-loop SKILL.md,
#          review-lenses.md, the plugin README) list the registry's lenses and
#          providers, providers from ASCENT plugins exist, and every agent that
#          calls itself a "delivery-loop review lens" is a provider
#   T13.9  docs: the README plugin table matches plugin.json versions, and every
#          plugin, skill and agent PILLARS.md names under "Checked by" exists
#   T13.10 id format: rule-table ids and script-header ids in plugins are
#          plugin-qualified (<CODE>-<family><n>), and every qualified id names a
#          registered or reserved family
#
# Usage: check-ownership.sh [ROOT]   (ROOT defaults to the repo root)
# Exit 0 when every rule passes, 1 otherwise.
# Portable: GNU/Linux and BSD/macOS, bash 3.2+, any POSIX awk.

set -euo pipefail
case "${1:-}" in -h|--help) sed -n '2,/^$/s/^# \{0,1\}//p' "$0"; exit 0 ;; esac
export LC_ALL=C

ROOT="$(cd "${1:-$(dirname "$0")/..}" && pwd)"
REG="$ROOT/docs/framework/OWNERSHIP.md"
W="$(mktemp -d)"
trap 'rm -rf "$W"' EXIT INT TERM
NFAIL=0
pass() { printf 'PASS  %s\n' "$1"; }
fail() { NFAIL=$((NFAIL + 1)); printf 'FAIL  %s\n' "$1"; }
# report LABEL WHAT FILE — PASS when FILE is empty, else FAIL with its lines joined
report() {
  if [ -s "$3" ]; then fail "$1 $(tr '\n' ';' < "$3" | sed 's/;$//')"; else pass "$1 $2"; fi
}

# table MARKER FILE OUT — rows of the marked table as tab-separated cells:
# CR stripped, cells trimmed, backticks and ** removed, "—" and empty cells
# written as "-" (so tab-split reads keep their columns). Problems go
# to OUT.err: a missing or repeated marker, no rows, or a row whose cell count
# differs from the header's.
table() {
  awk -v m="$1" -v out="$3" -v err="$3.err" '
    function cells(line,   n, i, c, s) {
      sub(/\r$/, "", line); sub(/^[ \t]*\|/, "", line); sub(/\|[ \t]*$/, "", line)
      n = split(line, c, "|"); s = ""
      for (i = 1; i <= n; i++) {
        gsub(/\t/, " ", c[i]); gsub(/^ +| +$/, "", c[i]); gsub(/`/, "", c[i]); gsub(/\*\*/, "", c[i])
        if (c[i] == "\342\200\224" || c[i] == "") c[i] = "-"
        s = s (i > 1 ? "\t" : "") c[i]
      }
      NC = n; return s
    }
    index($0, "<!-- ownership:" m ":start") { starts++; on = 1; hdr = 0; next }
    on && index($0, "<!-- ownership:") { on = 0 }   # a missing end marker stops at the next table
    index($0, "<!-- ownership:" m ":end") { ends++; on = 0; next }
    on && !/^[ \t]*\|/ && !/^[ \t\r]*$/ { printf "%s: line is not a table row (rows start with |): %s\n", m, $0 > err; next }
    on && /^[ \t]*\|/ {
      line = $0; sub(/\r$/, "", line)
      if (line ~ /^[ \t]*\|[-| :\t]+\|?[ \t]*$/) next
      row = cells(line)
      if (!hdr) { hdr = 1; want = NC; next }
      if (NC != want) printf "%s: row has %d cells, header has %d: %s\n", m, NC, want, line > err
      print row > out; rows++
    }
    END {
      if (starts != 1 || ends != 1) printf "%s: needs one start and one end marker (found %d and %d)\n", m, starts, ends > err
      else if (rows == 0) printf "%s: table has no rows\n", m > err
      close(out); close(err)
    }' "$2"
  touch "$3" "$3.err"
}

if [ ! -f "$REG" ]; then
  fail "T13.1 registry: docs/framework/OWNERSHIP.md not found"
  exit 1
fi

# T13.1 — registry well-formed
: > "$W/t1"
for t in signals plugins components families reserved domains lenses; do
  table "$t" "$REG" "$W/$t.tsv"
  cat "$W/$t.tsv.err" >> "$W/t1"
done
report "T13.1" "registry: 7 marked tables well-formed" "$W/t1"

col() { cut -f"$1" "$2" | grep -vx -- '-' || true; }   # COLUMN FILE — cells that are not none
awk -F'\t' '$3 == "released" { print $1 }' "$W/plugins.tsv" | sort -u > "$W/released"
awk -F'\t' '$3 == "planned" { print $1 }' "$W/plugins.tsv" | sort -u > "$W/planned"
cut -f1 "$W/plugins.tsv" | sort -u > "$W/registered"   # any status: a bad status is T13.2's finding
{ ls -d "$ROOT"/plugins/*/ 2>/dev/null || true; } | sed 's|/$||; s|.*/||' | sort -u > "$W/dirs"
MKT="$ROOT/.claude-plugin/marketplace.json"
: > "$W/t2pre"
# The "name" of each plugins[] entry, compact or one key per line; names inside
# nested objects (an entry's "author") are skipped by tracking brace depth.
if [ -f "$MKT" ]; then
  awk '
    !on { if (match($0, /"plugins"[ \t]*:[ \t]*\[/)) { on = 1; $0 = substr($0, RSTART + RLENGTH) } else next }
    { s = $0
      while (s != "") {
        if (d == 1 && match(s, /^"name"[ \t]*:[ \t]*"[^"]*"/)) {
          t = substr(s, 1, RLENGTH); s = substr(s, RLENGTH + 1)
          sub(/^"name"[ \t]*:[ \t]*"/, "", t); sub(/"$/, "", t); print t; continue
        }
        if (match(s, /^"([^"\\]|\\.)*"/)) { s = substr(s, RLENGTH + 1); continue }
        ch = substr(s, 1, 1); s = substr(s, 2)
        if (ch == "{") d++; else if (ch == "}") d--; else if (ch == "]" && d == 0) exit
      }
    }' "$MKT" | sort -u > "$W/mkt"
else
  : > "$W/mkt"; echo ".claude-plugin/marketplace.json not found" >> "$W/t2pre"
fi
TPL="$ROOT/skills/lloydbriantech-ascent/assets/template/.claude/skills"
ls "$TPL" 2>/dev/null | grep '^ascent-' | sort -u > "$W/template" || true
is_in() { grep -qxF -- "$1" "$2"; }

# T13.2 — plugins
cat "$W/t2pre" > "$W/t2"
while read -r d; do is_in "$d" "$W/released" || echo "plugins/$d has no released row" >> "$W/t2"; done < "$W/dirs"
while read -r r; do is_in "$r" "$W/dirs" || echo "released $r has no plugins/$r directory" >> "$W/t2"; done < "$W/released"
while read -r m; do is_in "$m" "$W/released" || echo "marketplace entry $m has no released row" >> "$W/t2"; done < "$W/mkt"
while read -r r; do is_in "$r" "$W/mkt" || echo "released $r has no marketplace entry" >> "$W/t2"; done < "$W/released"
while read -r p; do is_in "$p" "$W/dirs" && echo "planned $p already has a plugins/$p directory: mark it released" >> "$W/t2"; done < "$W/planned"
awk -F'\t' '$3 != "released" && $3 != "planned" { print $1 ": unknown status \"" $3 "\"" }
            $4 != "generated" && $4 != "hand-written" && $4 != "hybrid" { print $1 ": unknown build \"" $4 "\"" }' "$W/plugins.tsv" >> "$W/t2"
awk -F'\t' '{ print $1 }' "$W/plugins.tsv" | sort | uniq -d | sed 's/^/two plugin rows for /' >> "$W/t2"
col 2 "$W/signals.tsv" | sort -u > "$W/signalled"
while read -r s; do is_in "$s" "$W/released" || echo "signal row names $s, which is not a released plugin" >> "$W/t2"; done < "$W/signalled"
while read -r r; do is_in "$r" "$W/signalled" || echo "released $r has no signal in Which plugins do I need?" >> "$W/t2"; done < "$W/released"
report "T13.2" "plugins: $(wc -l < "$W/released" | tr -d ' ') released, $(wc -l < "$W/planned" | tr -d ' ') planned, directories and marketplace agree" "$W/t2"

# T13.3 — components
: > "$W/actual"
while read -r p; do
  [ -d "$ROOT/plugins/$p" ] || continue
  for s in "$ROOT/plugins/$p"/skills/*/; do [ -d "$s" ] && printf '%s\tskill\t%s\n' "$p" "$(basename "$s")" >> "$W/actual"; done
  for a in "$ROOT/plugins/$p"/agents/*.md; do [ -f "$a" ] && printf '%s\tagent\t%s\n' "$p" "$(basename "$a" .md)" >> "$W/actual"; done
  for h in "$ROOT/plugins/$p"/hooks/*.sh; do [ -f "$h" ] && printf '%s\thook\t%s\n' "$p" "$(basename "$h" .sh)" >> "$W/actual"; done
done < "$W/released"
sort -u "$W/actual" -o "$W/actual"
cut -f1-3 "$W/components.tsv" | sort -u > "$W/comps"
: > "$W/t3"
comm -23 "$W/actual" "$W/comps" | awk -F'\t' '{ print $2 " " $1 ":" $3 " is not registered" }' >> "$W/t3"
comm -13 "$W/actual" "$W/comps" | awk -F'\t' '{ print "registered " $2 " " $1 ":" $3 " does not exist" }' >> "$W/t3"
cut -f1-3 "$W/components.tsv" | sort | uniq -d | awk -F'\t' '{ print "two rows for " $1 ":" $3 }' >> "$W/t3"
report "T13.3" "components: $(wc -l < "$W/actual" | tr -d ' ') skills, agents and hooks registered" "$W/t3"

# T13.4 — codes, families and reserved names
: > "$W/t4"
col 2 "$W/plugins.tsv" | sort | uniq -d | sed 's/^/two plugins share the code /' >> "$W/t4"
awk -F'\t' '$2 == "-" { print $1 " has no code" }' "$W/plugins.tsv" >> "$W/t4"
cut -f1 "$W/families.tsv" | sort | uniq -d | sed 's/^/two families share the prefix /' >> "$W/t4"
cut -f1 "$W/reserved.tsv" | sort | uniq -d | sed 's/^/reserved twice: /' >> "$W/t4"
codeof() { awk -F'\t' -v p="$1" '$1 == p { print $2; exit }' "$W/plugins.tsv"; }
while IFS="$(printf '\t')" read -r pre plug kind file; do
  case "$kind" in
    internal)
      [ "$plug" = - ] || echo "internal family $pre names a plugin ($plug)" >> "$W/t4"
      printf '%s' "$pre" | grep -qE '^[A-Z]$' || echo "internal family $pre is not one capital letter" >> "$W/t4" ;;
    rule|catalogue)
      if ! is_in "$plug" "$W/registered"; then echo "family $pre names unregistered plugin $plug" >> "$W/t4"; continue; fi
      c=$(codeof "$plug")
      case "$pre" in "$c"-*) ;; *) echo "family $pre does not start with $plug's code $c-" >> "$W/t4" ;; esac
      printf '%s' "$pre" | grep -qE '^[A-Z]+-[A-Z]+$' || echo "family $pre is not <CODE>-<letters>" >> "$W/t4"
      if is_in "$pre" <(cut -f1 "$W/reserved.tsv"); then
        r=$(awk -F'\t' -v x="$pre" '$1 == x { print $2; exit }' "$W/reserved.tsv")
        [ "$r" = "$plug" ] || echo "family $pre is reserved for $r, used by $plug" >> "$W/t4"
      fi ;;
    *) echo "family $pre has unknown kind \"$kind\"" >> "$W/t4"; continue ;;
  esac
  if [ ! -f "$ROOT/$file" ]; then echo "family $pre: defining file $file not found" >> "$W/t4"
  elif [ "$kind" != internal ] && ! grep -qE "(^|[^A-Za-z0-9-])$pre[01]([^0-9]|$)" "$ROOT/$file"; then
    echo "family $pre: $file never mentions ${pre}1 (or ${pre}0)" >> "$W/t4"
  fi
done < "$W/families.tsv"
while IFS="$(printf '\t')" read -r res for rel; do
  is_in "$for" "$W/registered" || { echo "reserved $res is for unregistered plugin $for" >> "$W/t4"; continue; }
  case "$res" in *-*) c=$(codeof "$for"); case "$res" in "$c"-*) ;; *) echo "reserved $res does not start with $for's code $c-" >> "$W/t4" ;; esac ;; esac
done < "$W/reserved.tsv"
report "T13.4" "families: $(wc -l < "$W/families.tsv" | tr -d ' ') families and $(wc -l < "$W/plugins.tsv" | tr -d ' ') codes unique and defined" "$W/t4"

# T13.5 — contract sections
: > "$W/t5"
col 5 "$W/plugins.tsv" | sort | uniq -d | sed 's/^/two plugins claim the contract section /' >> "$W/t5"
while read -r p; do
  ct="$ROOT/plugins/$p/references/contract-template.yml"
  want=$(awk -F'\t' -v p="$p" '$1 == p { print ($5 == "-" ? "" : $5); exit }' "$W/plugins.tsv")
  got=""
  [ -f "$ct" ] && got=$(sed -n 's/^\([a-z_][a-z0-9_]*\):.*/\1/p' "$ct" | { grep -vx 'version' || true; } | sort -u | tr '\n' ' ' | sed 's/ $//')
  [ "$got" = "$want" ] || echo "$p: contract template declares '${got:-nothing}', registry says '${want:-nothing}'" >> "$W/t5"
done < "$W/released"
report "T13.5" "contract: each plugin declares only its own section" "$W/t5"

# T13.6 — cross-plugin markers
: > "$W/t6"
grep -rhoE '→ ascent-[a-z0-9-]+' "$ROOT/plugins" 2>/dev/null | sed 's/^→ //' | sort -u > "$W/markers" || true
while read -r m; do is_in "$m" "$W/released" || echo "marker → $m names no released plugin ($(grep -rlF -- "→ $m" "$ROOT/plugins" | sed "s|^$ROOT/||" | head -3 | tr '\n' ' '))" >> "$W/t6"; done < "$W/markers"
report "T13.6" "markers: $(wc -l < "$W/markers" | tr -d ' ') cross-plugin targets resolve" "$W/t6"

# T13.7 — domains
: > "$W/t7"
cut -f1 "$W/domains.tsv" | sort | uniq -d | sed 's/^/two rows for the domain /' >> "$W/t7"
while IFS="$(printf '\t')" read -r dom tgt prs st; do
  case "$st" in released|planned) ;; *) echo "$dom: unknown status \"$st\"" >> "$W/t7" ;; esac
  for o in "$tgt" "$prs"; do
    case "$o" in -|operator) continue ;; esac
    if is_in "$o" "$W/registered" || is_in "$o" "$W/template"; then
      [ "$st" = released ] && is_in "$o" "$W/planned" && echo "$dom is released but its owner $o is planned" >> "$W/t7"
    else echo "$dom: owner $o is not a registered plugin or template skill" >> "$W/t7"; fi
  done
done < "$W/domains.tsv"
report "T13.7" "domains: $(wc -l < "$W/domains.tsv" | tr -d ' ') domains, one row each, owners registered" "$W/t7"

# T13.8 — review lenses
norm() { sed 's/`//g; s/, then /,/g; s/, /,/g; s/[[:space:]]*$//'; }
: > "$W/t8"
cut -f1,2 "$W/lenses.tsv" | norm | sort > "$W/lens.reg"
DL="$ROOT/plugins/ascent-delivery/skills/delivery-loop"
# The lens table of a file is its first table whose first header cell is Lens.
for f in "$DL/SKILL.md" "$DL/references/review-lenses.md" "$ROOT/plugins/ascent-delivery/README.md"; do
  awk '/^[ \t]*\|[ \t]*(\*\*)?Lens(\*\*)?[ \t]*\|/ && !done { on = 1 } on && !/^[ \t]*\|/ { on = 0; done = 1 } on' "$f" > "$W/dl.md" 2>/dev/null || true
  if ! grep -q '^|' "$W/dl.md"; then echo "${f#"$ROOT"/} has no lens table" >> "$W/t8"; continue; fi
  printf '<!-- ownership:x:start -->\n' > "$W/dl2.md"; cat "$W/dl.md" >> "$W/dl2.md"; printf '<!-- ownership:x:end -->\n' >> "$W/dl2.md"
  table x "$W/dl2.md" "$W/dl.tsv"
  cut -f1,2 "$W/dl.tsv" | norm | sort > "$W/lens.got"
  if ! cmp -s "$W/lens.reg" "$W/lens.got"; then
    { comm -23 "$W/lens.reg" "$W/lens.got" | sed "s|^|${f#"$ROOT"/} lacks: |"; comm -13 "$W/lens.reg" "$W/lens.got" | sed "s|^|${f#"$ROOT"/} has, registry lacks: |"; } | tr '\t' ' ' >> "$W/t8"
  fi
done
cut -f2 "$W/lenses.tsv" | norm | tr ',' '\n' | { grep -v '^$' || true; } | sort -u > "$W/providers"
{ grep '^ascent-' "$W/providers" || true; } | while IFS=: read -r p c; do
  awk -F'\t' -v p="$p" -v c="$c" '$1 == p && $3 == c && ($2 == "agent" || $2 == "skill") { f = 1 } END { exit !f }' "$W/components.tsv" \
    || echo "provider $p:$c is not a registered skill or agent" >> "$W/t8"
done
for a in "$ROOT"/plugins/*/agents/*.md; do
  [ -f "$a" ] || continue
  awk '/^---/ { c++; next } c == 1' "$a" | tr -s '\n\r\t ' '    ' | grep -q 'delivery-loop review lens' || continue
  id="$(basename "$(dirname "$(dirname "$a")")"):$(basename "$a" .md)"
  is_in "$id" "$W/providers" || echo "agent $id calls itself a delivery-loop review lens but provides none" >> "$W/t8"
done
report "T13.8" "lenses: $(wc -l < "$W/lens.reg" | tr -d ' ') lenses match in the three delivery tables" "$W/t8"

# T13.9 — README and PILLARS
: > "$W/t9"
README="$ROOT/README.md"
while read -r p; do
  [ -f "$ROOT/plugins/$p/.claude-plugin/plugin.json" ] || continue   # T13.2 reports the missing plugin
  v=$(sed -n 's/^  "version":[[:space:]]*"\([^"]*\)".*/\1/p' "$ROOT/plugins/$p/.claude-plugin/plugin.json" | head -1)
  rv=$(sed -n "s/^| \[\`$p\`\]([^)]*) | \([^ |]*\) |.*/\1/p" "$README" | head -1)
  if [ -z "$rv" ]; then echo "README plugin table has no row for $p" >> "$W/t9"
  elif [ "$rv" != "$v" ]; then echo "README says $p $rv, plugin.json says $v" >> "$W/t9"; fi
done < "$W/released"
PIL="$ROOT/docs/framework/PILLARS.md"
awk -F'|' '/^\| Attribute \| Checked by \|/ { on = 1; next } on && /^\|/ { print $3; next } { on = 0 }' "$PIL" > "$W/checked"
{ grep -oE '`ascent-[a-z0-9-]+`' "$W/checked" || true; } | tr -d '`' | sort -u | while read -r n; do
  is_in "$n" "$W/registered" || is_in "$n" "$W/template" || echo "PILLARS names $n, which is neither a registered plugin nor a template skill" >> "$W/t9"
done
{ grep -oE '`ascent-[a-z0-9-]+` \([^)]*\)' "$W/checked" || true; } | while IFS= read -r g; do
  p=$(printf '%s' "$g" | sed 's/^`\([^`]*\)`.*/\1/')
  { printf '%s' "${g#*(}" | grep -oE '`[a-z][a-z0-9-]*`' || true; } | tr -d '`' | while read -r s; do
    awk -F'\t' -v p="$p" -v s="$s" '$1 == p && $3 == s { f = 1 } END { exit !f }' "$W/components.tsv" \
      || echo "PILLARS names $p ($s), which is not a registered component" >> "$W/t9"
  done
done
# A bare name (`quality-attributes`) must be a skill or agent of some registered plugin.
{ grep -oE '`[a-z][a-z0-9-]*`' "$W/checked" || true; } | tr -d '`' | { grep -v '^ascent-' || true; } | sort -u | while read -r s; do
  awk -F'\t' -v s="$s" '$3 == s { f = 1 } END { exit !f }' "$W/components.tsv" \
    || echo "PILLARS names $s, which is not a registered skill or agent" >> "$W/t9"
done
report "T13.9" "docs: README versions and PILLARS names match the registry" "$W/t9"

# T13.10 — qualified rule ids
: > "$W/t10"
CODES=$(col 2 "$W/plugins.tsv" | sort -u | tr '\n' '|' | sed 's/|$//')
{ cut -f1 "$W/families.tsv"; cut -f1 "$W/reserved.tsv"; } | grep -- '-' | sort -u > "$W/prefixes"
find "$ROOT/plugins" -name '*.md' | sort | while read -r f; do
  grep -nE '^\| [*`]{0,2}[A-Z]{1,2}[0-9]{1,2}[*`]{0,2} \|' "$f" | sed "s|^|${f#"$ROOT"/}:|; s/^\([^:]*:[0-9]*\):\(| [^|]*|\).*/\1 unqualified id cell \2/" >> "$W/t10" || true
done
find "$ROOT/plugins" -name '*.sh' | sort | while read -r f; do
  grep -nE '^#   [A-Z]{1,2}[0-9]{1,2} +(High|Medium|Low) ' "$f" | sed "s|^|${f#"$ROOT"/}:|; s/^\([^:]*:[0-9]*\):#   \([A-Z0-9]*\).*/\1 unqualified header id \2/" >> "$W/t10" || true
done
{ grep -rhoE "(^|[^A-Za-z0-9-])($CODES)-[A-Z]+[0-9]+" "$ROOT/plugins" "$ROOT/docs/framework/PILLARS.md" 2>/dev/null || true; } \
  | sed -E 's/^[^A-Z]*//; s/[0-9]+$//' | sort -u | while read -r pre; do
  is_in "$pre" "$W/prefixes" || echo "id prefix $pre is not a registered or reserved family" >> "$W/t10"
done
report "T13.10" "id format: plugin rule ids are qualified and registered" "$W/t10"

[ "$NFAIL" -eq 0 ]
