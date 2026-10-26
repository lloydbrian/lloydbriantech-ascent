# Sourced helpers; no shebang, no strict mode of its own.
log() { printf '%s %s\n' "$(date -u +%FT%TZ)" "$*" >&2; }
