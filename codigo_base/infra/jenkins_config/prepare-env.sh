#!/usr/bin/env sh
set -eu

if [ ! -f .env ]; then
  cp .env.example .env
fi

if [ -S /var/run/docker.sock ] && command -v stat >/dev/null 2>&1; then
  if stat -c '%g' /var/run/docker.sock >/dev/null 2>&1; then
    GID_VALUE="$(stat -c '%g' /var/run/docker.sock)"
    if grep -q '^DOCKER_GID=' .env; then
      sed -i.bak "s/^DOCKER_GID=.*/DOCKER_GID=$GID_VALUE/" .env && rm -f .env.bak
    else
      printf '\nDOCKER_GID=%s\n' "$GID_VALUE" >> .env
    fi
  fi
fi

printf "Revise SMEE_CHANNEL_URL en infra/jenkins_config/.env antes de levantar Jenkins.\n"
