package pe.utec.cs2032.ms2.resena;

import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.media.Content;
import io.swagger.v3.oas.annotations.media.Schema;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.responses.ApiResponses;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.http.MediaType;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import pe.utec.cs2032.ms2.common.ApiError;
import pe.utec.cs2032.ms2.common.PageResponse;
import pe.utec.cs2032.ms2.resena.dto.ResenaResponse;

@RestController
@RequestMapping("/api/v1/platos/{platoId}/resenas")
@RequiredArgsConstructor
@Tag(name = "Reseñas", description = "Reseñas de clientes por plato")
public class ResenaController {

    private final ResenaService resenaService;

    @GetMapping
    @Operation(summary = "Listar reseñas de un plato",
            description = "Lista paginada de reseñas de un plato, de la más reciente a la más antigua. "
                    + "El tamaño de página está topeado en 200.")
    @ApiResponses({
            @ApiResponse(responseCode = "200", description = "Página de reseñas",
                    content = @Content(mediaType = MediaType.APPLICATION_JSON_VALUE,
                            schema = @Schema(implementation = PageResponse.class))),
            @ApiResponse(responseCode = "404", description = "Plato no encontrado",
                    content = @Content(mediaType = MediaType.APPLICATION_JSON_VALUE,
                            schema = @Schema(implementation = ApiError.class)))
    })
    public PageResponse<ResenaResponse> listar(
            @PathVariable Long platoId,
            @Parameter(description = "Número de página (base 0)") @RequestParam(defaultValue = "0") int page,
            @Parameter(description = "Tamaño de página (máx. 200)") @RequestParam(defaultValue = "20") int size
    ) {
        Page<ResenaResponse> resultado = resenaService.listarPorPlato(platoId, page, size);
        return PageResponse.of(resultado);
    }
}
