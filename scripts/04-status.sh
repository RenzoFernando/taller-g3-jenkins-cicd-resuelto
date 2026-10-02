#!/usr/bin/env sh
set -eu
printf "=== INFRA ===\n"
docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}' | grep -E 'NAMES|nexus|jenkins|smee|studytrack' || true
printf "\n=== NEXUS ===\n"
curl -fsS http://localhost:9081/service/rest/v1/status && printf "\n"
printf "\n=== APP ===\n"
curl -fsS http://localhost:8080/api/tasks && printf "\n"
curl -I -fsS http://localhost:3000/ | head -n 1
