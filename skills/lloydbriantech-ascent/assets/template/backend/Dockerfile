# <<PROJECT_TITLE>> — backend Dockerfile.
#
# Multi-stage build (three stages):
#   builder     — installs production dependencies (including native better-sqlite3)
#   production  — minimal image with only runtime code + prod deps
#   development — full deps (including devDeps like Vitest) + hot reload
#
# docker-compose.yml (no target)      → uses 'development' stage (last)
# docker-compose.prod.yml (target: production) → uses 'production' stage

# ── Stage 1: builder ────────────────────────────────────────────
FROM node:22-alpine AS builder
WORKDIR /app

# Native build tooling for better-sqlite3 C++ compilation
RUN apk add --no-cache build-base python3

COPY package.json package-lock.json* ./
RUN npm install --omit=dev

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

# ── Stage 3: development (last = default for compose without target) ──
FROM node:22-alpine AS development
WORKDIR /app

# Native build tooling for better-sqlite3 C++ compilation
RUN apk add --no-cache build-base python3 curl

COPY package.json package-lock.json* ./
RUN npm install

COPY . .

# Data directory for SQLite
RUN mkdir -p /app/data

ENV <<INSIDE_CONTAINER_MARKER>>=1
EXPOSE 3001

HEALTHCHECK --interval=10s --timeout=5s --retries=3 --start-period=10s \
  CMD curl -sf http://localhost:3001/healthz || exit 1

CMD ["node", "--watch", "server.js"]
