FROM node:22-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates curl git gosu \
    jq procps lsof nano less htop && \
    curl -fsSL https://tailscale.com/install.sh | sh && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

RUN npm install -g openclaw

# Install Playwright Chromium with all system deps (runs as root)
RUN npx playwright install --with-deps chromium

EXPOSE 18789

HEALTHCHECK --interval=30s --timeout=5s --start-period=60s \
    CMD curl -f http://localhost:18789/healthz || exit 1

COPY --chmod=755 entrypoint.sh /entrypoint.sh
COPY config/ /opt/openclaw-config/
COPY --chmod=755 scripts/ /opt/openclaw-scripts/

ENTRYPOINT ["/entrypoint.sh"]
