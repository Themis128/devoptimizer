#!/bin/bash
cat > /home/tbaltzakis/cu130-slim/docker-compose.override.yml << 'OVEREOF'
# Local dev override: keep the real ComfyUI image reference so the scanned/published
# image is consistent, but override the runtime to a no-op sleep so the stack can start
# for Cloudflare-only carousel testing without a local GPU.
# This file is gitignored (docker-compose.override.yml) and intended for local use only.
# 2026-09-03: restart: always on every service so the full stack self-heals after
# Docker Desktop / WSL restarts, including containers that were stopped manually.
# (Running containers were also switched with: docker update --restart always)
# 2026-10-21: Converted 6 containers to on-demand (restart=no) per Phase 4 right-sizing

services:
  comfyui:
    image: ghcr.io/themis128/cu130-slim:comfyui-latest
    runtime: runc
    restart: always
    deploy: {}
    command: ["/bin/sh", "-c", "while true; do sleep 3600; done"]
    healthcheck:
      test: ["CMD-SHELL", "exit 0"]
      interval: 10s
      timeout: 5s
      retries: 3
      start_period: 5s
    ports: []
    volumes: []

  n8n:
    restart: always
    environment:
      - N8N_DISABLED_MODULES=

  social-frontend:
    image: ghcr.io/themis128/cu130-slim:social-frontend-latest
    build: !reset null
    pull_policy: always
    restart: always
    command: ["node", "novnc-server.cjs"]

  browser-novnc:
    restart: no
  celery-beat:
    restart: always
  chroma:
    restart: always
  env-manager-backend:
    restart: always
  env-manager-frontend:
    restart: always
  instagram-private-api:
    restart: no
  languagetool:
    restart: no
  local-diffusers:
    restart: always
  metabase:
    restart: no
  minio:
    restart: always
  n8n-sandbox:
    restart: always
  portainer:
    restart: always
  postgres:
    restart: always
  redis:
    restart: always
  social-api:
    restart: always
  cloudflared:
    restart: always
    networks:
      - backend
      - default
  social-postgres:
    restart: always
  social-worker-default:
    restart: always
  social-worker-media:
    restart: always
  social-worker-messenger:
    restart: always
  social-worker-publishing:
    restart: always
  flower:
    restart: always
  tiktok-browser-sidecar:
    restart: no
  warp-proxy:
    restart: no
OVEREOF
echo "File written successfully"