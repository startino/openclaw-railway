#!/bin/bash
set -e

OPENCLAW_HOME="/data/openclaw"
TS_STATE="/data/tailscale"

# Create dirs and fix Railway volume permissions (runs as root)
mkdir -p "$OPENCLAW_HOME" "$TS_STATE"
chown -R node:node /data

# Start Tailscale (needs root, userspace networking - no NET_ADMIN required)
tailscaled --state="$TS_STATE/tailscaled.state" --tun=userspace-networking --port=41641 &

# Wait for tailscaled socket
for i in $(seq 1 10); do
    if tailscale status --json >/dev/null 2>&1; then break; fi
    sleep 1
done

# Bring up Tailscale subnet router
tailscale up \
    --authkey="${TS_AUTHKEY:-}" \
    --hostname="${TS_HOSTNAME:-openclaw}" \
    --advertise-routes="${TS_ROUTES:-fd12::/16}" \
    --accept-dns=false

# Drop to node user, start OpenClaw gateway (becomes PID 1)
export HOME="/home/node"
export OPENCLAW_HOME="$OPENCLAW_HOME"
exec gosu node openclaw gateway --allow-unconfigured
