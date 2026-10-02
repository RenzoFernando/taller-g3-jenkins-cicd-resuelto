#!/usr/bin/env sh
set -eu

fail() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
ok() { printf 'OK: %s\n' "$*"; }

for c in nexus jenkins smee-client studytrack-api studytrack-frontend; do
  docker inspect "$c" >/dev/null 2>&1 || fail "falta el contenedor $c"
done
ok "contenedores esperados existen"

curl -fsS http://localhost:9081/service/rest/v1/status >/dev/null || fail "Nexus no responde"
ok "Nexus responde"

curl -fsS http://localhost:8080/api/tasks >/dev/null || fail "backend no responde en http://localhost:8080/api/tasks"
ok "backend responde"

curl -fsS http://localhost:3000/ >/dev/null || fail "frontend no responde en http://localhost:3000"
ok "frontend responde"

BACK_IMAGE="$(docker inspect -f '{{.Config.Image}}' studytrack-api)"
FRONT_IMAGE="$(docker inspect -f '{{.Config.Image}}' studytrack-frontend)"
case "$BACK_IMAGE" in localhost:9080/studytrack-api:*) ;; *) fail "backend no usa imagen de Nexus: $BACK_IMAGE" ;; esac
case "$FRONT_IMAGE" in localhost:9080/studytrack-frontend:*) ;; *) fail "frontend no usa imagen de Nexus: $FRONT_IMAGE" ;; esac
ok "deploy usa imágenes versionadas desde Nexus"

printf '\nBackend image: %s\nFrontend image: %s\n' "$BACK_IMAGE" "$FRONT_IMAGE"
printf '\nCHECK FINAL OK. Falta verificar visualmente Jenkins verde, Nexus con artefactos y webhook automático.\n'
