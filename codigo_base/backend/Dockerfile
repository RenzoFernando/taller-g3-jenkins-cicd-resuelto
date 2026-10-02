FROM maven:3.9.6-eclipse-temurin-17-alpine AS builder
WORKDIR /workspace

ARG APP_VERSION=1.0.0-local

COPY pom.xml ./
RUN mvn -B -q -DskipTests dependency:go-offline

COPY src ./src
RUN mvn -B -ntp clean package -DskipTests -Drevision="${APP_VERSION}"

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
