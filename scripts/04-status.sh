#!/usr/bin/env sh
set -eu
printf "=== INFRA ===\n"
docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}' | grep -E 'NAMES|nexus|jenkins|smee|studytrack' || true
printf "\n=== NEXUS ===\n"
curl -fsS http://localhost:9081/service/rest/v1/status && printf "\n"
printf "\n=== APP ===\n"
if curl -fsS http://localhost:8080/api/tasks >/dev/null 2>&1; then
  curl -fsS http://localhost:8080/api/tasks && printf "\n"
else
  printf "Backend todavía no desplegado o no disponible en :8080.\n"
fi
if curl -I -fsS http://localhost:3000/ >/dev/null 2>&1; then
  curl -I -fsS http://localhost:3000/ | head -n 1
else
  printf "Frontend todavía no desplegado o no disponible en :3000.\n"
fi
