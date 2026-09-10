package pe.utec.cs2032.ms2.plato.dto;

import java.util.List;

public record PreciosResponse(
        List<PrecioItem> encontrados,
        List<Long> noEncontrados
) {
    public record PrecioItem(
            Long id,
            String nombre,
            java.math.BigDecimal precio,
            boolean disponible
    ) {
    }
}
