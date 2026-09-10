package pe.utec.cs2032.ms2.categoria.dto;

import pe.utec.cs2032.ms2.categoria.Categoria;

public record CategoriaResumen(
        Long id,
        String nombre
) {
    public static CategoriaResumen from(Categoria categoria) {
        return new CategoriaResumen(categoria.getId(), categoria.getNombre());
    }
}
