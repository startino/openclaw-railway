#!/bin/bash
# Backs up OpenClaw workspace to git
set -e

WORKSPACE="${OPENCLAW_HOME:-/data/openclaw}/.openclaw/workspace"
REPO="${WORKSPACE_REPO:-https://github.com/startino/openclaw-workspace.git}"

cd "$WORKSPACE" || { echo "Workspace not found: $WORKSPACE"; exit 1; }

if [ ! -d ".git" ]; then
    echo "Initializing workspace git repo..."
    git init
    git remote add origin "$REPO"
fi

# Ensure .gitignore is in place
if [ -f /opt/openclaw-config/workspace.gitignore ] && [ ! -f .gitignore ]; then
    cp /opt/openclaw-config/workspace.gitignore .gitignore
fi

git add -A
if git diff --cached --quiet; then
    echo "No changes to backup."
    exit 0
fi

git commit -m "backup: $(date -u +%Y-%m-%d_%H:%M)"
git push -u origin main 2>/dev/null || git push --set-upstream origin main
echo "Workspace backed up."
