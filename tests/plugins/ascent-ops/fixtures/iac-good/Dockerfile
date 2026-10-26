# syntax=docker/dockerfile:1
FROM node:22.11.0-alpine
ARG BUILD_VERSION
ENV NODE_ENV=production
WORKDIR /app
COPY package.json package-lock.json ./
COPY .env.example ./
COPY src ./src
USER node
CMD ["node", "src/server.js"]
