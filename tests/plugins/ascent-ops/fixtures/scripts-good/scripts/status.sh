#!/bin/sh
# Show the stack status. Read-only.
# Usage: status.sh ENV
set -eu
case "${1:-}" in
  -h|--help|"") sed -n '3p' "$0" | sed 's/^# //'; exit 0 ;;
esac
aws cloudformation describe-stacks --stack-name "app-$1" --query 'Stacks[0].StackStatus'
