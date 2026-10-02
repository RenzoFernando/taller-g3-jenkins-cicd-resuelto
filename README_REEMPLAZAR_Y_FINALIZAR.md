# Parche final — Taller G3 Jenkins CI/CD

Este ZIP contiene **solo archivos para reemplazar/agregar** sobre tu proyecto actual. No incluye `.env`, contraseñas, PAT ni el volumen de Jenkins/Nexus.

## Qué corrige

1. `Jenkinsfile`: elimina la detección problemática con `fileExists()` y detecta la estructura mediante shell después del checkout. Además usa `skipDefaultCheckout(true)`, valida rutas y calcula de forma estable `APP_DIR`, `IMAGE_TAG` y `MAVEN_VERSION`.
2. `plugins.txt`: elimina versiones antiguas fijadas que ya causaron conflictos de dependencias al construir Jenkins.
3. `bootstrap-nexus.sh`: corrige el problema de Git Bash/MSYS con `/nexus-data/admin.password` y hace el bootstrap más reejecutable.
4. `03-up-jenkins.sh`: corrige el mismo problema de rutas de Git Bash para la clave inicial y no falla si Jenkins ya fue configurado.
5. `.gitignore`: ignora `.idea/` y mantiene fuera de Git los `.env` y secretos.
6. Se vuelven a incluir los archivos críticos de Maven, Docker, Compose y Nginx para que puedas sobrescribirlos y dejar una base coherente.
7. Se agrega `scripts/07-preflight.sh` para comprobar Nexus, registry, Docker socket y conectividad Jenkins→Nexus antes de disparar otro build.

## Cómo aplicarlo

Descomprime este ZIP **encima de la raíz de tu proyecto**:

```text
taller-g3-jenkins-cicd-resuelto/
├── Jenkinsfile
├── codigo_base/
├── scripts/
└── ...
```

Debe preguntar si quieres reemplazar archivos: responde **sí**.

No borres ni reemplaces:

```text
codigo_base/infra/jenkins_config/.env
codigo_base/infra/nexus_config/.env
```

porque contienen tu configuración local.

## Qué ejecutar después

Desde Git Bash en la raíz:

```bash
./scripts/07-preflight.sh

git status
git add Jenkinsfile .gitignore codigo_base scripts
git commit -m "fix: stabilize Jenkins Nexus CI/CD pipeline"
git push origin main
```

El push debe disparar Jenkins automáticamente si el webhook GitHub → Smee ya está configurado. Si no se dispara, configura el webhook con la **misma** URL Smee que tienes en `codigo_base/infra/jenkins_config/.env` y usa `application/json` + `Just the push event`.

En el build correcto debes ver:

```text
APP_DIR=codigo_base
IMAGE_TAG=<BUILD_NUMBER>-<8 caracteres del commit>
MAVEN_VERSION=1.0.<BUILD_NUMBER>-<8 caracteres del commit>
```

Y las cuatro etapas deben quedar verdes:

```text
Checkout & Test
Package & Tag Inmutable
Publish to Nexus
Deploy & Smoke Test
```

## Si falla en `docker push` con HTTPS/HTTP

Si aparece algo como:

```text
server gave HTTP response to HTTPS client
```

Docker Desktop → Settings → Docker Engine y agrega, conservando el resto de tu JSON:

```json
"insecure-registries": ["localhost:9080"]
```

Luego **Apply & Restart** y vuelve a ejecutar el build. En muchos Docker Desktop `localhost` ya es aceptado como registry local, así que solo haz esto si aparece ese error.

## ¿Cuándo está técnicamente terminado?

La implementación queda terminada cuando un **push real** a `main` dispara automáticamente el pipeline por Smee y el último build queda **SUCCESS** con las 4 etapas verdes, el JAR aparece en `maven-releases`, las dos imágenes aparecen en `docker-hosted`, y `http://localhost:8080/api/tasks` + `http://localhost:3000` responden.

Después de eso ya no falta código del taller; falta **documentar/entregar evidencia**: capturas de Jenkins verde, webhook/Smee, Nexus con artefactos, enlace al repo y completar cuestionario + reflexión/bitácora IAG del documento de resultados.
