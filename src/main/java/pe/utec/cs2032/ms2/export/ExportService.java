package pe.utec.cs2032.ms2.export;

import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.RequiredArgsConstructor;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.PreparedStatementCreator;
import org.springframework.jdbc.core.RowCallbackHandler;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.io.BufferedWriter;
import java.io.IOException;
import java.io.OutputStream;
import java.io.OutputStreamWriter;
import java.io.UncheckedIOException;
import java.io.Writer;
import java.math.BigDecimal;
import java.nio.charset.StandardCharsets;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.util.LinkedHashMap;
import java.util.Map;

/**
 * Volcado completo de las tablas para la ingesta a S3 (estrategia pull del 100%
 * de los registros que pide el enunciado del curso).
 * <p>
 * Escribe fila por fila directamente sobre el OutputStream de la respuesta, con
 * un cursor de servidor (fetch size acotado dentro de una transacción de solo
 * lectura). Nunca materializa la tabla completa en memoria: la tabla de reseñas
 * tiene 23,000+ filas y la VM de producción corre varios contenedores.
 * <p>
 * Ojo: se escribe desde el hilo de la petición y NO con StreamingResponseBody a
 * propósito. Con StreamingResponseBody el cuerpo se escribe después de que el
 * controlador retorna, cuando la transacción ya se cerró, y el fetch size deja
 * de tener efecto (el driver de Postgres se trae todo al cliente).
 */
@Service
@RequiredArgsConstructor
public class ExportService {

    private static final int FETCH_SIZE = 500;

    private final JdbcTemplate jdbcTemplate;
    private final ObjectMapper objectMapper;

    @Transactional(readOnly = true)
    public long contar(TablaExportable tabla) {
        Long total = jdbcTemplate.queryForObject(tabla.sqlConteo(), Long.class);
        return total == null ? 0L : total;
    }

    @Transactional(readOnly = true)
    public long exportar(TablaExportable tabla, FormatoExport formato, OutputStream salida) throws IOException {
        String[] columnas = tabla.columnas();
        long[] filas = {0L};

        try (Writer writer = new BufferedWriter(new OutputStreamWriter(salida, StandardCharsets.UTF_8), 32 * 1024)) {

            if (formato == FormatoExport.CSV) {
                writer.write(String.join(",", columnas));
                writer.write("\n");
            }

            PreparedStatementCreator psc = conexion -> {
                PreparedStatement ps = conexion.prepareStatement(
                        tabla.sql(), ResultSet.TYPE_FORWARD_ONLY, ResultSet.CONCUR_READ_ONLY);
                ps.setFetchSize(FETCH_SIZE);
                return ps;
            };

            RowCallbackHandler handler = rs -> {
                try {
                    if (formato == FormatoExport.CSV) {
                        escribirFilaCsv(writer, rs, columnas);
                    } else {
                        escribirFilaNdjson(writer, rs, columnas);
                    }
                    filas[0]++;
                } catch (IOException e) {
                    throw new UncheckedIOException(e);
                }
            };

            jdbcTemplate.query(psc, handler);
            writer.flush();
        } catch (UncheckedIOException e) {
            throw e.getCause();
        }

        return filas[0];
    }

    private void escribirFilaNdjson(Writer writer, ResultSet rs, String[] columnas)
            throws SQLException, IOException {
        Map<String, Object> fila = new LinkedHashMap<>(columnas.length);
        for (int i = 0; i < columnas.length; i++) {
            fila.put(columnas[i], normalizar(rs.getObject(i + 1)));
        }
        writer.write(objectMapper.writeValueAsString(fila));
        writer.write("\n");
    }

    private void escribirFilaCsv(Writer writer, ResultSet rs, String[] columnas)
            throws SQLException, IOException {
        for (int i = 0; i < columnas.length; i++) {
            if (i > 0) {
                writer.write(',');
            }
            writer.write(escaparCsv(rs.getObject(i + 1)));
        }
        writer.write("\n");
    }

    /** Jackson serializa BigDecimal como número y Boolean como true/false; el resto va tal cual. */
    private Object normalizar(Object valor) {
        if (valor instanceof BigDecimal decimal) {
            return decimal;
        }
        return valor;
    }

    /** CSV según RFC 4180: se entrecomilla si hay coma, comilla o salto de línea; la comilla se duplica. */
    private String escaparCsv(Object valor) {
        if (valor == null) {
            return "";
        }
        String texto = (valor instanceof BigDecimal decimal)
                ? decimal.toPlainString()
                : String.valueOf(valor);

        boolean necesitaComillas = texto.indexOf(',') >= 0
                || texto.indexOf('"') >= 0
                || texto.indexOf('\n') >= 0
                || texto.indexOf('\r') >= 0;

        if (!necesitaComillas) {
            return texto;
        }
        return '"' + texto.replace("\"", "\"\"") + '"';
    }
}
