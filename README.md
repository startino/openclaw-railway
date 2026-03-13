# OpenClaw Railway Service

Minimal OpenClaw gateway for Railway with Tailscale subnet routing.

## What this is

- OpenClaw gateway installed via npm (not built from source)
- Tailscale subnet router for Railway internal network access
- Root entrypoint that drops to `node` user via `gosu`
- Health check on `/healthz`

## Railway Environment Variables

| Variable | Value | Required |
|----------|-------|----------|
| `RAILWAY_RUN_UID` | `0` | Yes - entrypoint needs root for chown + tailscaled |
| `TS_AUTHKEY` | `tskey-auth-...` | Yes - reusable + ephemeral recommended |
| `TS_HOSTNAME` | `openclaw` | No (default) |
| `TS_ROUTES` | `fd12::/16` | No (default) |
| `PORT` | `18789` | If Railway needs explicit port |

Plus any OpenClaw-specific env vars (API keys, etc.).

## Deployment

1. Connect this repo to a Railway service
2. Add a volume mounted at `/data`
3. Set environment variables per table above
4. Deploy
5. Place `openclaw.json` at `/data/openclaw/openclaw.json` via SSH or `railway run`
6. Approve subnet route in Tailscale admin console
