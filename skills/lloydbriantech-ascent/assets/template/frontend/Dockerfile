# <<PROJECT_TITLE>> — frontend Dockerfile.
#
# Multi-stage build (three stages):
#   builder     — runs vite build, produces static files in dist/
#   production  — nginx serves the pre-built static bundle
#   development — Vite dev server with hot reload (LAST stage = compose default)
#
# docker-compose.yml (no target)      → uses 'development' stage (last)
# docker-compose.prod.yml (target: production) → uses 'production' stage

# ── Stage 1: builder ────────────────────────────────────────────
FROM node:22-alpine AS builder
WORKDIR /app
COPY package.json package-lock.json* ./
RUN npm install
COPY . .
RUN npm run build

# ── Stage 2: production ─────────────────────────────────────────
FROM nginx:alpine AS production
COPY --from=builder /app/dist /usr/share/nginx/html
EXPOSE 80

# ── Stage 3: development (last = default for compose without target) ──
FROM node:22-alpine AS development
WORKDIR /app

COPY package.json package-lock.json* ./
RUN npm install
COPY . .

ENV <<INSIDE_CONTAINER_MARKER>>=1
EXPOSE 3000

CMD ["npm", "run", "dev"]
