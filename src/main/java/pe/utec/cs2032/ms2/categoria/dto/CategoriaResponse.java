package pe.utec.cs2032.ms2.categoria.dto;

import pe.utec.cs2032.ms2.categoria.Categoria;

import java.time.Instant;

public record CategoriaResponse(
        Long id,
        String nombre,
        String descripcion,
        boolean activo,
        Instant creadoEn
) {
    public static CategoriaResponse from(Categoria categoria) {
        return new CategoriaResponse(
                categoria.getId(),
                categoria.getNombre(),
                categoria.getDescripcion(),
                categoria.isActivo(),
                categoria.getCreadoEn()
        );
    }
}
