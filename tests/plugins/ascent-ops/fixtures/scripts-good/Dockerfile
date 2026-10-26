FROM node:22.11.0-alpine AS build
WORKDIR /src
COPY . .
RUN npm ci && npx --yes tsc@5.6.3
FROM build AS test
RUN npm test
FROM gcr.io/distroless/nodejs22-debian12@sha256:0a1f6e0f4c2a9a1d0c0b4e8a8f1d1e6c5b4a3f2e1d0c9b8a7f6e5d4c3b2a1f0e
COPY --from=build /src/dist /app
