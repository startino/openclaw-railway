FROM node:22-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates curl gosu && \
    curl -fsSL https://tailscale.com/install.sh | sh && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

RUN npm install -g openclaw

EXPOSE 18789

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s \
    CMD curl -f http://localhost:18789/healthz || exit 1

COPY --chmod=755 entrypoint.sh /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]
