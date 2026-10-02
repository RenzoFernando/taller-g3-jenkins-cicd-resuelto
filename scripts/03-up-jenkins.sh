#!/usr/bin/env sh
set -eu
cd "$(dirname "$0")/../codigo_base/infra/jenkins_config"
./prepare-env.sh
printf "Edite .env y ponga SMEE_CHANNEL_URL si todavía está en REEMPLAZAR-CANAL.\n"
docker compose --env-file .env up -d --build
printf "Clave inicial de Jenkins:\n"
docker exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword 2>/dev/null || true
printf "Jenkins: http://localhost:9082\n"
