# MS2 — Menú y Platos

Microservicio de menú y platos para el proyecto de Cloud Computing (UTEC, CS2032, ciclo 2026-2).
Expone consultas sobre `categorias`, `platos` y `resenas`, respaldadas por PostgreSQL.

## Stack

- Java 21 + Spring Boot 3.3.x (Maven)
- PostgreSQL 16
- Flyway (migraciones)
- springdoc-openapi (Swagger UI)
- Spring Actuator (`/actuator/health`)
- Puerto: **8082**

## Modelo de datos

Tres tablas relacionadas:

```
categorias 1 ──< N platos 1 ──< N resenas
```

| Tabla | Filas | Para qué |
|---|---|---|
| `categorias` | 12 | Categorías de la carta |
| `platos` | 50 | La carta del restaurante |
| `resenas` | 24,481 | Calificaciones y comentarios de clientes por plato |

El enunciado del curso pide un mínimo de 20,000 registros en **al menos una tabla** de la
base de datos. Esa tabla es `resenas`. La carta se mantiene en 50 platos porque un menú
de 20,000 platos no es realista (indicación de la asesora del curso, 19-set-2026).

**Los datos del seed son determinísticos.** Las migraciones `V3`/`V5` no usan `random()`
ni `now()`: todos los valores salen de aritmética modular sobre `(id, número de fila)` y
de constantes de fecha. Levantar la base en dos máquinas distintas produce **exactamente
los mismos datos**, lo que permite que los archivos cargados al bucket S3 coincidan con
lo que devuelve la API sin importar desde dónde se hizo el volcado.

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

## Endpoints

### Consulta (los que usa el frontend)

```bash
# Listar categorías
curl http://localhost:8082/api/v1/categorias

# Listar platos (paginado, con filtros). Trae calificacionPromedio y totalResenas.
curl "http://localhost:8082/api/v1/platos?page=0&size=10&categoriaId=1&disponible=true"

# Detalle de un plato
curl http://localhost:8082/api/v1/platos/1

# Reseñas de un plato (paginado, de la más reciente a la más antigua)
curl "http://localhost:8082/api/v1/platos/1/resenas?page=0&size=10"
```

### Escritura

```bash
curl -X POST http://localhost:8082/api/v1/categorias \
  -H "Content-Type: application/json" \
  -d '{"nombre": "Postres de autor", "descripcion": "Postres de la casa"}'

curl -X POST http://localhost:8082/api/v1/platos \
  -H "Content-Type: application/json" \
  -d '{"categoriaId": 1, "nombre": "Causa nikkei", "precio": 24.00}'
```

### Consumo desde MS4 (precios en lote)

```bash
curl -X POST http://localhost:8082/api/v1/platos/precios \
  -H "Content-Type: application/json" \
  -d '{"ids": [1, 2, 3]}'
```

### Export para la ingesta a S3

Volcado completo de cada tabla, sin paginación y en streaming. Es lo que consume el
contenedor de ingesta (estrategia *pull* del 100% de los registros). **No es para el
frontend.**

```bash
# NDJSON (por defecto): un objeto JSON plano por línea. Es lo que leen Glue y Athena.
curl -O http://localhost:8082/api/v1/export/categorias
curl -O http://localhost:8082/api/v1/export/platos
curl -O http://localhost:8082/api/v1/export/resenas

# CSV RFC 4180 con cabecera
curl "http://localhost:8082/api/v1/export/platos?formato=csv" -o ms2_platos.csv
```

Cada respuesta trae la cabecera `X-Total-Rows` con el conteo exacto, para verificar de un
vistazo que el archivo bajado está completo:

```bash
curl -s -D- -o ms2_resenas.json http://localhost:8082/api/v1/export/resenas | grep X-Total-Rows
wc -l ms2_resenas.json   # 24481, tiene que coincidir
```

Las filas salen **planas** y con nombres de columna en `snake_case`: la categoría del
plato viene como `categoria_id` + `categoria_nombre`, no anidada. Una columna anidada se
cataloga como `struct` en AWS Glue y complica los JOIN en Athena.

**Al subirlos al bucket, cada tabla va en su propio prefijo**
(`s3://<bucket>/ms2_platos/`, `s3://<bucket>/ms2_resenas/`, …). Si los archivos quedan
sueltos en la raíz, el crawler de Glue los cataloga como una sola tabla con las columnas
mezcladas.

### Salud

```bash
curl http://localhost:8082/actuator/health
```

## Prueba de humo

```bash
BASE_URL=http://localhost:8082 ./scripts/smoke.sh
```

17 casos que cubren el contrato completo: salud, listados, filtros, detalle con agregado
de reseñas, creación, validación de errores, actualización, borrado, precios en lote y los
tres endpoints de export. Es idempotente: crea y borra su propia categoría y plato de
prueba con nombre `ZZ-smoke-<timestamp>`.

## Despliegue rápido en una VM

Para exponer el MS2 rápido con una sola VM temporal (Postgres + app juntos), usar
`scripts/user-data-solo.sh` como User data al lanzar una instancia EC2 Amazon Linux 2023.
El script instala Docker, crea 2 GB de swap, clona el repo, hace `docker compose up -d --build`
y espera a que `/actuator/health` responda `UP` (timeout 10 min), dejando el resultado en
`/var/log/ms2-bootstrap.log`.

Para verificar por SSH que quedó arriba:

```bash
docker compose -f /opt/ms2/docker-compose.yml ps
curl http://localhost:8082/actuator/health
curl "http://localhost:8082/api/v1/platos?size=1"
```

### Actualizar un despliegue existente

Las migraciones `V3`, `V4` y `V5` se aplican encima de una base que ya tiene `V1`/`V2`.
**No hace falta borrar el volumen de Postgres** (y no se debe, si esa VM comparte la base
con otros microservicios del equipo):

```bash
git pull
docker compose up -d --build
docker compose logs -f app   # confirmar que Flyway aplica V3, V4 y V5
```
