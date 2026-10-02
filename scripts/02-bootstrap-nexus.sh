#!/usr/bin/env sh
set -eu
cd "$(dirname "$0")/../codigo_base/infra/nexus_config"
[ -f .env ] || cp .env.example .env
set -a
. ./.env
set +a
./bootstrap-nexus.sh
