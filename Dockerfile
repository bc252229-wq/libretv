# ---------- LibreTV build ----------
FROM node:22-alpine AS libretv-builder
WORKDIR /app
RUN corepack enable
COPY package.json pnpm-lock.yaml pnpm-workspace.yaml ./
RUN pnpm install --frozen-lockfile
COPY . .
ENV DOCKER_BUILD=1
ENV NEXT_TELEMETRY_DISABLED=1
RUN pnpm build

# ---------- danmu_api ----------
FROM node:22-alpine AS danmu-builder
WORKDIR /danmu
COPY danmu_api/package.json ./package.json
RUN npm install --omit=dev --no-audit --no-fund
COPY danmu_api/danmu_api ./danmu_api
COPY danmu_api/config ./config

# ---------- runtime ----------
FROM node:22-alpine
WORKDIR /app
ENV NODE_ENV=production
ENV NEXT_TELEMETRY_DISABLED=1
ENV PORT=10000
ENV HOSTNAME=0.0.0.0
RUN apk add --no-cache tini
COPY --from=libretv-builder /app/.next/standalone ./
COPY --from=libretv-builder /app/.next/static ./.next/static
COPY --from=libretv-builder /app/public ./public
COPY --from=danmu-builder /danmu ./danmu
COPY entrypoint.sh ./
RUN chmod +x entrypoint.sh && mkdir -p /app/danmu/.cache
EXPOSE 10000
ENTRYPOINT ["/sbin/tini","--"]
CMD ["./entrypoint.sh"]