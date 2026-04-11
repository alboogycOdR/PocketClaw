#!/usr/bin/env bash
# Pocket Claw + OpenClaw + Paperclip — VPS bootstrap (spec §14.4).
set -euo pipefail

echo "=== Pocket Claw Company stack (OpenClaw + Paperclip) ==="
echo "Install Docker on your OS first, then re-run this script on the VPS."

apt-get update -y
apt-get install -y docker.io docker-compose-plugin git curl

mkdir -p /opt/pocketclaw/data
cd /opt/pocketclaw

cat > docker-compose.yml <<'EOF'
services:
  openclaw:
    image: openclaw/openclaw:latest
    restart: unless-stopped
    ports:
      - "127.0.0.1:18789:18789"
    volumes:
      - ./data/openclaw:/data
    environment:
      - TZ=UTC

  paperclip:
    image: paperclip/paperclip:latest
    restart: unless-stopped
    ports:
      - "127.0.0.1:3100:3100"
    volumes:
      - ./data/paperclip:/data
    environment:
      - TZ=UTC
EOF

echo "Compose file written to /opt/pocketclaw/docker-compose.yml"
echo "Bind services to localhost and reach them via Tailscale only."
echo "Next: docker compose up -d"
