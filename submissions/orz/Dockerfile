# Orz Paymaster API — multi-stage build.
#
# Stage 1: install + compile TypeScript.
# Stage 2: runtime — Node 20 slim, no dev deps.

FROM node:20-bookworm-slim AS builder
WORKDIR /app
COPY api/package.json api/tsconfig.json ./
RUN npm install --no-audit --no-fund
COPY api/server.ts ./
RUN npx tsc -p tsconfig.json

FROM node:20-bookworm-slim AS runtime
WORKDIR /app
ENV NODE_ENV=production
COPY api/package.json ./
RUN npm install --omit=dev --no-audit --no-fund \
 && rm -rf /root/.npm
COPY --from=builder /app/dist ./dist

# Healthcheck hits /healthz — fails the container if the signer service is down.
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s \
  CMD node -e "fetch('http://127.0.0.1:'+(process.env.PORT||8642)+'/healthz').then(r=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))"

EXPOSE 8642
USER node
CMD ["node", "--enable-source-maps", "dist/server.js"]
