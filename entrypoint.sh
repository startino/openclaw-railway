#!/bin/bash
set -e

OPENCLAW_HOME="/data/openclaw"
TS_STATE="/data/tailscale"

# Create dirs and fix Railway volume permissions (runs as root)
mkdir -p "$OPENCLAW_HOME" "$TS_STATE"
chown node:node /data "$OPENCLAW_HOME" "$TS_STATE"
# Fix ownership on openclaw config dir only (not entire volume - too slow on large volumes)
if [ -d "$OPENCLAW_HOME/.openclaw" ]; then
    chown -R node:node "$OPENCLAW_HOME/.openclaw"
fi

# Start Tailscale if auth key is provided
if [ -n "${TS_AUTHKEY:-}" ]; then
    echo "Starting Tailscale..."
    tailscaled --state="$TS_STATE/tailscaled.state" --tun=userspace-networking --port=41641 &

    # Wait for tailscaled socket
    for i in $(seq 1 10); do
        if tailscale status --json >/dev/null 2>&1; then break; fi
        sleep 1
    done

    # Bring up Tailscale subnet router
    tailscale up \
        --authkey="${TS_AUTHKEY}" \
        --hostname="${TS_HOSTNAME:-openclaw}" \
        --advertise-routes="${TS_ROUTES:-fd12::/16}" \
        --accept-dns=false
    echo "Tailscale connected."
else
    echo "TS_AUTHKEY not set, skipping Tailscale."
fi

# Patch config for Railway compatibility on every boot
CONFIG_FILE="$OPENCLAW_HOME/.openclaw/openclaw.json"
mkdir -p "$OPENCLAW_HOME/.openclaw"
if [ -f "$CONFIG_FILE" ]; then
    # Remove gateway.tailscale (conflicts with bind:lan), ensure bind is lan
    node -e "
      const fs = require('fs');
      const c = JSON.parse(fs.readFileSync('$CONFIG_FILE','utf8'));
      if (c.gateway) {
        delete c.gateway.tailscale;
        c.gateway.bind = 'lan';
        if (!c.gateway.controlUi) c.gateway.controlUi = {};
        c.gateway.controlUi.dangerouslyAllowHostHeaderOriginFallback = true;
      }
      fs.writeFileSync('$CONFIG_FILE', JSON.stringify(c, null, 2));
    "
    echo "Config patched for Railway."
else
    cat > "$CONFIG_FILE" << 'CONF'
{
  "gateway": {
    "bind": "lan",
    "controlUi": {
      "dangerouslyAllowHostHeaderOriginFallback": true
    }
  }
}
CONF
    echo "Default config written."
fi
chown node:node "$CONFIG_FILE"

# Drop to node user, start OpenClaw gateway (becomes PID 1)
export HOME="/home/node"
export OPENCLAW_HOME="$OPENCLAW_HOME"
echo "Starting OpenClaw gateway..."
exec gosu node openclaw gateway --allow-unconfigured --bind lan --port "${PORT:-18789}"
