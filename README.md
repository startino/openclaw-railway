# OpenClaw Railway Service

Declarative OpenClaw gateway for Railway with Tailscale subnet routing and workspace git backup.

## Architecture

- **Config as code**: `config/openclaw.json` is the source-of-truth config template, seeded on first boot
- **Env var patching**: Runtime values (auth token, allowed origins) are injected into the config on every boot
- **Workspace backup**: Git-based backup of the OpenClaw workspace directory via `scripts/workspace-backup.sh`
- **Tailscale**: Optional subnet router for Railway internal network access
- **Rootless**: Entrypoint runs as root for setup, then drops to `node` user via `gosu`

## Environment Variables

| Variable | Purpose | Required |
|----------|---------|----------|
| `RAILWAY_RUN_UID` | `0` - root for chown + tailscaled | Yes |
| `OPENCLAW_GATEWAY_TOKEN` | Auth token for Control UI | Yes |
| `OPENCLAW_ALLOWED_ORIGINS` | Comma-separated origins for Control UI | Yes |
| `GITHUB_TOKEN` | GitHub PAT for git auth (clone/push) | Yes |
| `TS_AUTHKEY` | Tailscale auth key | Optional |
| `TS_HOSTNAME` | Tailscale hostname (default: `openclaw`) | Optional |
| `TS_ROUTES` | Tailscale routes (default: `fd12::/16`) | Optional |
| `PORT` | Gateway port (default: `18789`) | Optional |
| `WORKSPACE_REPO` | Git remote for workspace backup (default: `startino/openclaw-workspace`) | Optional |

## Deployment

1. Connect this repo to a Railway service
2. Add a volume mounted at `/data`
3. Set environment variables per table above
4. Deploy - config is seeded automatically from `config/openclaw.json`
5. If using Tailscale, approve the subnet route in Tailscale admin console

## Config Management

The config template lives at `config/openclaw.json`. On first boot, it's copied to `/data/openclaw/.openclaw/openclaw.json`. On every boot, env-var-driven values (token, origins) are patched in.

To update the config: edit `config/openclaw.json`, push, and redeploy. If the config already exists on the volume, the template won't overwrite it - delete the volume config first to re-seed, or make the change in both places.

## Workspace Backup

The workspace backup script pushes the OpenClaw workspace to a git repo for version control.

**Manual backup** (from inside the container):
```bash
su - node -c "/opt/openclaw-scripts/workspace-backup.sh"
```

**Prerequisites**:
- `GITHUB_TOKEN` env var set (for git push auth via `.netrc`)
- `startino/openclaw-workspace` repo created on GitHub (or set `WORKSPACE_REPO`)
- Workspace directory exists at `/data/openclaw/.openclaw/workspace`

The backup script:
1. Initializes a git repo in the workspace if not already present
2. Copies `config/workspace.gitignore` to exclude secrets, sessions, logs
3. Commits all changes with a timestamped message
4. Pushes to the remote

## Files

| File | Purpose |
|------|---------|
| `entrypoint.sh` | Boot sequence: permissions, Tailscale, config, git auth, gateway |
| `config/openclaw.json` | Declarative config template (source of truth) |
| `config/workspace.gitignore` | Gitignore for workspace backup (excludes secrets, sessions, logs) |
| `scripts/workspace-backup.sh` | Manual/cron workspace backup to git |
| `Dockerfile` | Container image build |
| `railway.toml` | Railway deployment config |
