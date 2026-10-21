# Container Resource Profiles for Horizontal Scaling

**Generated:** 2026-10-21  
**Purpose:** Document current container resource usage to enable future offload to cloud GPU instances  
**Environment:** RTX 3070 Laptop 8GB VRAM, 75.7GB host RAM, WSL2 (20GB RAM / 16GB swap)

---

## Summary

| Category | Count | CPU (avg) | RAM (total) | VRAM | Storage (volumes) |
|----------|-------|-----------|-------------|------|-------------------|
| Always-Running | 31 | ~1-2% | ~2.5 GB | — | ~2.8 GB |
| GPU-Workloads | 2 (DMR, ComfyUI) | — | ~2 GB | 7.7 GB / 8 GB | 26.35 GB |
| On-Demand (restart=no) | 6 | — | — | — | — |

**Key Constraints:**
- VRAM: 92-95% utilized (DMR resident models + WDDM overhead)
- Host Available Memory: frequently <2.5 GB (triggers Host-Guard T2/T3)
- WSL Swap: 50-70% trending
- Docker data VHDX: 201.93 GB (needs compaction)

---

## Container Profiles

### GPU-Intensive Workloads (Primary Offload Candidates)

| Container | Image | CPU % | RAM | VRAM* | Volume | Use Case | Offload Priority |
|-----------|-------|-------|-----|-------|--------|----------|------------------|
| **docker-model-runner** | docker/model-runner:latest-vllm-cuda | — | ~500 MB | ~7.7 GB | docker-model-runner-models (26.35 GB) | LLM inference (llama.cpp) | **HIGH** |
| **social-media-comfyui-gpu** | ghcr.io/themis128/cu130-slim:comfyui-latest | 0% (restarting) | 0 B | — | — | AI image generation | **HIGH** |

*Note: VRAM usage per-container not visible via nvidia-smi on WSL2 host; DMR estimated at 7.7 GB based on total VRAM 8 GB - 370 MB system.*

---

### Always-Running Services (CPU/Memory Candidates)

| Container | Image | CPU % | RAM Usage / Limit | RAM % | Volume | Use Case | Offload Priority |
|-----------|-------|-------|-------------------|-------|--------|----------|------------------|
| n8n | n8nio/n8n:2.43.4 | 0.36% | 322.7 MiB / 1.25 GiB | 25% | — | Workflow automation | MEDIUM |
| social-api | ghcr.io/themis128/cu130-slim:social-api-latest | 0.57% | 309.2 MiB / 2 GiB | 15% | — | SocialAuto API | MEDIUM |
| social-postgres | postgres:17-alpine | 2.32% | 46.58 MiB / 768 MiB | 6% | cu130-slim_social_postgres_data (404.8 MB) + v17 (480.4 MB) | Primary DB | LOW (data gravity) |
| postgres | postgres:16-alpine | 2.23% | 16.77 MiB / 512 MiB | 3% | cu130-slim_postgres_data (86.33 MB) | Secondary DB | LOW |
| redis | redis:7-alpine | 2.46% | 17.92 MiB / 256 MiB | 7% | cu130-slim_redis_data (62.85 MB) | Cache/Queue | LOW |
| minio | bitnamilegacy/minio:latest | 0.04% | 270.6 MiB / 512 MiB | 53% | cu130-slim_minio_data (9.59 MB) | S3-compatible storage | LOW |
| prometheus | prom/prometheus:v2.54.1 | 0.02% | 92.95 MiB / 1 GiB | 9% | cu130-slim_prometheus_data (14.02 MB) | Metrics collection | MEDIUM |
| grafana | grafana/grafana:11.1.4 | 0.03% | 135.1 MiB / 512 MiB | 26% | cu130-slim_grafana_data (1.47 MB) | Dashboards | MEDIUM |
| chroma | chromadb/chroma:1.5.9 | 0.00% | 6.87 MiB / 768 MiB | 1% | — | Vector DB | LOW |
| alertmanager | prom/alertmanager:v0.27.0 | 0.08% | 24.55 MiB / 128 MiB | 19% | cu130-slim_alertmanager_data (0 B) | Alerts | MEDIUM |
| node-exporter | prom/node-exporter:v1.8.2 | 0.00% | 20.85 MiB / 128 MiB | 16% | — | Host metrics | LOW |
| cadvisor | gcr.io/cadvisor/cadvisor:v0.49.1 | 0.00% | 40.72 MiB / 256 MiB | 16% | — | Container metrics | LOW |
| social-api-gateway | nginx:1.27-alpine | 0.00% | 3.83 MiB / 128 MiB | 3% | — | API Gateway | LOW |
| social-metrics | nginx:1.27-alpine | 0.00% | 2.91 MiB / 256 MiB | 1% | — | Metrics endpoint | LOW |
| n8n-metrics | nginx:1.27-alpine | 0.00% | 3.18 MiB / 128 MiB | 2% | — | n8n metrics | LOW |
| social-frontend | ghcr.io/themis128/cu130-slim:social-frontend-latest | 0.00% | 55.22 MiB / 512 MiB | 11% | — | Frontend | LOW |
| stack-ops | cu130-slim-stack-ops | 0.00% | 38.3 MiB / 192 MiB | 20% | — | Stack management | LOW |
| dmr-watchdog | docker:27-cli | 0.00% | 524 KiB / 96 MiB | 1% | — | DMR monitoring | LOW |
| dmr-lan-proxy | node:24 | 0.00% | 10.24 MiB / 64 MiB | 16% | — | DMR LAN proxy | LOW |
| airbyte-mcp-server | cu130-slim-airbyte-mcp-server | 0.13% | 89.23 MiB / 512 MiB | 17% | cu130-slim_airbyte_mcp_data (0 B) | Airbyte MCP | LOW |
| linkedin-mcp-server | stickerdaniel/linkedin-mcp-server:latest | 4.25% | 28.11 MiB / 512 MiB | 5% | cu130-slim_linkedin_mcp_data (227.9 MB) | LinkedIn MCP | MEDIUM |
| nextcloud-mcp-server | ghcr.io/cbcoutinho/nextcloud-mcp-server:0.198.3 | 0.16% | 69.63 MiB / 512 MiB | 14% | cu130-slim_nextcloud_mcp_data (155.6 kB) | NextCloud MCP | LOW |
| elastic_babbage | mcr.microsoft.com/playwright/mcp:v0.0.82 | 0.00% | 105.4 MiB / 19.53 GiB | 1% | — | Playwright MCP | LOW |
| c7099c0d27fc_social-cloudflared | ghcr.io/themis128/cu130-slim:cloudflared-latest | 0.05% | 50.31 MiB / 256 MiB | 20% | — | Cloudflare tunnel | LOW |
| n8n-task-runner | n8nio/n8n-sandbox-service-sandbox:latest | 0.00% | 150.6 MiB / 512 MiB | 29% | — | n8n sandbox | LOW |
| thirsty_jones | hashicorp/terraform-mcp-server:0.4.0 | 0.00% | 7.70 MiB / 19.53 GiB | 0% | — | Terraform MCP | LOW |

---

### On-Demand Containers (restart=no) - Already Right-Sized

| Container | Image | Status | Volume | Use Case |
|-----------|-------|--------|--------|----------|
| local-diffusers | — | Down | — | Diffusion models |
| novnc | — | Down | — | VNC for browser |
| fb-sidecar | — | Down | cu130-slim_facebook_browser_data (4.29 kB) | Facebook automation |
| languagetool | erikvl87/languagetool:latest | Down | — | Grammar checking |
| metabase | metabase/metabase:v0.63.14.1 | Down | cu130-slim_social_postgres_data_v17 (shared) | BI |
| comfyui-gpu | ghcr.io/themis128/cu130-slim:comfyui-latest | Restarting | — | GPU image gen |

---

## Volume Storage Profile

| Volume | Size | Container(s) | Tier | Backup Priority |
|--------|------|--------------|------|-----------------|
| docker-model-runner-models | **26.35 GB** | DMR | Monthly | CRITICAL (models) |
| cu130-slim_browser_profile | **1.91 GB** | SocialAuto browser | Weekly | HIGH |
| cu130-slim_social_postgres_data_v17 | **480.4 MB** | Postgres v17 | Weekly | CRITICAL |
| cu130-slim_social_postgres_data | **404.8 MB** | Postgres | Weekly | CRITICAL |
| cu130-slim_linkedin_mcp_data | **227.9 MB** | LinkedIn MCP | Weekly | MEDIUM |
| cu130-slim_warp_data | **130.8 MB** | Warp | Weekly | MEDIUM |
| cu130-slim_postgres_data | **86.33 MB** | Postgres | Nightly | MEDIUM |
| cu130-slim_redis_data | **62.85 MB** | Redis | Nightly | MEDIUM |
| cu130-slim_prometheus_data | **14.02 MB** | Prometheus | Nightly | MEDIUM |
| cu130-slim_grafana_data | **1.47 MB** | Grafana | Nightly | LOW |
| cu130-slim_minio_data | **9.59 MB** | MinIO | Nightly | LOW |
| cu130-slim_nextcloud_mcp_data | **155.6 kB** | NextCloud MCP | Nightly | LOW |
| cu130-slim_browser_cookies | **1.74 MB** | Browser cookies | Nightly | LOW |
| cu130-slim_alertmanager_data | **0 B** | Alertmanager | Nightly | LOW |
| cu130-slim_airbyte_mcp_data | **0 B** | Airbyte MCP | Nightly | LOW |
| cu130-slim_instagram_sessions | **54.56 kB** | Instagram | Nightly | LOW |
| cu130-slim_tiktok_browser_data | **2.93 kB** | TikTok | Nightly | LOW |
| cu130-slim_tunnel_url | **27 B** | Tunnel | Nightly | LOW |
| cu130-slim_linkedin_browser_data | **95.73 kB** | LinkedIn browser | Nightly | LOW |
| cu130-slim_facebook_browser_data | **4.29 kB** | Facebook browser | Nightly | LOW |
| cu130-slim_portainer_data | **34.16 kB** | Portainer | Nightly | LOW |
| 6781f08ca958b5df654e82fbb535a29ebbde4978e79abd1b6294e6e41b30513b | **0 B** | — | Nightly | — |
| a2e81bba12295dbade0b914404cee9b84da8acc376bf9ca97763396c50ba919d | **0 B** | — | Nightly | — |
| 29e6e5ba4e37af55d8bb119cf556922e055ac730b2a7b60490356963d098f96f | **0 B** | — | Nightly | — |
| cu130-slim_social_postgres_data_v17 | **480.4 MB** | Postgres v17 | Weekly | CRITICAL |

**Total Volume Storage:** ~30.3 GB (dominated by DMR models at 26.35 GB)

---

## Cloud GPU Offload Target Profiles

### Tier 1: GPU Compute (Immediate Offload Candidates)

| Workload | Cloud Instance Type | Est. Cost/hr | VRAM Needed | Data Transfer |
|----------|---------------------|--------------|-------------|---------------|
| **DMR (llama.cpp)** | g5.xlarge (A10G 24GB) / g6.xlarge (H100 80GB) | $1.00-2.50/hr | 8-16 GB | 26.35 GB model volume (one-time) |
| **ComfyUI** | g5.xlarge / g6e.xlarge | $1.00-2.50/hr | 8-16 GB | Model weights (~5-10 GB) |

**Architecture:**
- Deploy DMR on cloud GPU instance with persistent EBS volume for models
- Use stack-ops wake proxy pattern for on-demand startup
- Connect via Tailscale/VPN or public endpoint with auth
- Model cache warm-up on first request (~30-60s)

### Tier 2: CPU/Memory Intensive (Batch Offload)

| Workload | Cloud Instance Type | Est. Cost/hr | RAM Needed | Data Transfer |
|----------|---------------------|--------------|------------|---------------|
| n8n workflows | t3.large / c6i.large | $0.08-0.10/hr | 2-4 GB | Minimal (config) |
| Prometheus/Grafana | t3.medium | $0.04/hr | 2 GB | 14 MB + dashboards |
| SocialAuto API | t3.large | $0.08/hr | 2 GB | PostgreSQL connection |
| LinkedIn MCP | t3.medium | $0.04/hr | 1 GB | 228 MB volume |

### Tier 3: Always-On Lightweight (Keep Local)

| Workload | Reason to Keep Local |
|----------|---------------------|
| PostgreSQL (social-postgres) | Data gravity - 885 MB active data, low latency required |
| Redis | Sub-millisecond latency for queues |
| MinIO | Local object storage, large objects |
| Cloudflared | Tunnel termination must be local |
| stack-ops | Wake proxy for on-demand containers |

---

## Migration Strategy

### Phase 1: DMR Offload (Week 1-2)
1. Provision g5.xlarge with 50 GB gp3 EBS for models
2. Sync `docker-model-runner-models` volume to EBS (one-time ~26 GB)
3. Deploy DMR container with `--gpus all` and model volume mount
4. Update stack-ops to route DMR requests to cloud endpoint
5. Test with `-ngl 999` (full GPU offload)
6. Verify VRAM drops to <2 GB locally

### Phase 2: ComfyUI Offload (Week 2-3)
1. Provision g5.xlarge (can share with DMR if time-sliced)
2. Deploy ComfyUI with model volume
3. Update stack-ops wake proxy for ComfyUI
4. Verify GPU container stops locally

### Phase 3: Observability Stack (Week 3-4)
1. Deploy Prometheus + Grafana on t3.medium
2. Configure remote_write from local node-exporter/cadvisor
3. Migrate dashboards
4. Decommission local Prometheus/Grafana (saves ~230 MB RAM)

### Phase 4: Batch Workloads (Month 2)
1. n8n workflows to t3.large (scheduled, not latency-sensitive)
2. LinkedIn MCP to t3.medium
3. Airbyte MCP to t3.medium

---

## Cost Estimation (Monthly, us-east-1 on-demand)

| Workload | Instance | Hours/Month | Cost/Month |
|----------|----------|-------------|------------|
| DMR (24/7) | g5.xlarge | 730 | ~$730 |
| ComfyUI (on-demand, ~4 hr/day) | g5.xlarge | 120 | ~$120 |
| Prometheus/Grafana (24/7) | t3.medium | 730 | ~$30 |
| n8n (24/7) | t3.large | 730 | ~$60 |
| LinkedIn MCP (on-demand) | t3.medium | 100 | ~$4 |
| **Total** | | | **~$944/month** |

*Reserved instances / Savings Plans can reduce by 30-40%*

---

## Network Architecture

```
Local Network (Tailscale)          Cloud VPC (us-east-1)
┌─────────────────────────┐        ┌─────────────────────────┐
│ stack-ops (wake proxy)  │◄──────►│ DMR (g5.xlarge)         │
│                         │        │   - Model volume (EBS)  │
│ Cloudflared tunnel      │        │ ComfyUI (g5.xlarge)     │
│                         │        │   - Model volume (EBS)  │
│ PostgreSQL (local)      │        │ Prometheus (t3.medium)  │
│ Redis (local)           │        │ Grafana (t3.medium)     │
│ MinIO (local)           │        │ n8n (t3.large)          │
└─────────────────────────┘        └─────────────────────────┘
```

---

## Action Items

- [ ] Provision cloud GPU instance (g5.xlarge) for DMR
- [ ] Create EBS volume and sync DMR models
- [ ] Update stack-ops wake proxy for DMR routing
- [ ] Test DMR cloud endpoint latency (<100ms target)
- [ ] Decommission local DMR container
- [ ] Monitor VRAM recovery (target: <2 GB local)
- [ ] Document ComfyUI offload procedure
- [ ] Set up cloud Prometheus/Grafana
- [ ] Configure remote_write from local exporters
- [ ] Create runbook for GPU instance lifecycle (start/stop/scale)