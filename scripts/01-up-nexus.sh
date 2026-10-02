#!/usr/bin/env sh
set -eu
cd "$(dirname "$0")/../codigo_base/infra/nexus_config"
[ -f .env ] || cp .env.example .env
docker compose --env-file .env up -d
printf "Esperando healthcheck de Nexus...\n"
until [ "$(docker inspect -f '{{.State.Health.Status}}' nexus 2>/dev/null || true)" = "healthy" ]; do sleep 5; done
printf "Nexus listo en http://localhost:9081\n"
