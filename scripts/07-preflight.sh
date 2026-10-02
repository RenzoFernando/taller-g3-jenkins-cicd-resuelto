#!/usr/bin/env sh
set -eu

ROOT="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

fail() { printf "ERROR: %s\n" "$*" >&2; exit 1; }
ok()   { printf "OK: %s\n" "$*"; }

[ -f Jenkinsfile ] || fail "falta Jenkinsfile en la raíz"
[ -f codigo_base/backend/pom.xml ] || fail "falta codigo_base/backend/pom.xml"
[ -f codigo_base/backend/settings.xml ] || fail "falta codigo_base/backend/settings.xml"
[ -f codigo_base/deploy/docker-compose.yml ] || fail "falta codigo_base/deploy/docker-compose.yml"
ok "estructura del repositorio"

docker inspect nexus >/dev/null 2>&1 || fail "contenedor nexus no existe"
docker inspect jenkins >/dev/null 2>&1 || fail "contenedor jenkins no existe"
docker inspect smee-client >/dev/null 2>&1 || fail "contenedor smee-client no existe"
ok "contenedores principales existen"

curl -fsS http://localhost:9081/service/rest/v1/status >/dev/null || fail "Nexus UI/REST no responde en :9081"
ok "Nexus REST responde"

REGISTRY_CODE="$(curl -s -o /dev/null -w '%{http_code}' http://localhost:9080/v2/ || true)"
case "$REGISTRY_CODE" in
  200|401) ok "Nexus Docker Registry responde en :9080 (HTTP $REGISTRY_CODE)" ;;
  *) fail "Nexus Docker Registry no responde correctamente en :9080 (HTTP ${REGISTRY_CODE:-sin-respuesta})" ;;
esac

docker exec jenkins sh -lc 'git --version >/dev/null && mvn -version >/dev/null && docker version >/dev/null' \
  || fail "Jenkins no tiene Git/Maven/Docker o no puede usar /var/run/docker.sock"
ok "Jenkins puede ejecutar Git, Maven y Docker"

docker exec jenkins curl -fsS http://nexus:8081/service/rest/v1/status >/dev/null \
  || fail "Jenkins no alcanza Nexus por cicd_network"
ok "Jenkins alcanza Nexus por http://nexus:8081"

if docker logs --tail 50 smee-client 2>&1 | grep -qi 'REEMPLAZAR-CANAL'; then
  fail "Smee sigue usando REEMPLAZAR-CANAL"
fi
ok "Smee no usa el placeholder"

printf "\nPreflight terminado. Si el webhook de GitHub ya apunta al mismo canal Smee, haga commit/push y observe Jenkins.\n"
