package pe.utec.cs2032.ms2.resena;

/**
 * Proyección para traer el agregado de reseñas de varios platos en UNA sola
 * consulta, en vez de una por plato (N+1) al armar el listado.
 */
public interface ResumenResenas {

    Long getPlatoId();

    Double getPromedio();

    Long getTotal();
}
