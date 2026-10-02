# Respuestas técnicas

## 1. Empaquetamiento inmutable

`:latest` no identifica de forma estable un artefacto: la misma etiqueta puede apuntar a contenidos distintos en momentos distintos, impidiendo reproducir exactamente un despliegue o auditar qué código lo produjo. En esta solución cada imagen usa `${BUILD_NUMBER}-${GIT_COMMIT_SHORT}` y el JAR usa `1.0.${BUILD_NUMBER}-${GIT_COMMIT_SHORT}`. Así el build de Jenkins y el hash del commit quedan ligados al artefacto publicado.

## 2. Webhooks vía Smee.io

Jenkins corre en la máquina local y no tiene una URL pública enrutable desde GitHub. Smee.io recibe el webhook en un endpoint HTTPS público y `smee-client` mantiene una conexión saliente para reenviarlo a `http://jenkins:8080/github-webhook/`. Si el relay/canal está detenido durante un push, Jenkins no recibe ese evento en tiempo real y el pipeline no se dispara automáticamente por ese webhook; debe recuperarse el relay y volver a generar un evento o ejecutar el build manualmente.

# Bitácora IAG - base para personalizar

- Fase 2: revisión de Dockerfiles multi-stage y usuario no root.
- Fase 2: parametrización de versión Maven y `distributionManagement` hacia Nexus.
- Fase 3: completado de Docker Compose para Nexus, Jenkins y Smee.
- Fase 4: construcción del Jenkinsfile con tag inmutable, credenciales de Jenkins, publicación en Nexus y smoke test.
- Depuración: diferencia entre el hostname de Nexus visto por Maven dentro de Docker (`nexus:8081`) y el registry visto por el Docker daemon del host (`localhost:9080`).

> La reflexión personal de 150 palabras debe ajustarse a lo que realmente ocurrió durante la ejecución y a las decisiones que tomó el estudiante.
