package pe.utec.cs2032.ms2.plato.dto;

import pe.utec.cs2032.ms2.categoria.dto.CategoriaResumen;
import pe.utec.cs2032.ms2.plato.Plato;

import java.math.BigDecimal;

public record PlatoResponse(
        Long id,
        String nombre,
        String descripcion,
        BigDecimal precio,
        boolean disponible,
        Integer tiempoPreparacionMin,
        Integer calorias,
        String imagenUrl,
        CategoriaResumen categoria
) {
    public static PlatoResponse from(Plato plato) {
        return new PlatoResponse(
                plato.getId(),
                plato.getNombre(),
                plato.getDescripcion(),
                plato.getPrecio(),
                plato.isDisponible(),
                plato.getTiempoPreparacionMin(),
                plato.getCalorias(),
                plato.getImagenUrl(),
                CategoriaResumen.from(plato.getCategoria())
        );
    }
}
