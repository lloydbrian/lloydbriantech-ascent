#!/usr/bin/env bash
# Zero-touch operations script for example-service (blueprint operable-service).
#
# Usage: ops-script-template.sh --env dev|prod [--dry-run] [--rollback] [--check-drift] [--teardown --yes]
#
# Deploys the configuration stack and restarts the containers, with pre-flight
# checks before any change and post-flight checks after it. Every value comes from
# a flag, the stack or a prompt; nothing is typed into a console. --dry-run prints
# each changing command instead of running it. --check-drift only reads.
# --teardown deletes the stack and needs --yes. Secrets are read with read -rs and
# passed on stdin, never as arguments.
set -euo pipefail

usage() { sed -n '4p' "$0" | sed 's/^# //'; }
ENV=""; DRY_RUN=0; ROLLBACK=0; DRIFT=0; TEARDOWN=0; YES=0
while [ $# -gt 0 ]; do
  case "$1" in
    --env) [ $# -ge 2 ] || { usage >&2; exit 2; }; ENV="$2"; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    --rollback) ROLLBACK=1; shift ;;
    --check-drift) DRIFT=1; shift ;;
    --teardown) TEARDOWN=1; shift ;;
    --yes) YES=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) usage >&2; exit 2 ;;
  esac
done
case "$ENV" in dev|prod) ;; *) usage >&2; exit 2 ;; esac
STACK="example-service-$ENV"

run() { if [ "$DRY_RUN" = 1 ]; then printf 'dry-run:'; printf ' %q' "$@"; printf '\n'; else "$@"; fi; }
step() { printf '\n== %s\n' "$*"; }

preflight() {
  step "Pre-flight"
  aws sts get-caller-identity --query Arn --output text >/dev/null || { echo "Stop: no AWS identity" >&2; exit 1; }
  git diff --quiet && git diff --cached --quiet || { echo "Stop: the working tree is not clean" >&2; exit 1; }
  aws cloudformation describe-stacks --stack-name "$STACK" --query 'Stacks[0].StackStatus' --output text 2>/dev/null || echo "stack $STACK not created yet"
}

postflight() {
  step "Post-flight"
  for _ in 1 2 3 4 5 6 7 8 9 10; do
    if curl -sf -o /dev/null "https://$ENV.example-service.example/-/ready"; then echo "ready"; return 0; fi
    sleep 6
  done
  echo "Stop: /-/ready did not pass within 60 seconds; run --rollback" >&2; exit 1
}

check_drift() {
  step "Drift check"
  id=$(aws cloudformation detect-stack-drift --stack-name "$STACK" --query StackDriftDetectionId --output text)
  aws cloudformation wait stack-drift-detection-complete --stack-drift-detection-id "$id" 2>/dev/null || sleep 20
  aws cloudformation describe-stack-drift-detection-status --stack-drift-detection-id "$id" --query StackDriftStatus --output text
}

if [ "$DRIFT" = 1 ]; then check_drift; exit 0; fi

preflight

if [ "$TEARDOWN" = 1 ]; then
  [ "$YES" = 1 ] || { echo "Stop: --teardown deletes $STACK; add --yes to confirm" >&2; exit 2; }
  run aws cloudformation delete-stack --stack-name "$STACK"
  exit 0
fi

RELEASE=$(git describe --tags --exact-match 2>/dev/null || true)
[ -n "$RELEASE" ] || { echo "Stop: check out a release tag first" >&2; exit 1; }
if [ "$ROLLBACK" = 1 ]; then
  RELEASE=$(git describe --tags --abbrev=0 "$RELEASE^" 2>/dev/null) || { echo "Stop: no previous release" >&2; exit 1; }
  step "Rolling back to $RELEASE"
fi

step "Deploy $RELEASE to $ENV"
read -rs -p "Registry token for $ENV: " REGISTRY_TOKEN; echo
printf '%s' "$REGISTRY_TOKEN" | run podman login --username deploy --password-stdin registry.example
unset REGISTRY_TOKEN
run aws cloudformation deploy --stack-name "$STACK" --template-file secure-parameters.yaml \
  --parameter-overrides "Environment=$ENV" --tags "Release=$RELEASE" --no-fail-on-empty-changeset
run podman compose -f compose.yml up -d

[ "$DRY_RUN" = 1 ] && { echo "dry-run: post-flight skipped"; exit 0; }
postflight
check_drift
