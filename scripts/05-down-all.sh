#!/usr/bin/env sh
set -eu
ROOT="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
cd "$ROOT/codigo_base/deploy"
IMAGE_TAG="${IMAGE_TAG:-dummy}" NEXUS_REGISTRY="${NEXUS_REGISTRY:-localhost:9080}" docker compose down --remove-orphans || true
cd "$ROOT/codigo_base/infra/jenkins_config"
docker compose down || true
cd "$ROOT/codigo_base/infra/nexus_config"
docker compose down || true
