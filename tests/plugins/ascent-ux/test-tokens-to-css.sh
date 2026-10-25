#!/usr/bin/env bash
# Behavior test for plugins/ascent-ux/scripts/tokens-to-css.sh.
#
# Value shapes (hex, srgb components, dimension and duration objects, font stacks,
# cubicBezier, numbers), alias resolution, the light block and both dark blocks
# (media query and [data-theme=dark]) with only the tokens that change, group
# $type inheritance, every shipped direction converting cleanly, the blueprint's
# tokens.css staying identical to the D1 output (no drift), and bad input.
#
# Runs with the default awk and every other awk found (mawk, gawk, BWK awk).
# Prints "test-tokens-to-css: N/N PASS" last (make/test-plugins.sh T11).
# Portable: bash 3.2+, GNU/Linux and BSD/macOS.

set -u
WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT INT TERM
HERE="$(cd "$(dirname "$0")" && pwd)"
PLUGIN="$HERE/../../../plugins/ascent-ux"
CONV="$PLUGIN/scripts/tokens-to-css.sh"
DIRS="$PLUGIN/directions"
BP="$PLUGIN/blueprints/accessible-page"
for f in "$CONV" "$BP/tokens.css"; do [ -f "$f" ] || { echo "test-tokens-to-css: missing $f"; echo "test-tokens-to-css: 0/1 PASS"; exit 1; }; done

PASS=0; FAIL=0
ok()  { PASS=$((PASS + 1)); }
bad() { FAIL=$((FAIL + 1)); printf "FAIL  [%s] %s\n" "$AWKNAME" "$1"; }
run() { PATH="$SHIM:$PATH" bash "$CONV" "$@" >"$WORK/out" 2>"$WORK/err"; RC=$?; OUT=$(cat "$WORK/out"); }
has() { if printf '%s\n' "$OUT" | grep -qF -- "$2"; then ok; else bad "$1: output lacks '$2'"; fi; }
lacks() { if printf '%s\n' "$OUT" | grep -qF -- "$2"; then bad "$1: output must not contain '$2'"; else ok; fi; }
rc() { if [ "$RC" -eq "$2" ]; then ok; else bad "$1: expected exit $2, got $RC: $(tr '\n' ';' < "$WORK/err")"; fi; }

cat > "$WORK/a.light.tokens.json" <<'J'
{
  "color": { "$type": "color",
    "text": { "$value": "#1f2328" },
    "comp": { "$value": { "colorSpace": "srgb", "components": [1, 0.5, 0] } },
    "link": { "$value": "{color.text}" },
    "same": { "$value": "#ffffff" } },
  "font": { "family": { "$type": "fontFamily", "body": { "$value": ["Source Serif 4", "Georgia", "serif"] } },
            "weight": { "$type": "fontWeight", "bold": { "$value": 700 } } },
  "space": { "$type": "dimension", "2": { "$value": { "value": 8, "unit": "px" } } },
  "motion": { "fast": { "$type": "duration", "$value": { "value": 120, "unit": "ms" } },
              "ease": { "$type": "cubicBezier", "$value": [0.2, 0, 0, 1] } }
}
J
cat > "$WORK/a.dark.tokens.json" <<'J'
{ "color": { "$type": "color", "text": { "$value": "#e6edf3" }, "same": { "$value": "#ffffff" } } }
J

matrix() {
  run "$WORK/a.light.tokens.json" "$WORK/a.dark.tokens.json"
  rc ok 0
  has root ":root {"
  has hex "  --color-text: #1f2328;"
  has comp "  --color-comp: #ff8000;"
  has alias "  --color-link: #1f2328;"
  has font '  --font-family-body: "Source Serif 4", Georgia, serif;'
  has weight "  --font-weight-bold: 700;"
  has dim "  --space-2: 8px;"
  has dur "  --motion-fast: 120ms;"
  has bezier "  --motion-ease: cubic-bezier(0.2, 0, 0, 1);"
  has media "@media (prefers-color-scheme: dark) {"
  has media-sel '  :root:not([data-theme="light"]) {'
  has dark-media "    --color-text: #e6edf3;"
  has dark-attr ':root[data-theme="dark"] {'
  has dark-attr-val "  --color-text: #e6edf3;"
  [ "$(printf '%s\n' "$OUT" | grep -c -- '--color-same:')" -eq 1 ] && ok || bad "unchanged token repeated in the dark blocks"
  # An alias resolves in its own theme: link follows text into dark.
  [ "$(printf '%s\n' "$OUT" | grep -c -- '--color-link: #e6edf3;')" -eq 0 ] && ok || bad "alias in dark should not appear (link is not defined in the dark file)"

  run "$WORK/a.light.tokens.json"
  rc light-only 0
  lacks light-only "prefers-color-scheme"

  # Every direction converts; the blueprint sheet is exactly the D1 output.
  for f in "$DIRS"/*.light.tokens.json; do
    run "$f" "${f%.light.tokens.json}.dark.tokens.json"
    if [ "$RC" -eq 0 ] && [ "$(printf '%s\n' "$OUT" | grep -c -- '^  --')" -ge 40 ]; then ok; else bad "direction $(basename "$f"): exit $RC, $(printf '%s\n' "$OUT" | grep -c -- '^  --') properties"; fi
  done
  run "$DIRS/D1-clean-neutral.light.tokens.json" "$DIRS/D1-clean-neutral.dark.tokens.json"
  if printf '%s\n' "$OUT" | cmp -s - "$BP/tokens.css"; then ok; else bad "blueprints/accessible-page/tokens.css drifted from the D1 tokens: regenerate it with tokens-to-css.sh"; fi

  # Bad input stops with exit 2.
  printf '{ "a": { "$value": "{nope.x}" } }' > "$WORK/alias.tokens.json"; run "$WORK/alias.tokens.json"; rc badalias 2
  printf '{ "a": { "$value": { "weird": 1 } } }' > "$WORK/obj.tokens.json"; run "$WORK/obj.tokens.json"; rc badobj 2
  printf '[1, 2]' > "$WORK/arr.tokens.json"; run "$WORK/arr.tokens.json"; rc notobject 2
  run "$WORK/missing.json"; rc nofile 2
  printf 'x' > "$WORK/x.css"; run "$WORK/x.css"; rc notjson 2
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

printf "test-tokens-to-css: %s/%s PASS (awk: %s)\n" "$PASS" "$((PASS + FAIL))" "$AWKS"
[ "$FAIL" -eq 0 ]
