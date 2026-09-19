package pe.utec.cs2032.ms2.export;

import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.media.Content;
import io.swagger.v3.oas.annotations.media.Schema;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.responses.ApiResponses;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.servlet.http.HttpServletResponse;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import pe.utec.cs2032.ms2.common.ApiError;

import java.io.IOException;

/**
 * Volcado completo de cada tabla, para el contenedor de ingesta que sube los
 * archivos al bucket S3 y luego se catalogan con AWS Glue y se consultan con
 * Athena. No es para el frontend: para la web están los endpoints paginados.
 */
@RestController
@RequestMapping("/api/v1/export")
@RequiredArgsConstructor
@Tag(name = "Export (ingesta)", description = "Volcado completo de las tablas para la ingesta a S3")
public class ExportController {

    private final ExportService exportService;

    @GetMapping("/categorias")
    @Operation(summary = "Exportar todas las categorías",
            description = "Devuelve el 100% de la tabla categorias, sin paginación. "
                    + "Formatos: ndjson (por defecto) o csv.")
    @ApiResponses({
            @ApiResponse(responseCode = "200", description = "Volcado completo (NDJSON o CSV)"),
            @ApiResponse(responseCode = "400", description = "Formato no soportado",
                    content = @Content(mediaType = MediaType.APPLICATION_JSON_VALUE,
                            schema = @Schema(implementation = ApiError.class)))
    })
    public void categorias(
            @Parameter(description = "ndjson (por defecto) o csv") @RequestParam(required = false) String formato,
            HttpServletResponse response) throws IOException {
        volcar(TablaExportable.CATEGORIAS, formato, response);
    }

    @GetMapping("/platos")
    @Operation(summary = "Exportar todos los platos",
            description = "Devuelve el 100% de la tabla platos con la categoría aplanada "
                    + "(categoria_id y categoria_nombre como columnas), sin paginación.")
    @ApiResponses({
            @ApiResponse(responseCode = "200", description = "Volcado completo (NDJSON o CSV)"),
            @ApiResponse(responseCode = "400", description = "Formato no soportado",
                    content = @Content(mediaType = MediaType.APPLICATION_JSON_VALUE,
                            schema = @Schema(implementation = ApiError.class)))
    })
    public void platos(
            @Parameter(description = "ndjson (por defecto) o csv") @RequestParam(required = false) String formato,
            HttpServletResponse response) throws IOException {
        volcar(TablaExportable.PLATOS, formato, response);
    }

    @GetMapping("/resenas")
    @Operation(summary = "Exportar todas las reseñas",
            description = "Devuelve el 100% de la tabla resenas (23,000+ filas) en streaming, sin paginación. "
                    + "Es la tabla que cumple el mínimo de 20,000 registros del enunciado.")
    @ApiResponses({
            @ApiResponse(responseCode = "200", description = "Volcado completo (NDJSON o CSV)"),
            @ApiResponse(responseCode = "400", description = "Formato no soportado",
                    content = @Content(mediaType = MediaType.APPLICATION_JSON_VALUE,
                            schema = @Schema(implementation = ApiError.class)))
    })
    public void resenas(
            @Parameter(description = "ndjson (por defecto) o csv") @RequestParam(required = false) String formato,
            HttpServletResponse response) throws IOException {
        volcar(TablaExportable.RESENAS, formato, response);
    }

    /**
     * El formato se resuelve ANTES de tocar el OutputStream: si es inválido, el
     * manejador global puede devolver un 400 con el JSON de error del contrato.
     * Una vez que empieza el streaming la respuesta ya está comprometida y no se
     * puede cambiar el código de estado.
     */
    private void volcar(TablaExportable tabla, String formatoParam, HttpServletResponse response)
            throws IOException {
        FormatoExport formato = FormatoExport.desde(formatoParam);
        long total = exportService.contar(tabla);

        response.setStatus(HttpServletResponse.SC_OK);
        response.setContentType(formato.contentType());
        response.setCharacterEncoding("UTF-8");
        response.setHeader(HttpHeaders.CONTENT_DISPOSITION,
                "attachment; filename=\"" + tabla.nombreArchivo() + "." + formato.extension() + "\"");
        // Permite verificar de un vistazo que el archivo bajado tiene todas las filas.
        response.setHeader("X-Total-Rows", String.valueOf(total));

        exportService.exportar(tabla, formato, response.getOutputStream());
    }
}
