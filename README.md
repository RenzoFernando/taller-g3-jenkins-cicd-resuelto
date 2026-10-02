# Taller Jenkins CI/CD - solución completa

Todo corre localmente con Docker: Nexus + Jenkins + Smee + backend + frontend. No hay AWS ni servidor QA externo.

## Lo único que debes completar tú

1. `codigo_base/infra/jenkins_config/.env` -> poner tu `SMEE_CHANNEL_URL`.
2. Ejecutar `bootstrap-nexus.sh` -> escoger las contraseñas de `admin` y `ci-publisher`.
3. En Jenkins crear la credencial **`nexus-credentials`** con usuario `ci-publisher` y la contraseña que pusiste en Nexus.
4. En Jenkins crear **`github-credentials`** con tu usuario de GitHub + PAT; esa credencial se selecciona en la configuración SCM del Job.
5. Crear el Job/Pipeline apuntando a tu repositorio Git.
6. Si subes **todo este ZIP** al repo, usa **Script Path: `Jenkinsfile`**. El Jenkinsfile detecta automáticamente que la app está en `codigo_base/`.
7. Si subes solo el contenido de `codigo_base/` como raíz del repo, usa también **Script Path: `Jenkinsfile`**.
8. Configurar el webhook de GitHub al mismo canal de Smee. Puedes hacerlo manual o con `scripts/06-create-github-webhook.sh`.

## Orden para levantarlo

```bash
./scripts/01-up-nexus.sh
./scripts/02-bootstrap-nexus.sh

# editar primero:
# codigo_base/infra/jenkins_config/.env
./scripts/03-up-jenkins.sh
```

Después en Jenkins:

```text
Credential ID: nexus-credentials
Tipo: Username with password
Username: ci-publisher
Password: <la que pusiste al ejecutar bootstrap-nexus.sh>

github-credentials:
Tipo: Username with password
Username: <tu usuario GitHub>
Password: <tu PAT>
```

Luego haces `git push`; Smee -> Jenkins -> test -> package -> Nexus -> deploy local -> smoke test.

## Qué tuve que corregir/reemplazar

- `pom.xml`: versión CI-friendly por build+commit y `distributionManagement` a Nexus.
- `settings.xml`: credenciales Maven desde variables de entorno, sin secretos en Git.
- Dockerfiles: multi-stage, versiones fijas, backend no-root, frontend no-root, healthchecks.
- `nginx.conf`: `try_files` para SPA.
- Nexus Compose: UI 9081, registry 9080, volumen, red y healthcheck.
- Nexus bootstrap: crea `docker-hosted` inmutable y el usuario `ci-publisher`.
- Jenkins Dockerfile: Docker CLI + Compose + Maven + Git + plugins.
- Jenkins Compose: socket Docker, GID, volumen, red compartida y Smee.
- `deploy/docker-compose.yml`: imágenes desde Nexus, healthcheck y dependencia frontend->backend.
- `Jenkinsfile`: 4 etapas completas, versión `BUILD_NUMBER + commit`, publicación Maven/Docker, deploy y smoke test.
- El Jenkinsfile soporta dos layouts: taller completo (`codigo_base/`) o código base directamente en la raíz.
- Se usa **`http://nexus:8081` para Maven** porque Maven corre dentro de Jenkins; se usa **`localhost:9080` para Docker** porque el Docker CLI de Jenkins habla con el daemon del host por `/var/run/docker.sock`. Ese detalle es de los más importantes para este taller local.
- El builder del backend usa `maven:3.9.6-eclipse-temurin-17-alpine` para fijar Maven 3.9.6 y Java 17 en la misma imagen.

## La fija para un taller parecido

- Buscar primero todos los `TODO`.
- Revisar puertos y nombres de red antes de tocar el pipeline.
- Separar URL interna de Docker (`nexus:8081`) de URL que usa el daemon del host (`localhost:9080`).
- JAR: versión única por build; no `SNAPSHOT` para releases.
- Docker: nunca `latest`; usar build + commit.
- Maven: `distributionManagement` + `settings.xml` con ID idéntico.
- Jenkins: Docker CLI no basta; también necesita el socket y permisos por GID.
- Smee: `SMEE_URL` pública y target interno `http://jenkins:8080/github-webhook/`.
- Deploy: `docker compose pull` antes de `up -d` para comprobar que sale de Nexus.
- Smoke test: reintentos, no un solo `curl`.
- Secretos: siempre `withCredentials`, nunca contraseña escrita en Jenkinsfile.

---

# Archivos completos

## Backend - pom.xml

`codigo_base/backend/pom.xml`

```xml
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 https://maven.apache.org/xsd/maven-4.0.0.xsd">
    <modelVersion>4.0.0</modelVersion>

    <parent>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-starter-parent</artifactId>
        <version>3.2.5</version>
        <relativePath/>
    </parent>

    <groupId>com.icesi</groupId>
    <artifactId>studytrack-api</artifactId>
    <version>${revision}</version>
    <name>studytrack-api</name>
    <description>Backend REST de StudyTrack (Taller Evaluativo 2 - Ingeniería de Software V)</description>

    <properties>
        <java.version>17</java.version>
        <revision>1.0.0-local</revision>
        <nexus.maven.repo>http://nexus:8081/repository/maven-releases/</nexus.maven.repo>
        <project.build.outputTimestamp>2026-01-01T00:00:00Z</project.build.outputTimestamp>
    </properties>

    <dependencies>
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-web</artifactId>
        </dependency>
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-data-jpa</artifactId>
        </dependency>
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-validation</artifactId>
        </dependency>
        <dependency>
            <groupId>com.h2database</groupId>
            <artifactId>h2</artifactId>
            <scope>runtime</scope>
        </dependency>
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-test</artifactId>
            <scope>test</scope>
        </dependency>
    </dependencies>

    <build>
        <finalName>studytrack-api</finalName>
        <plugins>
            <plugin>
                <groupId>org.springframework.boot</groupId>
                <artifactId>spring-boot-maven-plugin</artifactId>
            </plugin>
        </plugins>
    </build>

    <distributionManagement>
        <repository>
            <id>nexus-releases</id>
            <name>Nexus Maven Releases</name>
            <url>${nexus.maven.repo}</url>
        </repository>
    </distributionManagement>
</project>
```

## Backend - settings.xml

`codigo_base/backend/settings.xml`

```xml
<?xml version="1.0" encoding="UTF-8"?>
<settings xmlns="http://maven.apache.org/SETTINGS/1.2.0"
          xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
          xsi:schemaLocation="http://maven.apache.org/SETTINGS/1.2.0 https://maven.apache.org/xsd/settings-1.2.0.xsd">
    <servers>
        <server>
            <id>nexus-releases</id>
            <username>${env.NEXUS_USER}</username>
            <password>${env.NEXUS_PASS}</password>
        </server>
    </servers>
</settings>
```

## Backend - Dockerfile

`codigo_base/backend/Dockerfile`

```dockerfile
# ---------- Stage 1: Builder ----------
FROM maven:3.9.6-eclipse-temurin-17-alpine AS builder
WORKDIR /workspace

ARG APP_VERSION=1.0.0-local

COPY pom.xml ./
RUN mvn -B -q -DskipTests dependency:go-offline

COPY src ./src
RUN mvn -B clean package -DskipTests -Drevision="${APP_VERSION}"

# ---------- Stage 2: Runtime ----------
FROM eclipse-temurin:17-jre-alpine
WORKDIR /app

RUN apk add --no-cache curl \
    && addgroup -S appgroup \
    && adduser -S appuser -G appgroup

COPY --from=builder /workspace/target/studytrack-api.jar /app/studytrack-api.jar

RUN chown -R appuser:appgroup /app
USER appuser

EXPOSE 8080

HEALTHCHECK --interval=10s --timeout=3s --start-period=20s --retries=6 \
    CMD curl -fsS http://localhost:8080/api/tasks >/dev/null || exit 1

ENTRYPOINT ["java", "-jar", "/app/studytrack-api.jar"]
```

## Frontend - Dockerfile

`codigo_base/frontend/Dockerfile`

```dockerfile
# ---------- Stage 1: Builder ----------
FROM node:20-alpine AS builder
WORKDIR /app

COPY package*.json ./
RUN npm install

COPY . .
ARG VITE_API_URL=http://localhost:8080
ENV VITE_API_URL=${VITE_API_URL}
RUN npm run build

# ---------- Stage 2: Runtime ----------
FROM nginx:1.27-alpine

COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=builder /app/dist /usr/share/nginx/html

RUN touch /var/run/nginx.pid \
    && chown -R nginx:nginx /var/run/nginx.pid /var/cache/nginx /usr/share/nginx/html /etc/nginx/conf.d

USER nginx
EXPOSE 3000

HEALTHCHECK --interval=10s --timeout=3s --start-period=5s --retries=6 \
    CMD wget -q -O /dev/null http://localhost:3000/ || exit 1

CMD ["nginx", "-g", "daemon off;"]
```

## Frontend - nginx.conf

`codigo_base/frontend/nginx.conf`

```nginx
server {
    listen 3000;
    server_name localhost;

    root /usr/share/nginx/html;
    index index.html;

    location / {
        try_files $uri $uri/ /index.html;
    }

    location /assets/ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
}
```

## Nexus - .env.example

`codigo_base/infra/nexus_config/.env.example`

```dotenv
NEXUS_UI_PORT=9081
NEXUS_DOCKER_REGISTRY_PORT=9080
```

## Nexus - docker-compose.yml

`codigo_base/infra/nexus_config/docker-compose.yml`

```yaml
services:
  nexus:
    image: sonatype/nexus3:3.68.1
    container_name: nexus
    restart: unless-stopped
    networks:
      - cicd_network
    ports:
      - "${NEXUS_UI_PORT:-9081}:8081"
      - "${NEXUS_DOCKER_REGISTRY_PORT:-9080}:${NEXUS_DOCKER_REGISTRY_PORT:-9080}"
    volumes:
      - nexus_data:/nexus-data
    environment:
      INSTALL4J_ADD_VM_PARAMS: >-
        -Xms512m -Xmx1024m -XX:MaxDirectMemorySize=1024m
        -Djava.util.prefs.userRoot=/nexus-data/javaprefs
    healthcheck:
      test: ["CMD-SHELL", "curl -fsS http://localhost:8081/service/rest/v1/status >/dev/null || exit 1"]
      interval: 15s
      timeout: 5s
      retries: 20
      start_period: 120s

networks:
  cicd_network:
    name: cicd_network

volumes:
  nexus_data:
```

## Nexus - bootstrap-nexus.sh

`codigo_base/infra/nexus_config/bootstrap-nexus.sh`

```bash
#!/usr/bin/env sh
set -eu

NEXUS_URL="${NEXUS_URL:-http://localhost:9081}"
DOCKER_PORT="${NEXUS_DOCKER_REGISTRY_PORT:-9080}"
CI_USER="${NEXUS_CI_USER:-ci-publisher}"
CI_PASSWORD="${NEXUS_CI_PASSWORD:-}"
ADMIN_PASSWORD="${NEXUS_ADMIN_PASSWORD:-}"

if [ -z "$ADMIN_PASSWORD" ]; then
  printf "Nueva contraseña para admin de Nexus: " >&2
  stty -echo
  read ADMIN_PASSWORD
  stty echo
  printf "\n" >&2
fi

if [ -z "$CI_PASSWORD" ]; then
  printf "Contraseña para %s: " "$CI_USER" >&2
  stty -echo
  read CI_PASSWORD
  stty echo
  printf "\n" >&2
fi

printf "Esperando Nexus...\n"
until curl -fsS "$NEXUS_URL/service/rest/v1/status" >/dev/null 2>&1; do
  sleep 5
done

INITIAL_PASSWORD="$(docker exec nexus cat /nexus-data/admin.password 2>/dev/null || true)"
if [ -n "$INITIAL_PASSWORD" ]; then
  curl -fsS -u "admin:$INITIAL_PASSWORD" \
    -X PUT -H 'Content-Type: text/plain' --data-binary "$ADMIN_PASSWORD" \
    "$NEXUS_URL/service/rest/v1/security/users/admin/change-password" >/dev/null
else
  curl -fsS -u "admin:$ADMIN_PASSWORD" "$NEXUS_URL/service/rest/v1/status" >/dev/null
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
```

## Jenkins - .env.example

`codigo_base/infra/jenkins_config/.env.example`

```dotenv
JENKINS_UI_PORT=9082
JENKINS_AGENT_PORT=50000
DOCKER_GID=0
SMEE_CHANNEL_URL=https://smee.io/REEMPLAZAR-CANAL
```

## Jenkins - Dockerfile

`codigo_base/infra/jenkins_config/Dockerfile`

```dockerfile
FROM jenkins/jenkins:lts-jdk17

USER root

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
       ca-certificates curl gnupg git maven \
    && install -m 0755 -d /etc/apt/keyrings \
    && curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc \
    && chmod a+r /etc/apt/keyrings/docker.asc \
    && . /etc/os-release \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian ${VERSION_CODENAME} stable" > /etc/apt/sources.list.d/docker.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends docker-ce-cli docker-compose-plugin \
    && rm -rf /var/lib/apt/lists/*

COPY plugins.txt /usr/share/jenkins/ref/plugins.txt
RUN jenkins-plugin-cli --plugin-file /usr/share/jenkins/ref/plugins.txt

USER jenkins
```

## Jenkins - plugins.txt

`codigo_base/infra/jenkins_config/plugins.txt`

```text
git:5.2.1
github:1.39.0
workflow-aggregator:600.vb_57cdd26fdd7
pipeline-stage-view:2.34
docker-workflow:580.vc0c340686b_54
credentials-binding:657.v2b_19db_2b_2c6b_
htmlpublisher:1.35
junit:1.63
timestamper:1.25
ws-cleanup:0.45
```

## Jenkins - docker-compose.yml

`codigo_base/infra/jenkins_config/docker-compose.yml`

```yaml
services:
  jenkins:
    build: .
    container_name: jenkins
    restart: unless-stopped
    networks:
      - cicd_network
    ports:
      - "${JENKINS_UI_PORT:-9082}:8080"
      - "${JENKINS_AGENT_PORT:-50000}:50000"
    volumes:
      - jenkins_home:/var/jenkins_home
      - /var/run/docker.sock:/var/run/docker.sock
    group_add:
      - "${DOCKER_GID:-0}"
    extra_hosts:
      - "host.docker.internal:host-gateway"
    healthcheck:
      test: ["CMD-SHELL", "curl -fsS http://localhost:8080/login >/dev/null || exit 1"]
      interval: 10s
      timeout: 5s
      retries: 30
      start_period: 40s

  smee:
    build: ./smee
    container_name: smee-client
    restart: unless-stopped
    environment:
      SMEE_URL: "${SMEE_CHANNEL_URL}"
      SMEE_TARGET: "http://jenkins:8080/github-webhook/"
    networks:
      - cicd_network
    depends_on:
      jenkins:
        condition: service_healthy

networks:
  cicd_network:
    external: true
    name: cicd_network

volumes:
  jenkins_home:
```

## Smee - Dockerfile

`codigo_base/infra/jenkins_config/smee/Dockerfile`

```dockerfile
FROM node:20-alpine

RUN npm install -g smee-client

USER node
ENV SMEE_TARGET=http://jenkins:8080/github-webhook/

ENTRYPOINT ["sh", "-c", "smee -u \"$SMEE_URL\" -t \"$SMEE_TARGET\""]
```

## Jenkins - prepare-env.sh

`codigo_base/infra/jenkins_config/prepare-env.sh`

```bash
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
```

## Deploy - docker-compose.yml

`codigo_base/deploy/docker-compose.yml`

```yaml
services:
  backend:
    image: "${NEXUS_REGISTRY:-localhost:9080}/studytrack-api:${IMAGE_TAG}"
    container_name: studytrack-api
    restart: unless-stopped
    ports:
      - "8080:8080"
    networks:
      - product-network
    healthcheck:
      test: ["CMD-SHELL", "curl -fsS http://localhost:8080/api/tasks >/dev/null || exit 1"]
      interval: 5s
      timeout: 3s
      retries: 12
      start_period: 20s

  frontend:
    image: "${NEXUS_REGISTRY:-localhost:9080}/studytrack-frontend:${IMAGE_TAG}"
    container_name: studytrack-frontend
    restart: unless-stopped
    ports:
      - "3000:3000"
    networks:
      - product-network
    depends_on:
      backend:
        condition: service_healthy

networks:
  product-network:
    driver: bridge
```

## Pipeline - Jenkinsfile

`Jenkinsfile`

```groovy
pipeline {
    agent any

    options {
        timestamps()
        disableConcurrentBuilds()
    }

    triggers {
        githubPush()
    }

    environment {
        IMAGE_TAG = "pending"
        MAVEN_VERSION = "pending"
        APP_DIR = "."

        // Docker CLI en Jenkins usa el socket del host. El daemon del host hace push/pull.
        NEXUS_REGISTRY = "localhost:9080"

        // Maven sí corre dentro del contenedor Jenkins y alcanza Nexus por la red cicd_network.
        NEXUS_MAVEN_REPO = "http://nexus:8081/repository/maven-releases/"

        NEXUS_CREDENTIALS_ID = "nexus-credentials"
        VITE_API_URL = "http://localhost:8080"
    }

    stages {
        stage('Checkout & Test') {
            steps {
                checkout scm

                script {
                    env.APP_DIR = fileExists('codigo_base/backend/pom.xml') ? 'codigo_base' : '.'
                    echo "APP_DIR=${env.APP_DIR}"

                    env.GIT_COMMIT_SHORT = sh(
                        script: 'git rev-parse --short=8 HEAD',
                        returnStdout: true
                    ).trim()
                    env.IMAGE_TAG = "${env.BUILD_NUMBER}-${env.GIT_COMMIT_SHORT}"
                    env.MAVEN_VERSION = "1.0.${env.BUILD_NUMBER}-${env.GIT_COMMIT_SHORT}"
                    echo "IMAGE_TAG=${env.IMAGE_TAG}"
                    echo "MAVEN_VERSION=${env.MAVEN_VERSION}"
                }

                dir("${env.APP_DIR}/backend") {
                    sh 'mvn -B test -Drevision="${MAVEN_VERSION}"'
                }
            }
        }

        stage('Package & Tag Inmutable') {
            steps {
                dir("${env.APP_DIR}/backend") {
                    sh 'mvn -B clean package -DskipTests -Drevision="${MAVEN_VERSION}"'
                    sh '''
                        docker build \
                          --build-arg APP_VERSION="${MAVEN_VERSION}" \
                          -t "${NEXUS_REGISTRY}/studytrack-api:${IMAGE_TAG}" .
                    '''
                }

                dir("${env.APP_DIR}/frontend") {
                    sh '''
                        docker build \
                          --build-arg VITE_API_URL="${VITE_API_URL}" \
                          -t "${NEXUS_REGISTRY}/studytrack-frontend:${IMAGE_TAG}" .
                    '''
                }
            }
        }

        stage('Publish to Nexus') {
            steps {
                withCredentials([usernamePassword(
                    credentialsId: env.NEXUS_CREDENTIALS_ID,
                    usernameVariable: 'NEXUS_USER',
                    passwordVariable: 'NEXUS_PASS'
                )]) {
                    dir("${env.APP_DIR}/backend") {
                        sh '''
                            mvn -B deploy -DskipTests \
                              -Drevision="${MAVEN_VERSION}" \
                              -Dnexus.maven.repo="${NEXUS_MAVEN_REPO}" \
                              -s settings.xml
                        '''
                    }

                    sh '''
                        set +x
                        export DOCKER_CONFIG="$WORKSPACE/.docker-tmp"
                        mkdir -p "$DOCKER_CONFIG"
                        AUTH="$(printf '%s:%s' "$NEXUS_USER" "$NEXUS_PASS" | base64 | tr -d '\n')"
                        printf '{"auths":{"%s":{"auth":"%s"}}}\n' "$NEXUS_REGISTRY" "$AUTH" > "$DOCKER_CONFIG/config.json"
                        set -x

                        docker push "${NEXUS_REGISTRY}/studytrack-api:${IMAGE_TAG}"
                        docker push "${NEXUS_REGISTRY}/studytrack-frontend:${IMAGE_TAG}"

                        set +x
                        rm -rf "$DOCKER_CONFIG"
                    '''
                }
            }
        }

        stage('Deploy & Smoke Test') {
            steps {
                withCredentials([usernamePassword(
                    credentialsId: env.NEXUS_CREDENTIALS_ID,
                    usernameVariable: 'NEXUS_USER',
                    passwordVariable: 'NEXUS_PASS'
                )]) {
                    sh '''
                        set +x
                        export DOCKER_CONFIG="$WORKSPACE/.docker-tmp"
                        mkdir -p "$DOCKER_CONFIG"
                        AUTH="$(printf '%s:%s' "$NEXUS_USER" "$NEXUS_PASS" | base64 | tr -d '\n')"
                        printf '{"auths":{"%s":{"auth":"%s"}}}\n' "$NEXUS_REGISTRY" "$AUTH" > "$DOCKER_CONFIG/config.json"
                        set -x

                        export NEXUS_REGISTRY="${NEXUS_REGISTRY}"
                        export IMAGE_TAG="${IMAGE_TAG}"
                        COMPOSE_FILE="${APP_DIR}/deploy/docker-compose.yml"

                        docker compose -f "$COMPOSE_FILE" down --remove-orphans || true
                        docker compose -f "$COMPOSE_FILE" pull
                        docker compose -f "$COMPOSE_FILE" up -d

                        ok=0
                        for i in $(seq 1 12); do
                          if curl -fsS http://host.docker.internal:8080/api/tasks >/dev/null; then
                            ok=1
                            break
                          fi
                          echo "Smoke test backend: intento $i/12"
                          sleep 5
                        done

                        if [ "$ok" -ne 1 ]; then
                          docker compose -f "$COMPOSE_FILE" ps
                          docker compose -f "$COMPOSE_FILE" logs --no-color
                          exit 1
                        fi

                        curl -fsS http://host.docker.internal:3000/ >/dev/null
                        docker compose -f "$COMPOSE_FILE" ps

                        set +x
                        rm -rf "$DOCKER_CONFIG"
                    '''
                }
            }
        }
    }

    post {
        success {
            echo "Pipeline finalizado en verde. Artefactos publicados con tag: ${env.IMAGE_TAG}"
        }
        failure {
            echo "El pipeline falló. Revise los logs de la etapa correspondiente antes de reintentar."
        }
        always {
            sh 'rm -rf "$WORKSPACE/.docker-tmp" || true'
        }
    }
}
```

## .gitignore

`.gitignore`

```gitignore
.DS_Store

# Local secrets / environment
**/.env
!**/.env.example

# Build outputs
**/target/
**/dist/
**/node_modules/

# Temporary Jenkins Docker credentials
**/.docker-tmp/
```

## Script - 01-up-nexus.sh

`scripts/01-up-nexus.sh`

```bash
#!/usr/bin/env sh
set -eu
cd "$(dirname "$0")/../codigo_base/infra/nexus_config"
[ -f .env ] || cp .env.example .env
docker compose --env-file .env up -d
printf "Esperando healthcheck de Nexus...\n"
until [ "$(docker inspect -f '{{.State.Health.Status}}' nexus 2>/dev/null || true)" = "healthy" ]; do sleep 5; done
printf "Nexus listo en http://localhost:9081\n"
```

## Script - 02-bootstrap-nexus.sh

`scripts/02-bootstrap-nexus.sh`

```bash
#!/usr/bin/env sh
set -eu
cd "$(dirname "$0")/../codigo_base/infra/nexus_config"
[ -f .env ] || cp .env.example .env
set -a
. ./.env
set +a
./bootstrap-nexus.sh
```

## Script - 03-up-jenkins.sh

`scripts/03-up-jenkins.sh`

```bash
#!/usr/bin/env sh
set -eu
cd "$(dirname "$0")/../codigo_base/infra/jenkins_config"
./prepare-env.sh
printf "Edite .env y ponga SMEE_CHANNEL_URL si todavía está en REEMPLAZAR-CANAL.\n"
docker compose --env-file .env up -d --build
printf "Clave inicial de Jenkins:\n"
docker exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword 2>/dev/null || true
printf "Jenkins: http://localhost:9082\n"
```

## Script - 04-status.sh

`scripts/04-status.sh`

```bash
#!/usr/bin/env sh
set -eu
printf "=== INFRA ===\n"
docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}' | grep -E 'NAMES|nexus|jenkins|smee|studytrack' || true
printf "\n=== NEXUS ===\n"
curl -fsS http://localhost:9081/service/rest/v1/status && printf "\n"
printf "\n=== APP ===\n"
curl -fsS http://localhost:8080/api/tasks && printf "\n"
curl -I -fsS http://localhost:3000/ | head -n 1
```

## Script - 05-down-all.sh

`scripts/05-down-all.sh`

```bash
#!/usr/bin/env sh
set -eu
ROOT="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
cd "$ROOT/codigo_base/deploy"
IMAGE_TAG="${IMAGE_TAG:-dummy}" NEXUS_REGISTRY="${NEXUS_REGISTRY:-localhost:9080}" docker compose down --remove-orphans || true
cd "$ROOT/codigo_base/infra/jenkins_config"
docker compose down || true
cd "$ROOT/codigo_base/infra/nexus_config"
docker compose down || true
```

## Script - 06-create-github-webhook.sh

`scripts/06-create-github-webhook.sh`

```bash
#!/usr/bin/env sh
set -eu

: "${GITHUB_REPO:?Defina GITHUB_REPO=owner/repo}"
: "${GITHUB_TOKEN:?Defina GITHUB_TOKEN con permiso para administrar webhooks}"
: "${SMEE_CHANNEL_URL:?Defina SMEE_CHANNEL_URL=https://smee.io/...}"

curl -fsS -X POST \
  -H "Authorization: Bearer $GITHUB_TOKEN" \
  -H "Accept: application/vnd.github+json" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  "https://api.github.com/repos/$GITHUB_REPO/hooks" \
  -d "{
    \"name\": \"web\",
    \"active\": true,
    \"events\": [\"push\"],
    \"config\": {
      \"url\": \"$SMEE_CHANNEL_URL\",
      \"content_type\": \"json\",
      \"insecure_ssl\": \"0\"
    }
  }"
```

## Cuestionario

Las respuestas técnicas quedaron separadas en `RESPUESTAS_CUESTIONARIO.md`. La reflexión personal de IAG no la dejé fingida como experiencia propia: hay una base para que la ajustes a lo que realmente hiciste.
