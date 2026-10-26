#!/usr/bin/env bash
# Deploy the app stack. Zero-touch: every value comes from flags or a prompt.
# Usage: deploy.sh --env dev|prod [--dry-run] [--teardown --yes]
set -euo pipefail

usage() { sed -n '3p' "$0" | sed 's/^# //'; }
ENV=""; DRY_RUN=0; TEARDOWN=0; YES=0
while [ $# -gt 0 ]; do
  case "$1" in
    --env) ENV="$2"; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    --teardown) TEARDOWN=1; shift ;;
    --yes) YES=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) usage >&2; exit 2 ;;
  esac
done
[ -n "$ENV" ] || { usage >&2; exit 2; }

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

run() { if [ "$DRY_RUN" = 1 ]; then echo "dry-run: $*"; else "$@"; fi; }

preflight() {
  aws sts get-caller-identity >/dev/null
  git diff --quiet
}

postflight() {
  curl -sf "https://app.example/-/ready" >/dev/null
}

read -rs -p "Registry token: " REGISTRY_TOKEN; echo
printf '%s' "$REGISTRY_TOKEN" | podman login --username ci --password-stdin registry.example

preflight
if [ "$TEARDOWN" = 1 ]; then
  [ "$YES" = 1 ] || { echo "teardown needs --yes" >&2; exit 2; }
  run aws cloudformation delete-stack --stack-name "app-$ENV"
  exit 0
fi
cat > "$WORK/params.json" <<JSON
[{"ParameterKey": "Environment", "ParameterValue": "$ENV"}]
JSON
run aws cloudformation deploy --stack-name "app-$ENV" --template-file infra/template.yaml
rm -rf "${WORK:?}/params.json"
postflight
