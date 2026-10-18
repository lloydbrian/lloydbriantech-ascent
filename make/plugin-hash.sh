#!/usr/bin/env bash
# Content hash of one plugin directory (ADR-009, test-plugins T10).
#
# Prints one sha256 covering every file under DIR: each file's relative path
# and content hash, in byte-sorted path order, hashed again. Any added, removed,
# renamed or edited file changes the result. .DS_Store files are ignored.
#
# Usage: plugin-hash.sh DIR
# Portable: GNU/Linux and BSD/macOS, bash 3.2+ (shasum -a 256, else sha256sum).

set -euo pipefail

[ -d "${1:-}" ] || { echo "plugin-hash: no such directory: ${1:-}" >&2; exit 2; }

if command -v shasum >/dev/null 2>&1; then
  sha() { shasum -a 256 | awk '{print $1}'; }
elif command -v sha256sum >/dev/null 2>&1; then
  sha() { sha256sum | awk '{print $1}'; }
else
  echo "plugin-hash: neither shasum nor sha256sum found" >&2; exit 2
fi

cd "$1"
find . -type f ! -name .DS_Store | LC_ALL=C sort | while IFS= read -r f; do
  printf '%s\t%s\n' "$f" "$(sha < "$f")"
done | sha
