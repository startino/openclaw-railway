FROM node:22-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates curl git gosu \
    jq procps lsof nano less htop \
    # Chromium/Playwright deps for headless browser
    libnss3 libatk1.0-0 libatk-bridge2.0-0 libcups2 libdrm2 \
    libxkbcommon0 libxcomposite1 libxdamage1 libxrandr2 libgbm1 \
    libpango-1.0-0 libcairo2 libasound2 libxshmfence1 fonts-liberation && \
    curl -fsSL https://tailscale.com/install.sh | sh && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

RUN npm install -g openclaw

EXPOSE 18789

HEALTHCHECK --interval=30s --timeout=5s --start-period=60s \
    CMD curl -f http://localhost:18789/healthz || exit 1

COPY --chmod=755 entrypoint.sh /entrypoint.sh
COPY config/ /opt/openclaw-config/
COPY --chmod=755 scripts/ /opt/openclaw-scripts/

ENTRYPOINT ["/entrypoint.sh"]
