#!/bin/bash
set -e

OPENCLAW_HOME="/data/openclaw"
TS_STATE="/data/tailscale"
CONFIG_DIR="/opt/openclaw-config"

# Create dirs and fix Railway volume permissions (runs as root)
mkdir -p "$OPENCLAW_HOME/.openclaw" "$TS_STATE"
chown node:node /data "$OPENCLAW_HOME" "$TS_STATE"
if [ -d "$OPENCLAW_HOME/.openclaw" ]; then
    chown -R node:node "$OPENCLAW_HOME/.openclaw"
fi

# Start Tailscale if auth key is provided
if [ -n "${TS_AUTHKEY:-}" ]; then
    echo "Starting Tailscale..."
    tailscaled --state="$TS_STATE/tailscaled.state" --tun=userspace-networking --port=41641 &

    for i in $(seq 1 10); do
        if tailscale status --json >/dev/null 2>&1; then break; fi
        sleep 1
    done

    tailscale up \
        --authkey="${TS_AUTHKEY}" \
        --hostname="${TS_HOSTNAME:-openclaw}" \
        --advertise-routes="${TS_ROUTES:-fd12::/16}" \
        --accept-dns=false \
        --reset
    echo "Tailscale connected."
else
    echo "TS_AUTHKEY not set, skipping Tailscale."
fi

# Seed config from template if none exists, then patch env-var-driven values
CONFIG_FILE="$OPENCLAW_HOME/.openclaw/openclaw.json"
if [ ! -f "$CONFIG_FILE" ]; then
    cp "$CONFIG_DIR/openclaw.json" "$CONFIG_FILE"
    echo "Config seeded from template."
fi

# Patch runtime values (token, allowed origins) into config
node -e "
  const fs = require('fs');
  const c = JSON.parse(fs.readFileSync('$CONFIG_FILE', 'utf8'));

  // Ensure gateway structure
  if (!c.gateway) c.gateway = {};
  if (!c.gateway.controlUi) c.gateway.controlUi = {};

  // Auth: token mode with dangerouslyDisableDeviceAuth for CLI access
  if (!c.gateway.auth) c.gateway.auth = {};
  c.gateway.auth.mode = 'token';
  const token = process.env.OPENCLAW_GATEWAY_TOKEN;
  if (token) c.gateway.auth.token = token;
  // Disable device pairing for both Control UI and CLI
  c.gateway.controlUi.dangerouslyDisableDeviceAuth = true;

  // Sync allowed origins
  const origins = process.env.OPENCLAW_ALLOWED_ORIGINS;
  if (origins) c.gateway.controlUi.allowedOrigins = origins.split(',').map(s => s.trim());

  // Sanitize: remove keys that cause schema validation failures
  if (c.cron && c.cron.jobs) delete c.cron.jobs;
  // Ensure cron is properly enabled (not just empty object)
  if (c.cron && !c.cron.enabled) c.cron.enabled = true;

  fs.writeFileSync('$CONFIG_FILE', JSON.stringify(c, null, 2));
"
chown node:node "$CONFIG_FILE"
echo "Config ready."

# Configure git auth for both root and node users
if [ -n "${GITHUB_TOKEN:-}" ]; then
    NETRC_LINE="machine github.com login x-access-token password ${GITHUB_TOKEN}"
    echo "$NETRC_LINE" > /home/node/.netrc
    chown node:node /home/node/.netrc
    chmod 600 /home/node/.netrc
    echo "$NETRC_LINE" > /root/.netrc
    chmod 600 /root/.netrc
    echo "Git auth configured (root + node)."
fi

# Initialize workspace git repo if token is set and workspace exists
WORKSPACE="$OPENCLAW_HOME/.openclaw/workspace"
if [ -n "${GITHUB_TOKEN:-}" ] && [ -d "$WORKSPACE" ] && [ ! -d "$WORKSPACE/.git" ]; then
    REPO="${WORKSPACE_REPO:-https://github.com/startino/openclaw-workspace.git}"
    echo "Initializing workspace git repo..."
    cd "$WORKSPACE"
    gosu node git init
    gosu node git remote add origin "$REPO"
    cd /
    echo "Workspace git initialized (remote: $REPO)."
fi

# Copy workspace .gitignore if not present
if [ -d "$WORKSPACE" ] && [ ! -f "$WORKSPACE/.gitignore" ]; then
    cp "$CONFIG_DIR/workspace.gitignore" "$WORKSPACE/.gitignore"
    chown node:node "$WORKSPACE/.gitignore"
fi

# Drop to node user, start OpenClaw gateway
export HOME="/home/node"
export OPENCLAW_HOME="$OPENCLAW_HOME"

echo "Starting OpenClaw gateway..."
exec gosu node openclaw gateway --allow-unconfigured --bind lan --port "${PORT:-18789}" --token "${OPENCLAW_GATEWAY_TOKEN}"
