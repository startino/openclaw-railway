FROM node:22-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates curl git gosu ffmpeg \
    jq procps lsof nano less htop && \
    curl -fsSL https://tailscale.com/install.sh | sh && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

RUN npm install -g openclaw

# Install Chromium via OpenClaw's bundled Playwright CLI (not npx - avoids npm override conflicts)
# Install to shared path accessible by both root and node user
ENV PLAYWRIGHT_BROWSERS_PATH=/opt/pw-browsers
RUN node /usr/local/lib/node_modules/openclaw/node_modules/playwright-core/cli.js install --with-deps chromium && \
    chmod -R o+rx /opt/pw-browsers

EXPOSE 18789

HEALTHCHECK --interval=30s --timeout=5s --start-period=60s \
    CMD curl -f http://localhost:18789/healthz || exit 1

COPY --chmod=755 entrypoint.sh /entrypoint.sh
COPY config/ /opt/openclaw-config/
COPY --chmod=755 scripts/ /opt/openclaw-scripts/

ENTRYPOINT ["/entrypoint.sh"]
