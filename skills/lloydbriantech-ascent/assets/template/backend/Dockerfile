# <<PROJECT_TITLE>> — backend Dockerfile.
#
# Multi-stage build:
#   builder    — installs dependencies (including native better-sqlite3 compilation)
#   production — minimal image with only runtime dependencies
#
# The 'production' target is referenced by docker-compose.prod.yml.

# ── Stage 1: builder ────────────────────────────────────────────
FROM node:22-alpine AS builder
WORKDIR /app

# Native build tooling for better-sqlite3 C++ compilation
RUN apk add --no-cache --virtual .build-deps build-base python3

COPY package.json package-lock.json* ./
RUN npm ci --production --ignore-scripts=false

# ── Stage 2: production ─────────────────────────────────────────
FROM node:22-alpine AS production

# Non-root user (Principle: image hardening)
RUN addgroup -S app && adduser -S app -G app

# curl for healthcheck
RUN apk add --no-cache curl

WORKDIR /app

COPY --from=builder /app/node_modules ./node_modules
COPY . .

# Data directory for SQLite (mounted as volume in compose)
RUN mkdir -p /app/data && chown -R app:app /app

USER app

ENV <<INSIDE_CONTAINER_MARKER>>=1
EXPOSE 3001

HEALTHCHECK --interval=10s --timeout=5s --retries=3 --start-period=10s \
  CMD curl -sf http://localhost:3001/healthz || exit 1

CMD ["node", "server.js"]
