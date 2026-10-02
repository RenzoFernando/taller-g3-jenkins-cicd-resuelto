#!/usr/bin/env sh
set -eu

NEXUS_URL="${NEXUS_URL:-http://localhost:9081}"
DOCKER_PORT="${NEXUS_DOCKER_REGISTRY_PORT:-9080}"
CI_USER="${NEXUS_CI_USER:-ci-publisher}"
CI_PASSWORD="${NEXUS_CI_PASSWORD:-}"
ADMIN_PASSWORD="${NEXUS_ADMIN_PASSWORD:-}"

read_secret() {
  prompt="$1"
  printf "%s" "$prompt" >&2
  if [ -t 0 ]; then stty -echo 2>/dev/null || true; fi
  IFS= read -r value
  if [ -t 0 ]; then stty echo 2>/dev/null || true; fi
  printf "\n" >&2
  printf "%s" "$value"
}

if [ -z "$ADMIN_PASSWORD" ]; then
  ADMIN_PASSWORD="$(read_secret 'Contraseña de admin de Nexus (actual, o la nueva si es el primer arranque): ')"
fi

if [ -z "$CI_PASSWORD" ]; then
  CI_PASSWORD="$(read_secret "Contraseña para $CI_USER: ")"
fi

printf "Esperando Nexus...\n"
until curl -fsS "$NEXUS_URL/service/rest/v1/status" >/dev/null 2>&1; do
  sleep 5
done

# Git Bash/MSYS reescribe rutas /... de comandos Docker. Desactivamos esa conversión solo para docker exec.
docker_cat_admin_password() {
  case "$(uname -s 2>/dev/null || printf unknown)" in
    MINGW*|MSYS*|CYGWIN*)
      MSYS_NO_PATHCONV=1 docker exec nexus cat /nexus-data/admin.password 2>/dev/null || true
      ;;
    *)
      docker exec nexus cat /nexus-data/admin.password 2>/dev/null || true
      ;;
  esac
}

# Si la contraseña actual ya funciona, el bootstrap es reejecutable y no intenta reutilizar la clave inicial.
if curl -fsS -u "admin:$ADMIN_PASSWORD" "$NEXUS_URL/service/rest/v1/status" >/dev/null 2>&1; then
  printf "Credencial admin de Nexus ya configurada.\n"
else
  INITIAL_PASSWORD="$(docker_cat_admin_password)"
  if [ -z "$INITIAL_PASSWORD" ]; then
    printf "ERROR: no fue posible autenticar admin y tampoco leer /nexus-data/admin.password.\n" >&2
    exit 1
  fi

  curl -fsS -u "admin:$INITIAL_PASSWORD" \
    -X PUT -H 'Content-Type: text/plain' --data-binary "$ADMIN_PASSWORD" \
    "$NEXUS_URL/service/rest/v1/security/users/admin/change-password" >/dev/null
fi

AUTH="admin:$ADMIN_PASSWORD"

if ! curl -fsS -u "$AUTH" "$NEXUS_URL/service/rest/v1/repositories" | grep -q '"name"[[:space:]]*:[[:space:]]*"docker-hosted"'; then
  curl -fsS -u "$AUTH" -X POST \
    -H 'Content-Type: application/json' \
    "$NEXUS_URL/service/rest/v1/repositories/docker/hosted" \
    -d "{
      \"name\": \"docker-hosted\",
      \"online\": true,
      \"storage\": {
        \"blobStoreName\": \"default\",
        \"strictContentTypeValidation\": true,
        \"writePolicy\": \"ALLOW_ONCE\"
      },
      \"docker\": {
        \"v1Enabled\": false,
        \"forceBasicAuth\": true,
        \"httpPort\": $DOCKER_PORT
      }
    }" >/dev/null
fi

if ! curl -fsS -u "$AUTH" "$NEXUS_URL/service/rest/v1/security/roles" | grep -q '"id"[[:space:]]*:[[:space:]]*"role-ci-publisher"'; then
  curl -fsS -u "$AUTH" -X POST \
    -H 'Content-Type: application/json' \
    "$NEXUS_URL/service/rest/v1/security/roles" \
    -d '{
      "id": "role-ci-publisher",
      "name": "CI Publisher",
      "description": "Publica Maven releases e imagenes Docker del taller",
      "privileges": [
        "nx-repository-view-maven2-maven-releases-add",
        "nx-repository-view-maven2-maven-releases-browse",
        "nx-repository-view-maven2-maven-releases-edit",
        "nx-repository-view-maven2-maven-releases-read",
        "nx-repository-view-docker-docker-hosted-add",
        "nx-repository-view-docker-docker-hosted-browse",
        "nx-repository-view-docker-docker-hosted-edit",
        "nx-repository-view-docker-docker-hosted-read"
      ],
      "roles": []
    }' >/dev/null
fi

if ! curl -fsS -u "$AUTH" "$NEXUS_URL/service/rest/v1/security/users" | grep -q "\"userId\"[[:space:]]*:[[:space:]]*\"$CI_USER\""; then
  curl -fsS -u "$AUTH" -X POST \
    -H 'Content-Type: application/json' \
    "$NEXUS_URL/service/rest/v1/security/users" \
    -d "{
      \"userId\": \"$CI_USER\",
      \"firstName\": \"CI\",
      \"lastName\": \"Publisher\",
      \"emailAddress\": \"ci-publisher@example.local\",
      \"password\": \"$CI_PASSWORD\",
      \"status\": \"active\",
      \"roles\": [\"role-ci-publisher\"]
    }" >/dev/null
fi

printf "Nexus listo.\n"
printf "UI: %s\n" "$NEXUS_URL"
printf "Maven: %s/repository/maven-releases/\n" "$NEXUS_URL"
printf "Docker: localhost:%s\n" "$DOCKER_PORT"
printf "Usuario Jenkins/Nexus: %s\n" "$CI_USER"
