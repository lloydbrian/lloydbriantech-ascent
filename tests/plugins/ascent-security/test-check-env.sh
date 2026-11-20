#!/usr/bin/env bash
# Behavior test for plugins/ascent-security/scripts/check-env.sh.
#
# A good repository (a .env that git ignores, a tracked .env.example, a
# .dockerignore that excludes .env) passes SEC-E1–E3. Each check then gets
# negative controls: a repository broken in exactly one way fails that check
# and no other. Also covers .env files in subfolders, example files, a
# repository with no .env at all, --no-git, a folder that is not a repository,
# bad input, and that a value from a .env file is never printed.
#
# Every case runs in a throwaway git repository inside the test's temporary
# folder, with git's global and system configuration switched off; the
# project's repository is never touched.
# Prints "test-check-env: N/N PASS" last (make/test-plugins.sh T11 requires it).
# Portable: bash 3.2+, GNU/Linux and BSD/macOS.

set -u
WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT INT TERM

HERE="$(cd "$(dirname "$0")" && pwd)"
CHECK="$HERE/../../../plugins/ascent-security/scripts/check-env.sh"
[ -f "$CHECK" ] || { echo "test-check-env: missing $CHECK"; echo "test-check-env: 0/1 PASS"; exit 1; }
command -v git >/dev/null 2>&1 || { echo "test-check-env: git not found"; echo "test-check-env: 0/1 PASS"; exit 1; }
mkdir -p "$WORK/home"
SECRET='hunter2-s3cr3t-value'

PASS=0; FAIL=0
ok()  { PASS=$((PASS + 1)); }
bad() { FAIL=$((FAIL + 1)); printf "FAIL  %s\n" "$1"; }
G() { (cd "$WORK/$1" && shift && HOME="$WORK/home" GIT_CONFIG_NOSYSTEM=1 git -c user.name=test -c user.email=test@example.invalid -c commit.gpgsign=false -c core.hooksPath=/dev/null -c init.defaultBranch=main "$@") >/dev/null 2>&1; }
chk() {  # NAME [ARGS]
  local n="$1"; shift
  (cd "$WORK/$n" && HOME="$WORK/home" GIT_CONFIG_NOSYSTEM=1 bash "$CHECK" "$@") >"$WORK/out" 2>"$WORK/err"; RC=$?
  OUT=$(cat "$WORK/out" "$WORK/err")
}
# mk NAME — a good repository: .env ignored, .env.example tracked, .dockerignore excludes .env
mk() {
  rm -rf "${WORK:?}/$1"; mkdir -p "$WORK/$1/api"
  printf 'node_modules/\n.env\n.env.*\n!.env.example\n' > "$WORK/$1/.gitignore"
  printf '.git\n.env\n.env.*\n' > "$WORK/$1/.dockerignore"
  printf 'APP_SECRET=\n' > "$WORK/$1/.env.example"
  printf 'APP_SECRET=%s\n' "$SECRET" > "$WORK/$1/.env"
  printf 'FROM scratch\n' > "$WORK/$1/Dockerfile"
  G "$1" init -q; G "$1" add -A; G "$1" commit -q -m init
}
expect_only() {  # NAME CHECK SEVERITY
  nfail=$(printf '%s\n' "$OUT" | grep -c '^FAIL ' || true)
  nmine=$(printf '%s\n' "$OUT" | grep -c "^FAIL  $2 " || true)
  if [ "$RC" -ne 1 ]; then bad "$1: expected exit 1, got $RC: $(printf '%s\n' "$OUT" | head -3 | tr '\n' ';')"
  elif [ "$nmine" -eq 0 ]; then bad "$1: $2 did not fail: $(printf '%s\n' "$OUT" | grep '^FAIL' | head -2 | tr '\n' ';')"
  elif [ "$nfail" -ne "$nmine" ]; then bad "$1: expected only $2 to fail, got: $(printf '%s\n' "$OUT" | grep '^FAIL' | cut -c1-100 | tr '\n' ';')"
  elif ! printf '%s\n' "$OUT" | grep -q "^FAIL  $2 *$3 "; then bad "$1: $2 should be $3: $(printf '%s\n' "$OUT" | grep "^FAIL  $2" | head -1)"
  else ok; fi
}
expect_pass() { if [ "$RC" -eq 0 ] && ! printf '%s\n' "$OUT" | grep -q '^FAIL '; then ok; else bad "$1 should pass: exit $RC $(printf '%s\n' "$OUT" | grep '^FAIL' | head -2 | tr '\n' ';')"; fi; }
expect_rc() { if [ "$RC" -eq "$2" ]; then ok; else bad "$1: expected exit $2, got $RC: $(printf '%s\n' "$OUT" | head -2 | tr '\n' ';')"; fi; }
has() { if printf '%s\n' "$OUT" | grep -qF -- "$2"; then ok; else bad "$1: output lacks: $2"; fi; }
lacks() { if printf '%s\n' "$OUT" | grep -qF -- "$2"; then bad "$1: output must not contain: $2"; else ok; fi; }

mk good; chk good; expect_pass good
has good 'PASS  SEC-E1'; has good 'PASS  SEC-E2'; has good 'PASS  SEC-E3'; has good 'check-env: 0 failure(s)'
lacks good "$SECRET"
mkdir -p "$WORK/outer"; cp -R "$WORK/good" "$WORK/outer/app"; (cd "$WORK/outer" && HOME="$WORK/home" GIT_CONFIG_NOSYSTEM=1 bash "$CHECK" app) >"$WORK/out" 2>&1; RC=$?; OUT=$(cat "$WORK/out"); expect_pass good-by-path

# SEC-E1: a .env file is tracked by git
mk e1-tracked; G e1-tracked add -f .env; G e1-tracked commit -q -m oops; chk e1-tracked; expect_only e1-tracked SEC-E1 High
has e1-tracked '.env'; lacks e1-tracked "$SECRET"
mk e1-tracked-subdir; printf 'DB_PASSWORD=%s\n' "$SECRET" > "$WORK/e1-tracked-subdir/api/.env.production"
G e1-tracked-subdir add -f api/.env.production; G e1-tracked-subdir commit -q -m oops; chk e1-tracked-subdir; expect_only e1-tracked-subdir SEC-E1 High
has e1-tracked-subdir 'api/.env.production'; lacks e1-tracked-subdir "$SECRET"
mk e1-staged; G e1-staged add -f .env; chk e1-staged; expect_only e1-staged SEC-E1 High
mk e1-example-ok; for f in .env.sample .env.template api/.env.example .env.production.example; do printf 'A=\n' > "$WORK/e1-example-ok/$f"; done
G e1-example-ok add -f .env.sample .env.template api/.env.example .env.production.example; G e1-example-ok commit -q -m examples; chk e1-example-ok; expect_pass e1-example-ok
mk e1-envrc-ok; printf 'use nix\n' > "$WORK/e1-envrc-ok/.envrc"; printf 'x\n' > "$WORK/e1-envrc-ok/app.env.md"; G e1-envrc-ok add -A; G e1-envrc-ok commit -q -m other; chk e1-envrc-ok; expect_pass e1-envrc-ok
# a path git would print in quotes is still read as the path it is
U="$(printf 'caf\303\251 notes')"
mk e1-quoted-path; mkdir -p "$WORK/e1-quoted-path/$U"; printf 'A=%s\n' "$SECRET" > "$WORK/e1-quoted-path/$U/.env"; G e1-quoted-path add -f "$U/.env"; G e1-quoted-path commit -q -m oops
chk e1-quoted-path; expect_only e1-quoted-path SEC-E1 High; has e1-quoted-path "$U/.env"; lacks e1-quoted-path '\303'
mk e1-quoted-example; mkdir -p "$WORK/e1-quoted-example/$U"; printf 'A=\n' > "$WORK/e1-quoted-example/$U/.env.example"; G e1-quoted-example add -f "$U/.env.example"; G e1-quoted-example commit -q -m example
chk e1-quoted-example; expect_pass e1-quoted-example
mk e1-two; printf 'A=1\n' > "$WORK/e1-two/.env.local"; G e1-two add -f .env .env.local; chk e1-two
if [ "$(printf '%s\n' "$OUT" | grep -c '^FAIL  SEC-E1 ')" -eq 2 ]; then ok; else bad "e1-two: expected two SEC-E1 findings: $(printf '%s\n' "$OUT" | grep '^FAIL' | tr '\n' ';')"; fi

# SEC-E2: a .env file that exists is not ignored
mk e2-not-ignored; printf 'node_modules/\n' > "$WORK/e2-not-ignored/.gitignore"; G e2-not-ignored add .gitignore; G e2-not-ignored commit -q -m gi
chk e2-not-ignored; expect_only e2-not-ignored SEC-E2 High; has e2-not-ignored '.env'; lacks e2-not-ignored "$SECRET"
mk e2-subdir; printf 'node_modules/\n/.env\n' > "$WORK/e2-subdir/.gitignore"; printf 'K=%s\n' "$SECRET" > "$WORK/e2-subdir/api/.env"
chk e2-subdir; expect_only e2-subdir SEC-E2 High; has e2-subdir 'api/.env'
mk e2-absent; rm -f "$WORK/e2-absent/.env"; printf 'node_modules/\n' > "$WORK/e2-absent/.gitignore"; chk e2-absent; expect_pass e2-absent
has e2-absent 'no .env file'
mk e2-in-node-modules; printf '/.env\n' > "$WORK/e2-in-node-modules/.gitignore"; mkdir -p "$WORK/e2-in-node-modules/node_modules/pkg"; printf 'A=1\n' > "$WORK/e2-in-node-modules/node_modules/pkg/.env"; chk e2-in-node-modules; expect_pass e2-in-node-modules
mk e2-example-untracked; printf 'node_modules/\n.env\n' > "$WORK/e2-example-untracked/.gitignore"; printf 'A=\n' > "$WORK/e2-example-untracked/.env.sample"; chk e2-example-untracked; expect_pass e2-example-untracked

# SEC-E3: a .dockerignore that does not exclude .env
mk e3-dockerignore; printf '.git\nnode_modules\n' > "$WORK/e3-dockerignore/.dockerignore"; chk e3-dockerignore; expect_only e3-dockerignore SEC-E3 Medium
has e3-dockerignore '.dockerignore'
mk e3-reincluded; printf '.env\n!.env\n' > "$WORK/e3-reincluded/.dockerignore"; chk e3-reincluded; expect_only e3-reincluded SEC-E3 Medium
# several patterns on one line are one pattern to Docker: the line excludes nothing, and the finding says so
mk e3-one-line; printf '.git node_modules\n.env *.log\n' > "$WORK/e3-one-line/.dockerignore"; chk e3-one-line; expect_only e3-one-line SEC-E3 Medium
has e3-one-line '.dockerignore:2 '; has e3-one-line 'line 2 has several patterns'; has e3-one-line 'one pattern per line'
mk e3-one-line-ok; printf '.env *.log\n.env\n' > "$WORK/e3-one-line-ok/.dockerignore"; chk e3-one-line-ok; expect_pass e3-one-line-ok
mk e3-space-name; printf 'my notes\n' > "$WORK/e3-space-name/.dockerignore"; chk e3-space-name; expect_only e3-space-name SEC-E3 Medium; lacks e3-space-name 'several patterns'
mk e3-comment-only; printf '# .env\n' > "$WORK/e3-comment-only/.dockerignore"; chk e3-comment-only; expect_only e3-comment-only SEC-E3 Medium
mk e3-subdir; printf 'dist\n' > "$WORK/e3-subdir/api/.dockerignore"; chk e3-subdir; expect_only e3-subdir SEC-E3 Medium; has e3-subdir 'api/.dockerignore'
for pat in '.env' '.env*' '**/.env' '**/.env*' '*' '.*' '/.env' '*.env' '.env   '; do
  mk e3-pattern; printf '.git\n%s\n' "$pat" > "$WORK/e3-pattern/.dockerignore"; chk e3-pattern; expect_pass "e3-pattern '$pat'"
done
mk e3-allowlist; printf '*\n!src\n!package.json\n' > "$WORK/e3-allowlist/.dockerignore"; chk e3-allowlist; expect_pass e3-allowlist
mk e3-crlf; printf '.git\r\n.env\r\n' > "$WORK/e3-crlf/.dockerignore"; chk e3-crlf; expect_pass e3-crlf
mk e3-no-dockerignore; rm -f "$WORK/e3-no-dockerignore/.dockerignore" "$WORK/e3-no-dockerignore/Dockerfile"; chk e3-no-dockerignore; expect_pass e3-no-dockerignore
has e3-no-dockerignore 'N/A   SEC-E3'
mk e3-dockerfile-only; rm -f "$WORK/e3-dockerfile-only/.dockerignore"; chk e3-dockerfile-only; expect_only e3-dockerfile-only SEC-E3 Medium
has e3-dockerfile-only 'no .dockerignore'

# an ignore file named for its Dockerfile (Dockerfile.dockerignore) is an ignore file
mk e3-named-ignore; rm -f "$WORK/e3-named-ignore/.dockerignore"; printf '.env\n.env.*\n' > "$WORK/e3-named-ignore/Dockerfile.dockerignore"; chk e3-named-ignore; expect_pass e3-named-ignore
has e3-named-ignore 'PASS  SEC-E3'
mk e3-named-ignore-open; printf 'dist\n' > "$WORK/e3-named-ignore-open/api/api.Dockerfile.dockerignore"; chk e3-named-ignore-open; expect_only e3-named-ignore-open SEC-E3 Medium
has e3-named-ignore-open 'api/api.Dockerfile.dockerignore'

# without git
mk no-git; G no-git add -f .env; chk no-git --no-git; expect_pass no-git; has no-git 'N/A   SEC-E1'; has no-git 'N/A   SEC-E2'; has no-git 'PASS  SEC-E3'
rm -rf "${WORK:?}/not-a-repo"; mkdir -p "$WORK/not-a-repo"; printf 'A=%s\n' "$SECRET" > "$WORK/not-a-repo/.env"
(cd "$WORK/not-a-repo" && HOME="$WORK/home" GIT_CONFIG_NOSYSTEM=1 GIT_CEILING_DIRECTORIES="$WORK" bash "$CHECK") >"$WORK/out" 2>&1; RC=$?; OUT=$(cat "$WORK/out")
expect_pass not-a-repo; has not-a-repo 'N/A   SEC-E1'; has not-a-repo 'not a git repository'; lacks not-a-repo "$SECRET"

# usage
chk good --help; expect_rc help 0; has help '--no-git'
chk good --frobnicate; expect_rc bad-option 2
chk good one two; expect_rc two-repos 2
chk good "$WORK/nowhere"; expect_rc missing-repo 2

printf "test-check-env: %s/%s PASS\n" "$PASS" "$((PASS + FAIL))"
[ "$FAIL" -eq 0 ]
