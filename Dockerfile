# syntax=docker/dockerfile:1.7
ARG NODE_VERSION=22
ARG PB_VERSION=0.40.4

# ---------- Web (static SPA) ----------
FROM node:${NODE_VERSION}-bookworm-slim AS web
WORKDIR /app
COPY package.json package-lock.json ./
COPY apps/web/package.json apps/web/package.json
COPY apps/api/package.json apps/api/package.json
COPY apps/pocketbase/package.json apps/pocketbase/package.json
RUN npm ci --no-audit --no-fund
COPY apps/web apps/web
RUN npm run build --prefix apps/web

# ---------- Express API ----------
FROM node:${NODE_VERSION}-bookworm-slim AS api
WORKDIR /app
ENV NODE_ENV=production
COPY apps/api/package.json ./
RUN npm install --omit=dev --no-audit --no-fund
COPY apps/api/src ./src
EXPOSE 3001
CMD ["node", "src/main.js"]

# ---------- PocketBase ----------
FROM alpine:3.20 AS pocketbase
ARG PB_VERSION=0.40.4
ARG TARGETARCH
RUN apk add --no-cache ca-certificates curl unzip \
    && case "${TARGETARCH:-amd64}" in \
         amd64) pbarch=amd64 ;; \
         arm64) pbarch=arm64 ;; \
         *) echo "Unsupported architecture: ${TARGETARCH}" >&2; exit 1 ;; \
       esac \
    && curl -fsSL -o /tmp/pb.zip \
       "https://github.com/pocketbase/pocketbase/releases/download/v${PB_VERSION}/pocketbase_${PB_VERSION}_linux_${pbarch}.zip" \
    && unzip -o /tmp/pb.zip -d /pb \
    && rm /tmp/pb.zip \
    && chmod +x /pb/pocketbase
COPY apps/pocketbase/pb_migrations /pb/pb_migrations
COPY apps/pocketbase/pb_hooks /pb/pb_hooks
WORKDIR /pb
EXPOSE 8090
CMD ["/pb/pocketbase", "serve", "--http=0.0.0.0:8090", "--dir=/pb_data", "--migrationsDir=/pb/pb_migrations", "--hooksDir=/pb/pb_hooks", "--hooksWatch=false", "--encryptionEnv=PB_ENCRYPTION_KEY"]

# ---------- Caddy (TLS + static + reverse proxy) ----------
FROM caddy:2-alpine AS caddy
COPY --from=web /app/dist/apps/web /srv
COPY Caddyfile /etc/caddy/Caddyfile
EXPOSE 80 443
