# MS2 — Menú y Platos

Microservicio de menú y platos para el proyecto de Cloud Computing (UTEC, Ciclo 4).
Expone consultas sobre `categorias` y `platos` (relación 1-N), respaldadas por PostgreSQL.

## Stack

- Java 21 + Spring Boot 3.3.x (Maven)
- PostgreSQL 16
- Flyway (migraciones)
- springdoc-openapi (Swagger UI)
- Spring Actuator (`/actuator/health`)
- Puerto: **8082**

## Cómo levantarlo (local, con Docker Compose)

```bash
docker compose up --build
```

Esto levanta Postgres y la aplicación. La API queda disponible en `http://localhost:8082`.

## Swagger

- UI: http://localhost:8082/swagger-ui.html
- OpenAPI JSON: http://localhost:8082/v3/api-docs

El host que ve "Try it out" en el `server-url` del OpenAPI se controla con la variable
de entorno `PUBLIC_API_URL` (default `http://localhost:8082`). Al desplegar detrás del
API Gateway con un prefijo de stage, setear `PUBLIC_API_URL` al host+prefijo público
(p. ej. `https://api.example.com/prod`) para que las pruebas desde Swagger apunten al
lugar correcto.

## Ejemplos con curl

```bash
# Listar categorías
curl http://localhost:8082/api/v1/categorias

# Crear una categoría
curl -X POST http://localhost:8082/api/v1/categorias \
  -H "Content-Type: application/json" \
  -d '{"nombre": "Postres", "descripcion": "Postres tradicionales"}'

# Listar platos (paginado, con filtros)
curl "http://localhost:8082/api/v1/platos?page=0&size=10&categoriaId=1&disponible=true"

# Crear un plato
curl -X POST http://localhost:8082/api/v1/platos \
  -H "Content-Type: application/json" \
  -d '{"categoriaId": 1, "nombre": "Causa limeña", "precio": 18.50}'

# Consultar precios en lote
curl -X POST http://localhost:8082/api/v1/platos/precios \
  -H "Content-Type: application/json" \
  -d '{"ids": [1, 2, 3]}'

# Health check
curl http://localhost:8082/actuator/health
```

## Despliegue rápido en una VM

Para exponer el MS2 rápido con una sola VM temporal (Postgres + app juntos), usar
`scripts/user-data-solo.sh` como User data al lanzar una instancia EC2 Amazon Linux 2023.
El script instala Docker, crea 2 GB de swap, clona el repo, hace `docker compose up -d --build`
y espera a que `/actuator/health` responda `UP` (timeout 10 min), dejando el resultado en
`/var/log/ms2-bootstrap.log`.

Para verificar por SSH que quedó arriba:

```bash
# Contenedores corriendo (db + app)
docker compose -f /opt/ms2/docker-compose.yml ps

# Health check
curl http://localhost:8082/actuator/health

# Datos de ejemplo (debe mostrar totalElements)
curl "http://localhost:8082/api/v1/platos?size=1"
```
