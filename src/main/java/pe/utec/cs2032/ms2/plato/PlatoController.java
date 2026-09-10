package pe.utec.cs2032.ms2.plato;

import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.media.Content;
import io.swagger.v3.oas.annotations.media.Schema;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.responses.ApiResponses;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import pe.utec.cs2032.ms2.common.ApiError;
import pe.utec.cs2032.ms2.common.PageResponse;
import pe.utec.cs2032.ms2.plato.dto.PlatoRequest;
import pe.utec.cs2032.ms2.plato.dto.PlatoResponse;
import pe.utec.cs2032.ms2.plato.dto.PreciosRequest;
import pe.utec.cs2032.ms2.plato.dto.PreciosResponse;

import java.net.URI;

@RestController
@RequestMapping("/api/v1/platos")
@RequiredArgsConstructor
@Tag(name = "Platos", description = "Gestión y consulta de platos del menú")
public class PlatoController {

    private final PlatoService platoService;

    @GetMapping
    @Operation(summary = "Listar platos", description = "Lista paginada de platos, con filtros opcionales por categoría, disponibilidad y texto de búsqueda.")
    @ApiResponses({
            @ApiResponse(responseCode = "200", description = "Página de platos",
                    content = @Content(mediaType = MediaType.APPLICATION_JSON_VALUE, schema = @Schema(implementation = PageResponse.class)))
    })
    public PageResponse<PlatoResponse> listar(
            @Parameter(description = "Número de página (base 0)") @RequestParam(defaultValue = "0") int page,
            @Parameter(description = "Tamaño de página") @RequestParam(defaultValue = "20") int size,
            @Parameter(description = "Filtrar por id de categoría") @RequestParam(required = false) Long categoriaId,
            @Parameter(description = "Filtrar por disponibilidad") @RequestParam(required = false) Boolean disponible,
            @Parameter(description = "Búsqueda por nombre") @RequestParam(required = false) String q
    ) {
        Page<PlatoResponse> resultado = platoService.listar(page, size, categoriaId, disponible, q);
        return PageResponse.of(resultado);
    }

    @GetMapping("/{id}")
    @Operation(summary = "Obtener plato por id")
    @ApiResponses({
            @ApiResponse(responseCode = "200", description = "Plato encontrado",
                    content = @Content(mediaType = MediaType.APPLICATION_JSON_VALUE, schema = @Schema(implementation = PlatoResponse.class))),
            @ApiResponse(responseCode = "404", description = "Plato no encontrado",
                    content = @Content(mediaType = MediaType.APPLICATION_JSON_VALUE, schema = @Schema(implementation = ApiError.class)))
    })
    public PlatoResponse obtener(@PathVariable Long id) {
        return platoService.obtener(id);
    }

    @PostMapping
    @Operation(summary = "Crear plato")
    @ApiResponses({
            @ApiResponse(responseCode = "201", description = "Plato creado",
                    content = @Content(mediaType = MediaType.APPLICATION_JSON_VALUE, schema = @Schema(implementation = PlatoResponse.class))),
            @ApiResponse(responseCode = "400", description = "Datos inválidos",
                    content = @Content(mediaType = MediaType.APPLICATION_JSON_VALUE, schema = @Schema(implementation = ApiError.class))),
            @ApiResponse(responseCode = "404", description = "Categoría no encontrada",
                    content = @Content(mediaType = MediaType.APPLICATION_JSON_VALUE, schema = @Schema(implementation = ApiError.class))),
            @ApiResponse(responseCode = "409", description = "Ya existe un plato con ese nombre en la categoría",
                    content = @Content(mediaType = MediaType.APPLICATION_JSON_VALUE, schema = @Schema(implementation = ApiError.class)))
    })
    public ResponseEntity<PlatoResponse> crear(@Valid @RequestBody PlatoRequest request) {
        PlatoResponse creado = platoService.crear(request);
        return ResponseEntity.created(URI.create("/api/v1/platos/" + creado.id())).body(creado);
    }

    @PutMapping("/{id}")
    @Operation(summary = "Actualizar plato")
    @ApiResponses({
            @ApiResponse(responseCode = "200", description = "Plato actualizado",
                    content = @Content(mediaType = MediaType.APPLICATION_JSON_VALUE, schema = @Schema(implementation = PlatoResponse.class))),
            @ApiResponse(responseCode = "400", description = "Datos inválidos",
                    content = @Content(mediaType = MediaType.APPLICATION_JSON_VALUE, schema = @Schema(implementation = ApiError.class))),
            @ApiResponse(responseCode = "404", description = "Plato o categoría no encontrada",
                    content = @Content(mediaType = MediaType.APPLICATION_JSON_VALUE, schema = @Schema(implementation = ApiError.class))),
            @ApiResponse(responseCode = "409", description = "Ya existe un plato con ese nombre en la categoría",
                    content = @Content(mediaType = MediaType.APPLICATION_JSON_VALUE, schema = @Schema(implementation = ApiError.class)))
    })
    public PlatoResponse actualizar(@PathVariable Long id, @Valid @RequestBody PlatoRequest request) {
        return platoService.actualizar(id, request);
    }

    @DeleteMapping("/{id}")
    @Operation(summary = "Eliminar plato")
    @ApiResponses({
            @ApiResponse(responseCode = "204", description = "Plato eliminado"),
            @ApiResponse(responseCode = "404", description = "Plato no encontrado",
                    content = @Content(mediaType = MediaType.APPLICATION_JSON_VALUE, schema = @Schema(implementation = ApiError.class)))
    })
    public ResponseEntity<Void> eliminar(@PathVariable Long id) {
        platoService.eliminar(id);
        return ResponseEntity.noContent().build();
    }

    @PostMapping("/precios")
    @Operation(summary = "Consultar precios en lote", description = "Devuelve precio y disponibilidad para una lista de ids de platos.")
    @ApiResponses({
            @ApiResponse(responseCode = "200", description = "Precios encontrados/no encontrados",
                    content = @Content(mediaType = MediaType.APPLICATION_JSON_VALUE, schema = @Schema(implementation = PreciosResponse.class))),
            @ApiResponse(responseCode = "400", description = "Datos inválidos",
                    content = @Content(mediaType = MediaType.APPLICATION_JSON_VALUE, schema = @Schema(implementation = ApiError.class)))
    })
    public PreciosResponse precios(@Valid @RequestBody PreciosRequest request) {
        return platoService.precios(request.ids());
    }
}
