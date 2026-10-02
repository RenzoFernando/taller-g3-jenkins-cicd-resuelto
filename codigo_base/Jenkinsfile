pipeline {
    agent any

    options {
        timestamps()
        disableConcurrentBuilds()
        skipDefaultCheckout(true)
    }

    triggers {
        githubPush()
    }

    environment {
        // En ESTE repositorio la aplicación está siempre dentro de codigo_base/.
        // Se deja fija para evitar sombreado de variables del bloque environment.
        APP_DIR = "codigo_base"

        // Maven corre dentro del contenedor Jenkins y alcanza Nexus por la red cicd_network.
        NEXUS_MAVEN_REPO = "http://nexus:8081/repository/maven-releases/"

        // El Docker CLI de Jenkins usa el socket del host. El daemon del host ve el registry en localhost:9080.
        NEXUS_REGISTRY = "localhost:9080"

        NEXUS_CREDENTIALS_ID = "nexus-credentials"
        VITE_API_URL = "http://localhost:8080"
    }

    stages {
        stage('Checkout & Test') {
            steps {
                checkout scm

                script {
                    if (!fileExists("${env.APP_DIR}/backend/pom.xml")) {
                        error("No existe ${env.APP_DIR}/backend/pom.xml en el workspace. Revise la estructura del repositorio.")
                    }
                    if (!fileExists("${env.APP_DIR}/frontend/Dockerfile")) {
                        error("No existe ${env.APP_DIR}/frontend/Dockerfile en el workspace.")
                    }
                    if (!fileExists("${env.APP_DIR}/deploy/docker-compose.yml")) {
                        error("No existe ${env.APP_DIR}/deploy/docker-compose.yml en el workspace.")
                    }

                    // Estas variables NO se declaran arriba en environment{}, porque Jenkins
                    // no permite sobrescribir de forma fiable variables declarativas con env.VAR.
                    env.GIT_COMMIT_SHORT = sh(
                        script: 'git rev-parse --short=8 HEAD',
                        returnStdout: true
                    ).trim()
                    env.IMAGE_TAG = "${env.BUILD_NUMBER}-${env.GIT_COMMIT_SHORT}"
                    env.MAVEN_VERSION = "1.0.${env.BUILD_NUMBER}-${env.GIT_COMMIT_SHORT}"

                    echo "APP_DIR=${env.APP_DIR}"
                    echo "GIT_COMMIT_SHORT=${env.GIT_COMMIT_SHORT}"
                    echo "IMAGE_TAG=${env.IMAGE_TAG}"
                    echo "MAVEN_VERSION=${env.MAVEN_VERSION}"
                }

                dir("${env.APP_DIR}/backend") {
                    sh 'mvn -B -ntp test -Drevision="$MAVEN_VERSION"'
                }
            }
        }

        stage('Package & Tag Inmutable') {
            steps {
                dir("${env.APP_DIR}/backend") {
                    sh 'mvn -B -ntp clean package -DskipTests -Drevision="$MAVEN_VERSION"'
                    sh '''
                        docker build \
                          --build-arg APP_VERSION="$MAVEN_VERSION" \
                          -t "$NEXUS_REGISTRY/studytrack-api:$IMAGE_TAG" .
                    '''
                }

                dir("${env.APP_DIR}/frontend") {
                    sh '''
                        docker build \
                          --build-arg VITE_API_URL="$VITE_API_URL" \
                          -t "$NEXUS_REGISTRY/studytrack-frontend:$IMAGE_TAG" .
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
                            mvn -B -ntp deploy -DskipTests \
                              -Drevision="$MAVEN_VERSION" \
                              -Dnexus.maven.repo="$NEXUS_MAVEN_REPO" \
                              -s settings.xml
                        '''
                    }

                    sh '''
                        set +x
                        export DOCKER_CONFIG="$WORKSPACE/.docker-tmp"
                        rm -rf "$DOCKER_CONFIG"
                        mkdir -p "$DOCKER_CONFIG"
                        AUTH="$(printf '%s:%s' "$NEXUS_USER" "$NEXUS_PASS" | base64 | tr -d '\n')"
                        printf '{"auths":{"%s":{"auth":"%s"}}}\n' "$NEXUS_REGISTRY" "$AUTH" > "$DOCKER_CONFIG/config.json"
                        set -x

                        docker push "$NEXUS_REGISTRY/studytrack-api:$IMAGE_TAG"
                        docker push "$NEXUS_REGISTRY/studytrack-frontend:$IMAGE_TAG"

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
                        rm -rf "$DOCKER_CONFIG"
                        mkdir -p "$DOCKER_CONFIG"
                        AUTH="$(printf '%s:%s' "$NEXUS_USER" "$NEXUS_PASS" | base64 | tr -d '\n')"
                        printf '{"auths":{"%s":{"auth":"%s"}}}\n' "$NEXUS_REGISTRY" "$AUTH" > "$DOCKER_CONFIG/config.json"
                        set -x

                        COMPOSE_FILE="$APP_DIR/deploy/docker-compose.yml"
                        test -f "$COMPOSE_FILE"

                        export NEXUS_REGISTRY IMAGE_TAG
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

                        ok=0
                        for i in $(seq 1 12); do
                          if curl -fsS http://host.docker.internal:3000/ >/dev/null; then
                            ok=1
                            break
                          fi
                          echo "Smoke test frontend: intento $i/12"
                          sleep 3
                        done

                        if [ "$ok" -ne 1 ]; then
                          docker compose -f "$COMPOSE_FILE" ps
                          docker compose -f "$COMPOSE_FILE" logs --no-color
                          exit 1
                        fi

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
            echo "El pipeline falló. Revise la PRIMERA etapa roja; las posteriores pueden aparecer omitidas por arrastre."
        }
        always {
            sh 'rm -rf "$WORKSPACE/.docker-tmp" || true'
        }
    }
}
