# tokens.awk: shared design-token parsing for the ascent-ux scripts
# (check-token-contrast.sh, tokens-to-css.sh). Read-only, POSIX awk.
#
# json_load(TEXT, THEME) parses Design Tokens Community Group format 2025.10 JSON.
#   Tokens are objects with "$value"; groups nest; "$type" is inherited from the
#   nearest group; other "$" keys ($description, $extensions, $deprecated) are skipped.
#   $value may be a string (including an alias "{group.token}"), a number, an array
#   of strings or numbers, a color object with "hex" (or srgb "components"), or a
#   dimension or duration object {"value": N, "unit": "px"}.
#   Fills V[THEME, name], T[THEME, name] and NAMES[THEME] (space-separated), where
#   name is the token path joined with "-" (the CSS custom property name).
# css_load(TEXT) parses CSS custom properties ("--name: value;"). A property
#   counts for theme "dark" inside a dark selector or media query
#   (prefers-color-scheme: dark, [data-theme=dark], .dark, .theme-dark), else
#   "light". Rules that set both color and background(-color) from var(--x) are
#   recorded as inferred pairs in RULEPAIR[n] = "fg bg".
# resolve(THEME, NAME) follows aliases ({a.b} and var(--a)) to a final value,
#   falling back to theme "light", then "default". Sets RESERR on failure.
# parse_color(VALUE) sets CR, CG, CB (0-255) and CA (0-1); returns 1 on success,
#   0 when the value is not a supported color (hex, rgb(), rgba(), white, black).

function terr(m) { if (TOKERR == "") TOKERR = m " (offset " JP ")"; JP = JL + 1 }
function jch() { return substr(JS, JP, 1) }
function jws(  c) {
  while (JP <= JL) {
    c = substr(JS, JP, 1)
    if (c == " " || c == "\t" || c == "\n" || c == "\r") JP++; else break
  }
}
function jstr(  out, c, rest, k) {
  if (jch() != "\"") { terr("expected a string"); return "" }
  JP++; out = ""
  while (JP <= JL) {
    rest = substr(JS, JP)
    k = match(rest, /["\\]/)
    if (k == 0) { terr("unterminated string"); return out }
    out = out substr(rest, 1, k - 1); JP += k - 1
    c = substr(JS, JP, 1)
    if (c == "\"") { JP++; return out }
    out = out substr(JS, JP + 1, 1); JP += 2          # escaped character, kept literally
  }
  terr("unterminated string"); return out
}
function jscalar(  rest, k, s) {
  rest = substr(JS, JP)
  k = match(rest, /[,}\] \t\r\n]/)
  s = (k == 0) ? rest : substr(rest, 1, k - 1)
  if (s == "") { terr("expected a value"); return "" }
  JP += length(s)
  return s
}
function jskip(  c, depth) {
  c = jch()
  if (c == "\"") { jstr(); return }
  if (c != "{" && c != "[") { jscalar(); return }
  depth = 0
  while (JP <= JL) {
    c = jch()
    if (c == "\"") { jstr(); continue }
    if (c == "{" || c == "[") depth++
    else if (c == "}" || c == "]") { depth--; if (depth == 0) { JP++; return } }
    JP++
  }
  terr("unterminated object")
}
function jcolon() { jws(); if (jch() != ":") { terr("expected :"); return 0 } JP++; jws(); return 1 }
function srgb_hex(list,   n, p, i, out, x) {
  n = split(list, p, /, */)
  if (n != 3) return ""
  out = "#"
  for (i = 1; i <= 3; i++) { x = int(p[i] * 255 + 0.5); if (x < 0) x = 0; if (x > 255) x = 255; out = out sprintf("%02x", x) }
  return out
}
function jvalue(  c, s, k, hex, val, unit, cs, comp, out, first) {
  c = jch()
  if (c == "\"") return jstr()
  if (c == "[") {
    JP++; out = ""; first = 1
    while (JP <= JL) {
      jws()
      if (jch() == "]") { JP++; return out }
      if (jch() == "\"") { s = jstr(); if (s ~ / /) s = "\"" s "\"" }
      else if (jch() == "{" || jch() == "[") { terr("nested arrays or objects in an array value are not supported"); return "" }
      else s = jscalar()
      out = first ? s : out ", " s; first = 0
      jws(); if (jch() == ",") JP++
    }
    terr("unterminated array"); return ""
  }
  if (c == "{") {
    JP++; hex = ""; val = ""; unit = ""; cs = ""; comp = ""
    while (JP <= JL) {
      jws()
      if (jch() == "}") { JP++; break }
      k = jstr(); if (!jcolon()) return ""
      if (k == "hex") hex = jstr()
      else if (k == "value") val = (jch() == "\"") ? jstr() : jscalar()
      else if (k == "unit") unit = jstr()
      else if (k == "colorSpace") cs = jstr()
      else if (k == "components") comp = jvalue()
      else jskip()
      jws(); if (jch() == ",") JP++
    }
    if (hex != "") return hex
    if (val != "" && unit != "") return val unit
    if (cs == "srgb" && comp != "") { s = srgb_hex(comp); if (s != "") return s }
    terr("unsupported $value object"); return ""
  }
  return jscalar()
}
function jobj(theme, path,   key, v, name) {
  JP++; jws()
  if (jch() == "}") { JP++; return }
  while (JP <= JL) {
    jws(); key = jstr(); if (!jcolon()) return
    if (key == "$value") {
      v = jvalue(); name = path; gsub(/\./, "-", name)
      if (!((theme, name) in V)) NAMES[theme] = NAMES[theme] " " name
      V[theme, name] = v; TPATH[theme, name] = path
    } else if (key == "$type") {
      if (jch() == "\"") GTYPE[theme, path] = jstr(); else jskip()
    } else if (substr(key, 1, 1) == "$") jskip()
    else if (jch() == "{") jobj(theme, (path == "") ? key : path "." key)
    else jskip()
    jws()
    if (jch() == ",") { JP++; continue }
    if (jch() == "}") { JP++; return }
    terr("expected , or }"); return
  }
}
function json_load(text, theme,   n, i, nm, p, names) {
  JS = text; JL = length(JS); JP = 1; jws()
  if (jch() != "{") { terr("the file is not a JSON object"); return 0 }
  jobj(theme, "")
  if (TOKERR != "") return 0
  n = split(NAMES[theme], names, " ")
  for (i = 1; i <= n; i++) {
    nm = names[i]; p = TPATH[theme, nm]
    while (1) {
      if ((theme, p) in GTYPE) { T[theme, nm] = GTYPE[theme, p]; break }
      if (p !~ /\./) { if ((theme, "") in GTYPE) T[theme, nm] = GTYPE[theme, ""]; break }
      sub(/\.[^.]*$/, "", p)
    }
  }
  return 1
}

function trim(s) { sub(/^[ \t\r\n]+/, "", s); sub(/[ \t\r\n]+$/, "", s); return s }
function css_theme(ctx,   c) {
  c = tolower(ctx)
  if (c ~ /prefers-color-scheme:[ ]*dark/ || c ~ /data-theme=["']?dark/ || c ~ /\.dark([^a-z0-9_-]|$)/ || c ~ /\.theme-dark/) return "dark"
  return "light"
}
function css_decls(decls, theme,   n, d, i, k, prop, val, fg, bg) {
  n = split(decls, d, ";"); fg = ""; bg = ""
  for (i = 1; i <= n; i++) {
    k = index(d[i], ":"); if (k == 0) continue
    prop = trim(substr(d[i], 1, k - 1)); val = trim(substr(d[i], k + 1))
    sub(/[ \t]*!important$/, "", val)
    if (prop ~ /^--/) {
      prop = substr(prop, 3)
      if (!((theme, prop) in V)) NAMES[theme] = NAMES[theme] " " prop
      V[theme, prop] = val
    } else if (prop == "color" && match(val, /var\(--[A-Za-z0-9_-]+/)) fg = substr(val, RSTART + 6, RLENGTH - 6)
    else if ((prop == "background-color" || prop == "background") && match(val, /var\(--[A-Za-z0-9_-]+/)) bg = substr(val, RSTART + 6, RLENGTH - 6)
  }
  if (fg != "" && bg != "" && !((fg " " bg) in RULESEEN)) { RULESEEN[fg " " bg] = 1; RULEPAIR[++NRULEPAIR] = fg " " bg }
}
function css_load(text,   depth, ctx, seg, k, c, pre, j, decl) {
  while (match(text, /\/\*/)) {
    k = index(substr(text, RSTART + 2), "*/")
    text = substr(text, 1, RSTART - 1) " " ((k == 0) ? "" : substr(text, RSTART + 2 + k + 1))
  }
  depth = 0
  while (match(text, /[{}]/)) {
    seg = substr(text, 1, RSTART - 1); c = substr(text, RSTART, 1); text = substr(text, RSTART + 1)
    if (c == "{") {
      j = 0; pre = seg
      while (match(pre, /;/)) { j += RSTART; pre = substr(pre, RSTART + 1) }
      decl = (j > 0) ? substr(seg, 1, j) : ""
      if (depth > 0 && decl != "") css_decls(decl, css_theme(ctxs(depth)))
      depth++; CTX[depth] = trim(pre)
    } else {
      if (depth > 0) css_decls(seg, css_theme(ctxs(depth)))
      depth--; if (depth < 0) depth = 0
    }
  }
  return 1
}
function ctxs(n,   i, s) { s = ""; for (i = 1; i <= n; i++) s = s " " CTX[i]; return s }

function lookup(theme, name) {
  if ((theme, name) in V) return V[theme, name]
  if (theme != "light" && (("light", name) in V)) return V["light", name]
  if (theme != "default" && (("default", name) in V)) return V["default", name]
  RESERR = "no token " name; return ""
}
function resolve(theme, name,   v, depth, ref) {
  RESERR = ""; v = lookup(theme, name); depth = 0
  while (RESERR == "" && depth < 12) {
    if (v ~ /^\{[^}]+\}$/) { ref = substr(v, 2, length(v) - 2); gsub(/\./, "-", ref) }
    else if (v ~ /^var\(--[A-Za-z0-9_-]+[ ]*(,.*)?\)$/) { ref = v; sub(/^var\(--/, "", ref); sub(/[ ,)].*$/, "", ref) }
    else return v
    v = lookup(theme, ref); depth++
  }
  if (RESERR == "") RESERR = "alias loop at " name
  return ""
}
function hexval(h,   i, n, d) {
  n = 0; h = tolower(h)
  for (i = 1; i <= length(h); i++) { d = index("0123456789abcdef", substr(h, i, 1)); if (d == 0) return -1; n = n * 16 + d - 1 }
  return n
}
function parse_color(v,   h, p, n, i, x) {
  v = tolower(trim(v)); CA = 1
  if (v == "white") { CR = 255; CG = 255; CB = 255; return 1 }
  if (v == "black") { CR = 0; CG = 0; CB = 0; return 1 }
  if (v ~ /^#[0-9a-f]+$/) {
    h = substr(v, 2)
    if (length(h) == 3 || length(h) == 4) h = substr(h,1,1) substr(h,1,1) substr(h,2,1) substr(h,2,1) substr(h,3,1) substr(h,3,1) (length(h) == 4 ? substr(h,4,1) substr(h,4,1) : "")
    if (length(h) != 6 && length(h) != 8) return 0
    CR = hexval(substr(h, 1, 2)); CG = hexval(substr(h, 3, 2)); CB = hexval(substr(h, 5, 2))
    if (length(h) == 8) CA = hexval(substr(h, 7, 2)) / 255
    return 1
  }
  if (v ~ /^rgba?\(/) {
    sub(/^rgba?\(/, "", v); sub(/\)$/, "", v); gsub(/[\/,]/, " ", v)
    n = split(v, p, " ")
    if (n < 3) return 0
    for (i = 1; i <= 3; i++) { x = p[i]; if (x ~ /%$/) { sub(/%$/, "", x); x = x * 2.55 } if (i == 1) CR = x; else if (i == 2) CG = x; else CB = x }
    if (n >= 4) { x = p[4]; if (x ~ /%$/) { sub(/%$/, "", x); x = x / 100 } CA = x + 0 }
    return 1
  }
  return 0
}
