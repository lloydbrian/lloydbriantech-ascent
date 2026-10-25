#!/usr/bin/env bash
# Behavior test for plugins/ascent-ux/scripts/check-token-contrast.sh.
#
# Hand-checkable ratios (black on white is 21:1; #767676 on white is 4.54:1, just
# above AA; #777777 is 4.47:1, just below), the three kinds and their thresholds,
# truncation (never rounding up), aliases in JSON and CSS, srgb components without
# hex, themes from file names and from CSS selectors and media queries, dark falling
# back to light, inferred pairs (CSS rules, names, *-on-X only on X), missing tokens,
# alias loops, translucent colors, every shipped direction in both themes, and bad
# input.
#
# Runs with the default awk and every other awk found (mawk, gawk, BWK awk).
# Prints "test-check-token-contrast: N/N PASS" last (make/test-plugins.sh T11).
# Portable: bash 3.2+, GNU/Linux and BSD/macOS.

set -u
WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT INT TERM
HERE="$(cd "$(dirname "$0")" && pwd)"
PLUGIN="$HERE/../../../plugins/ascent-ux"
CHECK="$PLUGIN/scripts/check-token-contrast.sh"
DIRS="$PLUGIN/directions"
for f in "$CHECK" "$DIRS/pairs.tsv"; do [ -f "$f" ] || { echo "test-check-token-contrast: missing $f"; echo "test-check-token-contrast: 0/1 PASS"; exit 1; }; done

PASS=0; FAIL=0
ok()  { PASS=$((PASS + 1)); }
bad() { FAIL=$((FAIL + 1)); printf "FAIL  [%s] %s\n" "$AWKNAME" "$1"; }
run() { PATH="$SHIM:$PATH" bash "$CHECK" "$@" >"$WORK/out" 2>&1; RC=$?; OUT=$(cat "$WORK/out"); }
has() { if printf '%s\n' "$OUT" | grep -qF -- "$2"; then ok; else bad "$1: output lacks '$2': $(printf '%s' "$OUT" | head -4 | tr '\n' ';')"; fi; }
lacks() { if printf '%s\n' "$OUT" | grep -qF -- "$2"; then bad "$1: output must not contain '$2'"; else ok; fi; }
rc() { if [ "$RC" -eq "$2" ]; then ok; else bad "$1: expected exit $2, got $RC: $(printf '%s' "$OUT" | tail -2 | tr '\n' ';')"; fi; }

cat > "$WORK/t.light.tokens.json" <<'J'
{
  "$description": "fixture",
  "color": {
    "$type": "color",
    "text": {
      "black": { "$value": "#000000" },
      "grey76": { "$value": { "colorSpace": "srgb", "components": [0.4627, 0.4627, 0.4627], "hex": "#767676" } },
      "grey77": { "$value": "#777777" },
      "comp": { "$value": { "colorSpace": "srgb", "components": [0, 0, 0] } },
      "alias": { "$value": "{color.text.black}" },
      "loop-a": { "$value": "{color.text.loop-b}" },
      "loop-b": { "$value": "{color.text.loop-a}" },
      "ghost": { "$value": "#00000080" }
    },
    "surface": { "base": { "$value": "{color.white}" } },
    "white": { "$value": "#ffffff", "$description": "skipped key" }
  }
}
J
cat > "$WORK/t.dark.tokens.json" <<'J'
{ "color": { "$type": "color", "surface": { "base": { "$value": "#000000" } } } }
J
printf '# fixture pairs\ncolor-text-black\tcolor-surface-base\ttext\ncolor-text-grey76\tcolor-surface-base\ttext\ncolor-text-grey77\tcolor-surface-base\ttext\ncolor-text-grey77\tcolor-surface-base\tlarge-text\ncolor-text-grey77\tcolor-surface-base\tui\ncolor-text-comp\tcolor-surface-base\ttext\ncolor-text-alias\tcolor-surface-base\ttext\n' > "$WORK/pairs.tsv"

matrix() {
  run --pairs "$WORK/pairs.tsv" "$WORK/t.light.tokens.json"
  rc ratios 1
  has black "PASS  light  color-text-black on color-surface-base  21.00:1  text (needs 4.5)"
  has grey76 "PASS  light  color-text-grey76 on color-surface-base  4.54:1  text"
  has grey77 "FAIL  light  color-text-grey77 on color-surface-base  4.47:1  text (needs 4.5)"
  has large "PASS  light  color-text-grey77 on color-surface-base  4.47:1  large-text (needs 3)"
  has ui "PASS  light  color-text-grey77 on color-surface-base  4.47:1  ui (needs 3)"
  has components "PASS  light  color-text-comp on color-surface-base  21.00:1"
  has alias "PASS  light  color-text-alias on color-surface-base  21.00:1"
  has summary "check-token-contrast: 7 pairs in 1 theme(s), 6 pass, 1 fail, 0 skipped (pairs: pairs file)"

  # Dark comes from the file name; text not overridden in dark falls back to light.
  printf 'color-text-grey76\tcolor-surface-base\ttext\n' > "$WORK/p1.tsv"
  run --pairs "$WORK/p1.tsv" "$WORK/t.light.tokens.json" "$WORK/t.dark.tokens.json"
  rc themes 0
  has dark "PASS  dark   color-text-grey76 on color-surface-base  4.62:1"
  has light "PASS  light  color-text-grey76 on color-surface-base  4.54:1"

  # Missing tokens and alias loops are failures, never silent passes.
  printf 'color-text-nope\tcolor-surface-base\tui\ncolor-text-loop-a\tcolor-surface-base\ttext\n' > "$WORK/p2.tsv"
  run --pairs "$WORK/p2.tsv" "$WORK/t.light.tokens.json"
  rc missing 1
  has missing "missing: no token color-text-nope"
  has loop "missing: alias loop"

  # Translucent colors cannot be judged alone: SKIP, not PASS.
  printf 'color-text-ghost\tcolor-surface-base\ttext\n' > "$WORK/p3.tsv"
  run --pairs "$WORK/p3.tsv" "$WORK/t.light.tokens.json"
  rc translucent 0
  has translucent "SKIP  light  color-text-ghost on color-surface-base  translucent foreground"
  has skipcount "0 pass, 0 fail, 1 skipped"

  # CSS: themes from :root, a dark media query and [data-theme=dark]; var() chains;
  # pairs inferred from rules; *-on-X pairs only with X.
  cat > "$WORK/s.css" <<'C'
/* --commented: #ff0000; */
:root { --fg: #222; --bg: white; --link: var(--fg); --color-accent-base: #0a58ca; --color-text-on-accent: #ffffff; --color-surface-base: #ffffff; --color-text-body: #222222; }
@media (prefers-color-scheme: dark) { :root { --fg: #eeeeee; --bg: #121212; --color-surface-base: #121212; --color-text-body: #eeeeee; } }
.card { color: var(--fg); background-color: var(--bg); }
a { color: var(--link); background: var(--bg) }
C
  run "$WORK/s.css"
  rc css 0
  has css-dark "PASS  dark   fg on bg  16.14:1  text (needs 4.5)  inferred"
  has css-base "PASS  base   fg on bg  15.90:1  text (needs 4.5)  inferred"
  [ "$(printf '%s\n' "$OUT" | grep -c 'base   fg on bg ')" -eq 1 ] && ok || bad "a pair inferred from a rule and from names must appear once per theme"
  has css-chain "PASS  dark   link on bg  16.14:1"
  has on-accent "PASS  base   color-text-on-accent on color-accent-base"
  lacks on-surface "color-text-on-accent on color-surface-base"
  has named "color-text-body on color-surface-base"
  lacks comment "commented"
  has inferred "(pairs: inferred)"

  # An inferred pair whose variable is defined elsewhere is a SKIP, not a FAIL.
  printf ':root { --ink: #111111; }\n.note { color: var(--ink); background-color: var(--from-js); }\n' > "$WORK/partial.css"
  run "$WORK/partial.css"
  rc partial 0
  has partial "SKIP  base   ink on from-js  not defined in the scanned files: no token from-js  inferred"

  # A plain :root palette is "base", not "light", even when it is dark (C4); names
  # without the color- prefix are inferred (C6); pair files accept "--" (C5).
  printf ':root { --text-dim: #4a6a8a; --text-main: #e2e8f0; --bg: #0a0f1c; --bg-2: #0d1526; }\n' > "$WORK/dark-root.css"
  run "$WORK/dark-root.css"
  has c4-base "FAIL  base   text-dim on bg-2  3.22:1  text (needs 4.5)  inferred"
  lacks c4-nolight "light  text-dim"
  has c6-names "PASS  base   text-main on bg  "
  printf -- '--text-dim\t--bg-2\ttext\n' > "$WORK/dashes.tsv"
  run --pairs "$WORK/dashes.tsv" "$WORK/dark-root.css"
  has c5-dashes "FAIL  base   text-dim on bg-2  3.22:1  text (needs 4.5)"
  rc c5-rc 1

  # Every shipped direction passes the shared pairs in light and dark.
  n=0
  for f in "$DIRS"/*.light.tokens.json; do
    d=${f%.light.tokens.json}; n=$((n + 1))
    run --pairs "$DIRS/pairs.tsv" "$f" "$d.dark.tokens.json"
    if [ "$RC" -eq 0 ] && printf '%s\n' "$OUT" | grep -q ' 0 fail, 0 skipped'; then ok; else bad "direction $(basename "$d"): $(printf '%s\n' "$OUT" | grep -E '^(FAIL|SKIP)' | head -3 | tr '\n' ';')"; fi
  done
  [ "$n" -eq 5 ] && ok || bad "expected 5 directions, found $n"

  # Bad input stops with exit 2.
  printf 'a\tb\tbody\n' > "$WORK/badkind.tsv"; run --pairs "$WORK/badkind.tsv" "$WORK/t.light.tokens.json"; rc badkind 2
  printf '{ "color": ' > "$WORK/broken.tokens.json"; run "$WORK/broken.tokens.json"; rc badjson 2
  printf 'x' > "$WORK/x.txt"; run "$WORK/x.txt"; rc badtype 2
  run "$WORK/nope.json"; rc nofile 2
  printf '{ "space": { "$type": "dimension", "s": { "$value": { "value": 4, "unit": "px" } } } }' > "$WORK/nocolor.tokens.json"; run "$WORK/nocolor.tokens.json"; rc nopairs 2
}

realpath_of() { (cd "$(dirname "$1")" && printf '%s/%s\n' "$(pwd -P)" "$(basename "$1")"); }
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

printf "test-check-token-contrast: %s/%s PASS (awk: %s)\n" "$PASS" "$((PASS + FAIL))" "$AWKS"
[ "$FAIL" -eq 0 ]
