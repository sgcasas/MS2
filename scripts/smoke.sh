#!/usr/bin/env bash
#
# Smoke test para MS2 (menú/platos). Requiere curl y jq.
# Idempotente: cualquier dato que crea (una categoría y un plato de prueba)
# lo borra al final, incluso si algún caso falló antes (trap EXIT).
#
# Uso: BASE_URL=http://localhost:8082 ./scripts/smoke.sh
#      ./scripts/smoke.sh http://mi-gateway.example.com

set -u

BASE_URL="${1:-${BASE_URL:-http://localhost:8082}}"
BASE_URL="${BASE_URL%/}"

PASS=0
FAIL=0

TMP_BODY="$(mktemp)"
HDR_FILE="$(mktemp)"

# Ids de lo que el script crea, para el teardown final.
categoria_id=""
plato_id=""

request() {
    local method="$1" path="$2" data="${3:-}"
    if [ -n "$data" ]; then
        curl -s -o "$TMP_BODY" -w '%{http_code}' -X "$method" \
            -H 'Content-Type: application/json' \
            -d "$data" \
            "${BASE_URL}${path}"
    else
        curl -s -o "$TMP_BODY" -w '%{http_code}' -X "$method" \
            "${BASE_URL}${path}"
    fi
}

request_with_headers() {
    local method="$1" path="$2" data="${3:-}"
    if [ -n "$data" ]; then
        curl -s -D "$HDR_FILE" -o "$TMP_BODY" -w '%{http_code}' -X "$method" \
            -H 'Content-Type: application/json' \
            -d "$data" \
            "${BASE_URL}${path}"
    else
        curl -s -D "$HDR_FILE" -o "$TMP_BODY" -w '%{http_code}' -X "$method" \
            "${BASE_URL}${path}"
    fi
}

pass() {
    PASS=$((PASS + 1))
    echo "PASS - $1"
}

fail() {
    FAIL=$((FAIL + 1))
    echo "FAIL - $1"
    if [ -n "${2:-}" ]; then
        echo "       $2"
    fi
}

body() {
    cat "$TMP_BODY"
}

teardown() {
    local rc=$?
    echo
    echo "== Teardown =="

    if [ -n "$plato_id" ] && [ "$plato_id" != "null" ]; then
        code=$(request DELETE "/api/v1/platos/${plato_id}")
        if [ "$code" = "204" ]; then
            echo "OK   - plato de prueba ${plato_id} eliminado"
        elif [ "$code" = "404" ]; then
            echo "OK   - plato de prueba ${plato_id} ya no existía"
        else
            echo "WARN - no se pudo eliminar el plato de prueba ${plato_id} (code=$code body=$(body))"
        fi
    fi

    if [ -n "$categoria_id" ] && [ "$categoria_id" != "null" ]; then
        code=$(request DELETE "/api/v1/categorias/${categoria_id}")
        if [ "$code" = "204" ]; then
            echo "OK   - categoría de prueba ${categoria_id} eliminada"
        elif [ "$code" = "404" ]; then
            echo "OK   - categoría de prueba ${categoria_id} ya no existía"
        else
            echo "WARN - no se pudo eliminar la categoría de prueba ${categoria_id} (code=$code body=$(body))"
        fi
    fi

    rm -f "$TMP_BODY" "$HDR_FILE"
    exit "$rc"
}
trap teardown EXIT

echo "== Smoke test MS2 contra ${BASE_URL} =="
echo

# 1. GET /actuator/health -> 200 y status UP
code=$(request GET "/actuator/health")
if [ "$code" = "200" ] && [ "$(body | jq -r '.status')" = "UP" ]; then
    pass "1. GET /actuator/health -> 200 UP"
else
    fail "1. GET /actuator/health -> 200 UP" "code=$code body=$(body)"
fi

# 2. GET /api/v1/categorias -> están las 12 categorías del seed (por nombre,
#    no por total: el script no debe depender de que la tabla no tenga nada más).
SEED_CATEGORIAS=(
    "Entradas frías" "Entradas calientes" "Sopas y caldos" "Ceviches"
    "Criollos" "Pescados y mariscos" "Carnes" "Pastas" "Chifa"
    "Guarniciones" "Postres" "Bebidas"
)
code=$(request GET "/api/v1/categorias")
if [ "$code" = "200" ]; then
    categorias_json="$(body)"
    faltantes=()
    for nombre in "${SEED_CATEGORIAS[@]}"; do
        existe=$(echo "$categorias_json" | jq --arg n "$nombre" 'any(.[]; .nombre == $n)')
        if [ "$existe" != "true" ]; then
            faltantes+=("$nombre")
        fi
    done
    if [ "${#faltantes[@]}" -eq 0 ]; then
        pass "2. GET /api/v1/categorias -> están las 12 categorías del seed"
    else
        fail "2. GET /api/v1/categorias -> están las 12 categorías del seed" "faltan: ${faltantes[*]}"
    fi
else
    fail "2. GET /api/v1/categorias -> 200" "code=$code body=$(body)"
fi

# 3. GET /api/v1/platos?page=0&size=5 -> la carta tiene un tamaño realista.
#    Desde V3 el menú son ~50 platos: el mínimo de 20,000 registros que pide el
#    enunciado lo cumple la tabla de reseñas (ver caso 15), no la de platos.
code=$(request GET "/api/v1/platos?page=0&size=5")
total=$(body | jq -r '.totalElements' 2>/dev/null)
if [ "$code" = "200" ] && [ -n "$total" ] && [ "$total" != "null" ] && [ "$total" -ge 30 ] && [ "$total" -le 100 ]; then
    pass "3. GET /api/v1/platos?page=0&size=5 -> carta realista, 30-100 platos (totalElements=$total)"
else
    fail "3. GET /api/v1/platos?page=0&size=5 -> carta realista (30-100 platos)" "code=$code totalElements=$total body=$(body)"
fi

# 4. GET /api/v1/platos?categoriaId=1&disponible=true&q=ceviche -> 200
code=$(request GET "/api/v1/platos?categoriaId=1&disponible=true&q=ceviche")
if [ "$code" = "200" ]; then
    pass "4. GET /api/v1/platos?categoriaId=1&disponible=true&q=ceviche -> 200"
else
    fail "4. GET /api/v1/platos?categoriaId=1&disponible=true&q=ceviche -> 200" "code=$code body=$(body)"
fi

# 5. GET /api/v1/platos/{id} con un id de la respuesta del caso 3 -> 200
code=$(request GET "/api/v1/platos?page=0&size=5")
sample_id=$(body | jq -r '.content[0].id' 2>/dev/null)
if [ -n "$sample_id" ] && [ "$sample_id" != "null" ]; then
    code=$(request GET "/api/v1/platos/${sample_id}")
    if [ "$code" = "200" ]; then
        pass "5. GET /api/v1/platos/${sample_id} -> 200"
    else
        fail "5. GET /api/v1/platos/${sample_id} -> 200" "code=$code body=$(body)"
    fi
else
    fail "5. GET /api/v1/platos/{id} -> 200" "no se pudo obtener un id de muestra del listado"
fi

# 6. GET /api/v1/platos/999999999 -> 404 con JSON de error del contrato
code=$(request GET "/api/v1/platos/999999999")
if [ "$code" = "404" ]; then
    b=$(body)
    status_field=$(echo "$b" | jq -r '.status' 2>/dev/null)
    has_fields=$(echo "$b" | jq 'has("timestamp") and has("status") and has("error") and has("mensaje") and has("path")' 2>/dev/null)
    if [ "$has_fields" = "true" ] && [ "$status_field" = "404" ]; then
        pass "6. GET /api/v1/platos/999999999 -> 404 con ApiError"
    else
        fail "6. GET /api/v1/platos/999999999 -> 404 con ApiError" "body no cumple el contrato: $b"
    fi
else
    fail "6. GET /api/v1/platos/999999999 -> 404" "code=$code body=$(body)"
fi

# 7. POST /api/v1/categorias con body válido -> 201 + header Location.
#    Nombre inconfundible y único para que el teardown la reconozca sin dudas
#    y para no romper si se corre dos veces seguidas.
cat_nombre="ZZ-smoke-$(date +%s)-$$"
cat_payload=$(jq -n --arg nombre "$cat_nombre" '{nombre: $nombre, descripcion: "Categoría de smoke test (borrada al final)", activo: true}')
code=$(request_with_headers POST "/api/v1/categorias" "$cat_payload")
location=$(grep -i '^Location:' "$HDR_FILE" | tr -d '\r' | awk '{print $2}')
if [ "$code" = "201" ] && [ -n "$location" ]; then
    categoria_id=$(body | jq -r '.id')
    pass "7. POST /api/v1/categorias -> 201 + Location ($location)"
else
    fail "7. POST /api/v1/categorias -> 201 + Location" "code=$code location='$location' body=$(body)"
fi

# 8. POST /api/v1/platos con body válido -> 201.
#    Se crea dentro de la categoría de prueba del caso 7, nunca en una del seed.
if [ -n "$categoria_id" ] && [ "$categoria_id" != "null" ]; then
    plato_nombre="ZZ-smoke-plato-$(date +%s)-$$"
    plato_payload=$(jq -n --arg nombre "$plato_nombre" --argjson categoriaId "$categoria_id" \
        '{categoriaId: $categoriaId, nombre: $nombre, descripcion: "Plato de smoke test", precio: 19.90, disponible: true, tiempoPreparacionMin: 10, calorias: 500}')
    code=$(request POST "/api/v1/platos" "$plato_payload")
    if [ "$code" = "201" ]; then
        plato_id=$(body | jq -r '.id')
        pass "8. POST /api/v1/platos -> 201 (id=$plato_id)"
    else
        fail "8. POST /api/v1/platos -> 201" "code=$code body=$(body)"
    fi
else
    fail "8. POST /api/v1/platos -> 201" "no hay categoria_id disponible (falló el caso 7)"
fi

# 9. POST /api/v1/platos con precio negativo -> 400
precio_neg_categoria="${categoria_id:-1}"
plato_negativo=$(jq -n --argjson categoriaId "$precio_neg_categoria" \
    '{categoriaId: $categoriaId, nombre: "ZZ-smoke-precio-negativo", precio: -5.00, disponible: true}')
code=$(request POST "/api/v1/platos" "$plato_negativo")
if [ "$code" = "400" ]; then
    pass "9. POST /api/v1/platos con precio negativo -> 400"
else
    fail "9. POST /api/v1/platos con precio negativo -> 400" "code=$code body=$(body)"
fi

# 10. PUT /api/v1/platos/{id} -> 200
if [ -n "$plato_id" ] && [ "$plato_id" != "null" ]; then
    plato_update=$(jq -n --argjson categoriaId "$categoria_id" \
        '{categoriaId: $categoriaId, nombre: "ZZ-smoke-plato-actualizado", descripcion: "Actualizado por smoke test", precio: 24.90, disponible: false, tiempoPreparacionMin: 15, calorias: 600}')
    code=$(request PUT "/api/v1/platos/${plato_id}" "$plato_update")
    if [ "$code" = "200" ]; then
        pass "10. PUT /api/v1/platos/${plato_id} -> 200"
    else
        fail "10. PUT /api/v1/platos/${plato_id} -> 200" "code=$code body=$(body)"
    fi
else
    fail "10. PUT /api/v1/platos/{id} -> 200" "no hay plato_id disponible (falló el caso 8)"
fi

# 11. POST /api/v1/platos/precios con 2 ids válidos y 1 inválido
valid_id_1="$sample_id"
valid_id_2="$plato_id"
invalid_id="999999999"
if [ -n "$valid_id_1" ] && [ "$valid_id_1" != "null" ] && [ -n "$valid_id_2" ] && [ "$valid_id_2" != "null" ]; then
    precios_payload=$(jq -n --argjson a "$valid_id_1" --argjson b "$valid_id_2" --argjson c "$invalid_id" \
        '{ids: [$a, $b, $c]}')
    code=$(request POST "/api/v1/platos/precios" "$precios_payload")
    encontrados=$(body | jq '.encontrados | length' 2>/dev/null)
    no_encontrados=$(body | jq '.noEncontrados | length' 2>/dev/null)
    if [ "$code" = "200" ] && [ "$encontrados" = "2" ] && [ "$no_encontrados" = "1" ]; then
        pass "11. POST /api/v1/platos/precios -> encontrados=2, noEncontrados=1"
    else
        fail "11. POST /api/v1/platos/precios -> encontrados=2, noEncontrados=1" "code=$code encontrados=$encontrados noEncontrados=$no_encontrados body=$(body)"
    fi
else
    fail "11. POST /api/v1/platos/precios -> encontrados=2, noEncontrados=1" "faltan ids válidos (sample_id=$valid_id_1, plato_id=$valid_id_2)"
fi

# 12. DELETE /api/v1/platos/{id} -> 204
if [ -n "$plato_id" ] && [ "$plato_id" != "null" ]; then
    code=$(request DELETE "/api/v1/platos/${plato_id}")
    if [ "$code" = "204" ]; then
        pass "12. DELETE /api/v1/platos/${plato_id} -> 204"
        plato_id=""   # ya lo borramos aquí, el teardown no necesita repetirlo
    else
        fail "12. DELETE /api/v1/platos/${plato_id} -> 204" "code=$code body=$(body)"
    fi
else
    fail "12. DELETE /api/v1/platos/{id} -> 204" "no hay plato_id disponible (falló el caso 8)"
fi


# 13. GET /api/v1/platos/{id}/resenas -> 200 con al menos una reseña
if [ -n "$sample_id" ] && [ "$sample_id" != "null" ]; then
    code=$(request GET "/api/v1/platos/${sample_id}/resenas?page=0&size=5")
    total_resenas=$(body | jq -r '.totalElements' 2>/dev/null)
    if [ "$code" = "200" ] && [ -n "$total_resenas" ] && [ "$total_resenas" != "null" ] && [ "$total_resenas" -gt 0 ]; then
        pass "13. GET /api/v1/platos/${sample_id}/resenas -> 200 (totalElements=$total_resenas)"
    else
        fail "13. GET /api/v1/platos/${sample_id}/resenas -> 200 con reseñas" "code=$code totalElements=$total_resenas body=$(body)"
    fi
else
    fail "13. GET /api/v1/platos/{id}/resenas -> 200" "no hay sample_id disponible"
fi

# 14. GET /api/v1/platos/{id} -> trae el agregado de reseñas
if [ -n "$sample_id" ] && [ "$sample_id" != "null" ]; then
    code=$(request GET "/api/v1/platos/${sample_id}")
    prom=$(body | jq -r '.calificacionPromedio' 2>/dev/null)
    tot=$(body | jq -r '.totalResenas' 2>/dev/null)
    if [ "$code" = "200" ] && [ "$prom" != "null" ] && [ -n "$tot" ] && [ "$tot" != "null" ] && [ "$tot" -gt 0 ]; then
        pass "14. GET /api/v1/platos/${sample_id} -> agregado de reseñas (promedio=$prom, total=$tot)"
    else
        fail "14. GET /api/v1/platos/{id} -> agregado de reseñas" "code=$code promedio=$prom total=$tot body=$(body)"
    fi
else
    fail "14. GET /api/v1/platos/{id} -> agregado de reseñas" "no hay sample_id disponible"
fi

# 15. GET /api/v1/export/resenas -> el volcado completo, con >= 20,000 filas.
#     Este es el caso que demuestra el mínimo de registros del enunciado y que la
#     ingesta puede hacer pull del 100% de los datos.
code=$(request_with_headers GET "/api/v1/export/resenas")
filas_header=$(grep -i '^X-Total-Rows:' "$HDR_FILE" | tr -d '\r' | awk '{print $2}')
filas_body=$(wc -l < "$TMP_BODY" | tr -d ' ')
if [ "$code" = "200" ] && [ -n "$filas_header" ] && [ "$filas_header" -ge 20000 ] && [ "$filas_header" = "$filas_body" ]; then
    pass "15. GET /api/v1/export/resenas -> $filas_body filas NDJSON (>= 20000, coincide con X-Total-Rows)"
else
    fail "15. GET /api/v1/export/resenas -> >= 20000 filas y X-Total-Rows coincidente" \
         "code=$code X-Total-Rows=$filas_header lineas=$filas_body"
fi

# 16. GET /api/v1/export/platos?formato=csv -> cabecera correcta y filas planas
code=$(request_with_headers GET "/api/v1/export/platos?formato=csv")
cabecera=$(head -1 "$TMP_BODY" | tr -d '\r')
esperada="id,categoria_id,categoria_nombre,nombre,descripcion,precio,disponible,tiempo_preparacion_min,calorias,imagen_url,creado_en,actualizado_en"
filas_header=$(grep -i '^X-Total-Rows:' "$HDR_FILE" | tr -d '\r' | awk '{print $2}')
filas_body=$(( $(wc -l < "$TMP_BODY") - 1 ))
if [ "$code" = "200" ] && [ "$cabecera" = "$esperada" ] && [ "$filas_header" = "$filas_body" ]; then
    pass "16. GET /api/v1/export/platos?formato=csv -> cabecera plana + $filas_body filas"
else
    fail "16. GET /api/v1/export/platos?formato=csv -> cabecera plana y conteo coincidente" \
         "code=$code cabecera='$cabecera' X-Total-Rows=$filas_header filas=$filas_body"
fi

# 17. GET /api/v1/export/platos con formato inválido -> 400 con ApiError
code=$(request GET "/api/v1/export/platos?formato=xml")
if [ "$code" = "400" ]; then
    pass "17. GET /api/v1/export/platos?formato=xml -> 400"
else
    fail "17. GET /api/v1/export/platos?formato=xml -> 400" "code=$code body=$(head -c 200 "$TMP_BODY")"
fi

echo
echo "== Resultado: ${PASS} PASS, ${FAIL} FAIL =="

if [ "$FAIL" -gt 0 ]; then
    exit 1
fi
exit 0
