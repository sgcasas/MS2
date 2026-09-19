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
        CategoriaResumen categoria,
        /** Promedio de las reseñas del plato, null si todavía no tiene ninguna. */
        BigDecimal calificacionPromedio,
        /** Cantidad de reseñas del plato. */
        long totalResenas
) {
    /** Para platos recién creados o actualizados, que aún no traen el agregado cargado. */
    public static PlatoResponse from(Plato plato) {
        return from(plato, null, 0L);
    }

    public static PlatoResponse from(Plato plato, BigDecimal calificacionPromedio, long totalResenas) {
        return new PlatoResponse(
                plato.getId(),
                plato.getNombre(),
                plato.getDescripcion(),
                plato.getPrecio(),
                plato.isDisponible(),
                plato.getTiempoPreparacionMin(),
                plato.getCalorias(),
                plato.getImagenUrl(),
                CategoriaResumen.from(plato.getCategoria()),
                calificacionPromedio,
                totalResenas
        );
    }
}
