#!/usr/bin/env bash
# One-shot scaffold of the hello-world-app smoke-test project.
#
# Copies template assets → tools/scratch/hello-world-app/
# Substitutes all <<PLACEHOLDER>> values via sed.
# Runs npm install in backend/ and frontend/ to generate lock files.
#
# NOT production scaffolding — Phase 4's scaffold.py handles that.
# This script exists solely to validate that Chunks 1-7 template
# assets produce a working project when composed.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TEMPLATE_DIR="$REPO_ROOT/skills/lloydbriantech-ascent/assets/template"
TARGET_DIR="$SCRIPT_DIR/hello-world-app"

# ── Placeholder values ────────────────────────────────────────────
PROJECT_SLUG="hello-world-app"
PROJECT_SLUG_UPPER="HELLO_WORLD_APP"
PROJECT_TITLE="Hello World App"
PROJECT_PKG="hello-world-app"
PROJECT_LABEL="hello-world-app"
PROJECT_VERSION="0.1.0-alpha"
CONTAINER_DEV="hello-world-app-dev"
CONTAINER_PROD="hello-world-app-prod"
IMAGE_DEV="hello-world-app:dev"
IMAGE_PROD="hello-world-app:prod"
NETWORK_NAME="hello-world-app-net"
VOLUME_DATA="hello-world-app-data"
INSIDE_CONTAINER_MARKER="HELLO_WORLD_APP_INSIDE_CONTAINER"
ENV_PREFIX="HELLO_WORLD_APP"
GH_OWNER="lloydbrian"
GH_REPO="lloydbrian/hello-world-app"
BRAND="lloydbriantech"
SCAFFOLD_DATE="$(date +%Y-%m-%d)"
SCAFFOLD_YEAR="$(date +%Y)"
FRAMEWORK_VERSION="0.3.0"

# ── Step 1: Clean previous scaffold ──────────────────────────────
if [ -d "$TARGET_DIR" ]; then
  printf "Removing previous scaffold at %s...\n" "$TARGET_DIR"
  rm -rf "$TARGET_DIR"
fi

# ── Step 2: Copy template tree ───────────────────────────────────
printf "Copying template assets to %s...\n" "$TARGET_DIR"
cp -R "$TEMPLATE_DIR" "$TARGET_DIR"

# ── Step 3: Rename .tmpl files ───────────────────────────────────
printf "Renaming .tmpl files...\n"
find "$TARGET_DIR" -name '*.tmpl' | while IFS= read -r tmpl; do
  mv "$tmpl" "${tmpl%.tmpl}"
done

# ── Step 4: Substitute all <<PLACEHOLDER>> values ────────────────
printf "Substituting placeholders...\n"

# Order matters for overlapping patterns — longest first
declare -a SUBS=(
  "<<INSIDE_CONTAINER_MARKER>>|$INSIDE_CONTAINER_MARKER"
  "<<PROJECT_SLUG_UPPER>>|$PROJECT_SLUG_UPPER"
  "<<PROJECT_VERSION>>|$PROJECT_VERSION"
  "<<PROJECT_TITLE>>|$PROJECT_TITLE"
  "<<PROJECT_LABEL>>|$PROJECT_LABEL"
  "<<PROJECT_SLUG>>|$PROJECT_SLUG"
  "<<PROJECT_PKG>>|$PROJECT_PKG"
  "<<CONTAINER_DEV>>|$CONTAINER_DEV"
  "<<CONTAINER_PROD>>|$CONTAINER_PROD"
  "<<FRAMEWORK_VERSION>>|$FRAMEWORK_VERSION"
  "<<SCAFFOLD_DATE>>|$SCAFFOLD_DATE"
  "<<SCAFFOLD_YEAR>>|$SCAFFOLD_YEAR"
  "<<NETWORK_NAME>>|$NETWORK_NAME"
  "<<VOLUME_DATA>>|$VOLUME_DATA"
  "<<IMAGE_DEV>>|$IMAGE_DEV"
  "<<IMAGE_PROD>>|$IMAGE_PROD"
  "<<ENV_PREFIX>>|$ENV_PREFIX"
  "<<GH_OWNER>>|$GH_OWNER"
  "<<GH_REPO>>|$GH_REPO"
  "<<BRAND>>|$BRAND"
)

# Apply substitutions to all files (skip binary)
find "$TARGET_DIR" -type f | while IFS= read -r file; do
  # Skip binary files
  if file "$file" | grep -q "binary"; then
    continue
  fi
  for sub in "${SUBS[@]}"; do
    pattern="${sub%%|*}"
    replacement="${sub#*|}"
    # Use | as sed delimiter since paths may contain /
    sed -i '' "s|${pattern}|${replacement}|g" "$file" 2>/dev/null || true
  done
done

# ── Step 5: Create .env from .env.example (what any dev does after cloning) ──
printf "Creating .env from .env.example...\n"
cp "$TARGET_DIR/.env.example" "$TARGET_DIR/.env"

# ── Step 6: Done (no host npm install — Principle 1: container handles deps) ──
printf "\n"
printf "Scaffold complete: %s\n" "$TARGET_DIR"
printf "Next: cd %s && make dev-up\n" "$TARGET_DIR"
printf "\n"
printf "Note: npm dependencies install inside containers at build time.\n"
printf "The host needs only the container engine (Podman or Docker).\n"
