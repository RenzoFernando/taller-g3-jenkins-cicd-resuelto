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
        APP_DIR = "pending"
        GIT_COMMIT_SHORT = "pending"
        IMAGE_TAG = "pending"
        MAVEN_VERSION = "pending"

        // Maven corre dentro del contenedor Jenkins y alcanza Nexus por la red cicd_network.
        NEXUS_MAVEN_REPO = "http://nexus:8081/repository/maven-releases/"

        // El Docker CLI de Jenkins usa el socket del host. El daemon del host ve el registry publicado en localhost:9080.
        NEXUS_REGISTRY = "localhost:9080"

        NEXUS_CREDENTIALS_ID = "nexus-credentials"
        VITE_API_URL = "http://localhost:8080"
    }

    stages {
        stage('Checkout & Test') {
            steps {
                checkout scm

                script {
                    def detectedAppDir = sh(
                        script: '''
                            if [ -f codigo_base/backend/pom.xml ]; then
                              printf 'codigo_base'
                            elif [ -f backend/pom.xml ]; then
                              printf '.'
                            else
                              printf '__MISSING__'
                            fi
                        ''',
                        returnStdout: true
                    ).trim()

                    if (detectedAppDir == '__MISSING__') {
                        error('No se encontró backend/pom.xml ni codigo_base/backend/pom.xml en el workspace de Jenkins.')
                    }

                    env.APP_DIR = detectedAppDir
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

                        export NEXUS_REGISTRY="$NEXUS_REGISTRY"
                        export IMAGE_TAG="$IMAGE_TAG"
                        COMPOSE_FILE="$APP_DIR/deploy/docker-compose.yml"

                        test -f "$COMPOSE_FILE"

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
            echo "El pipeline falló. Revise la PRIMERA etapa roja; las posteriores pueden aparecer omitidas por arrastre."
        }
        always {
            sh 'rm -rf "$WORKSPACE/.docker-tmp" || true'
        }
    }
}
