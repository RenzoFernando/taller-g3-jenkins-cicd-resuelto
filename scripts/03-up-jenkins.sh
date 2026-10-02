#!/usr/bin/env sh
set -eu
cd "$(dirname "$0")/../codigo_base/infra/jenkins_config"
./prepare-env.sh

if grep -q 'REEMPLAZAR-CANAL' .env 2>/dev/null; then
  printf "ERROR: edite codigo_base/infra/jenkins_config/.env y ponga su SMEE_CHANNEL_URL real.\n" >&2
  exit 1
fi

docker compose --env-file .env up -d --build
printf "Jenkins: http://localhost:9082\n"

# La clave inicial solo existe antes de completar el asistente. En Git Bash evitamos conversión MSYS de /var/...
if docker exec jenkins sh -lc 'test -f /var/jenkins_home/secrets/initialAdminPassword' >/dev/null 2>&1; then
  printf "Clave inicial de Jenkins:\n"
  case "$(uname -s 2>/dev/null || printf unknown)" in
    MINGW*|MSYS*|CYGWIN*) MSYS_NO_PATHCONV=1 docker exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword ;;
    *) docker exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword ;;
  esac
else
  printf "Jenkins ya parece estar configurado; no se requiere la clave inicial.\n"
fi
