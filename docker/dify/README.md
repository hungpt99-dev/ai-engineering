# Docker — Dify Self-Host

This directory is a **placeholder** for a self-hosted Dify deployment.

## Why not a full compose here?

Dify's official compose is ~10 services (api, worker, web, db, redis, weaviate/pgvector, etc.) and changes frequently upstream. Vendoring a stale copy would drift. Instead:

### Recommended path

```bash
# Clone upstream (pinned tag recommended)
git clone https://github.com/langgenius/dify.git /tmp/dify
git -C /tmp/dify checkout 1.1.0  # or latest stable tag

cp -r /tmp/dify/docker/* docker/dify/
cp docker/dify/.env.example docker/dify/.env
# Edit docker/dify/.env (DB creds, hosts)
docker compose -f docker/dify/docker-compose.yaml up -d

# Open console
open http://localhost
```

Then create:
1. An account.
2. A Knowledge Base (or import via `company-google-drive` connector).
3. A **Dataset API key**: Knowledge → Service API → Create key.
4. Put that key in the AI Engineering repo's `.env` as `DIFY_API_KEY` and set `DIFY_BASE_URL=http://localhost/v1`.

Upstream docs: https://docs.dify.ai/en/self-host

## What this repo provides

- `docker/dify/docker-compose.yml` — stub explaining the vendoring step (avoids accidental heavy pulls in CI).
- `docker/dify/.env.example` — placeholder.
- `docker/dify/README.md` — this file.

For air-gapped / production installs, follow upstream's production guide (external DB/Redis, volume backups, TLS, etc.).
