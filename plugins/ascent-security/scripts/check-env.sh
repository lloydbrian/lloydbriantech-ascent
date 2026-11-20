#!/usr/bin/env bash
# Checks that a repository's .env files stay out of git and out of container
# images. Part of the ascent-security plugin (env-audit, and the local floor of
# ascent-governance's launch-readiness); made to run in a project's own CI at no
# token cost. Read-only: it reads file names, .dockerignore, and git ls-files
# and git check-ignore. It never opens a .env file, so it cannot print a value.
#
# Usage: check-env.sh [--no-git] [REPO]
#
# REPO is the repository root (default "."). A .env file is any file named
# .env or .env.<name>, in any folder; an example file (.env.example,
# .env.sample, .env.template, .env.dist, or .env.<name>.example and the like)
# is not one. Dependency and build folders are not searched. --no-git skips the
# two checks that need git.
#
# Checks:
#   SEC-E1  High    no .env file is tracked by git (committed or staged)
#   SEC-E2  High    every .env file that exists is ignored by git
#   SEC-E3  Medium  every .dockerignore excludes .env, and a repository with a
#                   Dockerfile has a .dockerignore
#
# Output: FAIL lines (FAIL  SEC-Ek  SEVERITY  file  message), a PASS line per
# check with no finding, N/A lines, then "check-env: ...". Limits: it checks
# where .env files are, not what is in them, and not whether a secret was
# committed in the past (env-audit Step 7 reads the history).
# Exit: 0 no FAIL; 1 at least one FAIL; 2 bad input.
# Portable: GNU/Linux and BSD/macOS, bash 3.2+, run with LC_ALL=C.

set -euo pipefail
export LC_ALL=C

usage() { sed -n '8p' "$0" | sed 's/^# //'; }
NOGIT=0; POS=()
while [ $# -gt 0 ]; do
  case "$1" in
    --no-git) NOGIT=1; shift ;;
    -h|--help) usage; sed -n '10,27p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    --) shift; while [ $# -gt 0 ]; do POS+=("$1"); shift; done ;;
    -*) usage >&2; echo "check-env: unknown option $1" >&2; exit 2 ;;
    *) POS+=("$1"); shift ;;
  esac
done
[ "${#POS[@]}" -le 1 ] || { usage >&2; exit 2; }
REPO="${POS[0]:-.}"
[ -d "$REPO" ] || { echo "check-env: $REPO is not a directory" >&2; exit 2; }
cd "$REPO"

T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT INT TERM
NFAIL=0
fail() { NFAIL=$((NFAIL + 1)); printf 'FAIL  %s  %-6s %s  %s\n' "$1" "$2" "$3" "$4"; }

# a .env file by its name: .env or .env.<name>, and not an example
is_env() {
  local b="${1##*/}"
  case "$b" in .env|.env.*) ;; *) return 1 ;; esac
  case "$b" in *.example|*.sample|*.template|*.dist|*.defaults|.env.example.*|.env.sample.*|.env.template.*) return 1 ;; esac
  return 0
}

GIT=0
if [ "$NOGIT" -eq 1 ]; then WHY="--no-git"
elif ! command -v git >/dev/null 2>&1; then WHY="git is not installed"
elif ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then WHY="not a git repository"
else GIT=1; fi

# --- SEC-E1: tracked ----------------------------------------------------------
if [ "$GIT" -eq 1 ]; then
  n=0
  while IFS= read -r -d '' f; do
    is_env "$f" || continue
    n=$((n + 1)); fail SEC-E1 High "$f" "this .env file is tracked by git: every clone and every fork has its values; remove it from the index (git rm --cached), ignore it, and rotate what it held"
  done < <(git ls-files -z -- . 2>/dev/null)     # -z: a path with a space, a quote or a letter outside ASCII is read as it is
  [ "$n" -eq 0 ] && echo "PASS  SEC-E1  no .env file is tracked by git"
else
  echo "N/A   SEC-E1  $WHY: whether a .env file is tracked was not checked"
fi

# --- SEC-E2: ignored ----------------------------------------------------------
find . \( -name .git -o -name node_modules -o -name vendor -o -name .venv -o -name venv -o -name dist -o -name build -o -name target \) -prune \
  -o -type f \( -name .env -o -name '.env.*' \) -print 2>/dev/null | sed 's|^\./||' | sort > "$T/envs"
if [ "$GIT" -eq 1 ]; then
  n=0; seen=0
  while IFS= read -r f; do
    is_env "$f" || continue
    seen=$((seen + 1))
    [ -n "$(git ls-files -- "$f" 2>/dev/null)" ] && continue          # tracked: SEC-E1 has it
    git check-ignore -q -- "$f" 2>/dev/null && continue
    n=$((n + 1)); fail SEC-E2 High "$f" "this .env file is not ignored by git: the next 'git add' commits it; add it to .gitignore"
  done < "$T/envs"
  if [ "$n" -eq 0 ]; then
    if [ "$seen" -eq 0 ]; then echo "PASS  SEC-E2  no .env file here to ignore"; else echo "PASS  SEC-E2  every .env file is ignored by git ($seen)"; fi
  fi
else
  echo "N/A   SEC-E2  $WHY: whether .env files are ignored was not checked"
fi

# --- SEC-E3: container images -------------------------------------------------
# whether a .dockerignore excludes .env: the last pattern that matches wins
excludes_env() {
  local line pat neg out=1
  while IFS= read -r line || [ -n "$line" ]; do
    line="${line#"${line%%[![:space:]]*}"}"; line="${line%"${line##*[![:space:]]}"}"   # also drops a CR
    neg=0; case "$line" in '!'*) neg=1; line="${line#!}" ;; esac
    pat="${line#/}"; pat="${pat#\*\*/}"; pat="${pat%/}"
    # shellcheck disable=SC2254
    case ".env" in $pat) if [ "$neg" -eq 1 ]; then out=1; else out=0; fi ;; esac
  done < "$1"
  return $out
}
find . \( -name .git -o -name node_modules -o -name vendor -o -name .venv -o -name venv -o -name dist -o -name build -o -name target \) -prune \
  -o -type f \( -name .dockerignore -o -name '*.dockerignore' -o -name Dockerfile -o -name 'Dockerfile.*' -o -name '*.Dockerfile' -o -name Containerfile \) -print 2>/dev/null | sed 's|^\./||' | sort > "$T/docker"
n=0; di=0
while IFS= read -r f; do
  case "${f##*/}" in *.dockerignore) ;; *) continue ;; esac                          # also Dockerfile.dockerignore, the ignore file of one Dockerfile
  di=$((di + 1))
  excludes_env "$f" && continue
  n=$((n + 1))
  # Docker reads one pattern per line: ".env *.log" is one pattern, and matches nothing
  ln=$(awk '!/^[ \t]*#/ && NF > 1 { for (i = 1; i <= NF; i++) if ($i == ".env" || $i == ".env*" || $i == ".env.*" || $i == "**/.env") { print NR; exit } }' "$f")
  if [ -n "$ln" ]; then fail SEC-E3 Medium "$f:$ln" "this .dockerignore does not exclude .env: line $ln has several patterns, and Docker reads one pattern per line, so the line excludes nothing; put .env and .env.* on lines of their own"; continue; fi
  fail SEC-E3 Medium "$f" "this .dockerignore does not exclude .env: a COPY of the folder puts the file in the image, where anyone with the image reads it; add .env and .env.*"
done < "$T/docker"
if [ "$di" -eq 0 ]; then
  first=$(head -1 "$T/docker")
  if [ -n "$first" ]; then n=$((n + 1)); fail SEC-E3 Medium "$first" "the repository builds an image and has no .dockerignore: a COPY of the folder puts .env in the image; add a .dockerignore with .env and .env.*"
  else echo "N/A   SEC-E3  no .dockerignore and no Dockerfile: nothing here builds an image"; fi
elif [ "$n" -eq 0 ]; then echo "PASS  SEC-E3  every .dockerignore excludes .env ($di)"; fi

echo "check-env: $NFAIL failure(s); it checks where .env files are, not what is in them"
[ "$NFAIL" -eq 0 ]
