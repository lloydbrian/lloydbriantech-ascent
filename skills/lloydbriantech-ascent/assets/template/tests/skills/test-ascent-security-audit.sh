#!/usr/bin/env bash
# Test: ascent-security-audit
# Verifies static security checks: env-file scope, hardcoded credentials (long and
# short), container privilege, nginx headers and dynamic code execution.
# Per PHASE-3-PLAN.md §4: bash test, self-contained, trap-based cleanup.
set -euo pipefail

FIXTURES_DIR="tests/skills/.fixtures/security-audit"
PASS_COUNT=0
FAIL_COUNT=0

cleanup() {
  rm -rf "$FIXTURES_DIR"
}
trap cleanup EXIT
# shellcheck source=lib/portable.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib/portable.sh"

assert_pass() {
  PASS_COUNT=$((PASS_COUNT + 1))
  printf "PASS  ascent-security-audit: %s\n" "$1"
}

assert_fail() {
  FAIL_COUNT=$((FAIL_COUNT + 1))
  printf "FAIL  ascent-security-audit: %s\n" "$1"
}

# Reusable: .env is ignored when a line names it exactly or by a pattern that
# matches the file .env itself (skill Step 1). `.env.local` or `.envrc` alone
# does not count; `/.env`, `*.env`, `**/.env` and `.env*` do.
check_env_gitignored() {
  local gitignore="$1"
  [ -f "$gitignore" ] && grep -qE '^[[:space:]]*(/|\*\*/|\*)?\.env(\*)?[[:space:]]*$|^[[:space:]]*\*\.env[[:space:]]*$' "$gitignore"
}

# Reusable: hardcoded credential findings (skill Step 2). Prints one line per
# finding as "file:line — <rule>". Content is matched but NEVER printed: the
# line numbers come from grep -n and only the number is kept.
CRED_KEY='[A-Za-z0-9_]*(api[_-]?key|secret|passw(or)?d|token|private[_-]?key|access[_-]?key|client[_-]?secret)[A-Za-z0-9_]*'
CRED_VAL="([\"'\`][^\"'\`[:space:]\$]{8,}[\"'\`]|[^[:space:]\"'\`\$#{<(*][^[:space:];,()]{7,}[[:space:];,]*\$)"
CRED_RE="${CRED_KEY}[\"']?[[:space:]]*[:=][[:space:]]*${CRED_VAL}"
CRED_SAFE="[:=][[:space:]]*[\"'\`]?(process\\.env|os\\.environ|getenv|ENV\\[|true[\"'\`]?[[:space:];,]*\$|false[\"'\`]?[[:space:];,]*\$|null[\"'\`]?[[:space:];,]*\$|[0-9]+[\"'\`]?[[:space:];,]*\$)"
AWS_RE='AKIA[0-9A-Z]{16}'
credential_findings() {
  local target="$1" f n
  {
    { grep -rliE --exclude-dir=node_modules --exclude-dir=dist --exclude-dir=build \
        --exclude-dir=vendor --exclude-dir=.git -- "$CRED_RE" "$target" 2>/dev/null || true; } |
    while IFS= read -r f; do
      { grep -niE -- "$CRED_RE" "$f" || true; } | { grep -viE -- "$CRED_SAFE" || true; } | cut -d: -f1 |
      while IFS= read -r n; do printf '%s:%s — hardcoded secret\n' "$f" "$n"; done
    done
    { grep -rlE --exclude-dir=node_modules --exclude-dir=dist --exclude-dir=build \
        --exclude-dir=vendor --exclude-dir=.git -- "$AWS_RE" "$target" 2>/dev/null || true; } |
    while IFS= read -r f; do
      { grep -nE -- "$AWS_RE" "$f" || true; } | cut -d: -f1 |
      while IFS= read -r n; do printf '%s:%s — cloud access key\n' "$f" "$n"; done
    done
    short_credential_findings "$target"
  } | awk -F' — ' '!seen[$1]++'
}

# Reusable: short hardcoded credentials (skill Step 2, Medium). A key is split
# into words at "_", "-" and lower-to-upper camelCase boundaries; one word must
# be exactly pin, passcode, password, passwd, secret or token (so adminPin,
# ORGANIZER_PIN and pin_code count; spinner, pinned and tokenizer do not). The
# key is assigned (":", "=", ":=") or compared ("==", "===", "!=", "!==") to a
# quoted literal of 4-7 characters with no spaces and no "$". Quoted digits
# ("4821") count; bare numbers, empty values and quoted true/false/null do not.
# Only file and line number are printed, never the value or the line.
SHORT_PRE="(pin|passcode|passw(or)?d|secret|token)[A-Za-z0-9_-]*[\"']?[[:space:]]*(:=?|=|[=!]==?)[[:space:]]*[\"'\`]"
short_credential_findings() {
  local target="$1" f
  { grep -rliE --exclude-dir=node_modules --exclude-dir=dist --exclude-dir=build \
      --exclude-dir=vendor --exclude-dir=.git -- "$SHORT_PRE" "$target" 2>/dev/null || true; } |
  while IFS= read -r f; do
    awk -v file="$f" '
      function keyhit(k,   i, c, prev, out, n, w) {
        out = ""; prev = ""
        for (i = 1; i <= length(k); i++) {
          c = substr(k, i, 1)
          if (c ~ /[A-Z]/ && prev ~ /[a-z0-9]/) out = out "_"
          out = out c; prev = c
        }
        out = tolower(out); gsub(/-/, "_", out)
        n = split(out, w, "_")
        for (i = 1; i <= n; i++) if (w[i] ~ /^(pin|passcode|password|passwd|secret|token)$/) return 1
        return 0
      }
      {
        s = $0
        while (match(s, /[A-Za-z0-9_-]+["\047]?[ \t]*(:=?|=|[=!]==?)[ \t]*["\047`][^"\047` \t$]*["\047`]/)) {
          m = substr(s, RSTART, RLENGTH); s = substr(s, RSTART + RLENGTH)
          key = m; sub(/["\047]?[ \t]*(:=?|=|[=!]==?)[ \t]*["\047`].*$/, "", key)
          val = m; sub(/^[^"\047`]*["\047]?[ \t]*(:=?|=|[=!]==?)[ \t]*["\047`]/, "", val); sub(/.$/, "", val)
          if (length(val) >= 4 && length(val) <= 7 && tolower(val) !~ /^(true|false|null)$/ && keyhit(key)) {
            print file ":" FNR " — short hardcoded secret"; break
          }
        }
      }' "$f"
  done
}

# Reusable: dynamic code execution (skill Step 6, Medium). Scans the source
# directories, scripts/ and root-level *.js/*.mjs/*.cjs/*.ts for eval( and
# new Function( in code files, skipping vendored and built directories and
# *.min.js bundles. Not findings: commented lines (starting with //, #, * or
# /*), member calls such as model.eval() or db.eval() (only window.eval and
# globalThis.eval count), and identifiers that merely contain eval
# (evaluate(, literal_eval(). Prints "file:line — dynamic code execution (eval)"
# or "(new Function)".
DYN_SKIP=(--exclude-dir=node_modules --exclude-dir=dist --exclude-dir=build --exclude-dir=vendor --exclude-dir=.git)
DYN_CODE=(--include='*.js' --include='*.mjs' --include='*.cjs' --include='*.jsx' --include='*.ts' --include='*.tsx' --include='*.mts' --include='*.cts' --include='*.vue' --include='*.svelte' --include='*.html' --include='*.htm' --include='*.py' --include='*.rb' --include='*.php')
dynamic_code_findings() {
  local root="$1" x f
  local targets=()
  for x in backend frontend server src app api scripts; do [ -d "$root/$x" ] && targets+=("$root/$x"); done
  for f in "$root"/*.js "$root"/*.mjs "$root"/*.cjs "$root"/*.ts; do [ -f "$f" ] && targets+=("$f"); done
  [ "${#targets[@]}" -gt 0 ] || return 0
  { grep -rlE "${DYN_SKIP[@]}" "${DYN_CODE[@]}" -- 'eval|Function' "${targets[@]}" 2>/dev/null || true; } |
  while IFS= read -r f; do
    case "$f" in *.min.js) continue ;; esac
    awk -v file="$f" '
      /^[ \t]*(\/\/|#|\*|\/\*)/ { next }
      /(^|[^A-Za-z0-9_$.])eval[ \t]*\(/ || /(^|[^A-Za-z0-9_$.])(window|globalThis)\.eval[ \t]*\(/ { print file ":" FNR " — dynamic code execution (eval)"; next }
      /(^|[^A-Za-z0-9_$.])new[ \t]+Function[ \t]*\(/ { print file ":" FNR " — dynamic code execution (new Function)" }' "$f"
  done
}

# Reusable: privileged containers (skill Step 3), ignoring commented lines.
check_privileged() {
  local file="$1"
  grep -vE '^[[:space:]]*#' "$file" 2>/dev/null |
    grep -qE "privileged:[[:space:]]*[\"']?true|--cap-add|cap_add:|SYS_ADMIN|SYS_PTRACE|network_mode:[[:space:]]*[\"']?host|/var/run/docker\\.sock"
}

# Reusable: nginx header findings (skill Step 4). Builds the block tree of an
# nginx config and applies nginx's add_header inheritance rule: a block that
# declares any add_header (or more_set_headers) of its own inherits NONE from
# its parent. Prints one line per problem:
#   MISSING <Header> (server line N)     required header absent in a server
#   VERIFY-TLS Strict-Transport-Security (server line N)   server has no TLS here (Info)
#   DROPPED <server|location|if> line N  a block's own add_header drops inherited required headers
#   DEPRECATED-ONLY (server line N)      X-XSS-Protection is the only protective header
# Files without a server block (snippets) produce no findings. include files are
# read relative to the config's directory. Known limit: a `{` or `}` inside a
# quoted value confuses the block count.
REQUIRED_HEADERS="Content-Security-Policy Strict-Transport-Security X-Content-Type-Options X-Frame-Options Referrer-Policy"
nginx_header_findings() {
  local conf="$1"
  awk -v req="$REQUIRED_HEADERS" -v dir="$(dirname "$conf")" '
    function strip(s) { sub(/(^|[ \t])#.*$/, "", s); return s }
    function hdr(b, name, val) {
      gsub(/["\047]/, "", name); name = tolower(name)
      own[b, name] = 1; hasown[b] = 1
      if (name == "content-security-policy" && tolower(val) ~ /frame-ancestors/) own[b, "x-frame-options"] = 1
    }
    function scan(s, b,   t, name, val, f, l2) {
      if (b == 0) return
      if (s ~ /(^|[ \t;{])add_header[ \t]/) {
        t = s; sub(/^.*add_header[ \t]+/, "", t)
        name = t; sub(/[ \t].*$/, "", name); val = t; sub(/^[^ \t]+/, "", val); hdr(b, name, val)
      }
      if (s ~ /(^|[ \t;{])more_set_headers[ \t]/) {
        t = s; sub(/^.*more_set_headers[ \t]+/, "", t); gsub(/^["\047]/, "", t)
        name = t; sub(/:.*$/, "", name); val = t; sub(/^[^:]*:/, "", val); hdr(b, name, val)
      }
      if (s ~ /(^|[ \t;{])include[ \t]/) {
        f = s; sub(/^.*include[ \t]+/, "", f); sub(/[ \t]*;.*$/, "", f); gsub(/["\047]/, "", f)
        if (f !~ /^\//) f = dir "/" f
        while ((getline l2 < f) > 0) scan(strip(l2), b)
        close(f)
      }
      if (s ~ /listen[ \t].*[ \t]ssl([ \t;]|$)/ || s ~ /(^|[ \t])ssl_certificate[ \t]/) tls[b] = 1
      if (s ~ /(^|[ \t;{])return[ \t]+30[1278]/) redirect[b] = 1
    }
    BEGIN { nreq = split(req, RO, " "); for (i = 1; i <= nreq; i++) R[i] = tolower(RO[i]) }
    {
      s = strip($0); o = index(s, "{")
      if (o > 0) {
        pre = substr(s, 1, o - 1); sub(/^[ \t]+/, "", pre); kind = pre; sub(/[ \t(].*$/, "", kind)
        nb++; type[nb] = kind; parent[nb] = cur; start[nb] = NR; stack[++top] = nb; cur = nb
        rest = substr(s, o + 1)
      } else rest = s
      scan(rest, cur)
      t = rest; nclose = gsub(/\}/, "", t)
      while (nclose-- > 0 && top > 0) { top--; cur = (top > 0 ? stack[top] : 0) }
    }
    END {
      for (b = 1; b <= nb; b++) {
        p = parent[b]
        for (i = 1; i <= nreq; i++) {
          h = R[i]
          if (hasown[b]) eff[b, h] = ((b, h) in own) ? 1 : 0
          else eff[b, h] = (p > 0) ? eff[p, h] : 0
        }
        if (hasown[b]) xss[b] = ((b, "x-xss-protection") in own) ? 1 : 0
        else xss[b] = (p > 0) ? xss[p] : 0
        if (!tls[b] && p > 0 && type[b] != "server") tls[b] = tls[p]
      }
      for (b = 1; b <= nb; b++) {
        if (type[b] == "server" && !redirect[b]) {
          nmiss = 0; want = 0
          for (i = 1; i <= nreq; i++) {
            h = R[i]
            if (h == "strict-transport-security" && !tls[b]) {
              if (!eff[b, h]) print "VERIFY-TLS " RO[i] " (server line " start[b] ")"
              continue
            }
            want++
            if (!eff[b, h]) { print "MISSING " RO[i] " (server line " start[b] ")"; nmiss++ }
          }
          if (nmiss == want && xss[b]) print "DEPRECATED-ONLY (server line " start[b] ")"
        }
        if (hasown[b] && parent[b] > 0 && (type[b] == "server" || type[b] == "location" || type[b] == "if")) {
          drop = 0
          for (i = 1; i <= nreq; i++) if (eff[parent[b], R[i]] && !eff[b, R[i]]) drop = 1
          if (drop) print "DROPPED " type[b] " line " start[b]
        }
      }
    }' "$conf"
}

# Test 1: Env-file scope — exact and pattern forms pass; near-misses fail
cleanup
mkdir -p "$FIXTURES_DIR"
PASS_FORMS=0; FAIL_FORMS=0
for good in '.env' '/.env' '*.env' '**/.env' '.env*'; do
  printf '%s\nnode_modules/\n' "$good" > "$FIXTURES_DIR/.gitignore"
  check_env_gitignored "$FIXTURES_DIR/.gitignore" && PASS_FORMS=$((PASS_FORMS + 1))
done
for badform in '.env.local' '.envrc' 'node_modules/'; do
  printf '%s\n' "$badform" > "$FIXTURES_DIR/.gitignore"
  check_env_gitignored "$FIXTURES_DIR/.gitignore" || FAIL_FORMS=$((FAIL_FORMS + 1))
done
rm -f "$FIXTURES_DIR/.gitignore"
MISSING_FILE=pass
check_env_gitignored "$FIXTURES_DIR/.gitignore" || MISSING_FILE=fail
if [ "$PASS_FORMS" -eq 5 ] && [ "$FAIL_FORMS" -eq 3 ] && [ "$MISSING_FILE" = "fail" ]; then
  assert_pass "env-file scope: 5 ignore forms pass; .env.local/.envrc/unrelated and a missing .gitignore fail"
else
  assert_fail "env scope: pass-forms=$PASS_FORMS/5, fail-forms=$FAIL_FORMS/3, missing .gitignore=$MISSING_FILE (want fail)"
fi

# Test 2: Credential scan — clean source has 0 findings; env-style, Django-style,
# YAML, template-literal and cloud keys are found; vendored code is skipped
cleanup
mkdir -p "$FIXTURES_DIR/backend/routes" "$FIXTURES_DIR/backend/node_modules/x" "$FIXTURES_DIR/config"
cat > "$FIXTURES_DIR/backend/routes/items.js" << 'EOF'
import express from 'express';
const router = express.Router();
export default router;
EOF
CLEAN_COUNT=$(credential_findings "$FIXTURES_DIR/backend" | wc -l | tr -d ' ')
cat > "$FIXTURES_DIR/backend/routes/bad.js" << 'EOF'
const API_KEY="sk_live_abc123def456";
const db_PASSWORD="supersecret";
const apiKey = `sk_live_tmpl7788`;
EOF
printf "SECRET_KEY = 'django-insecure-x9y8z7'\n" > "$FIXTURES_DIR/backend/settings.py"
printf 'api_key: abcdef1234567890\n' > "$FIXTURES_DIR/config/app.yaml"
printf 'const k = "AKIAABCDEFGHIJKLMNOP";\n' > "$FIXTURES_DIR/backend/aws.js"
printf 'const k = "AKIAABCDEFGHIJKLMNOP";\n' > "$FIXTURES_DIR/backend/node_modules/x/i.js"
DIRTY=$(credential_findings "$FIXTURES_DIR")
DIRTY_COUNT=$(printf '%s\n' "$DIRTY" | grep -c . || true)
if [ "$CLEAN_COUNT" -eq 0 ] && [ "$DIRTY_COUNT" -eq 6 ] && ! printf '%s' "$DIRTY" | grep -q node_modules; then
  assert_pass "credentials: clean=0; env, Django, template-literal, YAML and AWS forms found (6); node_modules skipped"
else
  assert_fail "credentials: clean=$CLEAN_COUNT (want 0), dirty=$DIRTY_COUNT (want 6): $DIRTY"
fi

# Test 3: Privileged containers — escalations found; a commented line is not
cleanup
mkdir -p "$FIXTURES_DIR"
printf 'services:\n  backend:\n    build: ./backend\n    # privileged: true\n' > "$FIXTURES_DIR/docker-compose.yml"
CLEAN_PRIV=false
check_privileged "$FIXTURES_DIR/docker-compose.yml" || CLEAN_PRIV=true
CAUGHT=0
for esc in '    privileged: "true"' '    cap_add: [NET_ADMIN]' '    network_mode: host' '      - /var/run/docker.sock:/var/run/docker.sock'; do
  printf 'services:\n  backend:\n    build: ./backend\n%s\n' "$esc" > "$FIXTURES_DIR/docker-compose.yml"
  check_privileged "$FIXTURES_DIR/docker-compose.yml" && CAUGHT=$((CAUGHT + 1))
done
if [ "$CLEAN_PRIV" = true ] && [ "$CAUGHT" -eq 4 ]; then
  assert_pass "container privilege: commented line clean; privileged, cap_add, host network and docker.sock all caught"
else
  assert_fail "privilege: clean=$CLEAN_PRIV (want true), caught=$CAUGHT/4"
fi

# Test 4: Redaction — findings cite file:line and never the value, including
# when the scan is pointed at a single file (grep then omits the filename)
cleanup
mkdir -p "$FIXTURES_DIR/backend/services"
SECRET_VALUE="sk_live_9f8e7d6c5b4a"
printf 'export const cfg = {\n  apiKey: "%s",\n};\n' "$SECRET_VALUE" > "$FIXTURES_DIR/backend/services/pay.js"
DIR_OUT=$(credential_findings "$FIXTURES_DIR/backend")
FILE_OUT=$(credential_findings "$FIXTURES_DIR/backend/services/pay.js")
if printf '%s' "$DIR_OUT" | grep -q 'pay.js:2 — hardcoded secret' && \
   printf '%s' "$FILE_OUT" | grep -q 'pay.js:2 — hardcoded secret' && \
   ! printf '%s%s' "$DIR_OUT" "$FILE_OUT" | grep -q "$SECRET_VALUE"; then
  assert_pass "redaction: pay.js:2 reported for directory and single-file scans, value never printed"
else
  assert_fail "redaction: dir='$DIR_OUT' file='$FILE_OUT' (want pay.js:2, value absent)"
fi

# Test 5: False positives stay out — env references, empty values, booleans,
# numbers and human-readable strings are not secrets
cleanup
mkdir -p "$FIXTURES_DIR/src"
cat > "$FIXTURES_DIR/src/ok.js" << 'EOF'
const password = process.env.DB_PASSWORD;
const API_KEY = "";
export TOKEN=${TOKEN}
RESET_PASSWORD=true
TOKEN_TTL=3600
const label = { password: "Password Here" };
EOF
FP=$(credential_findings "$FIXTURES_DIR/src")
if [ -z "$FP" ]; then
  assert_pass "false positives: env references, empty, boolean, numeric and human-readable values not flagged"
else
  assert_fail "false positives flagged: $FP"
fi

# Test 6: nginx — complete TLS config is clean; each broken variant is flagged
cleanup
mkdir -p "$FIXTURES_DIR/nginx"
HDRS='    add_header Content-Security-Policy "default-src '\''self'\''" always;
    add_header Strict-Transport-Security "max-age=31536000" always;
    add_header X-Content-Type-Options nosniff always;
    add_header X-Frame-Options DENY always;
    add_header Referrer-Policy strict-origin-when-cross-origin always;'
write_conf() {  # NAME BODY
  printf '%s\n' "$2" > "$FIXTURES_DIR/nginx/$1"
}
write_conf good.conf "server {
    listen 443 ssl;
$HDRS
    location ~* \\.(js|css)\$ {
        add_header Cache-Control \"public\";
$HDRS
    }
}"
write_conf drop.conf "server {
    listen 443 ssl;
$HDRS
    location ~* \\.(js|css)\$ {
        add_header Cache-Control \"public\";
    }
}"
write_conf nested.conf "server {
    listen 443 ssl;
$HDRS
    location / {
        add_header Cache-Control x;
        location /api {
            proxy_pass http://app;
        }
    }
}"
write_conf httpdrop.conf "http {
$HDRS
    server {
        listen 443 ssl;
        add_header Cache-Control x;
    }
}"
write_conf commented.conf "server {
    listen 443 ssl;
$(printf '%s\n' "$HDRS" | sed 's/add_header/# add_header/')
}"
write_conf reportonly.conf "server {
    listen 443 ssl;
$(printf '%s\n' "$HDRS" | sed 's/Content-Security-Policy /Content-Security-Policy-Report-Only /')
}"
write_conf framea.conf "server {
    listen 443 ssl;
$(printf '%s\n' "$HDRS" | grep -v X-Frame-Options | sed "s/default-src 'self'/default-src 'self'; frame-ancestors 'none'/")
}"
write_conf notls.conf "server {
    listen 80;
$(printf '%s\n' "$HDRS" | grep -v Strict-Transport)
}"
printf '%s\n' "$HDRS" > "$FIXTURES_DIR/nginx/security-headers.inc"
write_conf include.conf "server {
    listen 443 ssl;
    include security-headers.inc;
}"
write_conf xss.conf "server {
    listen 443 ssl;
    add_header X-XSS-Protection \"1; mode=block\";
}"
write_conf redirect.conf "server {
    listen 80;
    return 301 https://\$host\$request_uri;
}"
write_conf snippet.conf "gzip on;
add_header X-Test yes;"
R_GOOD=$(nginx_header_findings "$FIXTURES_DIR/nginx/good.conf")
R_DROP=$(nginx_header_findings "$FIXTURES_DIR/nginx/drop.conf")
R_NEST=$(nginx_header_findings "$FIXTURES_DIR/nginx/nested.conf")
R_HTTP=$(nginx_header_findings "$FIXTURES_DIR/nginx/httpdrop.conf" | grep '^DROPPED' || true)
R_COMM=$(nginx_header_findings "$FIXTURES_DIR/nginx/commented.conf" | grep -c '^MISSING' || true)
R_RO=$(nginx_header_findings "$FIXTURES_DIR/nginx/reportonly.conf")
R_FA=$(nginx_header_findings "$FIXTURES_DIR/nginx/framea.conf")
R_TLS=$(nginx_header_findings "$FIXTURES_DIR/nginx/notls.conf")
R_INC=$(nginx_header_findings "$FIXTURES_DIR/nginx/include.conf")
R_XSS=$(nginx_header_findings "$FIXTURES_DIR/nginx/xss.conf" | grep '^DEPRECATED' || true)
R_RED=$(nginx_header_findings "$FIXTURES_DIR/nginx/redirect.conf")
R_SNIP=$(nginx_header_findings "$FIXTURES_DIR/nginx/snippet.conf")
NGINX_OK=true
expect() {  # LABEL GOT WANT
  if [ "$2" != "$3" ]; then NGINX_OK=false; printf '  nginx %s: got [%s] want [%s]\n' "$1" "$2" "$3"; fi
}
expect good "$R_GOOD" ""
expect drop "$R_DROP" "DROPPED location line 8"
expect nested "$R_NEST" "DROPPED location line 8"
expect http-level "$R_HTTP" "DROPPED server line 7"
expect commented "$R_COMM" "5"
expect report-only "$R_RO" "MISSING Content-Security-Policy (server line 1)"
expect frame-ancestors "$R_FA" ""
expect no-tls "$R_TLS" "VERIFY-TLS Strict-Transport-Security (server line 1)"
expect include "$R_INC" ""
expect xss-only "$R_XSS" "DEPRECATED-ONLY (server line 1)"
expect redirect "$R_RED" ""
expect snippet "$R_SNIP" ""
if [ "$NGINX_OK" = true ]; then
  assert_pass "nginx: 12 configurations — clean, dropped (location, nested, http→server), commented, report-only, frame-ancestors, no-TLS, include, X-XSS-only, redirect, snippet"
else
  assert_fail "nginx header findings differ from expectations (see lines above)"
fi

# Test 7: Short hardcoded credentials — 4-7 character literals under whole-word
# key names are Medium findings (quoted digits included); near-miss names, bare
# numbers, empty, 3-character, boolean, $-reference and spaced values are not;
# 8+ characters stay with the High rule; values are never printed
cleanup
mkdir -p "$FIXTURES_DIR/src"
cat > "$FIXTURES_DIR/src/admin.js" << 'EOF'
const ORGANIZER_PIN = "4821";
const adminPin = '7731';
const config = { pin_code: "0042" };
if (pin === "1739") { unlock(); }
const passcode = `abc12`;
const password = "hunter2";
const db_password = "hunter22";
const spinner = "abcd";
const pinned = "wxyz";
const tokenizer = "wordpc";
const PIN_LENGTH = 4;
const pin = "";
const pin = "abc";
const userToken = "${TOKEN}";
const secret = "true";
const pin = "12 34";
{ "pin": "9988" }
EOF
SHORT_OUT=$(credential_findings "$FIXTURES_DIR/src" | sed "s|^$FIXTURES_DIR/src/||" | LC_ALL=C sort)
SHORT_WANT=$(printf '%s\n' "admin.js:1 — short hardcoded secret" "admin.js:2 — short hardcoded secret" \
  "admin.js:3 — short hardcoded secret" "admin.js:4 — short hardcoded secret" "admin.js:5 — short hardcoded secret" \
  "admin.js:6 — short hardcoded secret" "admin.js:7 — hardcoded secret" "admin.js:17 — short hardcoded secret" | LC_ALL=C sort)
LEAKED=""
for v in 4821 7731 0042 1739 abc12 hunter2 9988; do
  printf '%s' "$SHORT_OUT" | grep -q -- "$v" && LEAKED="$LEAKED $v"
done
if [ "$SHORT_OUT" = "$SHORT_WANT" ] && [ -z "$LEAKED" ]; then
  assert_pass "short credentials: 7 found (PINs as quoted digits, camelCase, snake_case, comparison, JSON key); spinner/pinned/tokenizer, number, empty, 3-char, boolean, \$-ref and spaced skipped; 8 chars stays High; no value printed"
else
  assert_fail "short credentials: leaked=[${LEAKED# }]
  got:  $(printf '%s' "$SHORT_OUT" | tr '\n' ';')
  want: $(printf '%s' "$SHORT_WANT" | tr '\n' ';')"
fi

# Test 8: Dynamic code execution — eval( and new Function( in source dirs,
# scripts/ and root-level scripts; commented lines, member calls, look-alike
# identifiers, vendored code, minified bundles, non-code files and directories
# outside the scan are not findings
cleanup
mkdir -p "$FIXTURES_DIR/scripts" "$FIXTURES_DIR/src/lib" "$FIXTURES_DIR/src/node_modules/x" "$FIXTURES_DIR/docs"
cat > "$FIXTURES_DIR/scripts/build.mjs" << 'EOF'
const render = new Function("return " + body);
  // eval(previous)
 * eval(doc)
const data = eval(text);
EOF
printf 'model.eval();\nevaluate(x);\nJSON.parse(s);\nwindow.eval(code);\n' > "$FIXTURES_DIR/src/page.js"
printf 'x = ast.literal_eval(s)\n# eval(y)\n' > "$FIXTURES_DIR/src/tool.py"
printf 'eval(x)\n' > "$FIXTURES_DIR/build.js"
printf 'eval(x)\n' > "$FIXTURES_DIR/notes.md"
printf 'eval(x)\n' > "$FIXTURES_DIR/src/notes.md"
printf 'eval(x)\n' > "$FIXTURES_DIR/src/node_modules/x/i.js"
printf 'eval(x)\n' > "$FIXTURES_DIR/src/lib/x.min.js"
printf 'eval(x)\n' > "$FIXTURES_DIR/docs/a.js"
DYN_OUT=$(dynamic_code_findings "$FIXTURES_DIR" | sed "s|^$FIXTURES_DIR/||" | LC_ALL=C sort)
DYN_WANT=$(printf '%s\n' "build.js:1 — dynamic code execution (eval)" \
  "scripts/build.mjs:1 — dynamic code execution (new Function)" "scripts/build.mjs:4 — dynamic code execution (eval)" \
  "src/page.js:4 — dynamic code execution (eval)" | LC_ALL=C sort)
mkdir -p "$FIXTURES_DIR/empty"
DYN_EMPTY=$(dynamic_code_findings "$FIXTURES_DIR/empty")
if [ "$DYN_OUT" = "$DYN_WANT" ] && [ -z "$DYN_EMPTY" ]; then
  assert_pass "dynamic code: new Function, eval, window.eval and a root script found (4); comments, model.eval, evaluate, literal_eval, node_modules, .min.js, .md and docs/ skipped"
else
  assert_fail "dynamic code: empty=[$DYN_EMPTY]
  got:  $(printf '%s' "$DYN_OUT" | tr '\n' ';')
  want: $(printf '%s' "$DYN_WANT" | tr '\n' ';')"
fi

# Summary
TOTAL=$((PASS_COUNT + FAIL_COUNT))
printf "\nascent-security-audit tests: %s/%s PASS\n" "$PASS_COUNT" "$TOTAL"
[ "$FAIL_COUNT" -eq 0 ] || exit 1
