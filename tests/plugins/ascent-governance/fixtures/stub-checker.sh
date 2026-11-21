#!/usr/bin/env bash
# A stand-in for another plugin's checker, used by the ascent-governance tests.
# Logs its own name and arguments to $STUB_LOG, one line per run, with the
# arguments separated by " | ". Exits with the number in
# $STUB_CTL/<plugin>__<script>.rc (default 0); on 1 it prints a FAIL line, as a
# real checker does (or the lines in $STUB_CTL/<plugin>__<script>.out), on 2 a
# usage line, and on 0 a PASS line (or the .out lines). A file
# $STUB_CTL/<plugin>__<script>.rc.<name> gives the exit code of the run whose
# last argument is a file of that name, and $STUB_CTL/<plugin>__<script>.out.<name>
# the lines it prints.
me="$(basename "$(dirname "$(dirname "$0")")")__$(basename "$0" .sh)"
{ printf '%s' "$me"; for a in "$@"; do printf ' | %s' "$a"; done; printf '\n'; } >> "${STUB_LOG:-/dev/null}"
rc=0; [ -f "${STUB_CTL:-/nonexistent}/$me.rc" ] && rc=$(cat "$STUB_CTL/$me.rc")
last=""; for a in "$@"; do last="$a"; done                      # one record can have its own exit code
[ -n "$last" ] && [ -f "${STUB_CTL:-/nonexistent}/$me.rc.${last##*/}" ] && rc=$(cat "$STUB_CTL/$me.rc.${last##*/}")
out="${STUB_CTL:-/nonexistent}/$me.out"                          # and its own lines
[ -n "$last" ] && [ -f "${STUB_CTL:-/nonexistent}/$me.out.${last##*/}" ] && out="$STUB_CTL/$me.out.${last##*/}"
case "$rc" in
  1) if [ -f "$out" ]; then cat "$out"; else echo "FAIL  XX-S1  High   src/app.js:3  the stub $me found a fault"; fi; echo "$me: 1 failure(s)" ;;
  2) echo "Usage: $(basename "$0") [--flag] PATH" >&2 ;;
  0) if [ -f "$out" ]; then cat "$out"; else echo "PASS  XX-S1  the stub passes"; fi; echo "$me: 0 failure(s)" ;;
  *) echo "the stub $me did not finish" >&2 ;;
esac
exit "$rc"
