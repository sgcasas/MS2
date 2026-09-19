package pe.utec.cs2032.ms2.export;

/**
 * Definición de cada volcado: el SQL que lo produce y los nombres de columna en
 * snake_case. Las filas salen PLANAS (nada anidado) porque el destino es un
 * catálogo de AWS Glue: una columna anidada se cataloga como struct y complica
 * los JOIN en Athena. Las fechas ya salen formateadas como texto ISO-8601 UTC
 * desde la consulta, para que CSV y NDJSON muestren exactamente lo mismo.
 */
public enum TablaExportable {

    CATEGORIAS(
            "ms2_categorias",
            "SELECT count(*) FROM categorias",
            """
            SELECT id,
                   nombre,
                   descripcion,
                   activo,
                   to_char(creado_en AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"') AS creado_en
            FROM categorias
            ORDER BY id
            """,
            new String[]{"id", "nombre", "descripcion", "activo", "creado_en"}),

    PLATOS(
            "ms2_platos",
            "SELECT count(*) FROM platos",
            """
            SELECT p.id,
                   p.categoria_id,
                   c.nombre AS categoria_nombre,
                   p.nombre,
                   p.descripcion,
                   p.precio,
                   p.disponible,
                   p.tiempo_preparacion_min,
                   p.calorias,
                   p.imagen_url,
                   to_char(p.creado_en      AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"') AS creado_en,
                   to_char(p.actualizado_en AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"') AS actualizado_en
            FROM platos p
            JOIN categorias c ON c.id = p.categoria_id
            ORDER BY p.id
            """,
            new String[]{"id", "categoria_id", "categoria_nombre", "nombre", "descripcion", "precio",
                    "disponible", "tiempo_preparacion_min", "calorias", "imagen_url",
                    "creado_en", "actualizado_en"}),

    RESENAS(
            "ms2_resenas",
            "SELECT count(*) FROM resenas",
            """
            SELECT id,
                   plato_id,
                   calificacion,
                   comentario,
                   autor,
                   to_char(creado_en AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"') AS creado_en
            FROM resenas
            ORDER BY id
            """,
            new String[]{"id", "plato_id", "calificacion", "comentario", "autor", "creado_en"});

    private final String nombreArchivo;
    private final String sqlConteo;
    private final String sql;
    private final String[] columnas;

    TablaExportable(String nombreArchivo, String sqlConteo, String sql, String[] columnas) {
        this.nombreArchivo = nombreArchivo;
        this.sqlConteo = sqlConteo;
        this.sql = sql;
        this.columnas = columnas;
    }

    public String nombreArchivo() {
        return nombreArchivo;
    }

    public String sqlConteo() {
        return sqlConteo;
    }

    public String sql() {
        return sql;
    }

    public String[] columnas() {
        return columnas.clone();
    }
}
